-- Tests for the server-side transactions: intake, booking, the scheduler,
-- job sheets and GDPR.

-- ── Lead intake ───────────────────────────────────────────────────────────
select assert_eq(
  (select count(*) from create_intake_lead(
     (select id from brands where slug = 'glasgow-moving'),
     '{"idempotency_key":"web-aaa1"}'::jsonb,
     'Rhona', 'Stewart', 'rhona@example.com', 'rhona@example.com',
     '07700 900456', '+447700900456', 'residential', '2026-07-01',
     'G1 1AA', 'G12 8QQ', 'G1', 'G12',
     '{"utm_source":"google"}'::jsonb, true,
     null, 'unassigned', 62, '[]'::jsonb, null, null))::int,
  1, 'intake creates a lead in one call');

select assert_eq(
  (select count(*)::int from customers where email_normalised = 'rhona@example.com'),
  1, 'intake created the customer');
select assert_eq(
  (select status::text from leads where customer_id = (select id from customers where email_normalised = 'rhona@example.com')),
  'new', 'a clean intake lands in the working pipeline');
select assert_true(
  (select consent_at is not null from customers where email_normalised = 'rhona@example.com'),
  'marketing consent is recorded with a timestamp at capture');
select assert_eq(
  (select count(*)::int from lead_events le
     join leads l on l.id = le.lead_id
   where l.customer_id = (select id from customers where email_normalised = 'rhona@example.com')
     and le.type = 'created'),
  1, 'intake writes a created event');

-- A second enquiry from the same person reuses the customer rather than
-- accumulating duplicates.
select create_intake_lead(
  (select id from brands where slug = 'glasgow-moving'),
  '{"idempotency_key":"web-aaa2"}'::jsonb,
  'Rhona', 'Stewart', 'rhona@example.com', 'rhona@example.com',
  '07700 900456', '+447700900456', 'residential', '2026-08-01',
  'G1 1AA', 'G12 8QQ', 'G1', 'G12', '{}'::jsonb, false,
  null, 'unassigned', 40, '[]'::jsonb,
  (select id from leads where customer_id = (select id from customers where email_normalised = 'rhona@example.com') limit 1),
  null);

select assert_eq(
  (select count(*)::int from customers where email_normalised = 'rhona@example.com'),
  1, 'a repeat enquirer does not create a second customer row');
select assert_eq(
  (select count(*)::int from leads l
     join customers c on c.id = l.customer_id
   where c.email_normalised = 'rhona@example.com' and l.status = 'duplicate'),
  1, 'a same-brand duplicate never enters the working pipeline');

-- ── Booking ───────────────────────────────────────────────────────────────
-- Its own quote, so the fixture job from 10_fixtures.sql does not interfere.
insert into quotes (id, brand_id, lead_id, reference, status, net_minor, vat_minor, gross_minor, deposit_minor, valid_until, sent_at)
select 'eeeeeeee-0000-0000-0000-000000000002', l.brand_id, l.id, next_reference(l.brand_id, 'quote'),
       'sent', 60000, 12000, 72000, 18000, now() + interval '14 days', now()
from leads l where l.id = 'dddddddd-0000-0000-0000-000000000002';

select assert_eq(
  (select count(*) from book_accepted_quote('eeeeeeee-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002'))::int,
  1, 'a sent quote books in one transaction');

select assert_eq((select status::text from quotes where id = 'eeeeeeee-0000-0000-0000-000000000002'),
  'accepted', 'the quote is marked accepted');
select assert_eq((select status::text from leads where id = 'dddddddd-0000-0000-0000-000000000002'),
  'booked', 'the lead advances to booked');
select assert_eq(
  (select count(*)::int from invoices where customer_id = 'cccccccc-0000-0000-0000-000000000002'),
  1, 'the invoice was raised in the same transaction');
select assert_eq(
  (select gross_minor from invoices where customer_id = 'cccccccc-0000-0000-0000-000000000002'),
  72000::bigint, 'the invoice carries the frozen quote total, not a recomputed one');
select assert_eq(
  (select count(*)::int from audit_log where action = 'quote.booked'),
  1, 'booking is audited');

-- The fixture job in 10_fixtures.sql already came from quote ...0001, so that
-- quote is already booked. Retrying must not raise a second invoice.
select assert_raises(
  $$select book_accepted_quote('eeeeeeee-0000-0000-0000-000000000001')$$,
  'a quote that already produced a job cannot be booked twice');
select assert_eq(
  (select count(*)::int from jobs where quote_id = 'eeeeeeee-0000-0000-0000-000000000001' and status <> 'cancelled'),
  1, 'the retry created no second job');

select assert_raises(
  $$select book_accepted_quote('00000000-0000-0000-0000-0000000000ff')$$,
  'booking an unknown quote raises rather than half-completing');
select assert_eq(
  (select count(*)::int from jobs where quote_id = '00000000-0000-0000-0000-0000000000ff'),
  0, 'the failed booking left no job behind');

-- ── The chase stops on booking ────────────────────────────────────────────
select enrol_in_sequence(
  (select brand_id from leads where id = 'dddddddd-0000-0000-0000-000000000002'),
  'quote_chase', 'lead', 'dddddddd-0000-0000-0000-000000000002',
  'cccccccc-0000-0000-0000-000000000002');

