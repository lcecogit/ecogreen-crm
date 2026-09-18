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
