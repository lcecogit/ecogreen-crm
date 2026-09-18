-- ==========================================================================
--  EcoGreen Group CRM — PART 4 — FUNCTIONS: intake, booking, scheduler, job sheets, GDPR
--
--  Safe to re-run. Run the parts in order: 1, 2, 3, 4, 5.
-- ==========================================================================

-- ---------------------------------------------------------------------------
-- Bootstrap. Present at the top of EVERY part so each one stands alone and no
-- part can fail with "schema private does not exist". Helpers live outside
-- `public` so that RLS policies which call them cannot recurse back through
-- the very tables those policies protect.
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Prerequisite check: a clear message beats a cryptic error.
do $precheck$
begin
    if to_regclass('public.leads') is null then
      raise exception 'Run PARTS 1-3 first — table "leads" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.quotes') is null then
      raise exception 'Run PARTS 1-3 first — table "quotes" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.outbox') is null then
      raise exception 'Run PARTS 1-3 first — table "outbox" does not exist.'
        using errcode = 'undefined_table';
    end if;
end
$precheck$;

create or replace function create_intake_lead(
  p_brand_id uuid,
  p_payload jsonb,
  p_first_name text,
  p_last_name text,
  p_email text,
  p_email_normalised text,
  p_phone text,
  p_phone_normalised text,
  p_customer_type text,
  p_move_date date,
  p_origin_postcode text,
  p_destination_postcode text,
  p_origin_outward text,
  p_destination_outward text,
  p_first_touch jsonb,
  p_marketing_consent boolean,
  p_owner_staff_id uuid,
  p_assignment_rule text,
  p_score int,
  p_score_components jsonb,
  p_duplicate_of uuid,
  p_overlap_of uuid
)
returns table (lead_id uuid, reference text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid;
  v_lead_id uuid;
  v_reference text;
begin
  -- Reuse an existing customer in this brand when the contact details match,
  -- so a repeat enquirer does not accumulate duplicate customer rows.
  select c.id into v_customer_id
  from public.customers c
  where c.brand_id = p_brand_id
    and (
      (p_email_normalised is not null and c.email_normalised = p_email_normalised)
      or (p_phone_normalised is not null and c.phone_normalised = p_phone_normalised)
    )
  limit 1;

  if v_customer_id is null then
    insert into public.customers (
      brand_id, first_name, last_name, email, email_normalised, phone, phone_normalised,
      marketing_consent, consent_source, consent_at
    )
    values (
      p_brand_id, p_first_name, p_last_name, p_email, p_email_normalised, p_phone, p_phone_normalised,
      coalesce(p_marketing_consent, false),
      case when p_marketing_consent then 'website_intake' end,
      case when p_marketing_consent then now() end
    )
    returning id into v_customer_id;
  end if;

  v_reference := public.next_reference(p_brand_id, 'lead');

  insert into public.leads (
    brand_id, reference, customer_id, customer_type, status, owner_staff_id, assigned_at,
    move_date, origin_postcode, destination_postcode, origin_outward, destination_outward,
    first_touch, last_touch, raw_payload, score, score_components,
    duplicate_of_lead_id, cross_brand_overlap_lead_id
  )
  values (
    p_brand_id, v_reference, v_customer_id, p_customer_type::public.customer_type,
    -- A same-brand duplicate never enters the working pipeline.
    case when p_duplicate_of is not null then 'duplicate' else 'new' end::public.lead_status,
    p_owner_staff_id,
    case when p_owner_staff_id is not null then now() end,
    p_move_date, p_origin_postcode, p_destination_postcode, p_origin_outward, p_destination_outward,
    coalesce(p_first_touch, '{}'::jsonb), coalesce(p_first_touch, '{}'::jsonb), coalesce(p_payload, '{}'::jsonb),
    p_score, coalesce(p_score_components, '[]'::jsonb),
    p_duplicate_of, p_overlap_of
  )
  returning id into v_lead_id;

  insert into public.lead_events (lead_id, type, payload)
  values (v_lead_id, 'created', jsonb_build_object('assignment_rule', p_assignment_rule, 'score', p_score));

  if p_owner_staff_id is not null then
    update public.staff set last_assigned_at = now() where id = p_owner_staff_id;
  end if;

  -- A cross-brand overlap is flagged on BOTH leads: which brand takes the job
  -- is a commercial decision, and hiding it from one side would prejudice it.
  if p_overlap_of is not null then
    insert into public.lead_events (lead_id, type, payload)
    values (p_overlap_of, 'cross_brand_overlap', jsonb_build_object('other_lead_id', v_lead_id));
  end if;

  if p_duplicate_of is not null then
    insert into public.lead_events (lead_id, type, payload)
    values (p_duplicate_of, 'duplicate_submission', jsonb_build_object('other_lead_id', v_lead_id));
  end if;

  return query select v_lead_id, v_reference;
end;
$$;

revoke all on function create_intake_lead from public, anon, authenticated;

-- ── Booking ───────────────────────────────────────────────────────────────
-- Accept the quote, create the job from the FROZEN quote data, raise the
-- invoice, advance the lead, stop the chase, and record it. Any failure rolls
-- the whole thing back: a job with no invoice is worse than a failed booking.
create or replace function book_accepted_quote(
  p_quote_id uuid,
  p_actor_staff_id uuid default null
)
returns table (job_id uuid, job_reference text, invoice_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_quote public.quotes%rowtype;
  v_lead public.leads%rowtype;
  v_job_id uuid;
  v_job_reference text;
  v_invoice_id uuid;
begin
  select * into v_quote from public.quotes where id = p_quote_id for update;
  if not found then
    raise exception 'Quote % not found', p_quote_id using errcode = 'no_data_found';
  end if;
  if v_quote.status not in ('sent','viewed','accepted') then
    raise exception 'Quote % is %, so it cannot be booked', p_quote_id, v_quote.status
      using errcode = 'invalid_parameter_value';
  end if;
  -- 'accepted' is a legal input status so that a retried booking is safe to
  -- call, but a quote that already produced a job must not produce a second
  -- one: that would raise two invoices for the same move.
  if exists (select 1 from public.jobs j where j.quote_id = p_quote_id and j.status <> 'cancelled') then
    raise exception 'Quote % is already booked', p_quote_id using errcode = 'unique_violation';
  end if;

  if v_quote.requires_manual_pricing then
    raise exception 'Quote % needs a price from the team before it can be booked', p_quote_id
      using errcode = 'invalid_parameter_value';
  end if;

  select * into v_lead from public.leads where id = v_quote.lead_id for update;

  update public.quotes
     set status = 'accepted', accepted_at = coalesce(accepted_at, now())
   where id = p_quote_id;

  v_job_reference := public.next_reference(v_quote.brand_id, 'job');

  -- access_notes and special_instructions are copied verbatim. Whatever the
  -- salesperson typed reaches the crew unedited — this is the fix for the
  -- "lost access notes" and "unrecorded special requests" problems.
  insert into public.jobs (
    brand_id, lead_id, quote_id, customer_id, branch_id, reference, status,
    access_notes, special_instructions, crew_size, volume_ft3
  )
  select v_quote.brand_id, v_quote.lead_id, v_quote.id, v_lead.customer_id, v_lead.branch_id,
         v_job_reference, 'booked',
         v_lead.origin_access->>'notes', v_quote.pricing_snapshot->>'special_instructions',
         v_quote.crew_size, v_quote.volume_ft3
  returning id into v_job_id;

  insert into public.invoices (
    brand_id, job_id, customer_id, number, status, issued_on, due_on,
    currency, net_minor, vat_minor, gross_minor
  )
  values (
    v_quote.brand_id, v_job_id, v_lead.customer_id,
    public.next_reference(v_quote.brand_id, 'invoice'), 'issued', current_date, current_date,
    v_quote.currency, v_quote.net_minor, v_quote.vat_minor, v_quote.gross_minor
  )
  returning id into v_invoice_id;

  update public.leads
     set status = 'booked', booked_at = now()
   where id = v_quote.lead_id;

  insert into public.lead_events (lead_id, type, actor_staff_id, payload)
  values (v_quote.lead_id, 'booked', p_actor_staff_id,
          jsonb_build_object('quote_id', p_quote_id, 'job_id', v_job_id, 'invoice_id', v_invoice_id));

  -- Stop every live sequence for this lead and quote. A customer who has just
  -- paid must not receive tomorrow's chase.
  update public.sequence_enrolments
     set status = 'stopped', stopped_reason = 'quote_accepted', stopped_at = now()
   where status = 'active'
     and ((subject_type = 'quote' and subject_id = p_quote_id)
       or (subject_type = 'lead' and subject_id = v_quote.lead_id));

  update public.outbox
     set status = 'cancelled'
   where status = 'queued'
     and enrolment_id in (
       select id from public.sequence_enrolments
       where stopped_reason = 'quote_accepted'
         and ((subject_type = 'quote' and subject_id = p_quote_id)
           or (subject_type = 'lead' and subject_id = v_quote.lead_id))
     );

  insert into public.audit_log (actor_staff_id, brand_id, action, entity_type, entity_id, after)
  values (p_actor_staff_id, v_quote.brand_id, 'quote.booked', 'quote', p_quote_id,
          jsonb_build_object('job_id', v_job_id, 'invoice_id', v_invoice_id));

  return query select v_job_id, v_job_reference, v_invoice_id;
end;
$$;

revoke all on function book_accepted_quote from public, anon;
grant execute on function book_accepted_quote to authenticated;

create or replace function claim_due_enrolments(p_limit int default 200)
returns table (
  enrolment_id uuid,
  brand_id uuid,
  customer_id uuid,
  sequence_key text,
  enrolled_at timestamptz,
  next_step_order int,
  satisfied_conditions text[],
  recent_capped_sends_at timestamptz[],
  to_address text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with claimed as (
    select e.id
    from public.sequence_enrolments e
    where e.status = 'active' and e.next_run_at <= now()
    order by e.next_run_at
    limit p_limit
    for update skip locked
  )
  select
    e.id,
    e.brand_id,
    e.customer_id,
    s.key,
    e.enrolled_at,
    e.next_step_order,
    -- Stop conditions are derived at dispatch time from current state, never
    -- from a flag written at enrolment: the customer who books an hour before
    -- the chase is due must not receive it.
    (
      select coalesce(array_agg(condition), '{}'::text[])
      from (
        select 'unsubscribed'::text as condition
        where exists (
          select 1 from public.unsubscribes u
          join public.customers c on c.id = e.customer_id
          where u.address_normalised in (c.email_normalised, c.phone_normalised)
        ) or exists (
          select 1 from public.customers c
          where c.id = e.customer_id and c.unsubscribed_at is not null
        )
        union all
        select 'quote_accepted'
        where e.subject_type = 'quote' and exists (
          select 1 from public.quotes q where q.id = e.subject_id and q.status = 'accepted'
        )
        union all
        select 'quote_expired'
        where e.subject_type = 'quote' and exists (
          select 1 from public.quotes q
          where q.id = e.subject_id and (q.status = 'expired' or q.valid_until < now())
        )
        union all
        select 'lead_lost'
        where exists (
          select 1 from public.leads l
          where l.status = 'lost'
            and (l.id = e.subject_id
              or l.id = (select q.lead_id from public.quotes q where q.id = e.subject_id))
        )
        union all
        select 'lead_booked'
        where exists (
          select 1 from public.leads l
          where l.status in ('booked','completed','reviewed')
            and (l.id = e.subject_id
              or l.id = (select q.lead_id from public.quotes q where q.id = e.subject_id))
        )
        union all
        select 'customer_replied'
        where exists (
          select 1 from public.message_log m
          where m.customer_id = e.customer_id
            and m.direction = 'inbound'
            and m.sent_at > e.enrolled_at
        )
      ) as conditions
    ),
    -- The fair-use cap counts across every brand and channel: a customer
    -- experiences one sender, not six.
    (
      select coalesce(array_agg(m.sent_at order by m.sent_at), '{}'::timestamptz[])
      from public.message_log m
      where m.customer_id = e.customer_id
        and m.counted_toward_cap
        and m.sent_at > now() - interval '7 days'
    ),
    (select c.email from public.customers c where c.id = e.customer_id)
  from public.sequence_enrolments e
  join claimed on claimed.id = e.id
  join public.sequences s on s.id = e.sequence_id;
end;
$$;

revoke all on function claim_due_enrolments from public, anon, authenticated;

create or replace function claim_due_outbox(p_limit int default 100)
returns table (
  id uuid,
  channel public.message_channel,
  to_address text,
  template_key text,
  brand_id uuid,
  customer_id uuid,
  counts_toward_frequency_cap boolean,
  subject text,
  body text,
  from_address text,
  reply_to text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with claimed as (
    select o.id
    from public.outbox o
    where o.status = 'queued' and o.send_after <= now()
    order by o.send_after
    limit p_limit
    for update skip locked
  )
  update public.outbox o
     set status = 'sending', attempts = o.attempts + 1
    from claimed, public.brands b
   where o.id = claimed.id and b.id = o.brand_id
  returning
    o.id, o.channel, o.to_address, o.template_key, o.brand_id, o.customer_id,
    o.counts_toward_frequency_cap,
    -- Brand template first, platform default second: a brand that has not
    -- written its own copy still sends something correct.
    (select t.subject from public.message_templates t
      where t.key = o.template_key and t.channel = o.channel and t.is_active
      order by (t.brand_id = o.brand_id) desc, t.version desc limit 1),
    (select t.body from public.message_templates t
      where t.key = o.template_key and t.channel = o.channel and t.is_active
      order by (t.brand_id = o.brand_id) desc, t.version desc limit 1),
    b.email_from,
    b.email_reply_to;
end;
$$;

revoke all on function claim_due_outbox from public, anon, authenticated;

create or replace function mark_outbox_sent(p_outbox_id uuid, p_provider_message_id text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.outbox%rowtype;
begin
  update public.outbox
     set status = 'sent', sent_at = now(), provider_message_id = p_provider_message_id, error = null
   where id = p_outbox_id
  returning * into v_row;

  if not found then
    return;
  end if;

  insert into public.message_log (
    brand_id, customer_id, outbox_id, direction, channel, template_key,
    to_address, provider_message_id, counted_toward_cap
  )
  values (
    v_row.brand_id, v_row.customer_id, v_row.id, 'outbound', v_row.channel, v_row.template_key,
    v_row.to_address, p_provider_message_id, v_row.counts_toward_frequency_cap
  );
end;
$$;

revoke all on function mark_outbox_sent from public, anon, authenticated;

-- ── Enrolment ─────────────────────────────────────────────────────────────
create or replace function enrol_in_sequence(
  p_brand_id uuid,
  p_sequence_key text,
  p_subject_type text,
  p_subject_id uuid,
  p_customer_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sequence_id uuid;
  v_enrolment_id uuid;
begin
  select s.id into v_sequence_id
  from public.sequences s
  where s.key = p_sequence_key and s.is_active
  order by (s.brand_id = p_brand_id) desc
  limit 1;

  if v_sequence_id is null then
    raise exception 'No active sequence %', p_sequence_key using errcode = 'no_data_found';
  end if;

  -- One live enrolment per subject per sequence. Re-enrolling a lead that is
  -- already being chased is how a customer gets the same email twice.
  insert into public.sequence_enrolments (
    brand_id, sequence_id, subject_type, subject_id, customer_id, next_run_at
  )
  values (p_brand_id, v_sequence_id, p_subject_type, p_subject_id, p_customer_id, now())
  on conflict (sequence_id, subject_type, subject_id) do nothing
  returning id into v_enrolment_id;

  return v_enrolment_id;
end;
$$;

revoke all on function enrol_in_sequence from public, anon;
grant execute on function enrol_in_sequence to authenticated;

create or replace function generate_job_sheet(p_job_id uuid, p_actor_staff_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sheet_id uuid;
  v_snapshot jsonb;
begin
  select jsonb_build_object(
    'generated_at', now(),
    'job', jsonb_build_object(
      'reference', j.reference,
      'status', j.status,
      'scheduled_start', j.scheduled_start,
      'scheduled_end', j.scheduled_end,
      'crew_size', j.crew_size,
      'volume_ft3', j.volume_ft3,
      'origin_address', j.origin_address,
      'destination_address', j.destination_address,
      -- Verbatim, and first in the object so it renders above the fold.
      'access_notes', j.access_notes,
      'special_instructions', j.special_instructions
    ),
    'customer', jsonb_build_object(
      'name', concat_ws(' ', c.first_name, c.last_name),
      'phone', c.phone
    ),
    'crew', (
      select coalesce(jsonb_agg(jsonb_build_object('name', s.full_name, 'role', ja.role)), '[]'::jsonb)
      from public.job_assignments ja
      join public.staff s on s.id = ja.staff_id
      where ja.job_id = j.id and ja.cancelled_at is null and ja.staff_id is not null
    ),
    'vehicles', (
      select coalesce(jsonb_agg(jsonb_build_object('registration', v.registration, 'type', v.type)), '[]'::jsonb)
      from public.job_assignments ja
      join public.vehicles v on v.id = ja.vehicle_id
      where ja.job_id = j.id and ja.cancelled_at is null and ja.vehicle_id is not null
    ),
    'inventory', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'item', coalesce(i.name, qi.custom_name),
        'room', qi.room_slug,
        'quantity', qi.quantity,
        'volume_ft3', qi.volume_ft3,
        'fragile', coalesce(i.is_fragile, false),
        'dismantle', coalesce(i.requires_dismantle, false),
        'handling', coalesce(i.handling, 'standard')
      ) order by qi.room_slug), '[]'::jsonb)
      from public.quote_items qi
      left join public.items i on i.slug = qi.item_slug
      where qi.quote_id = j.quote_id
    ),
    -- Crew see whether the job is paid, never what it cost.
    'payment_status', (
      select inv.status from public.invoices inv where inv.job_id = j.id limit 1
    )
  )
  into v_snapshot
  from public.jobs j
  join public.customers c on c.id = j.customer_id
  where j.id = p_job_id;

  if v_snapshot is null then
    raise exception 'Job % not found', p_job_id using errcode = 'no_data_found';
  end if;

  insert into public.job_sheets (job_id, generated_by_staff_id, snapshot)
  values (p_job_id, p_actor_staff_id, v_snapshot)
  returning id into v_sheet_id;

  return v_sheet_id;
end;
$$;

revoke all on function generate_job_sheet from public, anon;
grant execute on function generate_job_sheet to authenticated;

-- ── GDPR export ───────────────────────────────────────────────────────────
-- Everything held on one person, in one object. Scoped to the brand that holds
-- the record until a lawful basis for cross-brand sharing exists.
create or replace function export_customer_data(p_customer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_export jsonb;
begin
  select jsonb_build_object(
    'exported_at', now(),
    'customer', to_jsonb(c) - 'email_normalised' - 'phone_normalised',
    'leads', (select coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb) from public.leads l where l.customer_id = c.id),
    'quotes', (
      select coalesce(jsonb_agg(to_jsonb(q)), '[]'::jsonb)
      from public.quotes q
      join public.leads l on l.id = q.lead_id
      where l.customer_id = c.id
    ),
    'jobs', (select coalesce(jsonb_agg(to_jsonb(j)), '[]'::jsonb) from public.jobs j where j.customer_id = c.id),
    'invoices', (select coalesce(jsonb_agg(to_jsonb(i)), '[]'::jsonb) from public.invoices i where i.customer_id = c.id),
    'messages', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'direction', m.direction, 'channel', m.channel, 'subject', m.subject, 'sent_at', m.sent_at
      )), '[]'::jsonb)
      from public.message_log m where m.customer_id = c.id
    )
  )
  into v_export
  from public.customers c
  where c.id = p_customer_id;

  if v_export is null then
    raise exception 'Customer % not found', p_customer_id using errcode = 'no_data_found';
  end if;

  return v_export;
