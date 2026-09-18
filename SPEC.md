# SPEC.md — Unified CRM, Website & App Platform

**A build prompt for Claude Code.** Read this file, `DESIGN.md` and `ROADMAP.md`
in full before writing any code. Read `PROGRESS.md` at the start of every
session and append to it at the end of every session.

This document specifies **Phase 1 only**. Everything else lives in
`ROADMAP.md` and must not be built until Phase 1 is signed off.

---

## 0. How to use this document

- Every requirement is either **MUST**, **SHOULD**, or **MAY**. Only MUST items
  gate a milestone.
- Where this spec names a file path, use that path. Where it names a table or
  column, use that name. Consistency matters more than your preference.
- Where this spec is silent, choose the boring option and record the choice in
  `PROGRESS.md`.
- **Do not invent business numbers.** No invented prices, VAT rates, mileage
  rates, insurance limits, payroll rates or commission percentages. If a number
  is needed and not supplied, put it in a seed file marked
  `-- VALUE REQUIRED FROM BUSINESS` with an obviously-wrong placeholder and
  raise it in `PROGRESS.md`. A plausible-looking guessed price is worse than a
  blocked build.
- Work milestone by milestone (§15). Do not start milestone N+1 until N's
  acceptance criteria pass.

---

## 1. Decisions already taken

These were decided up front. Each can be overridden by the business owner, but
not silently by the implementing agent — if you disagree, say so in
`PROGRESS.md` and continue as specified.

| # | Decision | Rationale |
|---|---|---|
| 1 | The CRM is a **new Next.js app at `crm/`** in this repo, with its own `package.json`. The existing `movers-now` marketplace app at the repo root is **not modified**. | The marketplace is a two-sided product (third-party partners bid for work, get payouts, run auctions). The CRM is an in-house operations product (our crews, our sales team). Forcing both onto one `jobs`/`quotes` schema produces a data model that serves neither. 56 existing migrations are not worth destabilising. |
| 2 | The CRM gets its **own Supabase project**, not a schema inside the marketplace project. | Separate `auth.users` pool (staff and corporate clients must never share an identity pool with marketplace customers), separate migration history, separate backup and GDPR retention policy. |
| 3 | **Vercel** hosting, one Vercel project per app, `crm/` set as the Root Directory for the CRM project. | Instructed. Vercel Cron covers the scheduler (§9) with no extra infrastructure. |
| 4 | The six brand websites **stay where they are**. The platform exposes a signed lead-intake API and an embeddable quote widget. | Five of the six are live WordPress sites with real organic rankings. Rebuilding them is a separate migration project with real SEO downside and zero CRM benefit. |
| 5 | Phase 1 is **lead → quote → book → pay → chase → review**, plus a deliberately thin dispatch slice (§11). | This is where money leaks today. Dispatch is included only as far as stopping a booking from dead-ending. |
| 6 | Payroll **calculates nothing statutory**. It records hours and exports them. | PAYE/NI/overtime tiers are an HMRC liability, not a feature. The system feeds a payroll provider; it does not become one. |
| 7 | All external providers sit behind **adapter interfaces with working local stubs**. Nothing in the domain layer imports a vendor SDK directly. | Keys may not exist yet. The build must never block on procurement. |
| 8 | UI chrome is brand-themed; **data visualisation is not** (`DESIGN.md` §7). | Six accent colours applied to charts would make the same dashboard unreadable in five of six brands. |

**Open questions still owed by the business** — record answers in `PROGRESS.md`
as they arrive; until then, build against the stubs:

1. Real brand hex values, logo files and email sender domains for all six brands.
2. The actual rate card: base rates, per-mile rates, volume bands, crew-hour
   rates, surcharges, minimum charges, VAT treatment per service.
3. Whether Stripe, a transactional email provider and WhatsApp Business API
   credentials exist. WhatsApp in particular needs Meta Business verification
   and pre-approved message templates — weeks of lead time, not a code task.
4. Data retention periods per record class (§14).

---

## 2. Scope

### In scope for Phase 1 (MUST)

Multi-brand lead capture and routing · lead pipeline with owner and stage ·
duplicate and cross-brand overlap detection · visual room-and-item inventory
builder · volume, distance and crew pricing engine · branded PDF quote ·
Stripe payment link and bank transfer instructions · deposit capture and booking
confirmation · automated 48-hour chase sequences over email (WhatsApp/SMS
queued as drafts when no API) · quote expiry reminders · job calendar with
crew/vehicle assignment and double-booking prevention · printable job sheet
carrying access notes · post-completion review request · sales tracker against
targets by move size · lead-provider performance and marketing attribution ·
staff clock in/out per department · admin, sales, ops and customer portals ·
full audit log · GDPR export and erasure.

