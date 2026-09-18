-- RLS tests. Each block assumes a session as a specific staff member.
--
-- `set local role authenticated` matters: the table owner bypasses RLS, so a
-- test run as the migration user would pass vacuously.

-- ── A sales user sees their own brand only ────────────────────────────────
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

select assert_eq((select count(*) from leads)::int, 1,
  'a sales user sees only their own brand''s leads');
select assert_eq((select count(*) from leads where id = 'dddddddd-0000-0000-0000-000000000002')::int, 0,
  'a sales user cannot read another brand''s lead');
select assert_eq((select count(*) from customers)::int, 1,
  'a sales user sees only their own brand''s customers');
select assert_eq((select count(*) from brands)::int, 1,
  'a sales user sees only the brands they hold access to');
commit;

-- ── The other brand's salesperson sees the mirror image ───────────────────
begin;
set local role authenticated;
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select assert_eq((select count(*) from leads where id = 'dddddddd-0000-0000-0000-000000000001')::int, 0,
  'brand isolation holds in both directions');
select assert_eq((select count(*) from leads)::int, 1,
  'the London salesperson sees exactly their own lead');
commit;

-- ── Crew: assigned jobs only, and never a price ───────────────────────────
begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

select assert_eq((select count(*) from quotes)::int, 0,
  'crew cannot read quotes — a crew phone must not expose margins');
select assert_eq((select count(*) from rate_cards)::int, 0,
  'crew cannot read rate cards');
select assert_eq((select count(*) from invoices)::int, 0,
  'crew cannot read invoices');
select assert_eq((select count(*) from customers)::int, 0,
  'crew cannot read the customer table directly');
select assert_eq((select count(*) from jobs)::int, 0,
  'crew see no jobs until they are assigned to one');
commit;

-- Assign the crew member, then re-check.
insert into job_assignments (job_id, staff_id, role, starts_at, ends_at)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003',
        'mover', '2026-06-06 08:00+01', '2026-06-06 16:00+01');

begin;
set local role authenticated;
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
select assert_eq((select count(*) from jobs)::int, 1,
  'crew see a job once they are assigned to it');
select assert_eq((select count(*) from quotes)::int, 0,
  'and still cannot read its price');
commit;

-- ── Admin sees across brands ──────────────────────────────────────────────
begin;
set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select assert_eq((select count(*) from leads)::int, 2,
  'a platform admin sees every brand');
select assert_eq((select count(*) from brands)::int, 6,
  'a platform admin sees all six brands');
commit;

-- ── Nobody may read customer portal token hashes ──────────────────────────
begin;
set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select assert_eq((select count(*) from customer_portal_tokens)::int, 0,
  'not even an admin session can read portal token hashes');
commit;

-- ── The audit log is append-only for everyone ─────────────────────────────
insert into audit_log (action, entity_type, entity_id)
values ('test.write', 'lead', 'dddddddd-0000-0000-0000-000000000001');

begin;
set local role authenticated;
set local request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select assert_eq((select count(*) from audit_log)::int, 1, 'an admin can read the audit log');
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select assert_eq((select count(*) from audit_log)::int, 0,
  'a sales user cannot read the audit log');
commit;

select assert_raises(
  $$update audit_log set action = 'tampered'$$,
  'the audit log rejects UPDATE even from the owning role');
select assert_raises(
  $$delete from audit_log$$,
  'the audit log rejects DELETE even from the owning role');

-- ── Privilege escalation ──────────────────────────────────────────────────
-- Worth knowing, and the reason these assertions are written the way they are:
-- an RLS denial on UPDATE or DELETE is a silent no-op (zero rows), not an
-- error. Only INSERT raises, via WITH CHECK. So the escalation tests assert
-- the *outcome* — the grant did not change — rather than asserting a raise,
-- which would pass vacuously. Application code must check affected-row counts
-- for the same reason.
begin;
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- Targets a brand this user CAN see, so the statement is not a no-op for the
-- uninteresting reason that the subquery returned nothing.
select assert_raises(
  $$insert into staff_brand_access (staff_id, brand_id, role)
    select 'aaaaaaaa-0000-0000-0000-000000000002', id, 'admin' from brands where slug = 'ecogreen-movers'$$,
  'a sales user cannot grant admin access, even on a brand they can see');

update staff_brand_access set role = 'admin'
where staff_id = 'aaaaaaaa-0000-0000-0000-000000000001';
select assert_eq(
  (select count(*) from staff_brand_access
    where staff_id = 'aaaaaaaa-0000-0000-0000-000000000001' and role = 'admin')::int,
  0, 'a sales user cannot promote themselves to admin');
select assert_eq(private.is_platform_admin(), false,
  'and is still not a platform admin afterwards');
commit;

-- The grant really is unchanged outside the transaction too.
select assert_eq(
  (select role::text from staff_brand_access where staff_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'sales', 'the sales grant survived the escalation attempt');
