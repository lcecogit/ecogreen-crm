-- Tenancy and people.
--
-- brand_id is on every tenant-scoped table from here on. It is the spine of
-- both RLS and the cross-brand overlap detection, so it is never nullable and
-- never derived at query time.

create table brands (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  code text not null unique,            -- short prefix for human references, e.g. EGM
  name text not null,
  legal_name text,
  primary_domain text not null,
  accent_hex text not null,
  accent_dark_hex text not null,
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

create table branches (
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

create table staff (
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
  max_open_leads int not null default 0,   -- 0 = no cap
  last_assigned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table staff_brand_access (
  staff_id uuid not null references staff(id) on delete cascade,
  brand_id uuid not null references brands(id) on delete cascade,
  role brand_role not null,
  created_at timestamptz not null default now(),
  primary key (staff_id, brand_id)
);

create table organisations (
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

create table customers (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  organisation_id uuid references organisations(id) on delete set null,
  first_name text,
  last_name text,
  email text,
  phone text,
  -- Normalised forms, maintained by the application on write. Indexed for the
  -- duplicate matcher: matching on raw text misses "07700 900123" vs
  -- "+447700900123", which is the single most common duplicate in practice.
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

create index customers_brand_idx on customers (brand_id);
create index customers_email_idx on customers (email_normalised) where email_normalised is not null;
create index customers_phone_idx on customers (phone_normalised) where phone_normalised is not null;
create index customers_name_trgm_idx on customers using gin ((coalesce(first_name,'') || ' ' || coalesce(last_name,'')) gin_trgm_ops);

-- Customer portal access is a short-lived hashed token, not a password. The
-- raw token only ever exists in the email that carried it.
create table customer_portal_tokens (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  token_hash text not null unique,
  scope text not null default 'portal',
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index customer_portal_tokens_customer_idx on customer_portal_tokens (customer_id);

create trigger brands_touch before update on brands for each row execute function private.touch_updated_at();
create trigger branches_touch before update on branches for each row execute function private.touch_updated_at();
create trigger staff_touch before update on staff for each row execute function private.touch_updated_at();
create trigger organisations_touch before update on organisations for each row execute function private.touch_updated_at();
create trigger customers_touch before update on customers for each row execute function private.touch_updated_at();
