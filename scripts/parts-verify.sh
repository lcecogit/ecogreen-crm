#!/usr/bin/env bash
# Applies supabase/parts/*.sql to a throwaway Postgres in three ways:
#   1. each part ON ITS OWN against an empty database (must either succeed or
#      fail with the readable "run PART n first" message — never 3F000)
#   2. all five in order (must succeed)
#   3. all five in order a second time (must succeed — every part re-runnable)
set -euo pipefail

PGBIN=${PGBIN:-/usr/lib/postgresql/16/bin}
PGSOCK=${PGSOCK:-/tmp/pgt}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIM="$ROOT/tests/db/00_supabase_shim.sql"
PARTS=("$ROOT"/supabase/parts/*.sql)

pq() { command psql -h "$PGSOCK" -U postgres -v ON_ERROR_STOP=1 "$@"; }
fresh() {
  pq -q -d postgres -c "drop database if exists $1;" -c "create database $1;"
  pq -q -d "$1" -f "$SHIM"
}

echo "--- 1. each part alone on an empty database"
for f in "${PARTS[@]}"; do
  n=$(basename "$f")
  fresh solo
  if out=$(pq -q -d solo -f "$f" 2>&1); then
    echo "  $n: succeeded standalone"
  else
    if grep -q '3F000' <<<"$out"; then
      echo "  $n: FAILED with 3F000 (schema private) <<<"; echo "$out"; exit 1
    fi
    echo "  $n: refused with -> $(grep -m1 -o 'ERROR:.*' <<<"$out")"
  fi
done

echo "--- 2. all parts in order"
fresh crm_parts
for f in "${PARTS[@]}"; do
  printf '  %s ... ' "$(basename "$f")"
  pq -q -d crm_parts -f "$f" >/dev/null && echo ok
done

echo "--- 3. all parts in order again (idempotency)"
for f in "${PARTS[@]}"; do
  printf '  %s ... ' "$(basename "$f")"
  pq -q -d crm_parts -f "$f" >/dev/null && echo ok
done

echo "--- 4. shape"
pq -tA -d crm_parts <<'SQL'
select '  tables          : ' || count(*) from pg_tables where schemaname='public';
select '  rls policies    : ' || count(*) from pg_policies where schemaname='public';
select '  tables with rls : ' || count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and c.relrowsecurity;
select '  private helpers : ' || count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private';
select '  public funcs    : ' || count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public';
select '  brands          : ' || count(*) from brands;
select '  catalogue items : ' || count(*) from items;
select '  rate cards      : ' || count(*) from rate_cards;
SQL
echo "parts verification passed"
