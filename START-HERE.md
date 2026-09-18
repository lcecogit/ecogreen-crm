# EcoGreen Group CRM — start here

Verified before packaging, on Node 20:

    npm run typecheck    clean
    npm test             81 passing, 0 failing
    npm run build        succeeds, 12 routes
    npm run db:verify:parts   all SQL parts pass on PostgreSQL 16

## Run it locally (3 minutes, costs nothing)

    npm install
    cp .env.example .env.local
    npm run dev          # http://localhost:3000

It opens in SAMPLE MODE — a banner says so. There is no Supabase project yet,
so every screen renders with realistic sample data. Nothing is billed, nothing
is hosted, and you can judge the design before paying for anything.

## What is actually built

Working:
  /                  public quote funnel + enquiry form
  /login             staff sign-in
  /dashboard         charts and numbers
  /leads             list, with filters
  /leads/[id]        lead detail and timeline
  /calendar          jobs by day
  /inbox             message queue
  /styleguide        every component, light and dark
  api/intake/lead    the intake endpoint the six brand sites post to
  api/cron/tick      the sequence scheduler

  src/domain/        all business logic, 81 unit tests, no I/O
  supabase/          42 tables, 68 RLS policies, verified

Not built yet: roughly 38 of the 44 modules in the left-hand navigation.
They appear in the sidebar with the word "soon" beside them — employees,
timesheets, payroll, fleet, invoices, rate cards and the rest. The sidebar is
the full map from RECOMMENDATIONS.md; most of the screens behind it do not
exist. Better you read that here than find it by clicking.

## Connect a database when you are ready

See SETUP.md. Short version: create a Supabase project, paste
supabase/install.sql into its SQL Editor, put the project URL and keys in
.env.local, then link your first staff account with the SQL at the end of
SETUP.md. Until a staff row exists, row level security denies everything —
that is deliberate, not a fault.

## The documents the code refers to

  SPEC.md              what this is and what it must do
  DESIGN.md            the design system; DESIGN.md §9 is the audit gate
  DECISIONS.md         defaults chosen, and what still needs your sign-off
  RECOMMENDATIONS.md   module map, pricing matrix, 54 improvements
  ROADMAP.md           phases 2-6