end;
$$;

revoke all on function export_customer_data from public, anon, authenticated;

-- ── GDPR erasure ──────────────────────────────────────────────────────────
-- Anonymise, do not delete. Financial records must survive for the statutory
-- period; the person must not. Identifying fields become a tombstone, the
-- invoice keeps its numbers, and the erasure itself is recorded.
create or replace function erase_customer_data(p_customer_id uuid, p_actor_staff_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_brand_id uuid;
  v_has_financial boolean;
begin
  select brand_id into v_brand_id from public.customers where id = p_customer_id;
  if v_brand_id is null then
    raise exception 'Customer % not found', p_customer_id using errcode = 'no_data_found';
  end if;

  select exists (
    select 1 from public.invoices i where i.customer_id = p_customer_id
  ) into v_has_financial;

  update public.customers
     set first_name = 'Erased',
         last_name = 'Customer',
         email = null,
         email_normalised = null,
         phone = null,
         phone_normalised = null,
         marketing_consent = false,
         consent_source = null,
         unsubscribed_at = now(),
         anonymised_at = now()
   where id = p_customer_id;

  -- Behavioural and message data has no retention basis once the person is
  -- erased, so it goes entirely rather than being anonymised.
  delete from public.message_log where customer_id = p_customer_id;
  delete from public.customer_portal_tokens where customer_id = p_customer_id;

  update public.sequence_enrolments
     set status = 'stopped', stopped_reason = 'erasure', stopped_at = now()
   where customer_id = p_customer_id and status = 'active';
  update public.outbox set status = 'cancelled'
   where customer_id = p_customer_id and status in ('queued','needs_manual_send');

  -- The raw intake payload contains the original contact details.
  update public.leads
     set raw_payload = jsonb_build_object('erased', true),
         first_touch = '{}'::jsonb,
         last_touch = '{}'::jsonb
   where customer_id = p_customer_id;

  insert into public.data_requests (customer_id, customer_email, kind, completed_at, performed_by_staff_id, notes)
  values (p_customer_id, 'erased', 'erasure', now(), p_actor_staff_id,
          case when v_has_financial
            then 'Anonymised; financial records retained for the statutory period'
            else 'Anonymised; no financial records held' end);

  insert into public.audit_log (actor_staff_id, brand_id, action, entity_type, entity_id, after)
  values (p_actor_staff_id, v_brand_id, 'customer.erased', 'customer', p_customer_id,
          jsonb_build_object('financial_records_retained', v_has_financial));

  return jsonb_build_object('anonymised', true, 'financial_records_retained', v_has_financial);
end;
$$;

revoke all on function erase_customer_data from public, anon, authenticated;
