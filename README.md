# EcoGreen group CRM

One CRM, portal and quoting engine across six removals brands. Built to
`../SPEC.md` (what it does), `../DESIGN.md` (how it looks and the craft gate it
has to pass), `../DECISIONS.md` (the recommended defaults and which of them
still need business sign-off) and `../ROADMAP.md` (everything deliberately not
in Phase 1).

## Running it

```bash
npm install
cp .env.example .env.local     # Supabase values required; every provider is optional
npm run dev
```

**Nothing blocks on a paid provider.** With `STRIPE_SECRET_KEY`,
`EMAIL_PROVIDER_API_KEY` and `WHATSAPP_ACCESS_TOKEN` all empty, the whole flow
runs: payment links are local and marked paid by hand, email renders to
`.tmp/mail/`, and WhatsApp and SMS steps are drafted into a staff send queue.
That queue is the intended workflow for the weeks Meta verification takes, not
a degraded mode. Set a key, get the real provider — no code changes.

## Checks

| Command | What it proves |
|---|---|
| `npm run typecheck` | TypeScript strict, no `any` in `src/domain` |
| `npm run lint` | ESLint |
| `npm test` | 81 unit tests over the pure domain layer |
| `npm run build` | Production build |
| `npm run db:verify` | Applies all 19 migrations to a throwaway Postgres and runs 88 SQL assertions |
| `npm run audit` | The DESIGN.md §9 craft gate: axe in both themes, 320/640px layout floors, keyboard focus rings, touch targets. Needs the app running. |
| `npm run check` | typecheck + tests |

`db:verify` needs a local Postgres 16 with `btree_gist` and `pg_trgm`
available. It creates and drops its own database and never touches a hosted
project. `tests/db/00_supabase_shim.sql` stands in for the auth schema and the
three PostgREST roles that Supabase provides.

## Looking at it

`/styleguide` renders every primitive and every one of the five required states
with static data and no database. It is the surface `npm run audit` runs
against, and the reason the empty, filtered-empty, loading, error and partial
states actually exist — in a real app they are hard to reach, so they are the
ones that never get built.

## Layout

```
src/domain/      pure business logic — no I/O, no ambient clock, no env
src/adapters/    provider interfaces + working stubs
src/app/api/     intake (HMAC-signed), cron tick, webhooks
src/app/(staff)/ admin, sales and ops screens
src/styles/      design tokens — the only place a colour or size is defined
supabase/        migrations; the catalogue, rate-card and sequence seeds are
                 GENERATED from src/domain by `npm run seed:generate`
```

Two rules worth knowing before changing anything:

1. **`src/domain` stays pure.** No `fetch`, no Supabase client, no
   `process.env`, no `Date.now()` — time is injected. That is what makes the
   pricing engine reproducible when a customer disputes a quote months later.
2. **The database enforces the guarantees, not the application.** Double
   booking, quote immutability, audit-log append-only, outbox idempotency and
   the webhook replay guard are all constraints. A check in a route handler
   gets bypassed by a second tab, a concurrent request or an import.

One consequence of RLS worth carrying: a denial on UPDATE or DELETE is a
**silent no-op, not an error**. Only INSERT raises. Application code must check
affected-row counts rather than relying on a thrown error.

## Deploying

Vercel, with **Root Directory set to `crm`**. `vercel.json` registers the
5-minute cron that drives the chase sequences; it needs `CRON_SECRET` set or
the route returns 401.

## Not built yet

See the "Deferred" entries in `../PROGRESS.md`. The significant ones: the quote
builder UI and PDF rendering, the Stripe webhook route, the dispatch calendar,
and the embeddable widget. No Supabase project has been created.
