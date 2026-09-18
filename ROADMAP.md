# ROADMAP.md — Everything after Phase 1

The brief listed roughly 50 operational parameters, 25 modules, 60+ extended
features and 50 roadmap steps. That is a multi-year product plan for a funded
engineering team, not one build. Compressed into a single spec it produces a
document where every feature gets one shallow paragraph and the implementing
agent invents the rest — which is exactly how a build stalls or silently ships
guessed business rules.

So the scope is phased here, honestly, with three labels:

- **BUILD** — development work, specified when its phase starts.
- **PROCURE** — a vendor, contract or integration. The development part is
  small; the lead time is not. Start these early.
- **DECIDE** — blocked on a business, legal or compliance decision. No amount of
  engineering unblocks it.

Nothing in this file gets built while Phase 1 is open.

---

## Phase 1 — Lead to cash *(specified in `SPEC.md`)*

Multi-brand lead intake · pipeline · inventory builder · pricing engine ·
branded PDF quotes · payments · 48-hour chasing · thin dispatch · sales tracker ·
attendance · dashboards · GDPR.

**Start these PROCURE items during Phase 1, because they gate later phases:**

| Item | Why early |
|---|---|
| WhatsApp Business API | Meta business verification plus per-template approval. Weeks, not days. Phase 1 ships a manual-send queue precisely because of this. |
| Stripe account and webhooks | Needed for real payment testing in M6. |
| Transactional email domain, SPF/DKIM/DMARC | Domain reputation takes time to warm. Six sending domains, six DNS changes. |
| Payroll provider and its import format | Determines the export shape in Phase 4. |

---

## Phase 2 — Operations and the crew app

Turns the thin dispatch slice into a real operations system.

- **BUILD** Crew mobile app (PWA first, native only if push and background
  location prove insufficient): today's jobs, job sheet, check in/out,
  condition photos before and after, completion sign-off.
- **BUILD** On-screen signature capture for completion and damage waivers, with
  the signed document stored immutably.
- **BUILD** Crew skill matrix — staff tagged by certification (forklift, heavy
  lifting, IT dismantling, piano, security clearance) — and job-to-crew matching
  that refuses to assign an uncertified crew to a job that requires it.
- **BUILD** Multi-drop route planning and mileage estimation.
- **BUILD** Vehicle pre-trip inspection checklists; MOT and insurance expiry
  reminders derived from `vehicles`.
- **BUILD** Shift handover notes between dispatch and morning crew leads.
- **BUILD** Crew workload balancing view — heavy and long-distance jobs
  distributed visibly, to address burnout.
- **BUILD** Damage claim tickets with photo evidence and an escalation path.
- **PROCURE** Map and routing provider with a commercial licence for
  optimisation (most free tiers forbid it).
- **DECIDE** Geofenced check-in is location tracking of employees. It needs a
  DPIA, a stated lawful basis, a written policy and staff consultation before a
  line of code. Legitimate interest is arguable for job-site check-in; continuous
  tracking is much harder to justify.

**Explicitly rejected from this phase:** biometric and facial-recognition
clock-in. Biometric data is special-category under UK GDPR, requires explicit
consent that staff can withdraw, and demands a fallback for anyone who refuses —
so you build the fallback anyway. GPS geofence check-in achieves the same
operational outcome with a fraction of the legal exposure. If the business still
wants it after that, it is a **DECIDE**, not a backlog item.

---

## Phase 3 — Money

- **BUILD** Invoicing consolidated across transport, packing materials and
  storage on one document — the "fragmented invoicing" problem.
- **BUILD** Bank reconciliation: match incoming deposits and Stripe payouts to
  open invoices, with a review queue for near-matches.
- **BUILD** Cash-flow view: received, due, overdue, forecast from pipeline
  probability.
- **BUILD** Supplier and subcontractor payment tracking.
- **BUILD** Accounting export in the provider's import format.
- **BUILD** Recurring billing for long-term storage.
- **BUILD** Customer lifetime value and churn indicators for corporate accounts.
- **PROCURE** Open Banking feed for automatic bank-transfer matching (this is
  what removes the manual reconciliation step left in Phase 1).
