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
