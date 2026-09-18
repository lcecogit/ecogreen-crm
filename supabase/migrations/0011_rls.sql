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
create policy brands_read on brands for select to authenticated
  using (private.has_brand_access(id, 'readonly'));
create policy brands_write on brands for all to authenticated
  using (private.has_brand_access(id, 'admin')) with check (private.has_brand_access(id, 'admin'));

alter table branches enable row level security;
create policy branches_read on branches for select to authenticated
  using (private.has_brand_access(brand_id, 'readonly'));
create policy branches_write on branches for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table staff enable row level security;
-- Staff can always see themselves; otherwise a manager in a shared brand.
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
create policy staff_self_update on staff for update to authenticated
  using (auth_user_id = auth.uid()) with check (auth_user_id = auth.uid());
create policy staff_admin_write on staff for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

alter table staff_brand_access enable row level security;
create policy sba_read on staff_brand_access for select to authenticated
  using (private.has_brand_access(brand_id, 'manager') or staff_id = private.current_staff_id());
-- Writes are additionally gated by the trigger in 0009; the policy alone is
-- not relied upon for privilege escalation.
create policy sba_write on staff_brand_access for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

alter table organisations enable row level security;
create policy organisations_read on organisations for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy organisations_write on organisations for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table customers enable row level security;
-- Note: 'sales' and above. Crew are excluded entirely — what they need about a
-- customer reaches them on the job sheet, which is generated server-side.
create policy customers_read on customers for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy customers_write on customers for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table customer_portal_tokens enable row level security;
-- Server-side only. No policy: nothing with a user session may read token
-- hashes, including an admin.

-- ── Pipeline ──────────────────────────────────────────────────────────────
alter table services enable row level security;
create policy services_read on services for select to authenticated
  using (private.has_brand_access(brand_id, 'readonly'));
create policy services_write on services for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table lead_sources enable row level security;
create policy lead_sources_read on lead_sources for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy lead_sources_write on lead_sources for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table lead_providers enable row level security;
create policy lead_providers_read on lead_providers for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy lead_providers_write on lead_providers for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table lost_reasons enable row level security;
create policy lost_reasons_read on lost_reasons for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy lost_reasons_write on lost_reasons for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table reference_sequences enable row level security;
-- Server-side only: references are allocated by next_reference(), which is
-- security definer. No session may edit the counter.

alter table leads enable row level security;
create policy leads_read on leads for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy leads_write on leads for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table lead_events enable row level security;
create policy lead_events_read on lead_events for select to authenticated
  using (exists (select 1 from leads l where l.id = lead_events.lead_id and private.has_brand_access(l.brand_id, 'sales')));
-- Append-only from a session: no update or delete policy exists, so the
-- timeline cannot be rewritten after the fact.
create policy lead_events_insert on lead_events for insert to authenticated
  with check (exists (select 1 from leads l where l.id = lead_events.lead_id and private.has_brand_access(l.brand_id, 'sales')));

alter table partial_submissions enable row level security;
create policy partial_submissions_read on partial_submissions for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));

-- ── Catalogue, quoting ────────────────────────────────────────────────────
alter table rooms enable row level security;
create policy rooms_read on rooms for select to authenticated using (true);

alter table items enable row level security;
create policy items_read on items for select to authenticated using (true);

alter table rate_cards enable row level security;
-- Rate cards are commercially sensitive: managers and accounts, never crew,
-- and never a sales user in another brand.
create policy rate_cards_read on rate_cards for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy rate_cards_write on rate_cards for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table promo_codes enable row level security;
create policy promo_codes_read on promo_codes for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy promo_codes_write on promo_codes for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

alter table quotes enable row level security;
create policy quotes_read on quotes for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy quotes_write on quotes for all to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table quote_items enable row level security;
create policy quote_items_all on quote_items for all to authenticated
  using (exists (select 1 from quotes q where q.id = quote_items.quote_id and private.has_brand_access(q.brand_id, 'sales')))
  with check (exists (select 1 from quotes q where q.id = quote_items.quote_id and private.has_brand_access(q.brand_id, 'sales')));

alter table quote_lines enable row level security;
create policy quote_lines_all on quote_lines for all to authenticated
  using (exists (select 1 from quotes q where q.id = quote_lines.quote_id and private.has_brand_access(q.brand_id, 'sales')))
  with check (exists (select 1 from quotes q where q.id = quote_lines.quote_id and private.has_brand_access(q.brand_id, 'sales')));

-- ── Operations ────────────────────────────────────────────────────────────
alter table vehicles enable row level security;
create policy vehicles_read on vehicles for select to authenticated
  using (private.has_brand_access(brand_id, 'crew'));
create policy vehicles_write on vehicles for all to authenticated
  using (private.has_brand_access(brand_id, 'ops')) with check (private.has_brand_access(brand_id, 'ops'));

alter table jobs enable row level security;
-- Ops and above see the brand's jobs; crew see only jobs they are on.
create policy jobs_read on jobs for select to authenticated
  using (private.has_brand_access(brand_id, 'ops') or private.is_assigned_to_job(id));
