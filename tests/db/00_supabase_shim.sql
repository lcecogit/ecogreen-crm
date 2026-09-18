-- Minimal local stand-in for the parts of a Supabase project the migrations
-- depend on: the three PostgREST roles, the auth schema, and auth.uid().
--
-- This exists so `npm run db:verify` can apply every migration to a throwaway
-- Postgres and prove the schema, the constraints and the RLS policies actually
-- work, without touching a hosted project. It is never applied to Supabase,
-- which provides all of this itself.

-- Roles are cluster-wide, so a re-run must not fail on an existing role.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to service_role;

create schema if not exists auth;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  created_at timestamptz not null default now()
);

-- Supabase derives this from the request JWT. Locally we set it per-session
-- with `set local request.jwt.claim.sub`, which is what the RLS tests do.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant select on auth.users to authenticated, service_role;
