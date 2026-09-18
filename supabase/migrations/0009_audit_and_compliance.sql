-- Audit and GDPR.

create table audit_log (
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

create index audit_log_entity_idx on audit_log (entity_type, entity_id, occurred_at desc);
create index audit_log_actor_idx on audit_log (actor_staff_id, occurred_at desc);

-- Append-only, for everyone including admins. An audit log that a compromised
-- admin session can edit is not an audit log.
create or replace function private.reject_audit_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_log is append-only' using errcode = 'restrict_violation';
end;
$$;

create trigger audit_log_no_update before update on audit_log for each row execute function private.reject_audit_mutation();
create trigger audit_log_no_delete before delete on audit_log for each row execute function private.reject_audit_mutation();

create table data_requests (
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

create table retention_policies (
  entity_type text primary key,
  retain_days int not null,
  basis text not null,
  action retention_action not null,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Role and brand-access changes are admin-only and audited. A session that can
-- promote itself is a session that can read every brand's margins.
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

create trigger staff_brand_access_guard
  before insert or update or delete on staff_brand_access
  for each row execute function private.guard_brand_access_change();
