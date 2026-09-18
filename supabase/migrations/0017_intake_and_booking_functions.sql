-- Server-side transactions.
--
-- Lead creation and booking each touch several tables and must be all-or-
-- nothing. Doing that with sequential PostgREST calls from a route handler
-- gives you a customer with no lead, or a job with no invoice, whenever a
-- request dies halfway. These run in one transaction each, by definition.

-- ── Lead intake ───────────────────────────────────────────────────────────
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