### Explicitly out of scope for Phase 1 (MUST NOT build)

Fleet telemetry and GPS tracking · tachograph and drivers' hours · payroll
calculation · bookkeeping ledger · storage capacity and warehouse management ·
customs, bonded warehouse and international shipping documents · council permit
applications · packing material stock control and auto-reordering · 3D room
visualiser and van capacity simulation · AI chatbot triage · sentiment analysis ·
credit checks, background checks, competitor price monitoring · call recording ·
biometric clock-in · white-label partner portals · franchise permission tiers ·
auction and subcontractor routing · offline mode.

Every one of these is in `ROADMAP.md` with a phase and, where relevant, a note
that it is a procurement or compliance task rather than a development task.

---

## 3. Architecture

```
devplaneco/
├── src/                    # existing movers-now marketplace — DO NOT TOUCH
├── crm/                    # THIS BUILD
│   ├── package.json
│   ├── next.config.mjs
│   ├── tailwind.config.ts
│   ├── supabase/migrations/
│   ├── src/
│   │   ├── app/
│   │   │   ├── (marketing)/          # portal landing + login only
│   │   │   ├── (staff)/              # admin · sales · ops
│   │   │   ├── (customer)/           # customer portal
│   │   │   ├── api/
│   │   │   │   ├── intake/           # public lead intake (signed)
│   │   │   │   ├── widget/           # embeddable quote widget assets
│   │   │   │   ├── cron/             # Vercel Cron targets
│   │   │   │   └── webhooks/         # stripe, email provider
│   │   │   └── embed/                # iframe-able quote widget
│   │   ├── components/
│   │   ├── domain/                   # pure business logic, no I/O
│   │   │   ├── pricing/
│   │   │   ├── inventory/
│   │   │   ├── pipeline/
│   │   │   └── sequences/
│   │   ├── adapters/                 # payments, email, sms, whatsapp, pdf, geo
│   │   ├── lib/
│   │   └── styles/
│   └── tests/
├── SPEC.md · DESIGN.md · ROADMAP.md · PROGRESS.md
```

**Rules**

- `domain/` MUST be pure: no `fetch`, no Supabase client, no `process.env`, no
  `Date.now()` (time is injected). Every function in it is unit-testable with no
  mocks. This is what makes the pricing engine auditable when a customer
  disputes a quote.
- `adapters/` MUST expose interfaces (`PaymentProvider`, `EmailProvider`,
  `MessagingProvider`, `PdfRenderer`, `GeoProvider`) with a `stub` implementation
  selected when the relevant env var is absent. Stub implementations write to a
  local outbox table and log, and MUST be usable end to end in development.
- Server-side data access goes through Supabase with the user's session (RLS
  enforced). The service-role key is used **only** in `api/cron/*`,
  `api/webhooks/*` and `api/intake/*`, never in a page or client component.

**Port these files from the marketplace app** — copy, don't import across apps;
note the divergence in `PROGRESS.md`:

- `src/lib/geo/postcodes.ts`, `src/lib/geo/distance.ts` → `crm/src/adapters/geo/`
- `src/lib/time/uk-datetime.ts` → `crm/src/lib/time/`
- The item catalogue seed in `supabase/migrations/0031_seed_item_catalogue.sql`
  → re-derive as the Phase 1 item catalogue seed, extended per §6.

