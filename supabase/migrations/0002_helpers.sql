-- Helper functions live in a `private` schema, never in `public`.
--
-- This is not stylistic. The marketplace app in this repo hit RLS infinite
-- recursion when its helpers lived in `public` (see its migrations 0014-0015):
-- a policy on a table called a function that itself selected from a table whose
-- policy called the same function. Keeping helpers in a schema that is not
-- exposed through PostgREST, and marking them `security definer` with a pinned
-- search_path, breaks that cycle and closes the search-path hijack vector.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

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

-- The access helpers that read tables live in 0010_rls_helpers.sql, after the
-- tables they query exist: a `security definer` SQL function is validated at
-- creation, so it cannot be declared before its dependencies.