create policy jobs_write on jobs for all to authenticated
  using (private.has_brand_access(brand_id, 'ops')) with check (private.has_brand_access(brand_id, 'ops'));

alter table job_assignments enable row level security;
create policy job_assignments_read on job_assignments for select to authenticated
  using (
    staff_id = private.current_staff_id()
    or exists (select 1 from jobs j where j.id = job_assignments.job_id and private.has_brand_access(j.brand_id, 'ops'))
  );
create policy job_assignments_write on job_assignments for all to authenticated
  using (exists (select 1 from jobs j where j.id = job_assignments.job_id and private.has_brand_access(j.brand_id, 'ops')))
  with check (exists (select 1 from jobs j where j.id = job_assignments.job_id and private.has_brand_access(j.brand_id, 'ops')));

alter table job_sheets enable row level security;
create policy job_sheets_read on job_sheets for select to authenticated
  using (
    private.is_assigned_to_job(job_id)
    or exists (select 1 from jobs j where j.id = job_sheets.job_id and private.has_brand_access(j.brand_id, 'ops'))
  );

alter table attendance enable row level security;
create policy attendance_self on attendance for all to authenticated
  using (staff_id = private.current_staff_id()) with check (staff_id = private.current_staff_id());
create policy attendance_manager_read on attendance for select to authenticated
  using (brand_id is not null and private.has_brand_access(brand_id, 'manager'));

alter table sales_targets enable row level security;
create policy sales_targets_read on sales_targets for select to authenticated
  using (staff_id = private.current_staff_id() or private.has_brand_access(brand_id, 'manager'));
create policy sales_targets_write on sales_targets for all to authenticated
  using (private.has_brand_access(brand_id, 'manager')) with check (private.has_brand_access(brand_id, 'manager'));

-- ── Money ─────────────────────────────────────────────────────────────────
alter table invoices enable row level security;
create policy invoices_read on invoices for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy invoices_write on invoices for all to authenticated
  using (private.has_brand_access(brand_id, 'accounts')) with check (private.has_brand_access(brand_id, 'accounts'));

alter table payments enable row level security;
create policy payments_read on payments for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy payments_write on payments for all to authenticated
  using (private.has_brand_access(brand_id, 'accounts')) with check (private.has_brand_access(brand_id, 'accounts'));

alter table payment_links enable row level security;
create policy payment_links_read on payment_links for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));

alter table webhook_events enable row level security;
-- Service role only. Raw provider payloads are not for any user session.

-- ── Messaging ─────────────────────────────────────────────────────────────
alter table message_templates enable row level security;
create policy message_templates_read on message_templates for select to authenticated
  using (brand_id is null or private.has_brand_access(brand_id, 'sales'));
create policy message_templates_write on message_templates for all to authenticated
  using (brand_id is not null and private.has_brand_access(brand_id, 'manager'))
  with check (brand_id is not null and private.has_brand_access(brand_id, 'manager'));

alter table sequences enable row level security;
create policy sequences_read on sequences for select to authenticated
  using (brand_id is null or private.has_brand_access(brand_id, 'sales'));
create policy sequences_write on sequences for all to authenticated
  using (brand_id is not null and private.has_brand_access(brand_id, 'manager'))
  with check (brand_id is not null and private.has_brand_access(brand_id, 'manager'));

alter table sequence_steps enable row level security;
create policy sequence_steps_read on sequence_steps for select to authenticated
  using (exists (select 1 from sequences s where s.id = sequence_steps.sequence_id
                   and (s.brand_id is null or private.has_brand_access(s.brand_id, 'sales'))));

alter table sequence_enrolments enable row level security;
create policy sequence_enrolments_read on sequence_enrolments for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
create policy sequence_enrolments_write on sequence_enrolments for update to authenticated
  using (private.has_brand_access(brand_id, 'sales')) with check (private.has_brand_access(brand_id, 'sales'));

alter table outbox enable row level security;
create policy outbox_read on outbox for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));
-- Staff may only act on the manual-send queue; the dispatcher itself runs
-- under the service role.
create policy outbox_manual_update on outbox for update to authenticated
  using (private.has_brand_access(brand_id, 'sales') and status = 'needs_manual_send')
  with check (private.has_brand_access(brand_id, 'sales'));

alter table message_log enable row level security;
create policy message_log_read on message_log for select to authenticated
  using (private.has_brand_access(brand_id, 'sales'));

alter table unsubscribes enable row level security;
create policy unsubscribes_read on unsubscribes for select to authenticated using (true);

-- ── Audit and compliance ──────────────────────────────────────────────────
alter table audit_log enable row level security;
create policy audit_log_insert on audit_log for insert to authenticated with check (true);
create policy audit_log_read on audit_log for select to authenticated
  using (private.is_platform_admin());
-- No update or delete policy, and the triggers in 0009 reject both regardless.

alter table data_requests enable row level security;
create policy data_requests_admin on data_requests for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

alter table retention_policies enable row level security;
create policy retention_policies_read on retention_policies for select to authenticated using (true);
create policy retention_policies_write on retention_policies for all to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());

-- Nothing in this schema is readable without a session.
revoke all on all tables in schema public from anon;
