-- Booked work, crews, vehicles and attendance.

create table vehicles (
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

create table jobs (
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
  -- Copied from the quote at booking, verbatim. These two columns are the fix
  -- for "lost access notes" and "unrecorded special requests": whatever the
  -- salesperson typed reaches the crew unedited, above the fold on the sheet.
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
  constraint jobs_schedule_ordered check (scheduled_end is null or scheduled_start is null or scheduled_end > scheduled_start)
);

create index jobs_calendar_idx on jobs (brand_id, scheduled_start) where status <> 'cancelled';
create index jobs_customer_idx on jobs (customer_id);

-- ── Double-booking prevention ─────────────────────────────────────────────
-- A database constraint, not UI validation. Peak-weekend double-booking is on
-- the problem list, and a check in the form is bypassed by a second tab, a
-- concurrent request, or an import.
create table job_assignments (
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

alter table job_assignments
  add constraint job_assignments_no_staff_overlap
  exclude using gist (
    staff_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (staff_id is not null and cancelled_at is null);

alter table job_assignments
  add constraint job_assignments_no_vehicle_overlap
  exclude using gist (
    vehicle_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (vehicle_id is not null and cancelled_at is null);

create index job_assignments_job_idx on job_assignments (job_id) where cancelled_at is null;
create index job_assignments_staff_idx on job_assignments (staff_id, starts_at) where cancelled_at is null;

create table job_sheets (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  generated_at timestamptz not null default now(),
  generated_by_staff_id uuid references staff(id) on delete set null,
  pdf_path text,
  snapshot jsonb not null
);

create index job_sheets_job_idx on job_sheets (job_id, generated_at desc);

create table attendance (
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
create unique index attendance_one_open_shift_idx on attendance (staff_id) where clock_out_at is null;
create index attendance_period_idx on attendance (staff_id, clock_in_at desc);

create table sales_targets (
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

create unique index sales_targets_unique_idx
  on sales_targets (brand_id, coalesce(staff_id, '00000000-0000-0000-0000-000000000000'::uuid), period, period_start, size);

create trigger vehicles_touch before update on vehicles for each row execute function private.touch_updated_at();
create trigger jobs_touch before update on jobs for each row execute function private.touch_updated_at();
create trigger attendance_touch before update on attendance for each row execute function private.touch_updated_at();
create trigger sales_targets_touch before update on sales_targets for each row execute function private.touch_updated_at();