### Environment

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_KEY=            # server only, never NEXT_PUBLIC_
NEXT_PUBLIC_APP_URL=
CRON_SECRET=                    # required; cron routes 401 without it
INTAKE_SIGNING_SECRET=          # HMAC for website lead posts
STRIPE_SECRET_KEY=              # absent → stub payment provider
STRIPE_WEBHOOK_SECRET=
EMAIL_PROVIDER_API_KEY=         # absent → stub email provider
WHATSAPP_ACCESS_TOKEN=          # absent → drafts queued for manual send
NEXT_PUBLIC_ALLOW_INDEXING=false
```

The CRM is a private application. `robots.txt` MUST disallow everything and
every route MUST carry `X-Robots-Tag: noindex, nofollow` regardless of the
indexing flag — the flag exists only for the public `/embed` widget host page.

---

## 4. Domain model

Postgres, `public` schema, `snake_case`, UUID v4 primary keys, `created_at` and
`updated_at` on every table (trigger-maintained), soft delete via `deleted_at`
only where §14 requires it.

**Money is never a float.** Every monetary column is `amount_minor bigint` plus
`currency char(3)`, with a snapshot `fx_rate_to_gbp numeric(12,6)` on any row
that can be non-GBP. Display formatting happens once, in one helper.

**Every tenant-scoped table carries `brand_id uuid not null`.** No exceptions —
this is the spine of both RLS and the cross-brand overlap detection in §5.

### Tenancy and people

| Table | Key columns |
|---|---|
| `brands` | `slug`, `name`, `legal_name`, `primary_domain`, `accent_hex`, `logo_path`, `email_from`, `email_reply_to`, `phone`, `vat_number`, `is_active` |
| `branches` | `brand_id`, `name`, `city`, `outward_codes text[]`, `timezone` |
| `staff` | `auth_user_id`, `full_name`, `email`, `phone`, `department` (`admin`/`sales`/`transport`/`movers`/`support`/`accounts`), `job_title`, `employment_status`, `started_on`, `ended_on` |
| `staff_brand_access` | `staff_id`, `brand_id`, `role` (`admin`/`manager`/`sales`/`ops`/`crew`/`accounts`/`readonly`) — composite PK |
| `organisations` | `brand_id`, `name`, `type` (`corporate`/`public_sector`/`education`/`healthcare`/`agent`), `billing_email`, `payment_terms_days` |
| `customers` | `brand_id`, `organisation_id` (nullable), `first_name`, `last_name`, `email`, `phone`, `preferred_language`, `marketing_consent`, `consent_source`, `consent_at` |
| `customer_portal_tokens` | `customer_id`, `token_hash`, `expires_at`, `used_at`, `scope` |

`staff` is separate from `auth.users` and from `customers`. A person is never
both a staff row and a customer row on the same identity.

### Pipeline

| Table | Key columns |
|---|---|
| `lead_sources` | `brand_id`, `kind` (`website`/`provider`/`phone`/`whatsapp`/`referral`/`repeat`/`ppc`/`organic`), `name`, `cost_model`, `is_active` |
| `lead_providers` | `brand_id`, `name`, `contact_email`, `cost_per_lead_minor`, `currency`, `active_from`, `active_to` |
| `leads` | `brand_id`, `reference` (human-readable, see below), `customer_id`, `source_id`, `provider_id`, `branch_id`, `service_id`, `customer_type` (`residential`/`commercial`/`office`/`specialist`/`clearance`/`storage`), `status`, `owner_staff_id`, `move_date`, `move_date_flexible`, `origin_postcode`, `destination_postcode`, `origin_access`, `destination_access`, `first_touch jsonb`, `last_touch jsonb`, `raw_payload jsonb`, `duplicate_of_lead_id`, `lost_reason_id`, `score` |
| `lead_events` | `lead_id`, `type`, `actor_staff_id`, `payload jsonb`, `occurred_at` — append-only |
| `lost_reasons` | `brand_id`, `label`, `sort_order` |
| `services` | `brand_id`, `slug`, `name`, `category`, `is_active` |

**Lead status** is a Postgres enum, and it is the pipeline from the brief:
`new` → `qualifying` → `quoted` → `chasing` → `booked` → `completed` →
`reviewed`, plus terminal `lost` and `duplicate`. Transitions MUST go through
`domain/pipeline/transition.ts`, which owns the legal-transition table and
writes a `lead_events` row for every move. No route updates `leads.status`
directly.

`reference` format: `{BRAND_CODE}-{YY}{MM}-{SEQ}` e.g. `EGM-2609-0412`. Generate
from a per-brand-per-month sequence. Staff read these over the phone; they must
be short and unambiguous. Never use a UUID as a human reference.

### Inventory and quoting

| Table | Key columns |
|---|---|
| `rooms` | `slug`, `name`, `icon`, `sort_order` — global, not brand-scoped |
| `items` | `slug`, `name`, `room_slug`, `icon`, `volume_ft3 numeric`, `is_fragile`, `requires_dismantle`, `crew_minutes`, `handling_class` (`standard`/`heavy`/`fine_art`/`piano`/`it_equipment`/`laboratory`/`medical`) |
| `quotes` | `brand_id`, `lead_id`, `reference`, `version`, `status` (`draft`/`sent`/`viewed`/`accepted`/`expired`/`superseded`/`declined`), `valid_until`, `prepared_by_staff_id`, `totals` (net/vat/gross minor + currency), `pricing_snapshot jsonb`, `sent_at`, `first_viewed_at`, `accepted_at` |
| `quote_items` | `quote_id`, `item_slug`, `room_slug`, `quantity`, `volume_ft3`, `notes` |
| `quote_lines` | `quote_id`, `kind` (`transport`/`labour`/`materials`/`surcharge`/`discount`/`storage`), `label`, `quantity`, `unit_amount_minor`, `net_minor`, `vat_rate`, `vat_minor`, `gross_minor` |
| `rate_cards` | `brand_id`, `service_id`, `effective_from`, `effective_to`, `rules jsonb` |
| `promo_codes` | `brand_id`, `code`, `kind`, `value`, `max_uses`, `used_count`, `valid_from`, `valid_to` |

**Quote immutability.** Once a quote is `sent` it is frozen: `quote_lines`,
`quote_items` and `pricing_snapshot` become read-only. A change creates
version N+1 and marks N `superseded`. The customer's accepted PDF must always be
reproducible byte-for-byte from `pricing_snapshot` — this is what settles a
"you quoted me less" dispute. Enforce with a trigger, not a convention.

### Booking and operations

| Table | Key columns |
|---|---|
| `jobs` | `brand_id`, `quote_id`, `customer_id`, `reference`, `status` (`booked`/`scheduled`/`in_progress`/`completed`/`cancelled`), `scheduled_start`, `scheduled_end`, `origin_address jsonb`, `destination_address jsonb`, `access_notes`, `special_instructions`, `crew_size`, `cancelled_reason` |
| `vehicles` | `brand_id`, `registration`, `type`, `capacity_ft3`, `is_active`, `mot_due`, `insurance_due` |
| `job_assignments` | `job_id`, `staff_id` nullable, `vehicle_id` nullable, `role`, `starts_at`, `ends_at` — the double-booking constraint lives here |
| `job_sheets` | `job_id`, `generated_at`, `pdf_path`, `snapshot jsonb` |
| `attendance` | `staff_id`, `department`, `clock_in_at`, `clock_out_at`, `source` (`web`/`mobile`), `location jsonb` nullable, `job_id` nullable |

**Double-booking prevention is a database constraint, not UI validation.** Use
`tstzrange` exclusion constraints on `job_assignments` so the same `staff_id`
and the same `vehicle_id` cannot hold overlapping active assignments:

```sql
alter table job_assignments
  add constraint job_assignments_no_staff_overlap
  exclude using gist (
    staff_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (staff_id is not null and cancelled_at is null);
```

Same shape for `vehicle_id`. Peak-weekend double-booking is on the problem list;
a UI check alone will not stop it.

### Money in

| Table | Key columns |
|---|---|
| `invoices` | `brand_id`, `job_id`, `number`, `status`, `issued_on`, `due_on`, net/vat/gross minor, `currency` |
| `payments` | `brand_id`, `invoice_id`, `method` (`stripe`/`bank_transfer`/`cash`/`card_terminal`), `amount_minor`, `currency`, `status`, `provider_reference`, `received_at`, `reconciled_at`, `reconciled_by_staff_id` |
| `payment_links` | `quote_id`, `provider`, `provider_reference`, `url`, `amount_minor`, `expires_at`, `status` |
| `sales_targets` | `brand_id`, `staff_id` nullable, `period` (`day`/`week`/`month`), `period_start`, `move_size` (`small`/`medium`/`large`/`commercial`/`office`), `target_amount_minor`, `target_count` |

### Messaging

| Table | Key columns |
|---|---|
| `message_templates` | `brand_id`, `key`, `channel` (`email`/`sms`/`whatsapp`), `subject`, `body`, `locale`, `version`, `is_active` |
| `sequences` | `brand_id`, `key`, `trigger` , `is_active` |
| `sequence_steps` | `sequence_id`, `step_order`, `delay_minutes`, `channel`, `template_key`, `stop_conditions jsonb` |
| `sequence_enrolments` | `sequence_id`, `subject_type`, `subject_id`, `status`, `next_step_order`, `next_run_at`, `stopped_reason` |
| `outbox` | `brand_id`, `channel`, `to_address`, `template_key`, `payload jsonb`, `send_after`, `status` (`queued`/`sending`/`sent`/`failed`/`cancelled`/`needs_manual_send`), `attempts`, `idempotency_key unique`, `provider_message_id`, `error` |
| `message_log` | append-only record of everything actually sent or received, with `direction`, `channel`, `subject_id`, `provider_message_id`, `opened_at`, `clicked_at` |

### Audit and compliance

| Table | Key columns |
|---|---|
| `audit_log` | `actor_staff_id`, `actor_role`, `action`, `entity_type`, `entity_id`, `before jsonb`, `after jsonb`, `ip`, `occurred_at` — append-only, no UPDATE or DELETE grant to any role |
| `data_requests` | `customer_id`, `kind` (`export`/`erasure`), `requested_at`, `completed_at`, `performed_by_staff_id`, `result_path` |
| `retention_policies` | `entity_type`, `retain_days`, `basis`, `action` (`anonymise`/`delete`) |

---

## 5. Lead intake, routing and de-duplication

### Intake API

`POST /api/intake/lead`

- Authenticated by HMAC-SHA256 over the raw body using `INTAKE_SIGNING_SECRET`,
  in an `X-Signature` header, with a `X-Timestamp` replay window of 5 minutes.
- Body carries `brand_slug`, contact fields, `source`, UTM parameters, referrer,
  an idempotency key, and an open `payload` object.
- MUST be idempotent on the idempotency key.
- MUST return `202` with the lead reference in under 500 ms; heavy work
  (geocoding, scoring, duplicate detection, acknowledgement email) is queued.
- MUST persist the raw body to `leads.raw_payload` **before** validation, so a
  malformed submission from a brand site is recoverable rather than lost. This
  is the "integration timeouts / abandoned forms" problem from the brief —
  never drop a payload because it failed a schema check.
- Returns `503` with a retry hint, never a silent failure, if the database is
  unreachable — and the widget MUST retain the form state client-side and retry.

A partial-submission endpoint `POST /api/intake/partial` stores half-filled web
forms against a session id so abandoned enquiries can be recovered.

### Duplicate and cross-brand overlap detection

Run on every intake. Score a candidate match on: normalised email exact,
normalised phone (E.164) exact, and fuzzy name + origin outward code +
move date within ±3 days.

- Same brand, strong match → set `duplicate_of_lead_id`, status `duplicate`,
  notify the existing owner. Never create a second pipeline entry.
- **Different brand, strong match** → do not merge. Create the lead, flag it
  with a `cross_brand_overlap` lead event referencing the other lead, and
  surface a banner in both leads. Eco London Movers and EcoGreen's London branch
  bidding against each other for the same customer is a commercial decision for
  a manager, not something the system should resolve silently.

### Routing

`domain/pipeline/assign.ts` assigns `owner_staff_id` on creation using, in order:
explicit round-robin within the brand's sales staff who are on shift, falling
back to the brand's manager if nobody is on shift. Out-of-hours leads MUST
still be assigned and MUST still receive an acknowledgement — "overnight lead
loss" is on the problem list. An unassigned lead older than 15 minutes raises an
alert on the ops dashboard.

### Lead scoring

`domain/pipeline/score.ts`, pure, returns 0–100 from declared property size,
service category, move date proximity, organisation presence and source
historical conversion. The weights live in one exported constant object with a
comment per weight. No ML, no magic — a salesperson must be able to read why a
lead scored 80.

---

## 6. Inventory and pricing engine

### Inventory builder

A room-by-room selector: pick rooms, then add items with quantity steppers,
each with an icon. Volume accumulates live. Requirements:

- MUST work on a phone, one-handed, with 44 px minimum targets.
- MUST support a free-text "other item" with a manual volume estimate.
- MUST show a running total in cubic feet **and** cubic metres, plus an
  estimated van count — customers underestimate; showing the consequence is the
  correction.
- MUST persist progress continuously to the partial-submission store so a
  half-finished inventory survives a dropped connection.
- Items carrying a non-`standard` `handling_class` MUST raise a visible
  "specialist handling — we'll confirm this with you" note on the quote, and
  MUST flag the lead for manual pricing review rather than auto-quoting.

### Pricing

`domain/pricing/calculate.ts`, a pure function:

```ts
calculateQuote(input: QuoteInput, rateCard: RateCard, clock: Clock): QuotePricing
```

`QuotePricing` MUST include a `breakdown` array where every line states its rule
id, its inputs and its output. A salesperson answering "why is this £480?" must
be able to read the answer off the screen.

Inputs the rate card MUST support: volume bands, distance bands (origin to
destination via the geo adapter, **road distance, not straight line**), crew
size and hours, access difficulty (floors, lift, stairs, parking distance),
packing service and materials, date-based multipliers (weekend, bank holiday,
seasonal peak), congestion/ULEZ zone entry, fuel surcharge index, minimum
charge, promo codes, VAT.

Hard rules:

- Rate card rules live in `rate_cards.rules jsonb` and are versioned by
  `effective_from`. A quote stores the **resolved** rate card id and the full
  computed breakdown in `pricing_snapshot`. Re-pricing a historical quote must
  never produce a different number.
- Every input that affects price MUST appear in the breakdown, including a
  multiplier of 1.0 — a silent surcharge is how margin disputes start.
- The engine MUST be able to return `requires_manual_pricing` with a reason,
  rather than guessing. Specialist handling, declared values above a threshold,
  international legs and multi-day jobs all take this path.
- Currency: quote in the brand's default currency; store `fx_rate_to_gbp` at
  quote time for non-GBP so reporting can consolidate without re-fetching rates.

**Unit tests are mandatory here.** A golden-file test per service category with
a fixed clock and a fixed rate card. This is the one part of the system where a
regression costs real money on every job until someone notices.

---

## 7. Quote document, payment and booking

### PDF

`adapters/pdf` renders from a React template to PDF server-side. Requirements:

- Per-brand logo, colours, typography, footer, VAT and company registration
  details, pulled from `brands` — never hardcoded.
- Sections: summary, room-by-room inventory with icons, what's included, what's
  not, price breakdown, validity date, payment options, terms reference.
- Deterministic: same `pricing_snapshot` in, same bytes out.
- Stored in Supabase Storage under a non-guessable path; served through a
  short-lived signed URL, never a public bucket.

### Quote delivery and view tracking

Sending a quote MUST record `sent_at`, enqueue the chase sequence, and produce a
tracked customer-portal link. Opening it sets `first_viewed_at` and moves the
lead to `quoted`. "Viewed but not booked" is the trigger the whole chase engine
hangs off — get this event right.

### Payment

- `PaymentProvider` interface: `createPaymentLink`, `getPayment`,
  `handleWebhook`. Stripe implementation when keys exist; stub otherwise.
- Bank transfer: generate per-quote reference, display account details from
  `brands`, and create a `payments` row in `pending` status. Reconciliation in
  Phase 1 is a **manual mark-as-received action by an accounts user**, which
  writes an audit row. Automatic bank feed matching is Phase 3.
- Deposit vs balance MUST be configurable per brand and per service.
- Webhook handler MUST be idempotent on the provider event id, MUST verify the
  signature, and MUST NOT trust amounts from the request body over the stored
  quote total.
- A failed or expired payment MUST NOT silently cancel a booking. It raises a
  task for the owner and triggers a payment-retry sequence.

### Booking

`domain/pipeline/book.ts` in a single transaction: accept the quote, create the
`jobs` row copying the frozen quote data, create the invoice, transition the
lead to `booked`, stop the chase sequence, enrol the pre-move sequence, write
the audit row. Partial failure MUST roll back entirely — a job with no invoice
is worse than a failed booking.

---

## 8. Chasing, sequences and the 48-hour rule

One scheduler, one outbox, no per-feature timers.

- `GET /api/cron/tick` runs every 5 minutes via Vercel Cron, authorised by
  `CRON_SECRET`. It advances due `sequence_enrolments` and dispatches due
  `outbox` rows. It MUST be idempotent and safe to run concurrently (row-level
  `for update skip locked`).
- The 48-hour rule: a quote `sent` and `viewed` but not accepted after 48 hours
  enrols in the `quote_chase` sequence. Steps are data, not code.
- **Stop conditions are mandatory on every step**: quote accepted, lead lost,
  customer replied, customer unsubscribed, quote expired, manual stop. A
  sequence that keeps sending after the customer books is the "message fatigue"
  problem in the brief, and it is worse than not sending at all.
- **Global frequency cap**: at most N automated messages per customer per
  rolling 7 days across all channels and all brands, N configurable, default 3.
  Enforced in the dispatcher, not in each sequence.
- Quiet hours: no automated send outside 08:00–20:00 UK time; due messages
  defer to the next window.
- Channel fallback: if WhatsApp is unconfigured, the step is written to `outbox`
  with status `needs_manual_send` and appears in a staff queue with the message
  pre-drafted. The workflow works on day one without the API.
- Every send writes `message_log`. Every unsubscribe is honoured immediately
  across all six brands — a customer who opts out of EcoGreen must not start
  receiving Edinburgh Moving mail.

Sequences to ship in Phase 1: `lead_acknowledgement` (immediate, all hours),
`quote_chase` (48h rule), `quote_expiry_warning`, `booking_confirmation`,
`pre_move_reminder`, `review_request` (post-completion), `payment_retry`,
`abandoned_inventory` (partial submission recovery).

---

## 9. Multi-brand theming and the embeddable widget

- `brands` drives runtime theming: accent colour, logo, typography is shared
  (see `DESIGN.md` — one typeface across all brands is deliberate), email
  templates, PDF chrome, sender addresses.
- Brand resolution order: explicit `brand_slug` on intake → host header on the
  embed → the staff user's active brand selector.
- The embeddable widget is a single script tag on each WordPress site that
  mounts an iframe pointing at `/embed/quote?brand=<slug>`. Requirements:
  responsive height via `postMessage`, no cookies before consent, CSP
  `frame-ancestors` restricted to the six brand domains, and a `<noscript>`
  fallback linking to a hosted form. It MUST NOT load the CRM's design system
  onto the host page or touch host styles.

---

## 10. Portals and access control

Four surfaces, one codebase:

| Portal | Who | Sees |
|---|---|---|
| Admin / Management | `admin`, `manager` | Everything in their accessible brands; `admin` sees all brands, financial dashboards, cross-brand analytics, user management, audit log |
| Sales | `sales` | Own and team leads in their brands, inventory builder, quoting, chase queue, own targets and conversion |
| Operations & Dispatch | `ops`, `crew` | Job calendar, assignments, job sheets, vehicle list. `crew` sees only their own assignments and today's job sheets |
| Customer | customer token | Their own quotes, payment, booking status, documents, review link |

RLS requirements:

- Deny by default on every table. No table ships without a policy.
- Brand scoping via a `private.has_brand_access(brand_id, min_role)` helper in a
  `private` schema (follow the pattern already proven in the marketplace app's
  migrations 0014–0015 — helpers in `public` caused RLS recursion there).
- `crew` MUST NOT read customer contact details beyond what the job sheet needs,
  and MUST NOT read any price field. A crew phone left in a customer's hallway
  should not expose the brand's margins.
- `audit_log`: INSERT only for all roles, SELECT for `admin`, no UPDATE/DELETE
  grant to anyone including `admin`.
- Role changes and brand-access changes MUST be admin-only and MUST be
  write-protected by trigger so a compromised session cannot self-promote.
- Staff accounts are **invite only**. No public signup route exists.
- 2FA MUST be available and MUST be enforced for `admin` and `accounts`.

---

## 11. The thin dispatch slice

Only enough to stop a booking dead-ending. Anything beyond this list is Phase 2.

- A week and day calendar of jobs, filterable by brand, branch and department.
- Assign staff and vehicles to a job; overlapping assignments rejected by the
  database constraint in §4 with a clear, specific error in the UI.
- A printable and PDF job sheet that carries: addresses, contact, access notes,
  special instructions, the full inventory with handling flags, crew, vehicle,
  and payment status. The "lost access notes" and "unrecorded special requests"
  problems are solved by one rule: **anything the salesperson typed into
  `access_notes` or `special_instructions` appears on the job sheet, verbatim,
  above the fold.**
- Mark a job complete, capture completion time, which triggers the review
  sequence.
- Staff clock in/out per department, with the job optionally attached, and a
  variance view of logged hours against scheduled job duration.

No GPS, no crew mobile app, no photos, no signature capture in Phase 1.

---

## 12. Dashboards and reporting

Every dashboard number MUST be traceable: clicking a figure opens the filtered
list of rows behind it. A KPI that cannot be drilled into will be distrusted and
then ignored.

- **Management**: leads by stage and brand, conversion rate, revenue booked vs
  target, average quote value, chase queue depth, unassigned leads, cash
  position (received vs outstanding).
- **Sales tracker**: per salesperson and per brand, daily/weekly/monthly against
  `sales_targets`, split by move size. Quote-to-booking conversion per person is
  a first-class number, not a report.
- **Lead providers**: leads, cost, bookings, revenue, cost per acquisition,
  ranked. Include organic and PPC sources so acquisition cost per website is
  answerable.
- **Attribution**: first-touch and last-touch stored per lead, reported side by
  side. Do not pick one model and hide the other.

Chart construction follows `DESIGN.md` §7 exactly — including the hard rule
against dual-axis charts and the fixed categorical colour order.

---

## 13. Integrations

| Concern | Interface | Phase 1 real implementation | Stub behaviour |
|---|---|---|---|
| Payments | `PaymentProvider` | Stripe if keys present | Fake link, manual mark-as-paid |
| Email | `EmailProvider` | Resend/Postmark if key present | Writes to outbox, renders to `.tmp/mail/` |
| SMS | `MessagingProvider` | — | `needs_manual_send` queue |
| WhatsApp | `MessagingProvider` | Only if Business API approved | `needs_manual_send` queue with drafted text |
| PDF | `PdfRenderer` | Server-side React → PDF | Same, no stub needed |
| Geo | `GeoProvider` | Road distance + postcode lookup | Ported marketplace implementation |

Every adapter MUST have a contract test that both the real and stub
implementations pass.

---

## 14. Compliance, security and data

- **GDPR export**: one action produces a machine-readable archive of everything
  held on a customer across all six brands. Logged in `data_requests`.
- **Erasure**: anonymise rather than hard-delete where financial records must be
  retained (UK company records: 6 years). Replace identifying fields with a
  tombstone, keep the financial row, record the erasure. Hard-delete marketing
  and behavioural data. The retention rules live in `retention_policies` as
  data, with the periods supplied by the business — do not invent them.
- **Consent** is recorded with source and timestamp at capture. Marketing sends
  check consent at dispatch time, not at enrolment time.
- **Cross-brand data sharing requires an explicit lawful basis.** Until the
  business confirms one, a customer's record is visible only within the brand
  that captured it; the cross-brand overlap flag in §5 exposes the *existence*
  of an overlap to managers, not the other brand's contact record.
- Secrets never in the client bundle. `SUPABASE_SECRET_KEY` server-only.
- All uploads to private buckets with signed URLs. Validate MIME type and size
  server-side.
- Rate-limit intake, login and token endpoints.
- Audit every state transition, price override, role change, payment
  reconciliation and data request.

---

## 15. Build order

Each milestone is a working, deployed, reviewable increment. Do not batch.

Status below is what has actually been verified, not what has been attempted.
Every "done" claim is backed by a command in `crm/README.md` that anyone can
re-run. Where a milestone is partly done, the split is always the same shape:
the logic and its database guarantees exist and are tested, and the screen that
would let a person reach them does not.

| M | Deliverable | Status at 17 Sep 2026 |
|---|---|---|
| **M0** | `crm/` app scaffolded, design tokens, auth, staff shell | **Done.** Builds, lints, typechecks. Tokens are the only source of colour, type, space and motion. Login and the unauthenticated redirect verified against the running server. |
| **M1** | Schema + RLS for tenancy, people, pipeline. Audit log. | **Done.** 19 migrations apply to a throwaway Postgres; 88 assertions cover brand isolation both ways, crew price exclusion, privilege escalation and audit-log immutability. |
| **M2** | Lead intake API, widget, duplicate + cross-brand detection, routing, acknowledgement | **Partly done.** `/api/intake/lead` is built and the signature, payload, dedupe, routing and scoring logic is tested; `create_intake_lead` is transactional and tested. **Not done:** the embeddable widget, the partial-submission endpoint. |
| **M3** | Lead workspace: list, detail, stage transitions, notes, timeline | **Partly done.** The list view and the transition state machine exist and are tested. **Not done:** the lead detail screen, so transitions are not yet reachable from the UI. |
| **M4** | Item catalogue, inventory builder, pricing engine, golden tests | **Partly done.** Catalogue, volume and the pricing engine are complete with golden tests; a specialist item routes to manual pricing. **Not done:** the visual room-and-item builder UI. |
| **M5** | Quote versioning, PDF, send, view tracking, portal link | **Partly done.** Immutability is enforced by trigger and tested. **Not done:** PDF rendering, sending, view tracking, the portal link. |
| **M6** | Payment links, bank transfer, webhook, booking transaction, invoice | **Partly done.** `book_accepted_quote` is atomic, refuses to book a quote twice, and is tested; the payment adapter and its stub exist. **Not done:** the Stripe webhook route and the bank-transfer reconciliation screen. |
| **M7** | Outbox, sequences, cron tick, 48-hour chase, quiet hours, frequency cap, unsubscribe | **Done.** The scheduler is pure and tested; the cron tick, claim functions and dispatcher are built; concurrent ticks provably claim disjoint work; a cross-brand unsubscribe is honoured. |
| **M8** | Dispatch slice: calendar, assignment, job sheet, completion, attendance | **Partly done.** Double-booking is rejected by a database constraint and the job sheet carries access notes verbatim, both tested. **Not done:** the calendar and assignment UI. |
| **M9** | Dashboards, sales tracker, provider performance, attribution | **Partly done.** Four drill-through KPI tiles and the attention queue. **Not done:** sales tracker, provider performance, attribution reporting. |
| **M10** | GDPR export/erasure, retention job, 2FA, security review, design audit | **Partly done.** Export and erasure are implemented and tested — erasure anonymises and keeps the invoice. **Not done:** the retention purge job, 2FA enforcement, a full security review. |

---

## 16. Non-functional requirements

- TypeScript strict. No `any` in `domain/`. No `as` casts to silence the
  compiler — fix the type.
- Tests: unit tests for everything in `domain/` (this is not negotiable for
  pricing, pipeline transitions and sequence scheduling); integration tests for
  RLS policies and the booking transaction; one end-to-end test per milestone's
  acceptance criteria.
- Performance budgets on every staff screen: LCP < 1.8 s on simulated 4G, CLS <
  0.05, INP < 200 ms. A list view with 5 000 leads must paginate server-side,
  not ship 5 000 rows.
- Accessibility: WCAG 2.2 AA, zero axe criticals, complete keyboard operation,
  visible focus on every interactive element.
- Errors: no bare `throw` reaching a user. Every failure state has a designed
  screen (`DESIGN.md` §8) that says what happened and what to do next.

---

## 17. Session discipline

At the end of every session append to `PROGRESS.md`:

```
### [Date] — [Milestone / short description]
- Built: routes, tables, key files
- Key decisions: what was chosen and why
- Blocked on business input: anything marked VALUE REQUIRED FROM BUSINESS
- Deferred / not done yet: so the next session does not assume it is done
```

Never mark a milestone complete because the code compiles. Run its acceptance
criteria and say in `PROGRESS.md` how you verified them. If a criterion failed,
say so with the output — a milestone reported green that is amber costs more
than an honest amber.
