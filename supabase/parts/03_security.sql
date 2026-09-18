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
