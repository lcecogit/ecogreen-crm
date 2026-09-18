-- Test fixtures and assertion helpers.
--
-- Supabase grants table privileges to `authenticated` by default and relies on
-- RLS as the actual gate. The local shim reproduces that here, after the
-- migrations have run, so these tests exercise the policies rather than
-- accidentally passing because a grant was missing.
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

create or replace function assert_true(condition boolean, description text)
returns void language plpgsql as $$
begin
  if condition is not true then
    raise exception 'ASSERTION FAILED: %', description;
  end if;
  raise notice '  ok  %', description;
end;
$$;

create or replace function assert_eq(actual anyelement, expected anyelement, description text)
returns void language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'ASSERTION FAILED: % (expected %, got %)', description, expected, actual;
  end if;
  raise notice '  ok  %', description;
end;
$$;

-- Runs a statement and asserts it raises. Used for the constraint tests, where
-- "the database refuses this" is the behaviour under test.
create or replace function assert_raises(statement text, description text)
returns void language plpgsql as $$
begin
  begin
    execute statement;
  exception when others then
    raise notice '  ok  % (%)', description, sqlerrm;
    return;
  end;
  raise exception 'ASSERTION FAILED: % — the statement was accepted', description;
end;
$$;

-- ── People ────────────────────────────────────────────────────────────────
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'sales.eco@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'sales.london@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'crew.eco@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'admin@example.com'),
  ('55555555-5555-5555-5555-555555555555', 'ops.eco@example.com');

insert into staff (id, auth_user_id, full_name, email, department) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Hania',  'sales.eco@example.com',    'sales'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Adara',  'sales.london@example.com', 'sales'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'Ash',    'crew.eco@example.com',     'movers'),
  ('aaaaaaaa-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444', 'Zak',    'admin@example.com',        'admin'),
  ('aaaaaaaa-0000-0000-0000-000000000005', '55555555-5555-5555-5555-555555555555', 'David',  'ops.eco@example.com',      'transport');

-- The brand-access trigger is admin-only, so the fixture inserts bypass it the
-- same way a bootstrap script would: as the superuser, with the trigger off.
alter table staff_brand_access disable trigger staff_brand_access_guard;
insert into staff_brand_access (staff_id, brand_id, role)
select 'aaaaaaaa-0000-0000-0000-000000000001', id, 'sales'   from brands where slug = 'ecogreen-movers';
insert into staff_brand_access (staff_id, brand_id, role)
select 'aaaaaaaa-0000-0000-0000-000000000002', id, 'sales'   from brands where slug = 'eco-london-movers';
insert into staff_brand_access (staff_id, brand_id, role)
select 'aaaaaaaa-0000-0000-0000-000000000003', id, 'crew'    from brands where slug = 'ecogreen-movers';
insert into staff_brand_access (staff_id, brand_id, role)
select 'aaaaaaaa-0000-0000-0000-000000000004', id, 'admin'   from brands where slug = 'ecogreen-movers';
insert into staff_brand_access (staff_id, brand_id, role)
select 'aaaaaaaa-0000-0000-0000-000000000005', id, 'ops'     from brands where slug = 'ecogreen-movers';
alter table staff_brand_access enable trigger staff_brand_access_guard;

-- ── Two customers and two leads, one per brand ────────────────────────────
insert into customers (id, brand_id, first_name, last_name, email, email_normalised)
select 'cccccccc-0000-0000-0000-000000000001', id, 'Jo', 'Bloggs', 'jo@example.com', 'jo@example.com'
from brands where slug = 'ecogreen-movers';
insert into customers (id, brand_id, first_name, last_name, email, email_normalised)
select 'cccccccc-0000-0000-0000-000000000002', id, 'Sam', 'Patel', 'sam@example.com', 'sam@example.com'
from brands where slug = 'eco-london-movers';

insert into leads (id, brand_id, reference, customer_id, status, owner_staff_id)
select 'dddddddd-0000-0000-0000-000000000001', id, next_reference(id, 'lead'),
       'cccccccc-0000-0000-0000-000000000001', 'new', 'aaaaaaaa-0000-0000-0000-000000000001'
from brands where slug = 'ecogreen-movers';
insert into leads (id, brand_id, reference, customer_id, status, owner_staff_id)
select 'dddddddd-0000-0000-0000-000000000002', id, next_reference(id, 'lead'),
       'cccccccc-0000-0000-0000-000000000002', 'new', 'aaaaaaaa-0000-0000-0000-000000000002'
from brands where slug = 'eco-london-movers';

-- ── A quote, a job, a vehicle ─────────────────────────────────────────────
insert into quotes (id, brand_id, lead_id, reference, status, net_minor, vat_minor, gross_minor, deposit_minor, valid_until)
select 'eeeeeeee-0000-0000-0000-000000000001', l.brand_id, l.id, next_reference(l.brand_id, 'quote'),
       'draft', 40000, 8000, 48000, 12000, now() + interval '14 days'
from leads l where l.id = 'dddddddd-0000-0000-0000-000000000001';

insert into vehicles (id, brand_id, registration, type)
select 'ffffffff-0000-0000-0000-000000000001', id, 'AB12 CDE', 'luton'
from brands where slug = 'ecogreen-movers';

insert into jobs (id, brand_id, lead_id, quote_id, customer_id, reference, status, scheduled_start, scheduled_end, access_notes)
select 'bbbbbbbb-0000-0000-0000-000000000001', l.brand_id, l.id, 'eeeeeeee-0000-0000-0000-000000000001',
       'cccccccc-0000-0000-0000-000000000001', next_reference(l.brand_id, 'job'), 'scheduled',
       '2026-06-06 08:00+01', '2026-06-06 16:00+01', 'Narrow stairs, no lift. Low bridge on Mill Lane.'
from leads l where l.id = 'dddddddd-0000-0000-0000-000000000001';