- **PROCURE** Accounting package decision — Xero, QuickBooks or Sage. This
  determines the export format and should be settled before the phase starts.
- **DECIDE** Multi-currency and international VAT. Cross-border VAT treatment is
  an accountant's determination; the system implements the rules it is given and
  must not infer them.

---

## Phase 4 — People

- **BUILD** Timesheet approval, overtime flagging, variance between logged hours
  and actual job durations.
- **BUILD** Payroll **export** to the chosen provider. The system records hours,
  departments and rates; the provider calculates PAYE, NI and statutory
  deductions. This boundary is deliberate — calculating statutory deductions
  in-house converts a software bug into an HMRC liability.
- **BUILD** Commission and bonus calculation from booked revenue and conversion.
- **BUILD** Staff onboarding checklists and training modules.
- **BUILD** Performance reviews linked to productivity metrics.
- **PROCURE** Payroll provider with an API or a documented import format.
- **PROCURE** Background and right-to-work checking vendor.
- **DECIDE** How productivity metrics are used. Metrics attached to pay or
  discipline change their character and need a policy staff have seen. Build the
  measurement; do not build the consequence without the policy.

---

## Phase 5 — Storage, compliance and specialist work

- **BUILD** Storage: unit, pallet and archive-box inventory, occupancy, warehouse
  layout view, check-in and check-out.
- **BUILD** QR/barcode labelling — scan boxes into storage and into destination
  rooms. Solves untracked crate returns and storage shrinkage.
- **BUILD** Waste transfer notes with digital sign-off for clearance jobs.
- **BUILD** Certificates of Insurance generated and emailed to building managers.
- **BUILD** Risk assessments and method statements generated per job from
  templates.
- **BUILD** Health and safety handbooks in the staff app.
- **BUILD** Document retention and vault access logs for archive storage.
- **PROCURE** Waste carrier licence verification and any registry integration.
- **DECIDE** Hazardous materials and laboratory biohazard transport. This is
  regulated carriage. The system can hold the paperwork and enforce a checklist;
  it cannot make the business compliant. Specialist advice first.

---

## Phase 6 — Growth and intelligence

- **BUILD** Unified inbox: email, WhatsApp, SMS and web chat in one thread per
  customer.
- **BUILD** Win-back campaigns for dormant corporate accounts.
- **BUILD** Referral and affiliate attribution with estate agents and partners.
- **BUILD** Review feed aggregation and reply tracking.
- **BUILD** Video survey upload with staff-assisted volume estimation.
- **BUILD** Report builder for management.
- **BUILD** Branch scorecards and per-brand acquisition cost.
- **PROCURE** Review platform APIs (Trustpilot and Feefo are paid tiers for API
  access; Google is via Business Profile).
- **PROCURE** Translation provider for multilingual enquiries.
- **DECIDE** AI lead triage and sentiment analysis. Useful, but both make
  decisions about customers from inferred data. Decide the human-review boundary
  before building: triage that routes is fine; triage that discards is not.

---

## Never — or not as software

Listed so they stop coming back around.

| Item | Why not |
|---|---|
| Tachograph and drivers' hours integration | Regulated telematics. Buy a certified vendor's system; integrate read-only. Building it is neither legal nor sensible. |
| Fleet GPS telemetry | Hardware plus a telematics contract. **PROCURE**, then integrate — not a development project. |
| Customs declarations and bonded warehouse | Dedicated customs software with HMRC CDS access. The CRM stores references and documents; it does not file declarations. |
| Council parking suspension applications | Every council has a different portal, most with no API. Build reminders and a checklist; a human submits. |
| Credit checks, background checks, competitor price monitoring, call recording | All vendor services with contracts and compliance implications. Integrate; do not build. |
| In-house PAYE/NI calculation | See Phase 4. |
| 3D room visualiser and van packing simulation | A months-long 3D engineering effort whose commercial return is unproven for this business. Revisit only with evidence that customers ask for it. |
| Facial-recognition clock-in | See Phase 2. |

---

## How to change this roadmap

Move an item earlier only by moving another item later. The failure mode this
file exists to prevent is not "we forgot a feature" — everything from the brief
is here. It is starting six phases at once and finishing none, which is how the
current situation of separate sheets, inboxes and tools came about in the first
place.
