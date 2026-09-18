-- Invoicing and payments. Every amount is integer minor units plus a currency;
-- non-GBP rows snapshot the rate so consolidated reporting never re-fetches.

create table invoices (
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

create index invoices_outstanding_idx on invoices (brand_id, due_on) where status in ('issued','part_paid','overdue');

create table payments (
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
  -- Phase 1 reconciles bank transfers by hand. Recording who did it, and when,
  -- is what makes that acceptable rather than a hole.
  reconciled_at timestamptz,
  reconciled_by_staff_id uuid references staff(id) on delete set null,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A provider reference can only appear once. This is what makes the Stripe
-- webhook idempotent under replay, which it will be: providers retry.
create unique index payments_provider_reference_idx on payments (provider_reference) where provider_reference is not null;
create index payments_invoice_idx on payments (invoice_id);

create table payment_links (
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

create index payment_links_quote_idx on payment_links (quote_id);

-- Raw provider events, stored before processing. A webhook whose handler threw
-- is replayable from here rather than lost.
create table webhook_events (
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

create trigger invoices_touch before update on invoices for each row execute function private.touch_updated_at();
create trigger payments_touch before update on payments for each row execute function private.touch_updated_at();
