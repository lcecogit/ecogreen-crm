-- Job sheets, GDPR and retention.

-- ── Job sheet ─────────────────────────────────────────────────────────────
-- A frozen snapshot, not a live view. The sheet a crew worked from must still
-- be readable after the job, the quote and the customer record have all moved
-- on — that is what settles a damage or scope dispute.
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
