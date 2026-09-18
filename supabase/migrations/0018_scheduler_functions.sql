-- Scheduler support.
--
-- The claim functions use FOR UPDATE SKIP LOCKED so two cron ticks running at
-- once divide the work rather than fighting over it or double-sending.

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
