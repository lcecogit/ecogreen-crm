#!/usr/bin/env bash
# Applies every migration to a throwaway Postgres and runs the RLS and
# constraint tests against it. Requires a local postgres; CI runs the same
# thing against a service container.
set -euo pipefail

PGBIN=${PGBIN:-/usr/lib/postgresql/16/bin}
PGSOCK=${PGSOCK:-/tmp/pgt}
PGPORT=${PGPORT:-55432}
DB=${DB:-crm_verify}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

psql() { command psql -h "$PGSOCK" -p "$PGPORT" -U postgres -v ON_ERROR_STOP=1 "$@"; }

psql -d postgres -c "drop database if exists ${DB};" >/dev/null
psql -d postgres -c "create database ${DB};" >/dev/null

psql -q -d "$DB" -f "$ROOT/tests/db/00_supabase_shim.sql"

for file in "$ROOT"/supabase/migrations/*.sql; do
  printf '  applying %s\n' "$(basename "$file")"
  psql -q -d "$DB" -f "$file"
done

for file in "$ROOT"/tests/db/[1-9]*.sql; do
  [ -e "$file" ] || continue
  printf '  testing  %s\n' "$(basename "$file")"
  psql -q -d "$DB" -f "$file"
done

echo "database verification passed"
