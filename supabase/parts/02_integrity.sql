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
