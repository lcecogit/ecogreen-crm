-- ==========================================================================
--  EcoGreen Group CRM — COMPLETE INSTALL
--
--  Generated from supabase/parts/*.sql by scripts/bundle-sql.sh. Do not edit
--  by hand; edit the parts and re-run the script.
--
--  Paste the whole file into the Supabase SQL Editor and run it. It is safe to
--  re-run. If your editor truncates a paste this long, run the five files in
--  supabase/parts/ one at a time instead, in numerical order.
-- ==========================================================================


-- ##########################################################################
-- # 01_schema.sql
-- ##########################################################################

-- ==========================================================================
--  EcoGreen Group CRM — PART 1 — SCHEMA: extensions, enums, tables, indexes, triggers
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

-- ---------------------------------------------------------------------------
-- 1. Extensions
--    btree_gist is required by the job-assignment exclusion constraints, which
--    mix equality on a uuid with overlap on a tstzrange.
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";
create extension if not exists "btree_gist";
create extension if not exists "pg_trgm";

-- ---------------------------------------------------------------------------
-- 2. Enum types — ALL of them, before any table that references one
-- ---------------------------------------------------------------------------
do $$ begin create type currency_code     as enum ('GBP','EUR','USD'); exception when duplicate_object then null; end $$;
do $$ begin create type staff_department  as enum ('admin','sales','transport','movers','support','accounts'); exception when duplicate_object then null; end $$;
do $$ begin create type brand_role        as enum ('admin','manager','sales','ops','crew','accounts','readonly'); exception when duplicate_object then null; end $$;
do $$ begin create type organisation_type as enum ('corporate','public_sector','education','healthcare','agent'); exception when duplicate_object then null; end $$;
do $$ begin create type lead_status       as enum ('new','qualifying','quoted','chasing','booked','completed','reviewed','lost','duplicate'); exception when duplicate_object then null; end $$;
do $$ begin create type customer_type     as enum ('residential','commercial','office','specialist','clearance','storage'); exception when duplicate_object then null; end $$;
do $$ begin create type lead_source_kind  as enum ('website','provider','phone','whatsapp','referral','repeat','ppc','organic','walk_in'); exception when duplicate_object then null; end $$;
do $$ begin create type quote_status      as enum ('draft','sent','viewed','accepted','expired','superseded','declined'); exception when duplicate_object then null; end $$;
do $$ begin create type quote_line_kind   as enum ('transport','labour','materials','surcharge','discount','storage'); exception when duplicate_object then null; end $$;
do $$ begin create type packing_service   as enum ('none','materials_only','part','full'); exception when duplicate_object then null; end $$;
do $$ begin create type handling_class    as enum ('standard','heavy','fine_art','piano','it_equipment','laboratory','medical'); exception when duplicate_object then null; end $$;
do $$ begin create type job_status        as enum ('booked','scheduled','in_progress','completed','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type assignment_role   as enum ('lead_mover','mover','driver','supervisor','vehicle'); exception when duplicate_object then null; end $$;
do $$ begin create type invoice_status    as enum ('draft','issued','part_paid','paid','overdue','void'); exception when duplicate_object then null; end $$;
do $$ begin create type payment_method    as enum ('stripe','bank_transfer','cash','card_terminal'); exception when duplicate_object then null; end $$;
do $$ begin create type payment_status    as enum ('pending','succeeded','failed','refunded','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type message_channel   as enum ('email','sms','whatsapp','task'); exception when duplicate_object then null; end $$;
do $$ begin create type message_direction as enum ('outbound','inbound'); exception when duplicate_object then null; end $$;
do $$ begin create type outbox_status     as enum ('queued','sending','sent','failed','cancelled','needs_manual_send'); exception when duplicate_object then null; end $$;
do $$ begin create type enrolment_status  as enum ('active','stopped','completed'); exception when duplicate_object then null; end $$;
do $$ begin create type target_period     as enum ('day','week','month'); exception when duplicate_object then null; end $$;
do $$ begin create type move_size         as enum ('small','medium','large','commercial','office'); exception when duplicate_object then null; end $$;
do $$ begin create type data_request_kind as enum ('export','erasure'); exception when duplicate_object then null; end $$;
do $$ begin create type retention_action  as enum ('anonymise','delete'); exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 4. Tenancy and people
-- ---------------------------------------------------------------------------
create table if not exists brands (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  code text not null unique,                 -- short prefix for references, e.g. EGM
  name text not null,
  legal_name text,
  primary_domain text not null,
  accent_hex text not null,
  accent_dark_hex text not null,
  accent_text_hex text,
  accent_text_dark_hex text,
  accent_contrast_hex text,
  brand_identity_confirmed boolean not null default false,
  logo_path text,
  email_from text not null,
  email_reply_to text,
  phone text,
  vat_number text,
  company_number text,
  bank_account_name text,
  bank_sort_code text,
  bank_account_number text,
  default_currency currency_code not null default 'GBP',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists branches (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  name text not null,
  city text not null,
  outward_codes text[] not null default '{}',
  timezone text not null default 'Europe/London',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, name)
);

create table if not exists staff (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null,
  email text not null unique,
  phone text,
  department staff_department not null,
  job_title text,
  started_on date,
  ended_on date,
  accepting_leads boolean not null default true,
  max_open_leads int not null default 0,     -- 0 = no cap
  last_assigned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists staff_brand_access (
  staff_id uuid not null references staff(id) on delete cascade,
  brand_id uuid not null references brands(id) on delete cascade,
  role brand_role not null,
  created_at timestamptz not null default now(),
  primary key (staff_id, brand_id)
);

create table if not exists organisations (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  name text not null,
  type organisation_type not null default 'corporate',
  billing_email text,
  billing_address jsonb,
  payment_terms_days int not null default 0,
  purchase_order_required boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  organisation_id uuid references organisations(id) on delete set null,
  first_name text,
  last_name text,
  email text,
  phone text,
  -- Normalised forms, written by the application. Matching on raw text misses
  -- "07700 900123" against "+447700900123", the most common duplicate there is.
  email_normalised text,
  phone_normalised text,
  preferred_language text not null default 'en',
  marketing_consent boolean not null default false,
  consent_source text,
  consent_at timestamptz,
  unsubscribed_at timestamptz,
  anonymised_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists customers_brand_idx on customers (brand_id);
create index if not exists customers_email_idx on customers (email_normalised) where email_normalised is not null;
create index if not exists customers_phone_idx on customers (phone_normalised) where phone_normalised is not null;
create index if not exists customers_name_trgm_idx on customers
  using gin ((coalesce(first_name,'') || ' ' || coalesce(last_name,'')) gin_trgm_ops);

create table if not exists customer_portal_tokens (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  token_hash text not null unique,
  scope text not null default 'portal',
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists customer_portal_tokens_customer_idx on customer_portal_tokens (customer_id);

-- ---------------------------------------------------------------------------
-- 5. Pipeline
-- ---------------------------------------------------------------------------
create table if not exists services (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  slug text not null,
  name text not null,
  category customer_type not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, slug)
);

create table if not exists lead_sources (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  kind lead_source_kind not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, name)
);

create table if not exists lead_providers (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  name text not null,
  contact_email text,
  cost_per_lead_minor bigint not null default 0,
  currency currency_code not null default 'GBP',
  active_from date,
  active_to date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, name)
);

create table if not exists lost_reasons (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  label text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  unique (brand_id, label)
);

-- Human-readable references: EGM-2609-0412. Staff read these over the phone,
-- so a UUID is not an option.
create table if not exists reference_sequences (
  brand_id uuid not null references brands(id) on delete cascade,
  entity text not null,                      -- 'lead' | 'quote' | 'job' | 'invoice'
  period text not null,                      -- 'YYMM'
  last_value int not null default 0,
  primary key (brand_id, entity, period)
);

create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  reference text not null,
  customer_id uuid references customers(id) on delete set null,
  branch_id uuid references branches(id) on delete set null,
  source_id uuid references lead_sources(id) on delete set null,
  provider_id uuid references lead_providers(id) on delete set null,
  service_id uuid references services(id) on delete set null,
  customer_type customer_type,
  status lead_status not null default 'new',
  owner_staff_id uuid references staff(id) on delete set null,
  assigned_at timestamptz,
  move_date date,
  move_date_flexible boolean not null default false,
  origin_postcode text,
  destination_postcode text,
  origin_outward text,
  destination_outward text,
  origin_access jsonb not null default '{}'::jsonb,
  destination_access jsonb not null default '{}'::jsonb,
  -- Both attribution models stored, both reported. Picking one and hiding the
  -- other is how marketing spend gets misattributed.
  first_touch jsonb not null default '{}'::jsonb,
  last_touch jsonb not null default '{}'::jsonb,
  -- The raw submission, persisted before validation so a malformed post from a
  -- brand website is recoverable rather than lost.
  raw_payload jsonb not null default '{}'::jsonb,
  score int,
  score_components jsonb,
  duplicate_of_lead_id uuid references leads(id) on delete set null,
  cross_brand_overlap_lead_id uuid references leads(id) on delete set null,
  lost_reason_id uuid references lost_reasons(id) on delete set null,
  quoted_at timestamptz,
  booked_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, reference)
);

create index if not exists leads_brand_status_idx on leads (brand_id, status);
create index if not exists leads_owner_idx on leads (owner_staff_id)
  where status in ('new','qualifying','quoted','chasing');
create index if not exists leads_unassigned_idx on leads (created_at) where owner_staff_id is null;
create index if not exists leads_move_date_idx on leads (move_date);

-- Append-only. Every status change, note, call and message lands here.
create table if not exists lead_events (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references leads(id) on delete cascade,
  type text not null,
  actor_staff_id uuid references staff(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists lead_events_lead_idx on lead_events (lead_id, occurred_at desc);

create table if not exists partial_submissions (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  session_key text not null,
  payload jsonb not null default '{}'::jsonb,
  email text,
  phone text,
  converted_lead_id uuid references leads(id) on delete set null,
  recovery_sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, session_key)
);

-- ---------------------------------------------------------------------------
-- 6. Inventory catalogue and quoting
-- ---------------------------------------------------------------------------
create table if not exists rooms (
  slug text primary key,
  name text not null,
  icon text not null,
  sort_order int not null default 0
);

create table if not exists items (
  slug text primary key,
  name text not null,
  room_slug text not null references rooms(slug) on delete restrict,
  icon text not null,
  volume_ft3 numeric(8,2) not null check (volume_ft3 > 0),
  crew_minutes int not null check (crew_minutes > 0),
  is_fragile boolean not null default false,
  requires_dismantle boolean not null default false,
  handling handling_class not null default 'standard',
  is_active boolean not null default true
);

create index if not exists items_room_idx on items (room_slug, name);

create table if not exists rate_cards (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  service_category customer_type not null,
  currency currency_code not null default 'GBP',
  effective_from date not null,
  effective_to date,
  -- True until the business signs the numbers off.
  provisional boolean not null default true,
  rules jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Overlapping cards would make a historical quote irreproducible.
create unique index if not exists rate_cards_unique_idx
  on rate_cards (brand_id, service_category, effective_from);

create table if not exists promo_codes (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  code text not null,
  kind text not null check (kind in ('percentage','fixed')),
  value numeric(10,4) not null,
  max_uses int,
  used_count int not null default 0,
  valid_from timestamptz,
  valid_to timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (brand_id, code)
);

create table if not exists quotes (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  lead_id uuid not null references leads(id) on delete cascade,
  reference text not null,
  version int not null default 1,
  status quote_status not null default 'draft',
  rate_card_id uuid references rate_cards(id) on delete restrict,
  prepared_by_staff_id uuid references staff(id) on delete set null,
  requires_manual_pricing boolean not null default false,
  manual_pricing_reasons text[] not null default '{}',
  packing packing_service not null default 'none',
  volume_ft3 numeric(10,2) not null default 0,
  crew_size int not null default 2,
  crew_minutes int not null default 0,
  road_distance_miles numeric(8,1),
  currency currency_code not null default 'GBP',
  net_minor bigint not null default 0,
  vat_minor bigint not null default 0,
  gross_minor bigint not null default 0,
  deposit_minor bigint not null default 0,
  fx_rate_to_gbp numeric(12,6) not null default 1,
  -- The frozen computation. The accepted PDF must be reproducible from this
  -- alone, months later, when a customer says "you quoted me less".
  pricing_snapshot jsonb,
  valid_until timestamptz,
  sent_at timestamptz,
  first_viewed_at timestamptz,
  accepted_at timestamptz,
  declined_at timestamptz,
  superseded_by_quote_id uuid references quotes(id) on delete set null,
  pdf_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, reference, version)
);

create index if not exists quotes_lead_idx on quotes (lead_id, version desc);
create index if not exists quotes_chase_idx on quotes (status, first_viewed_at) where status in ('sent','viewed');
create index if not exists quotes_expiry_idx on quotes (valid_until) where status in ('sent','viewed');

create table if not exists quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references quotes(id) on delete cascade,
  item_slug text references items(slug) on delete restrict,
  room_slug text references rooms(slug) on delete restrict,
  custom_name text,
  quantity int not null check (quantity > 0),
  volume_ft3 numeric(8,2) not null,
  notes text,
  -- Either a catalogue item or a named custom one, never neither: a line with
  -- no identity is how an item goes missing between the quote and the van.
  constraint quote_items_identified check (item_slug is not null or custom_name is not null)
);

create index if not exists quote_items_quote_idx on quote_items (quote_id);

create table if not exists quote_lines (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references quotes(id) on delete cascade,
  rule_id text not null,
  kind quote_line_kind not null,
  label text not null,
  detail text,
  inputs jsonb not null default '{}'::jsonb,
  quantity numeric(10,2),
  unit_amount_minor bigint,
  net_minor bigint not null,
  vat_rate numeric(5,4) not null default 0.2000,
  sort_order int not null default 0
);

create index if not exists quote_lines_quote_idx on quote_lines (quote_id, sort_order);

-- ---------------------------------------------------------------------------
-- 7. Jobs and operations
-- ---------------------------------------------------------------------------
create table if not exists vehicles (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  registration text not null,
  type text not null,
  capacity_ft3 int,
  is_active boolean not null default true,
  mot_due date,
  insurance_due date,
  service_due_mileage int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, registration)
);

create table if not exists jobs (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  lead_id uuid not null references leads(id) on delete restrict,
  quote_id uuid not null references quotes(id) on delete restrict,
  customer_id uuid not null references customers(id) on delete restrict,
  branch_id uuid references branches(id) on delete set null,
  reference text not null,
  status job_status not null default 'booked',
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  actual_start timestamptz,
  actual_end timestamptz,
  origin_address jsonb not null default '{}'::jsonb,
  destination_address jsonb not null default '{}'::jsonb,
  -- Copied from the quote at booking, verbatim. Whatever the salesperson typed
  -- reaches the crew unedited — the fix for lost access notes.
  access_notes text,
  special_instructions text,
  crew_size int not null default 2,
  volume_ft3 numeric(10,2),
  handling_classes handling_class[] not null default '{}',
  cancelled_reason text,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, reference),
  constraint jobs_schedule_ordered
    check (scheduled_end is null or scheduled_start is null or scheduled_end > scheduled_start)
);

create index if not exists jobs_calendar_idx on jobs (brand_id, scheduled_start) where status <> 'cancelled';
create index if not exists jobs_customer_idx on jobs (customer_id);

create table if not exists job_assignments (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  staff_id uuid references staff(id) on delete cascade,
  vehicle_id uuid references vehicles(id) on delete cascade,
  role assignment_role not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  cancelled_at timestamptz,
  assigned_by_staff_id uuid references staff(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint job_assignments_subject check (staff_id is not null or vehicle_id is not null),
  constraint job_assignments_ordered check (ends_at > starts_at)
);

-- Double-booking prevention as a database constraint, not UI validation: a
-- check in the form is bypassed by a second tab, a concurrent request, or an
-- import.
do $$ begin
  alter table job_assignments
    add constraint job_assignments_no_staff_overlap
    exclude using gist (
      staff_id with =,
      tstzrange(starts_at, ends_at, '[)') with &&
    ) where (staff_id is not null and cancelled_at is null);
exception when duplicate_table or duplicate_object then null; end $$;

do $$ begin
  alter table job_assignments
    add constraint job_assignments_no_vehicle_overlap
    exclude using gist (
      vehicle_id with =,
      tstzrange(starts_at, ends_at, '[)') with &&
    ) where (vehicle_id is not null and cancelled_at is null);
exception when duplicate_table or duplicate_object then null; end $$;

create index if not exists job_assignments_job_idx on job_assignments (job_id) where cancelled_at is null;
create index if not exists job_assignments_staff_idx on job_assignments (staff_id, starts_at) where cancelled_at is null;

create table if not exists job_sheets (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  generated_at timestamptz not null default now(),
  generated_by_staff_id uuid references staff(id) on delete set null,
  pdf_path text,
  snapshot jsonb not null
);

create index if not exists job_sheets_job_idx on job_sheets (job_id, generated_at desc);

create table if not exists attendance (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references staff(id) on delete cascade,
  brand_id uuid references brands(id) on delete set null,
  department staff_department not null,
  job_id uuid references jobs(id) on delete set null,
  clock_in_at timestamptz not null,
  clock_out_at timestamptz,
  source text not null default 'web',
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attendance_ordered check (clock_out_at is null or clock_out_at > clock_in_at)
);

-- One open shift per person. Two open clock-ins is how timesheets stop
-- reconciling, and it is easier to prevent than to correct at payroll.
create unique index if not exists attendance_one_open_shift_idx on attendance (staff_id) where clock_out_at is null;
create index if not exists attendance_period_idx on attendance (staff_id, clock_in_at desc);

create table if not exists sales_targets (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  staff_id uuid references staff(id) on delete cascade,
  period target_period not null,
  period_start date not null,
  size move_size not null,
  target_amount_minor bigint not null default 0,
  target_count int not null default 0,
  currency currency_code not null default 'GBP',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists sales_targets_unique_idx
  on sales_targets (brand_id, coalesce(staff_id, '00000000-0000-0000-0000-000000000000'::uuid), period, period_start, size);

-- ---------------------------------------------------------------------------
-- 8. Money
--    Every amount is integer minor units plus a currency; non-GBP rows
--    snapshot the rate so consolidated reporting never re-fetches.
-- ---------------------------------------------------------------------------
create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  job_id uuid references jobs(id) on delete set null,
  customer_id uuid not null references customers(id) on delete restrict,
  organisation_id uuid references organisations(id) on delete set null,
  number text not null,
  status invoice_status not null default 'draft',
  issued_on date,
  due_on date,
  currency currency_code not null default 'GBP',
  net_minor bigint not null default 0,
  vat_minor bigint not null default 0,
  gross_minor bigint not null default 0,
  paid_minor bigint not null default 0,
  fx_rate_to_gbp numeric(12,6) not null default 1,
  pdf_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, number)
);

create index if not exists invoices_outstanding_idx on invoices (brand_id, due_on)
  where status in ('issued','part_paid','overdue');

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  invoice_id uuid references invoices(id) on delete set null,
  quote_id uuid references quotes(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  method payment_method not null,
  status payment_status not null default 'pending',
  amount_minor bigint not null,
  currency currency_code not null default 'GBP',
  fx_rate_to_gbp numeric(12,6) not null default 1,
  provider_reference text,
  bank_reference text,
  received_at timestamptz,
  reconciled_at timestamptz,
  reconciled_by_staff_id uuid references staff(id) on delete set null,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A provider reference can appear only once. This is what makes the Stripe
-- webhook idempotent under replay, which it will be: providers retry.
create unique index if not exists payments_provider_reference_idx
  on payments (provider_reference) where provider_reference is not null;
create index if not exists payments_invoice_idx on payments (invoice_id);

create table if not exists payment_links (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  quote_id uuid not null references quotes(id) on delete cascade,
  provider text not null,
  provider_reference text,
  url text not null,
  amount_minor bigint not null,
  currency currency_code not null default 'GBP',
  status text not null default 'open',
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists payment_links_quote_idx on payment_links (quote_id);

-- Raw provider events, stored before processing, so a handler that threw is
-- replayable rather than lost.
create table if not exists webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_id text not null,
  event_type text,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  error text,
  unique (provider, event_id)
);

-- ---------------------------------------------------------------------------
-- 9. Messaging
-- ---------------------------------------------------------------------------
create table if not exists message_templates (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references brands(id) on delete cascade,   -- null = platform default
  key text not null,
  channel message_channel not null,
  locale text not null default 'en',
  subject text,
  body text not null,
  version int not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists message_templates_resolution_idx
  on message_templates (coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid), key, channel, locale, version);

create table if not exists sequences (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references brands(id) on delete cascade,
  key text not null,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists sequences_key_idx
  on sequences (coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid), key);

create table if not exists sequence_steps (
  id uuid primary key default gen_random_uuid(),
  sequence_id uuid not null references sequences(id) on delete cascade,
  step_order int not null,
  -- Minutes from enrolment, not from the previous step: absolute offsets stay
  -- correct when a step is deferred by quiet hours or the fair-use cap.
  delay_minutes int not null,
  channel message_channel not null,
  template_key text not null,
  stop_conditions text[] not null,
  respect_quiet_hours boolean not null default true,
  counts_toward_frequency_cap boolean not null default true,
  unique (sequence_id, step_order),
  -- cardinality(), not array_length(): array_length('{}', 1) is NULL and a
  -- CHECK that evaluates to NULL passes, letting an empty array through.
  constraint sequence_steps_have_stops check (cardinality(stop_conditions) >= 1)
);

create table if not exists sequence_enrolments (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  sequence_id uuid not null references sequences(id) on delete cascade,
  subject_type text not null,                -- 'lead' | 'quote' | 'job' | 'invoice'
  subject_id uuid not null,
  customer_id uuid references customers(id) on delete cascade,
  status enrolment_status not null default 'active',
  next_step_order int not null default 1,
  next_run_at timestamptz not null default now(),
  stopped_reason text,
  stopped_at timestamptz,
  enrolled_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- One live enrolment per subject per sequence: re-enrolling a lead already
  -- being chased is how a customer gets the same email twice.
  unique (sequence_id, subject_type, subject_id)
);

create index if not exists sequence_enrolments_due_idx on sequence_enrolments (next_run_at) where status = 'active';

create table if not exists outbox (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  enrolment_id uuid references sequence_enrolments(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  channel message_channel not null,
  to_address text,
  template_key text not null,
  payload jsonb not null default '{}'::jsonb,
  send_after timestamptz not null default now(),
  status outbox_status not null default 'queued',
  attempts int not null default 0,
  -- seq:{enrolment}:{step}. One enrolment and one step can only ever produce
  -- one message, so concurrent cron ticks cannot double-send.
  idempotency_key text not null unique,
  provider_message_id text,
  counts_toward_frequency_cap boolean not null default true,
  error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists outbox_due_idx on outbox (send_after) where status = 'queued';
create index if not exists outbox_manual_queue_idx on outbox (brand_id, created_at) where status = 'needs_manual_send';

create table if not exists message_log (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  outbox_id uuid references outbox(id) on delete set null,
  direction message_direction not null,
  channel message_channel not null,
  template_key text,
  subject text,
  body_preview text,
  to_address text,
  from_address text,
  provider_message_id text,
  counted_toward_cap boolean not null default false,
  sent_at timestamptz not null default now(),
  delivered_at timestamptz,
  opened_at timestamptz,
  clicked_at timestamptz,
  replied_at timestamptz,
  failed_at timestamptz
);

create index if not exists message_log_cap_idx on message_log (customer_id, sent_at desc) where counted_toward_cap;

-- Unsubscribes are global by contact, not per brand. A customer who opts out
-- of one brand must not start receiving another's mail.
create table if not exists unsubscribes (
  id uuid primary key default gen_random_uuid(),
  channel message_channel not null,
  address_normalised text not null,
  reason text,
  created_at timestamptz not null default now(),
  unique (channel, address_normalised)
);

-- ---------------------------------------------------------------------------
-- 10. Audit and compliance
-- ---------------------------------------------------------------------------
create table if not exists audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_staff_id uuid references staff(id) on delete set null,
  actor_role brand_role,
  actor_email text,
  brand_id uuid references brands(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before jsonb,
  after jsonb,
  ip inet,
  user_agent text,
  occurred_at timestamptz not null default now()
);

create index if not exists audit_log_entity_idx on audit_log (entity_type, entity_id, occurred_at desc);
create index if not exists audit_log_actor_idx on audit_log (actor_staff_id, occurred_at desc);

create table if not exists data_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id) on delete set null,
  customer_email text not null,
  kind data_request_kind not null,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  performed_by_staff_id uuid references staff(id) on delete set null,
  result_path text,
  notes text
);

create table if not exists retention_policies (
  entity_type text primary key,
  retain_days int not null,
  basis text not null,
  action retention_action not null,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 11. updated_at triggers
--     Created last, so every table they attach to already exists.
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'brands','branches','staff','organisations','customers','services',
    'lead_sources','lead_providers','leads','partial_submissions','rate_cards',
    'quotes','vehicles','jobs','attendance','sales_targets','invoices',
    'payments','message_templates','sequences','sequence_enrolments','outbox'
  ]
  loop
    execute format(
      'drop trigger if exists %I on public.%I', t || '_touch', t
    );
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.touch_updated_at()',
      t || '_touch', t
    );
  end loop;
end $$;


-- ##########################################################################
-- # 02_integrity.sql
-- ##########################################################################

-- ==========================================================================
--  EcoGreen Group CRM — PART 2 — INTEGRITY: references, quote freezing, audit immutability
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
    if to_regclass('public.quotes') is null then
      raise exception 'Run PART 1 (schema) first — table "quotes" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.audit_log') is null then
      raise exception 'Run PART 1 (schema) first — table "audit_log" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.staff_brand_access') is null then
      raise exception 'Run PART 1 (schema) first — table "staff_brand_access" does not exist.'
        using errcode = 'undefined_table';
    end if;
end
$precheck$;

create or replace function next_reference(target_brand uuid, target_entity text, at timestamptz default now())
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- Prefixed to avoid colliding with the column names below: an unprefixed
  -- `period` is ambiguous inside the INSERT and plpgsql rejects it.
  v_period text := to_char(at at time zone 'Europe/London', 'YYMM');
  v_brand_code text;
  v_seq int;
begin
  select b.code into v_brand_code from public.brands b where b.id = target_brand;
  if v_brand_code is null then
    raise exception 'Unknown brand %', target_brand;
  end if;

  insert into public.reference_sequences as rs (brand_id, entity, period, last_value)
  values (target_brand, target_entity, v_period, 1)
  on conflict (brand_id, entity, period)
    do update set last_value = rs.last_value + 1
  returning rs.last_value into v_seq;

  return v_brand_code || '-' || v_period || '-' || lpad(v_seq::text, 4, '0');
end;
$$;


create or replace function private.reject_sent_quote_change()
returns trigger
language plpgsql
as $$
declare
  frozen_status public.quote_status[] := array['sent','viewed','accepted','expired','superseded','declined'];
begin
  if tg_op = 'DELETE' then
    if old.status = any (frozen_status) then
      raise exception 'Quote % has been sent and cannot be deleted; supersede it with a new version.', old.id
        using errcode = 'restrict_violation';
    end if;
    return old;
  end if;

  if old.status = any (frozen_status) then
    -- Status, view/acceptance timestamps and the supersede pointer are the
    -- only things a sent quote may still record about itself.
    if (new.net_minor, new.vat_minor, new.gross_minor, new.deposit_minor,
        new.pricing_snapshot, new.rate_card_id, new.volume_ft3, new.packing,
        new.currency, new.valid_until)
       is distinct from
       (old.net_minor, old.vat_minor, old.gross_minor, old.deposit_minor,
        old.pricing_snapshot, old.rate_card_id, old.volume_ft3, old.packing,
        old.currency, old.valid_until)
    then
      raise exception 'Quote % is sent and its pricing is frozen; create version %.', old.id, old.version + 1
        using errcode = 'restrict_violation';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists quotes_freeze_after_send on quotes;
create trigger quotes_freeze_after_send
  before update or delete on quotes
  for each row execute function private.reject_sent_quote_change();

create or replace function private.reject_sent_quote_child_change()
returns trigger
language plpgsql
as $$
declare
  parent uuid := coalesce(new.quote_id, old.quote_id);
  parent_status public.quote_status;
begin
  select q.status into parent_status from public.quotes q where q.id = parent;
  if parent_status in ('sent','viewed','accepted','expired','superseded','declined') then
    raise exception 'Quote % is sent; its lines and items are frozen.', parent
      using errcode = 'restrict_violation';
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists quote_items_freeze on quote_items;
create trigger quote_items_freeze
  before insert or update or delete on quote_items
  for each row execute function private.reject_sent_quote_child_change();

drop trigger if exists quote_lines_freeze on quote_lines;
create trigger quote_lines_freeze
  before insert or update or delete on quote_lines
  for each row execute function private.reject_sent_quote_child_change();


create or replace function private.reject_audit_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_log is append-only' using errcode = 'restrict_violation';
end;
$$;

drop trigger if exists audit_log_no_update on audit_log;
create trigger audit_log_no_update before update on audit_log for each row execute function private.reject_audit_mutation();
drop trigger if exists audit_log_no_delete on audit_log;
create trigger audit_log_no_delete before delete on audit_log for each row execute function private.reject_audit_mutation();


create or replace function private.guard_brand_access_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_platform_admin() then
    raise exception 'Only a platform admin may change brand access'
      using errcode = 'insufficient_privilege';
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists staff_brand_access_guard on staff_brand_access;
create trigger staff_brand_access_guard
  before insert or update or delete on staff_brand_access
  for each row execute function private.guard_brand_access_change();


-- ##########################################################################
-- # 03_security.sql
-- ##########################################################################

-- ==========================================================================
--  EcoGreen Group CRM — PART 3 — SECURITY: helpers and row level security
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
    if to_regclass('public.brands') is null then
      raise exception 'Run PART 1 (schema) first — table "brands" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.staff') is null then
      raise exception 'Run PART 1 (schema) first — table "staff" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.jobs') is null then
      raise exception 'Run PART 1 (schema) first — table "jobs" does not exist.'
        using errcode = 'undefined_table';
    end if;
end
$precheck$;

-- Role ranking, so a policy can say "manager or above" without listing roles.
create or replace function private.role_rank(r public.brand_role)
returns int
language sql
immutable
as $$
  select case r
    when 'admin'    then 60
    when 'manager'  then 50
    when 'accounts' then 40
    when 'ops'      then 30
    when 'sales'    then 20
    when 'crew'     then 10
    when 'readonly' then 5
  end;
$$;

grant usage on schema private to authenticated;

-- Access helpers.
--
-- These read tables, so they are created after those tables exist. They live
-- in the `private` schema rather than `public`, are `security definer`, and
-- pin an empty search_path.
--
-- That combination is not stylistic. The marketplace app in this repo hit RLS
-- infinite recursion when its helpers lived in `public` (see its migrations
-- 0014-0015): a policy called a function that selected from a table whose own
-- policy called the same function. A helper outside the RLS graph breaks the
-- cycle, and the pinned search_path closes the hijack vector.

-- The staff row for the current session, or null for a customer/anon session.
create or replace function private.current_staff_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id from public.staff s
  where s.auth_user_id = auth.uid()
    and s.ended_on is null
  limit 1;
$$;

create or replace function private.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff s
    join public.staff_brand_access a on a.staff_id = s.id
    where s.auth_user_id = auth.uid()
      and s.ended_on is null
      and a.role = 'admin'
  );
$$;

create or replace function private.has_brand_access(target_brand uuid, min_role public.brand_role default 'readonly')
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.staff s
    join public.staff_brand_access a on a.staff_id = s.id
    where s.auth_user_id = auth.uid()
      and s.ended_on is null
      -- A platform admin's access is not brand-scoped; everyone else must hold
      -- a grant on this specific brand.
      and (a.brand_id = target_brand or a.role = 'admin')
      and private.role_rank(a.role) >= private.role_rank(min_role)
  );
$$;

-- Crew access is by assignment, not by brand: a mover sees the jobs they are
-- actually on and nothing else. Broken out so the job policies stay readable.
create or replace function private.is_assigned_to_job(target_job uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.job_assignments ja
    where ja.job_id = target_job
      and ja.staff_id = private.current_staff_id()
      and ja.cancelled_at is null
  );
$$;

-- Row Level Security.
--
-- Deny by default, everywhere. Every table below has RLS enabled; a table with
-- RLS on and no matching policy returns nothing, which is the correct failure
-- mode. Adding a table without adding its policy here is a bug that fails
-- closed rather than leaking.
--
-- Two deliberate design points:
--
--  1. The customer portal does NOT get its own policies. Customers authenticate
--     with a short-lived hashed token, not a Supabase session, and their reads
--     go through server routes that validate the token and use the service key.
--     Giving customers a role in the same RLS graph as staff doubles the number
--     of ways a policy can be wrong, for no benefit.
--
--  2. Crew see their own assignments and nothing priced. A crew phone left in a
--     customer's hallway must not expose the brand's margins.

-- ── Tenancy and people ────────────────────────────────────────────────────
alter table brands enable row level security;
drop policy if exists brands_read on brands;
create policy brands_read on brands for select to authenticated
  using (private.has_brand_access(id, 'readonly'));
drop policy if exists brands_write on brands;
create policy brands_write on brands for all to authenticated
  using (private.has_brand_access(id, 'admin')) with check (private.has_brand_access(id, 'admin'));

alter table branches enable row level security;
drop policy if exists branches_read on branches;
create policy branches_read on branches for select to authenticated
  using (private.has_brand_access(brand_id, 'readonly'));
drop policy if exists branches_write on branches;
create policy branches_write on branches for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table staff enable row level security;
-- Staff can always see themselves; otherwise a manager in a shared brand.
drop policy if exists staff_read on staff;
create policy staff_read on staff for select to authenticated
  using (
    auth_user_id = auth.uid()
    or private.is_platform_admin()
    or exists (
      select 1 from staff_brand_access a
      where a.staff_id = staff.id
        and private.has_brand_access(a.brand_id, 'manager')
    )
  );
drop policy if exists staff_self_update on staff;
create policy staff_self_update on staff for update to authenticated
  using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid());
drop policy if exists staff_admin_write on staff;
create policy staff_admin_write on staff for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

alter table staff_brand_access enable row level security;
drop policy if exists sba_read on staff_brand_access;
create policy sba_read on staff_brand_access for select to authenticated
  using (private.has_brand_access(brand_id, 'manager') or staff_id = private.current_staff_id());
-- Writes are additionally gated by the trigger in 0009; the policy alone is
-- not relied upon for privilege escalation.
drop policy if exists sba_write on staff_brand_access;
create policy sba_write on staff_brand_access for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

alter table organisations enable row level security;
drop policy if exists organisations_read on organisations;
create policy organisations_read on organisations for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists organisations_write on organisations;
create policy organisations_write on organisations for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table customers enable row level security;
-- Note: 'sales' and above. Crew are excluded entirely — what they need about a
-- customer reaches them on the job sheet, which is generated server-side.
drop policy if exists customers_read on customers;
create policy customers_read on customers for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists customers_write on customers;
create policy customers_write on customers for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table customer_portal_tokens enable row level security;
-- Server-side only. No policy: nothing with a user session may read token
-- hashes, including an admin.

-- ── Pipeline ──────────────────────────────────────────────────────────────
alter table services enable row level security;
drop policy if exists services_read on services;
create policy services_read on services for select to authenticated
  using (private.has_brand_access(brand_id, 'readonly'));
drop policy if exists services_write on services;
create policy services_write on services for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table lead_sources enable row level security;
drop policy if exists lead_sources_read on lead_sources;
create policy lead_sources_read on lead_sources for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists lead_sources_write on lead_sources;
create policy lead_sources_write on lead_sources for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table lead_providers enable row level security;
drop policy if exists lead_providers_read on lead_providers;
create policy lead_providers_read on lead_providers for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists lead_providers_write on lead_providers;
create policy lead_providers_write on lead_providers for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table lost_reasons enable row level security;
drop policy if exists lost_reasons_read on lost_reasons;
create policy lost_reasons_read on lost_reasons for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists lost_reasons_write on lost_reasons;
create policy lost_reasons_write on lost_reasons for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table reference_sequences enable row level security;
-- Server-side only: references are allocated by next_reference(), which is
-- security definer. No session may edit the counter.

alter table leads enable row level security;
drop policy if exists leads_read on leads;
create policy leads_read on leads for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists leads_write on leads;
create policy leads_write on leads for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table lead_events enable row level security;
drop policy if exists lead_events_read on lead_events;
create policy lead_events_read on lead_events for select to authenticated
  using (exists (select 1 from leads l where l.id = lead_events.lead_id and private.has_brand_access(l.brand_id, 'sales')));
-- Append-only from a session: no update or delete policy exists, so the
-- timeline cannot be rewritten after the fact.
drop policy if exists lead_events_insert on lead_events;
create policy lead_events_insert on lead_events for insert to authenticated
  with check (exists (select 1 from leads l where l.id = lead_events.lead_id and private.has_brand_access(l.brand_id, 'sales')));

alter table partial_submissions enable row level security;
drop policy if exists partial_submissions_read on partial_submissions;
create policy partial_submissions_read on partial_submissions for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));

-- ── Catalogue, quoting ────────────────────────────────────────────────────
alter table rooms enable row level security;
drop policy if exists rooms_read on rooms;
create policy rooms_read on rooms for select to authenticated using (true);

alter table items enable row level security;
drop policy if exists items_read on items;
create policy items_read on items for select to authenticated using (true);

alter table rate_cards enable row level security;
-- Rate cards are commercially sensitive: managers and accounts, never crew,
-- and never a sales user in another brand.
drop policy if exists rate_cards_read on rate_cards;
create policy rate_cards_read on rate_cards for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists rate_cards_write on rate_cards;
create policy rate_cards_write on rate_cards for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table promo_codes enable row level security;
drop policy if exists promo_codes_read on promo_codes;
create policy promo_codes_read on promo_codes for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists promo_codes_write on promo_codes;
create policy promo_codes_write on promo_codes for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table quotes enable row level security;
drop policy if exists quotes_read on quotes;
create policy quotes_read on quotes for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists quotes_write on quotes;
create policy quotes_write on quotes for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table quote_items enable row level security;
drop policy if exists quote_items_all on quote_items;
create policy quote_items_all on quote_items for all to authenticated
  using (exists (select 1 from quotes q where q.id = quote_items.quote_id and private.has_brand_access(q.brand_id, 'sales')))
  with check (exists (select 1 from quotes q where q.id = quote_items.quote_id and private.has_brand_access(q.brand_id, 'sales')));

alter table quote_lines enable row level security;
drop policy if exists quote_lines_all on quote_lines;
create policy quote_lines_all on quote_lines for all to authenticated
  using (exists (select 1 from quotes q where q.id = quote_lines.quote_id and private.has_brand_access(q.brand_id, 'sales')))
  with check (exists (select 1 from quotes q where q.id = quote_lines.quote_id and private.has_brand_access(q.brand_id, 'sales')));

-- ── Operations ────────────────────────────────────────────────────────────
alter table vehicles enable row level security;
drop policy if exists vehicles_read on vehicles;
create policy vehicles_read on vehicles for select to authenticated
  using (private.has_brand_access(brand_id, 'crew'));
drop policy if exists vehicles_write on vehicles;
create policy vehicles_write on vehicles for all to authenticated
  using (private.has_brand_access(brand_id, 'ops')) with check (private.has_brand_access(brand_id, 'ops'));

alter table jobs enable row level security;
-- Ops and above see the brand's jobs; crew see only jobs they are on.
drop policy if exists jobs_read on jobs;
create policy jobs_read on jobs for select to authenticated
  using (private.has_brand_access(brand_id, 'ops') or private.is_assigned_to_job(id));
drop policy if exists jobs_write on jobs;
create policy jobs_write on jobs for all to authenticated
  using (private.has_brand_access(brand_id, 'ops')) with check (private.has_brand_access(brand_id, 'ops'));

alter table job_assignments enable row level security;
drop policy if exists job_assignments_read on job_assignments;
create policy job_assignments_read on job_assignments for select to authenticated
  using (
    staff_id = private.current_staff_id()
    or exists (select 1 from jobs j where j.id = job_assignments.job_id and private.has_brand_access(j.brand_id, 'ops'))
  );
drop policy if exists job_assignments_write on job_assignments;
create policy job_assignments_write on job_assignments for all to authenticated
  using (exists (select 1 from jobs j where j.id = job_assignments.job_id and private.has_brand_access(j.brand_id, 'ops')))
  with check (exists (select 1 from jobs j where j.id = job_assignments.job_id and private.has_brand_access(j.brand_id, 'ops')));

alter table job_sheets enable row level security;
drop policy if exists job_sheets_read on job_sheets;
create policy job_sheets_read on job_sheets for select to authenticated
  using (
    private.is_assigned_to_job(job_id)
    or exists (select 1 from jobs j where j.id = job_sheets.job_id and private.has_brand_access(j.brand_id, 'ops'))
  );

alter table attendance enable row level security;
drop policy if exists attendance_self on attendance;
create policy attendance_self on attendance for all to authenticated
  using (staff_id = private.current_staff_id()) with check (staff_id = private.current_staff_id());
drop policy if exists attendance_manager_read on attendance;
create policy attendance_manager_read on attendance for select to authenticated
  using (brand_id is not null and private.has_brand_access(brand_id, 'manager'));

alter table sales_targets enable row level security;
drop policy if exists sales_targets_read on sales_targets;
create policy sales_targets_read on sales_targets for select to authenticated
  using (staff_id = private.current_staff_id() or private.has_brand_access(brand_id, 'manager'));
drop policy if exists sales_targets_write on sales_targets;
create policy sales_targets_write on sales_targets for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

-- ── Money ─────────────────────────────────────────────────────────────────
alter table invoices enable row level security;
drop policy if exists invoices_read on invoices;
create policy invoices_read on invoices for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists invoices_write on invoices;
create policy invoices_write on invoices for all to authenticated
  using (private.has_brand_access(brand_id, 'accounts')) with check (private.has_brand_access(brand_id, 'accounts'));

alter table payments enable row level security;
drop policy if exists payments_read on payments;
create policy payments_read on payments for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists payments_write on payments;
create policy payments_write on payments for all to authenticated
  using (private.has_brand_access(brand_id, 'accounts')) with check (private.has_brand_access(brand_id, 'accounts'));

alter table payment_links enable row level security;
drop policy if exists payment_links_read on payment_links;
create policy payment_links_read on payment_links for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));

alter table webhook_events enable row level security;
-- Service role only. Raw provider payloads are not for any user session.

-- ── Messaging ─────────────────────────────────────────────────────────────
alter table message_templates enable row level security;
drop policy if exists message_templates_read on message_templates;
create policy message_templates_read on message_templates for select to authenticated
  using (brand_id is null or private.has_brand_access(brand_id, 'sales'));
drop policy if exists message_templates_write on message_templates;
create policy message_templates_write on message_templates for all to authenticated
  using (brand_id is not null and private.has_brand_access(brand_id, 'manager'))
  with check (brand_id is not null and private.has_brand_access(brand_id, 'manager'));

alter table sequences enable row level security;
drop policy if exists sequences_read on sequences;
create policy sequences_read on sequences for select to authenticated
  using (brand_id is null or private.has_brand_access(brand_id, 'sales'));
drop policy if exists sequences_write on sequences;
create policy sequences_write on sequences for all to authenticated
  using (brand_id is not null and private.has_brand_access(brand_id, 'manager'))
  with check (brand_id is not null and private.has_brand_access(brand_id, 'manager'));

alter table sequence_steps enable row level security;
drop policy if exists sequence_steps_read on sequence_steps;
create policy sequence_steps_read on sequence_steps for select to authenticated
  using (exists (select 1 from sequences s where s.id = sequence_steps.sequence_id
                   and (s.brand_id is null or private.has_brand_access(s.brand_id, 'sales'))));

alter table sequence_enrolments enable row level security;
drop policy if exists sequence_enrolments_read on sequence_enrolments;
create policy sequence_enrolments_read on sequence_enrolments for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
drop policy if exists sequence_enrolments_write on sequence_enrolments;
create policy sequence_enrolments_write on sequence_enrolments for update to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table outbox enable row level security;
drop policy if exists outbox_read on outbox;
create policy outbox_read on outbox for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
-- Staff may only act on the manual-send queue; the dispatcher itself runs
-- under the service role.
drop policy if exists outbox_manual_update on outbox;
create policy outbox_manual_update on outbox for update to authenticated
  using (private.has_brand_access(brand_id, 'sales') and status = 'needs_manual_send')
  with check (private.has_brand_access(brand_id, 'sales'));

alter table message_log enable row level security;
drop policy if exists message_log_read on message_log;
create policy message_log_read on message_log for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));

alter table unsubscribes enable row level security;
drop policy if exists unsubscribes_read on unsubscribes;
create policy unsubscribes_read on unsubscribes for select to authenticated using (true);

-- ── Audit and compliance ──────────────────────────────────────────────────
alter table audit_log enable row level security;
drop policy if exists audit_log_insert on audit_log;
create policy audit_log_insert on audit_log for insert to authenticated with check (true);
drop policy if exists audit_log_read on audit_log;
create policy audit_log_read on audit_log for select to authenticated
  using (private.is_platform_admin());
-- No update or delete policy, and the triggers in 0009 reject both regardless.

alter table data_requests enable row level security;
drop policy if exists data_requests_admin on data_requests;
create policy data_requests_admin on data_requests for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

alter table retention_policies enable row level security;
drop policy if exists retention_policies_read on retention_policies;
create policy retention_policies_read on retention_policies for select to authenticated using (true);
drop policy if exists retention_policies_write on retention_policies;
create policy retention_policies_write on retention_policies for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

-- Nothing in this schema is readable without a session.
revoke all on all tables in schema public from anon;


-- ##########################################################################
-- # 04_functions.sql
-- ##########################################################################

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


-- ##########################################################################
-- # 05_seed.sql
-- ##########################################################################

-- ==========================================================================
--  EcoGreen Group CRM — PART 5 — SEED DATA: brands, catalogue, rate cards, sequences
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
    if to_regclass('public.brands') is null then
      raise exception 'Run PARTS 1-3 first — table "brands" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.rooms') is null then
      raise exception 'Run PARTS 1-3 first — table "rooms" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.rate_cards') is null then
      raise exception 'Run PARTS 1-3 first — table "rate_cards" does not exist.'
        using errcode = 'undefined_table';
    end if;
end
$precheck$;

-- Guarded: if any brand already exists the whole block is skipped, so
-- re-running this script never duplicates the catalogue or the rate cards.
do $seed$
begin
  if exists (select 1 from public.brands) then
    raise notice 'Seed data already present - skipping.';
    return;
  end if;


insert into brands (slug, code, name, primary_domain, accent_hex, accent_dark_hex, email_from, email_reply_to, phone)
values
  ('ecogreen-movers',              'EGM', 'EcoGreen Movers',              'ecogreenmovers.co.uk',              '#18794E', '#3FBF84', 'quotes@ecogreenmovers.co.uk',              'hello@ecogreenmovers.co.uk',              null),
  ('eco-london-movers',            'ELM', 'Eco London Movers',            'ecolondonmovers.co.uk',             '#0B5FA5', '#4DA3E8', 'quotes@ecolondonmovers.co.uk',             'hello@ecolondonmovers.co.uk',             null),
  ('continuum-green',              'CG',  'Continuum Green',              'continuumgreen.co.uk',              '#146B63', '#35B3A6', 'quotes@continuumgreen.co.uk',              'hello@continuumgreen.co.uk',              null),
  ('removals-company-manchester',  'RCM', 'Removals Company Manchester',  'removalscompanymanchester.co.uk',   '#B42318', '#F0736A', 'quotes@removalscompanymanchester.co.uk',   'hello@removalscompanymanchester.co.uk',   null),
  ('edinburgh-moving',             'EDM', 'Edinburgh Moving',             'edinburghmoving.co.uk',             '#43467F', '#9195DB', 'quotes@edinburghmoving.co.uk',             'hello@edinburghmoving.co.uk',             null),
  ('glasgow-moving',               'GM',  'Glasgow Moving',               'glasgowmoving.co.uk',               '#1D4ED8', '#7CA0F5', 'quotes@glasgowmoving.co.uk',               'hello@glasgowmoving.co.uk',               null);
-- Branches. Outward codes are left empty rather than guessed: they drive
-- distance banding and branch routing, and a wrong list silently misroutes.
insert into branches (brand_id, name, city)
select b.id, v.name, v.city
from brands b
join (values
  ('ecogreen-movers', 'London',     'London'),
  ('ecogreen-movers', 'Manchester', 'Manchester'),
  ('ecogreen-movers', 'Edinburgh',  'Edinburgh'),
  ('eco-london-movers', 'London',   'London'),
  ('continuum-green', 'London',     'London'),
  ('removals-company-manchester', 'Manchester', 'Manchester'),
  ('edinburgh-moving', 'Edinburgh', 'Edinburgh'),
  ('glasgow-moving', 'Glasgow',     'Glasgow')
) as v(brand_slug, name, city) on v.brand_slug = b.slug;
-- Services, one row per brand per category actually offered.
insert into services (brand_id, slug, name, category)
select b.id, v.slug, v.name, v.category::customer_type
from brands b
cross join (values
  ('home-removals',        'Home removals',            'residential'),
  ('commercial-removals',  'Commercial removals',      'commercial'),
  ('office-relocation',    'Office relocation',        'office'),
  ('specialist-moves',     'Specialist relocations',   'specialist'),
  ('clearance',            'Clearance and disposal',   'clearance'),
  ('storage',              'Storage',                  'storage')
) as v(slug, name, category);
-- Lead sources and lost reasons, per brand.
insert into lead_sources (brand_id, kind, name)
select b.id, v.kind::lead_source_kind, v.name
from brands b
cross join (values
  ('website',  'Website enquiry form'),
  ('website',  'Embedded quote widget'),
  ('phone',    'Inbound call'),
  ('whatsapp', 'WhatsApp'),
  ('organic',  'Google organic'),
  ('ppc',      'Google Ads'),
  ('referral', 'Referral'),
  ('repeat',   'Repeat customer'),
  ('provider', 'Lead provider')
) as v(kind, name);
insert into lost_reasons (brand_id, label, sort_order)
select b.id, v.label, v.sort_order
from brands b
cross join (values
  ('Price too high', 1),
  ('Booked a competitor', 2),
  ('Move cancelled or postponed', 3),
  ('Date unavailable', 4),
  ('No response after chasing', 5),
  ('Out of area', 6),
  ('Service not offered', 7),
  ('Duplicate enquiry', 8)
) as v(label, sort_order);
insert into rooms (slug, name, icon, sort_order) values
  ('living_room', 'Living room', 'sofa', 1),
  ('dining_room', 'Dining room', 'dining-table', 2),
  ('kitchen', 'Kitchen', 'kitchen', 3),
  ('bedroom', 'Bedroom', 'bed', 4),
  ('nursery', 'Nursery', 'cot', 5),
  ('bathroom', 'Bathroom', 'bath', 6),
  ('study', 'Study / home office', 'desk', 7),
  ('garage', 'Garage / shed', 'garage', 8),
  ('garden', 'Garden', 'plant', 9),
  ('loft', 'Loft / storage', 'boxes', 10),
  ('office', 'Commercial office', 'office', 11),
  ('specialist', 'Specialist items', 'shield', 12);
insert into items (slug, name, room_slug, icon, volume_ft3, crew_minutes, is_fragile, requires_dismantle, handling) values
  ('sofa_2', 'Sofa, 2-seater', 'living_room', 'sofa', 20.00, 12, false, false, 'standard'),
  ('sofa_3', 'Sofa, 3-seater', 'living_room', 'sofa', 25.00, 15, false, false, 'standard'),
  ('sofa_corner', 'Corner sofa', 'living_room', 'sofa', 45.00, 25, false, true, 'standard'),
  ('armchair', 'Armchair', 'living_room', 'armchair', 12.00, 8, false, false, 'standard'),
  ('coffee_table', 'Coffee table', 'living_room', 'table', 8.00, 5, false, false, 'standard'),
  ('tv_55', 'Television, up to 55"', 'living_room', 'tv', 8.00, 8, true, false, 'standard'),
  ('tv_75', 'Television, over 55"', 'living_room', 'tv', 14.00, 12, true, false, 'standard'),
  ('bookcase', 'Bookcase', 'living_room', 'bookcase', 20.00, 12, false, true, 'standard'),
  ('rug_large', 'Rug, large', 'living_room', 'rug', 6.00, 5, false, false, 'standard'),
  ('floor_lamp', 'Floor lamp', 'living_room', 'lamp', 5.00, 4, false, false, 'standard'),
  ('dining_table_4', 'Dining table, seats 4', 'dining_room', 'dining-table', 20.00, 14, false, true, 'standard'),
  ('dining_table_8', 'Dining table, seats 6-8', 'dining_room', 'dining-table', 32.00, 20, false, true, 'standard'),
  ('dining_chair', 'Dining chair', 'dining_room', 'chair', 6.00, 3, false, false, 'standard'),
  ('sideboard', 'Sideboard', 'dining_room', 'sideboard', 25.00, 15, false, false, 'standard'),
  ('display_cabinet', 'Display cabinet', 'dining_room', 'cabinet', 28.00, 18, true, false, 'standard'),
  ('fridge_freezer', 'Fridge freezer', 'kitchen', 'fridge', 30.00, 20, false, false, 'heavy'),
  ('under_counter_fridge', 'Under-counter fridge', 'kitchen', 'fridge', 12.00, 10, false, false, 'standard'),
  ('washing_machine', 'Washing machine', 'kitchen', 'washer', 12.00, 15, false, false, 'heavy'),
  ('dishwasher', 'Dishwasher', 'kitchen', 'dishwasher', 12.00, 12, false, false, 'heavy'),
  ('cooker', 'Cooker / range', 'kitchen', 'cooker', 20.00, 18, false, false, 'heavy'),
  ('microwave', 'Microwave', 'kitchen', 'microwave', 4.00, 3, false, false, 'standard'),
  ('kitchen_box', 'Kitchen box, packed', 'kitchen', 'box', 4.00, 2, true, false, 'standard'),
  ('bed_single', 'Bed, single', 'bedroom', 'bed', 20.00, 14, false, true, 'standard'),
  ('bed_double', 'Bed, double', 'bedroom', 'bed', 30.00, 18, false, true, 'standard'),
  ('bed_king', 'Bed, king or super king', 'bedroom', 'bed', 40.00, 22, false, true, 'standard'),
  ('mattress_double', 'Mattress, double', 'bedroom', 'mattress', 18.00, 10, false, false, 'standard'),
  ('wardrobe_single', 'Wardrobe, single', 'bedroom', 'wardrobe', 30.00, 18, false, true, 'standard'),
  ('wardrobe_double', 'Wardrobe, double', 'bedroom', 'wardrobe', 40.00, 25, false, true, 'standard'),
  ('chest_drawers', 'Chest of drawers', 'bedroom', 'drawers', 18.00, 12, false, false, 'standard'),
  ('bedside_table', 'Bedside table', 'bedroom', 'table', 6.00, 4, false, false, 'standard'),
  ('mirror_large', 'Mirror, large', 'bedroom', 'mirror', 5.00, 6, true, false, 'standard'),
  ('cot', 'Cot / cot bed', 'nursery', 'cot', 18.00, 12, false, true, 'standard'),
  ('changing_table', 'Changing table', 'nursery', 'table', 12.00, 8, false, false, 'standard'),
  ('pushchair', 'Pushchair', 'nursery', 'pushchair', 8.00, 4, false, false, 'standard'),
  ('bathroom_cabinet', 'Bathroom cabinet', 'bathroom', 'cabinet', 8.00, 6, false, false, 'standard'),
  ('bathroom_box', 'Bathroom box, packed', 'bathroom', 'box', 4.00, 2, false, false, 'standard'),
  ('desk', 'Desk', 'study', 'desk', 20.00, 14, false, true, 'standard'),
  ('office_chair', 'Office chair', 'study', 'chair', 10.00, 5, false, false, 'standard'),
  ('filing_cabinet', 'Filing cabinet', 'study', 'cabinet', 14.00, 12, false, false, 'heavy'),
  ('desktop_computer', 'Desktop computer', 'study', 'computer', 6.00, 6, true, false, 'standard'),
  ('printer', 'Printer', 'study', 'printer', 6.00, 5, true, false, 'standard'),
  ('bicycle', 'Bicycle', 'garage', 'bicycle', 12.00, 6, false, false, 'standard'),
  ('lawnmower', 'Lawnmower', 'garage', 'mower', 12.00, 8, false, false, 'standard'),
  ('tool_chest', 'Tool chest', 'garage', 'toolbox', 14.00, 12, false, false, 'heavy'),
  ('workbench', 'Workbench', 'garage', 'workbench', 25.00, 18, false, false, 'heavy'),
  ('bbq', 'Barbecue', 'garden', 'bbq', 15.00, 10, false, false, 'standard'),
  ('garden_table_set', 'Garden table and chairs', 'garden', 'dining-table', 30.00, 18, false, false, 'standard'),
  ('plant_pot_large', 'Plant pot, large', 'garden', 'plant', 8.00, 6, false, false, 'heavy'),
  ('box_small', 'Box, standard (small)', 'loft', 'box', 2.00, 1, false, false, 'standard'),
  ('box_large', 'Box, double-walled (large)', 'loft', 'box', 4.00, 2, false, false, 'standard'),
  ('wardrobe_box', 'Wardrobe box', 'loft', 'wardrobe-box', 12.00, 4, false, false, 'standard'),
  ('suitcase', 'Suitcase', 'loft', 'suitcase', 4.00, 2, false, false, 'standard'),
  ('storage_crate', 'Storage crate', 'loft', 'crate', 5.00, 2, false, false, 'standard'),
  ('office_desk', 'Office desk', 'office', 'desk', 22.00, 15, false, true, 'standard'),
  ('office_pedestal', 'Desk pedestal', 'office', 'drawers', 8.00, 6, false, false, 'standard'),
  ('meeting_table', 'Meeting table', 'office', 'dining-table', 40.00, 25, false, true, 'standard'),
  ('office_storage_unit', 'Office storage unit', 'office', 'cabinet', 25.00, 16, false, false, 'standard'),
  ('server_rack', 'Server rack', 'office', 'server', 35.00, 45, true, false, 'it_equipment'),
  ('photocopier', 'Photocopier', 'office', 'printer', 30.00, 35, false, false, 'heavy'),
  ('piano_upright', 'Piano, upright', 'specialist', 'piano', 45.00, 60, false, false, 'piano'),
  ('piano_grand', 'Piano, grand', 'specialist', 'piano', 80.00, 120, false, true, 'piano'),
  ('artwork_framed', 'Artwork, framed', 'specialist', 'art', 6.00, 20, true, false, 'fine_art'),
  ('sculpture', 'Sculpture', 'specialist', 'art', 15.00, 30, true, false, 'fine_art'),
  ('safe', 'Safe', 'specialist', 'safe', 20.00, 45, false, false, 'heavy'),
  ('lab_equipment', 'Laboratory equipment', 'specialist', 'flask', 20.00, 40, true, false, 'laboratory'),
  ('medical_equipment', 'Medical equipment', 'specialist', 'medical', 25.00, 40, true, false, 'medical'),
  ('antique_furniture', 'Antique furniture', 'specialist', 'antique', 25.00, 30, true, false, 'fine_art');
insert into rate_cards (brand_id, service_category, effective_from, provisional, rules)
select b.id, v.category::customer_type, v.effective_from::date, v.provisional, v.rules
from brands b
cross join (values
  ('residential', '2026-01-01', true, '{"minimumChargeMinor":18000,"volumeBands":[{"upToFt3":250,"perFt3Minor":90},{"upToFt3":500,"perFt3Minor":70},{"upToFt3":900,"perFt3Minor":55},{"upToFt3":1400,"perFt3Minor":45},{"upToFt3":null,"perFt3Minor":38}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":2800,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('commercial', '2026-01-01', true, '{"minimumChargeMinor":35000,"volumeBands":[{"upToFt3":250,"perFt3Minor":110},{"upToFt3":500,"perFt3Minor":85},{"upToFt3":900,"perFt3Minor":68},{"upToFt3":1400,"perFt3Minor":55},{"upToFt3":null,"perFt3Minor":46}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":3200,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('office', '2026-01-01', true, '{"minimumChargeMinor":35000,"volumeBands":[{"upToFt3":250,"perFt3Minor":110},{"upToFt3":500,"perFt3Minor":85},{"upToFt3":900,"perFt3Minor":68},{"upToFt3":1400,"perFt3Minor":55},{"upToFt3":null,"perFt3Minor":46}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":3200,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('specialist', '2026-01-01', true, '{"minimumChargeMinor":50000,"volumeBands":[{"upToFt3":250,"perFt3Minor":140},{"upToFt3":500,"perFt3Minor":110},{"upToFt3":900,"perFt3Minor":90},{"upToFt3":1400,"perFt3Minor":75},{"upToFt3":null,"perFt3Minor":60}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":3800,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('clearance', '2026-01-01', true, '{"minimumChargeMinor":15000,"volumeBands":[{"upToFt3":250,"perFt3Minor":70},{"upToFt3":500,"perFt3Minor":55},{"upToFt3":900,"perFt3Minor":44},{"upToFt3":1400,"perFt3Minor":36},{"upToFt3":null,"perFt3Minor":30}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":2600,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('storage', '2026-01-01', true, '{"minimumChargeMinor":12000,"volumeBands":[{"upToFt3":250,"perFt3Minor":60},{"upToFt3":500,"perFt3Minor":48},{"upToFt3":900,"perFt3Minor":38},{"upToFt3":1400,"perFt3Minor":32},{"upToFt3":null,"perFt3Minor":28}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":2600,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb)
) as v(category, effective_from, provisional, rules);
insert into retention_policies (entity_type, retain_days, basis, action) values
  ('invoices',            2555, 'UK company and HMRC record-keeping (6 years + current year)', 'anonymise'),
  ('payments',            2555, 'UK company and HMRC record-keeping',                          'anonymise'),
  ('jobs_completed',      2555, 'Contract limitation period (England & Wales)',                'anonymise'),
  ('quotes_accepted',     2555, 'Contract limitation period',                                  'anonymise'),
  ('job_sheets',          2555, 'Claims evidence window',                                      'anonymise'),
  ('leads_unconverted',    730, 'No lawful basis to retain beyond active interest',            'delete'),
  ('quotes_unaccepted',    730, 'Follows the lead that produced it',                           'delete'),
  ('partial_submissions',   90, 'Recovery window only',                                        'delete'),
  ('marketing_consent',    730, 'Consent is not indefinite; 24 months of no engagement',       'delete'),
  ('message_log',          395, 'Behavioural analytics norm (13 months)',                      'delete'),
  ('customer_portal_tokens',  7, 'Single-use access tokens',                                   'delete'),
  ('staff_records',       2555, 'Employment record-keeping norm',                              'anonymise'),
  ('audit_log',           2555, 'Kept for the full financial period; never editable',          'anonymise');
insert into sequences (brand_id, key, name, description)
select null, v.key, v.name, v.description
from (values
  ('lead_acknowledgement', 'Enquiry acknowledgement', 'Sent immediately, at any hour. An enquiry that arrives at 2 a.m. is answered at 2 a.m. — this is the fix for overnight lead loss.'),
  ('quote_chase', '48-hour quote chase', 'The core of the brief: a quote viewed but not accepted within 48 hours is chased, then chased again, then handed to a human.'),
  ('quote_expiry_warning', 'Quote expiry warning', 'Warns before a fixed price lapses, rather than letting it lapse silently.'),
  ('abandoned_inventory', 'Abandoned inventory recovery', 'Recovers a half-finished inventory from the web form.'),
  ('booking_confirmation', 'Booking confirmation', 'Transactional. Goes out immediately regardless of hour or cap.'),
  ('pre_move_reminder', 'Pre-move reminder', 'Three days out, then the evening before.'),
  ('payment_retry', 'Payment retry', 'A failed or expired payment never silently cancels a booking — it chases, then raises a task.'),
  ('review_request', 'Review request', 'Sent the day after completion, while the move is fresh. Review lag is on the problem list; the fix is timing, not nagging.')
) as v(key, name, description);
insert into sequence_steps (sequence_id, step_order, delay_minutes, channel, template_key, stop_conditions, respect_quiet_hours, counts_toward_frequency_cap)
select s.id, v.step_order, v.delay_minutes, v.channel::message_channel, v.template_key, v.stop_conditions, v.respect_quiet_hours, v.counts_toward_cap
from (values
  ('lead_acknowledgement', 1, 0, 'email', 'lead_acknowledgement', array['unsubscribed','manual_stop']::text[], false, false),
  ('quote_chase', 1, 2880, 'email', 'quote_chase_1', array['unsubscribed','manual_stop','lead_lost','quote_accepted','customer_replied','quote_expired']::text[], true, true),
  ('quote_chase', 2, 5760, 'whatsapp', 'quote_chase_2', array['unsubscribed','manual_stop','lead_lost','quote_accepted','customer_replied','quote_expired']::text[], true, true),
  ('quote_chase', 3, 10080, 'task', 'quote_chase_call_task', array['unsubscribed','manual_stop','lead_lost','quote_accepted','quote_expired']::text[], false, false),
  ('quote_expiry_warning', 1, 0, 'email', 'quote_expiry_warning', array['unsubscribed','manual_stop','lead_lost','quote_accepted','quote_expired']::text[], true, true),
  ('abandoned_inventory', 1, 120, 'email', 'abandoned_inventory', array['unsubscribed','manual_stop','lead_lost','quote_accepted','customer_replied']::text[], true, true),
  ('booking_confirmation', 1, 0, 'email', 'booking_confirmation', array['manual_stop']::text[], false, false),
  ('pre_move_reminder', 1, 0, 'email', 'pre_move_reminder_3d', array['manual_stop','unsubscribed']::text[], true, false),
  ('pre_move_reminder', 2, 2880, 'whatsapp', 'pre_move_reminder_1d', array['manual_stop','unsubscribed']::text[], true, false),
  ('payment_retry', 1, 60, 'email', 'payment_retry_1', array['payment_received','manual_stop']::text[], true, false),
  ('payment_retry', 2, 1440, 'task', 'payment_retry_task', array['payment_received','manual_stop']::text[], false, false),
  ('review_request', 1, 1440, 'email', 'review_request_1', array['unsubscribed','manual_stop','lead_lost','customer_replied']::text[], true, true),
  ('review_request', 2, 7200, 'whatsapp', 'review_request_2', array['unsubscribed','manual_stop','lead_lost','customer_replied']::text[], true, true)
) as v(sequence_key, step_order, delay_minutes, channel, template_key, stop_conditions, respect_quiet_hours, counts_toward_cap)
join sequences s on s.key = v.sequence_key and s.brand_id is null;

end
$seed$;

-- Brand identity. These are UPDATEs, so they run on every install and stay
-- correct whether or not the seed block above was skipped.

comment on column brands.accent_hex is
  'Accent as a FILL. Not guaranteed to pass contrast as text — use accent_text_hex for that.';
comment on column brands.accent_contrast_hex is
  'What sits ON the accent fill. For EcoGreen this is navy, not white: white on the brand lime measures 2.38:1 and fails AA, navy on it is 7.14:1.';
comment on column brands.brand_identity_confirmed is
  'False means the values here are the group default standing in for a brand that has not been designed yet.';

update brands set
  accent_hex = '#7DB903',
  accent_dark_hex = '#7DB903',
  accent_text_hex = '#235F2A',
  accent_text_dark_hex = '#97DD09',
  accent_contrast_hex = '#161A36',
  email_from = 'info@ecogreenmovers.co.uk',
  email_reply_to = 'info@ecogreenmovers.co.uk',
  logo_path = 'https://ecogreenmovers.co.uk/wp-content/uploads/2023/11/EcoGreen-Movers-commercial-Movers-Office-Movers-Horizontal-with-tag-line.webp',
  brand_identity_confirmed = true
where slug = 'ecogreen-movers';

update brands set
  accent_hex = '#E4581B',
  accent_dark_hex = '#E4581B',
  accent_text_hex = '#B8420E',
  accent_text_dark_hex = '#E4581B',
  accent_contrast_hex = '#1D1A16',
  brand_identity_confirmed = true
where slug = 'glasgow-moving';

-- Awaiting a real identity: the group palette, explicitly marked as such.
update brands set
  accent_hex = '#7DB903',
  accent_dark_hex = '#7DB903',
  accent_text_hex = '#235F2A',
  accent_text_dark_hex = '#97DD09',
  accent_contrast_hex = '#161A36',
  brand_identity_confirmed = false
where slug in ('eco-london-movers', 'continuum-green', 'removals-company-manchester', 'edinburgh-moving');
