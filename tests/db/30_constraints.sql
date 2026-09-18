-- Constraint tests: the guarantees this schema makes in the database rather
-- than in application code, because application code gets bypassed.

-- ── Double-booking ────────────────────────────────────────────────────────
-- The crew member from 20_rls.sql is already assigned 08:00-16:00 on 6 June.
select assert_raises(
  $$insert into job_assignments (job_id, staff_id, role, starts_at, ends_at)
    values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003',
            'mover', '2026-06-06 12:00+01', '2026-06-06 18:00+01')$$,
  'the same mover cannot be booked on two overlapping jobs');

-- Touching, not overlapping: a back-to-back assignment is legitimate.
insert into job_assignments (job_id, staff_id, role, starts_at, ends_at)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003',
        'mover', '2026-06-06 16:00+01', '2026-06-06 18:00+01');
select assert_true(true, 'a back-to-back assignment starting as the last one ends is allowed');

insert into job_assignments (job_id, vehicle_id, role, starts_at, ends_at)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'ffffffff-0000-0000-0000-000000000001',
        'vehicle', '2026-06-06 08:00+01', '2026-06-06 16:00+01');
select assert_raises(
  $$insert into job_assignments (job_id, vehicle_id, role, starts_at, ends_at)
    values ('bbbbbbbb-0000-0000-0000-000000000001', 'ffffffff-0000-0000-0000-000000000001',
            'vehicle', '2026-06-06 15:00+01', '2026-06-06 20:00+01')$$,
  'the same van cannot be booked on two overlapping jobs');

-- A cancelled assignment releases the slot.
update job_assignments set cancelled_at = now()
where staff_id = 'aaaaaaaa-0000-0000-0000-000000000003' and starts_at = '2026-06-06 16:00+01';
insert into job_assignments (job_id, staff_id, role, starts_at, ends_at)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003',
        'mover', '2026-06-06 17:00+01', '2026-06-06 19:00+01');
select assert_true(true, 'cancelling an assignment frees the slot for a re-book');

-- ── Quote immutability ────────────────────────────────────────────────────
update quotes set status = 'sent', sent_at = now()
where id = 'eeeeeeee-0000-0000-0000-000000000001';
select assert_true(true, 'a draft quote can be sent');

select assert_raises(
  $$update quotes set net_minor = 1 where id = 'eeeeeeee-0000-0000-0000-000000000001'$$,
  'a sent quote''s price cannot be edited');
select assert_raises(
  $$update quotes set pricing_snapshot = '{}'::jsonb where id = 'eeeeeeee-0000-0000-0000-000000000001'$$,
  'a sent quote''s pricing snapshot is frozen');
select assert_raises(
  $$delete from quotes where id = 'eeeeeeee-0000-0000-0000-000000000001'$$,
  'a sent quote cannot be deleted');
select assert_raises(
  $$insert into quote_lines (quote_id, rule_id, kind, label, net_minor)
    values ('eeeeeeee-0000-0000-0000-000000000001', 'sneaky', 'surcharge', 'Extra', 5000)$$,
  'a line cannot be added to a sent quote');

-- Recording that the customer looked at it is still allowed.
update quotes set status = 'viewed', first_viewed_at = now()
where id = 'eeeeeeee-0000-0000-0000-000000000001';
select assert_true(true, 'a sent quote can still record that it was viewed');

-- ── References ────────────────────────────────────────────────────────────
select assert_true(
  (select reference from leads where id = 'dddddddd-0000-0000-0000-000000000001') ~ '^EGM-\d{4}-\d{4}$',
  'lead references are human-readable and brand-prefixed');
select assert_true(
  (select count(distinct reference) from leads) = (select count(*) from leads),
  'references do not collide');

-- ── Attendance ────────────────────────────────────────────────────────────
insert into attendance (staff_id, department, clock_in_at)
values ('aaaaaaaa-0000-0000-0000-000000000003', 'movers', now());
select assert_raises(
  $$insert into attendance (staff_id, department, clock_in_at)
    values ('aaaaaaaa-0000-0000-0000-000000000003', 'movers', now())$$,
  'a second open shift is rejected — two open clock-ins break payroll');
select assert_raises(
  $$insert into attendance (staff_id, department, clock_in_at, clock_out_at)
    values ('aaaaaaaa-0000-0000-0000-000000000005', 'transport', now(), now() - interval '1 hour')$$,
  'a shift cannot end before it starts');

-- ── Sequences and the outbox ──────────────────────────────────────────────
select assert_raises(
  $$insert into sequence_steps (sequence_id, step_order, delay_minutes, channel, template_key, stop_conditions)
    select id, 99, 60, 'email', 'orphan', '{}'::text[] from sequences where key = 'quote_chase'$$,
  'a sequence step with no stop conditions is rejected — it would send forever');

insert into outbox (brand_id, channel, template_key, idempotency_key, to_address)
select id, 'email', 'quote_chase_1', 'seq:enr-1:1', 'jo@example.com' from brands where slug = 'ecogreen-movers';
select assert_raises(
  $$insert into outbox (brand_id, channel, template_key, idempotency_key, to_address)
    select id, 'email', 'quote_chase_1', 'seq:enr-1:1', 'jo@example.com' from brands where slug = 'ecogreen-movers'$$,
  'the outbox idempotency key makes concurrent cron ticks safe');

-- ── Payments ──────────────────────────────────────────────────────────────
insert into payments (brand_id, method, amount_minor, provider_reference)
select id, 'stripe', 12000, 'pi_test_123' from brands where slug = 'ecogreen-movers';
select assert_raises(
  $$insert into payments (brand_id, method, amount_minor, provider_reference)
    select id, 'stripe', 12000, 'pi_test_123' from brands where slug = 'ecogreen-movers'$$,
  'a replayed provider webhook cannot create a second payment');

-- ── Seed integrity ────────────────────────────────────────────────────────
select assert_eq((select count(*) from brands)::int, 6, 'all six brands are seeded');
select assert_eq((select count(*) from rate_cards)::int, 36, 'every brand has a card for all six services');
select assert_true((select count(*) from items) >= 50, 'the item catalogue is seeded');
select assert_true(
  (select bool_and(provisional) from rate_cards),
  'every seeded rate card is flagged provisional until the business signs it off');
select assert_true(
  (select count(*) from sequence_steps) >= 12,
  'the sequence steps are seeded');
select assert_eq(
  (select delay_minutes from sequence_steps s
    join sequences q on q.id = s.sequence_id
   where q.key = 'quote_chase' and s.step_order = 1),
  2880, 'the first quote chase fires at 48 hours');

-- ── Brand identity ────────────────────────────────────────────────────────
select assert_eq(
  (select email_from from brands where slug = 'ecogreen-movers'),
  'info@ecogreenmovers.co.uk', 'the flagship brand sends from its real address');
select assert_eq(
  (select accent_contrast_hex from brands where slug = 'ecogreen-movers'),
  '#161A36', 'the label on the brand lime is navy, not white — white fails AA on it');
select assert_eq(
  (select count(*)::int from brands where brand_identity_confirmed),
  2, 'only the two sites that are actually branded are marked confirmed');
select assert_true(
  (select bool_and(accent_text_hex is not null and accent_contrast_hex is not null) from brands),
  'every brand carries a text step and a fill-contrast step, not just a fill');
