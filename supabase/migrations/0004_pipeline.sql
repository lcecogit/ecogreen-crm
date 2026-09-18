-- The lead pipeline.

create table services (
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

create table lead_sources (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  kind lead_source_kind not null,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, name)
);

create table lead_providers (
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

create table lost_reasons (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  label text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  unique (brand_id, label)
);

-- Human-readable references: {CODE}-{YYMM}-{SEQ}, e.g. EGM-2609-0412.
-- Staff read these over the phone, so a UUID is not an option.
create table reference_sequences (
  brand_id uuid not null references brands(id) on delete cascade,
  entity text not null,              -- 'lead' | 'quote' | 'job' | 'invoice'
  period text not null,              -- 'YYMM'
  last_value int not null default 0,
  primary key (brand_id, entity, period)
);

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

create table leads (
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
  -- Attribution: both models stored, both reported. Picking one and hiding the
  -- other is how marketing spend gets misattributed.
  first_touch jsonb not null default '{}'::jsonb,
  last_touch jsonb not null default '{}'::jsonb,
  -- The raw submission, persisted before validation so a malformed post from a
  -- brand site is recoverable rather than lost.
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

create index leads_brand_status_idx on leads (brand_id, status);
create index leads_owner_idx on leads (owner_staff_id) where status in ('new','qualifying','quoted','chasing');
create index leads_unassigned_idx on leads (created_at) where owner_staff_id is null;
create index leads_move_date_idx on leads (move_date);

-- Append-only. Every status change, note, call, quote send and inbound message
-- lands here, which is what makes the pipeline auditable.
create table lead_events (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references leads(id) on delete cascade,
  type text not null,
  actor_staff_id uuid references staff(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index lead_events_lead_idx on lead_events (lead_id, occurred_at desc);

-- Half-finished web forms. Recovering these is the "abandoned forms" fix, and
-- they are deliberately separate from leads so an incomplete enquiry does not
-- pollute pipeline reporting.
create table partial_submissions (
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

create trigger services_touch before update on services for each row execute function private.touch_updated_at();
create trigger lead_sources_touch before update on lead_sources for each row execute function private.touch_updated_at();
create trigger lead_providers_touch before update on lead_providers for each row execute function private.touch_updated_at();
create trigger leads_touch before update on leads for each row execute function private.touch_updated_at();
create trigger partial_submissions_touch before update on partial_submissions for each row execute function private.touch_updated_at();
