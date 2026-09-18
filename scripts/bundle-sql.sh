#!/usr/bin/env bash
# Concatenates supabase/parts/*.sql into supabase/install.sql — the one file to
# paste into the Supabase SQL Editor when the whole script fits in one go.
# The parts stay the source of truth; this is generated. Run: npm run sql:bundle
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/supabase/install.sql"

{
  cat <<'HEADER'
-- ==========================================================================
--  EcoGreen Group CRM — COMPLETE INSTALL
--
--  Generated from supabase/parts/*.sql by scripts/bundle-sql.sh. Do not edit
--  by hand; edit the parts and re-run the script.
--
--  Paste the whole file into the Supabase SQL Editor and run it. It is safe to
--  re-run. If your editor truncates a paste this long, run the five files in
--  supabase/parts/ one at a time instead, in numerical order.
-- ==========================================================================
HEADER
  for f in "$ROOT"/supabase/parts/*.sql; do
    printf '\n\n-- ##########################################################################\n-- # %s\n-- ##########################################################################\n\n' "$(basename "$f")"
    cat "$f"
  done
} > "$OUT"

printf 'Wrote %s (%s lines, %s bytes)\n' "$OUT" "$(wc -l < "$OUT")" "$(wc -c < "$OUT")"