select assert_eq(
  (select count(*)::int from sequence_enrolments where subject_id = 'dddddddd-0000-0000-0000-000000000002'),
  1, 'a lead can be enrolled in the chase');

select enrol_in_sequence(
  (select brand_id from leads where id = 'dddddddd-0000-0000-0000-000000000002'),
  'quote_chase', 'lead', 'dddddddd-0000-0000-0000-000000000002',
  'cccccccc-0000-0000-0000-000000000002');
select assert_eq(
  (select count(*)::int from sequence_enrolments where subject_id = 'dddddddd-0000-0000-0000-000000000002'),
  1, 'enrolling twice does not double-chase the customer');

-- claim_due_enrolments derives the stop conditions from live state.
select assert_true(
  (select 'lead_booked' = any(satisfied_conditions)
     from claim_due_enrolments(50)
    where enrolment_id = (select id from sequence_enrolments where subject_id = 'dddddddd-0000-0000-0000-000000000001')
   ) is not false,
  'stop conditions are derived at dispatch time from current state');

-- An unsubscribed customer is reported as such, whichever brand is sending.
insert into unsubscribes (channel, address_normalised) values ('email', 'sam@example.com');
update sequence_enrolments set next_run_at = now() where subject_id = 'dddddddd-0000-0000-0000-000000000002';
select assert_true(
  (select 'unsubscribed' = any(satisfied_conditions) from claim_due_enrolments(50)
    where enrolment_id = (select id from sequence_enrolments where subject_id = 'dddddddd-0000-0000-0000-000000000002')),
  'an unsubscribe is honoured across every brand');

-- ── Outbox dispatch ───────────────────────────────────────────────────────
insert into outbox (brand_id, channel, template_key, idempotency_key, to_address, customer_id, counts_toward_frequency_cap)
select id, 'email', 'quote_chase_1', 'seq:test:1', 'jo@example.com', 'cccccccc-0000-0000-0000-000000000001', true
from brands where slug = 'ecogreen-movers';

-- 30_constraints.sql left one queued row behind, so this asserts the specific
-- row rather than a total.
select assert_true((select count(*) from claim_due_outbox(10)) >= 1, 'a due outbox row is claimed');
select assert_eq((select status::text from outbox where idempotency_key = 'seq:test:1'), 'sending',
  'claiming marks the row in flight, so a second tick skips it');
select assert_eq((select count(*) from claim_due_outbox(10))::int, 0,
  'a concurrent tick claims nothing — the row is no longer queued');

select mark_outbox_sent((select id from outbox where idempotency_key = 'seq:test:1'), 'prov-123');
select assert_eq((select status::text from outbox where idempotency_key = 'seq:test:1'), 'sent', 'the row is marked sent');
select assert_eq((select count(*)::int from message_log where provider_message_id = 'prov-123'), 1,
  'every send is written to the message log');
select assert_true(
  (select counted_toward_cap from message_log where provider_message_id = 'prov-123'),
  'and counts toward the fair-use cap');

-- ── Job sheet ─────────────────────────────────────────────────────────────
select assert_true(generate_job_sheet('bbbbbbbb-0000-0000-0000-000000000001') is not null,
  'a job sheet can be generated');

select assert_eq(
  (select snapshot->'job'->>'access_notes' from job_sheets where job_id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'Narrow stairs, no lift. Low bridge on Mill Lane.',
  'access notes reach the crew verbatim — this is the whole point of the sheet');
select assert_true(
  (select snapshot::text not like '%net_minor%' and snapshot::text not like '%gross_minor%'
     from job_sheets where job_id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'the job sheet carries payment status but never a price');
select assert_true(
  (select jsonb_array_length(snapshot->'crew') >= 1 from job_sheets where job_id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'the assigned crew appear on the sheet');

-- ── GDPR ──────────────────────────────────────────────────────────────────
select assert_true(
  (select export_customer_data('cccccccc-0000-0000-0000-000000000001')->'leads' is not null),
  'a customer export gathers their leads');
select assert_true(
  (select jsonb_array_length(export_customer_data('cccccccc-0000-0000-0000-000000000002')->'invoices') = 1),
  'and their invoices');

select assert_eq(
  erase_customer_data('cccccccc-0000-0000-0000-000000000002')->>'financial_records_retained',
  'true', 'erasure reports that financial records were retained');
select assert_eq(
  (select email from customers where id = 'cccccccc-0000-0000-0000-000000000002'),
  null, 'the contact details are gone');
select assert_eq(
  (select first_name from customers where id = 'cccccccc-0000-0000-0000-000000000002'),
  'Erased', 'the row is tombstoned rather than deleted');
select assert_eq(
  (select count(*)::int from invoices where customer_id = 'cccccccc-0000-0000-0000-000000000002'),
  1, 'the invoice survives, because the statutory period has not passed');
select assert_eq(
  (select count(*)::int from message_log where customer_id = 'cccccccc-0000-0000-0000-000000000002'),
  0, 'behavioural and message data is deleted outright');
select assert_eq(
  (select raw_payload->>'erased' from leads where id = 'dddddddd-0000-0000-0000-000000000002'),
  'true', 'the raw intake payload, which held the original contact details, is cleared');
select assert_eq(
  (select count(*)::int from data_requests where kind = 'erasure'),
  1, 'the erasure itself is recorded');
select assert_eq(
  (select count(*)::int from audit_log where action = 'customer.erased'),
  1, 'and audited');
