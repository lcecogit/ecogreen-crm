-- Templates, sequences and the single outbox everything sends through.

create table message_templates (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references brands(id) on delete cascade,  -- null = platform default
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

create unique index message_templates_resolution_idx
  on message_templates (coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid), key, channel, locale, version);

create table sequences (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references brands(id) on delete cascade,
  key text not null,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index sequences_key_idx
  on sequences (coalesce(brand_id, '00000000-0000-0000-0000-000000000000'::uuid), key);

create table sequence_steps (
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
  -- A step with no stop conditions would send forever.
  -- cardinality(), not array_length(): array_length('{}', 1) is NULL, and a
  -- CHECK that evaluates to NULL passes. That mistake let an empty array
  -- through until the constraint test caught it.
  constraint sequence_steps_have_stops check (cardinality(stop_conditions) >= 1)
);

create table sequence_enrolments (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  sequence_id uuid not null references sequences(id) on delete cascade,
  subject_type text not null,          -- 'lead' | 'quote' | 'job' | 'invoice'
  subject_id uuid not null,
  customer_id uuid references customers(id) on delete cascade,
  status enrolment_status not null default 'active',
  next_step_order int not null default 1,
  next_run_at timestamptz not null default now(),
  stopped_reason text,
  stopped_at timestamptz,
  enrolled_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- One live enrolment per subject per sequence: re-enrolling a lead that is
  -- already being chased is how a customer gets the same email twice.
  unique (sequence_id, subject_type, subject_id)
);

create index sequence_enrolments_due_idx on sequence_enrolments (next_run_at) where status = 'active';

create table outbox (
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

create index outbox_due_idx on outbox (send_after) where status = 'queued';
create index outbox_manual_queue_idx on outbox (brand_id, created_at) where status = 'needs_manual_send';

-- Append-only record of everything that actually went out or came in.
create table message_log (
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

-- The fair-use cap counts from here, across every brand and channel.
create index message_log_cap_idx on message_log (customer_id, sent_at desc) where counted_toward_cap;

-- Unsubscribes are global by contact, not per brand. A customer who opts out
-- of EcoGreen must not start receiving Edinburgh Moving mail — they experience
-- one sender, not six.
create table unsubscribes (
  id uuid primary key default gen_random_uuid(),
  channel message_channel not null,
  address_normalised text not null,
  reason text,
  created_at timestamptz not null default now(),
  unique (channel, address_normalised)
);

create trigger message_templates_touch before update on message_templates for each row execute function private.touch_updated_at();
create trigger sequences_touch before update on sequences for each row execute function private.touch_updated_at();
create trigger sequence_enrolments_touch before update on sequence_enrolments for each row execute function private.touch_updated_at();
create trigger outbox_touch before update on outbox for each row execute function private.touch_updated_at();
