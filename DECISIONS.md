# DECISIONS.md — Recommended defaults

`SPEC.md` §1 listed four things blocked on business input. Rather than hold the
build, each is answered here with a recommendation, the reasoning behind it, and
a single place to change it.

**Read this once.** Every number below is a *starting position chosen to be
safe and defensible*, not a fact about your business. Two of them — the rate
card and the retention periods — have real commercial and legal consequences,
and they are flagged accordingly. The system is built so each is one file to
change, and changing it never touches code.

| # | Decision | Status | Change it in |
|---|---|---|---|
| 1 | Brand accents | Recommended, contrast-verified | `crm/supabase/migrations/0011_seed_brands.sql` |
| 2 | Rate card | **Recommended — needs sign-off before quoting a real customer** | `crm/supabase/migrations/0013_seed_rate_cards.sql` |
| 3 | Integrations | Recommended, stubs ship working | `.env` |
| 4 | Retention periods | **Recommended — needs legal sign-off** | `crm/supabase/migrations/0014_seed_retention.sql` |

---

## 1. Brand accents

Each brand gets one accent with a light-mode and a dark-mode step. All twelve
were checked against their surface and all clear WCAG AA for text (4.5:1):

| Brand | Light accent | vs white | Dark accent | vs `#0B0B0C` |
|---|---|---|---|---|
| EcoGreen Movers | `#18794E` | 5.41 | `#3FBF84` | 8.43 |
| Eco London Movers | `#0B5FA5` | 6.57 | `#4DA3E8` | 7.23 |
| Continuum Green | `#146B63` | 6.34 | `#35B3A6` | 7.64 |
| Removals Company Manchester | `#B42318` | 6.57 | `#F0736A` | 6.90 |
| Edinburgh Moving | `#43467F` | 8.67 | `#9195DB` | 7.05 |
| Glasgow Moving | `#1D4ED8` | 6.70 | `#7CA0F5` | 7.69 |

Reasoning: the two green brands are separated by hue (forest vs teal) rather
than lightness so they stay distinguishable in a brand switcher; the four
regional brands take distinct hue families so a screenshot is identifiable
without reading the logo.

**When you send the real brand colours**, replace the light step and re-derive
the dark one. If a real brand colour fails 4.5:1 — bright greens and oranges
usually do — keep it for the logo and darken it for interactive use. Do not ship
a failing ratio to preserve a hex; `DESIGN.md` §2 says this and it is not
negotiable.

---

## 2. Rate card — **needs sign-off**

This is the one that can cost you money on every job until someone notices, so
read it properly.

I have **not** invented your prices. What is seeded is the *shape* a UK removals
rate card takes, with round, obviously-provisional numbers in it. The structure
is the valuable part and is what the pricing engine is built against; the
numbers are twenty-odd values in one seed file.

Seeded structure, per brand and per service, versioned by `effective_from`:

| Component | Seeded default | Note |
|---|---|---|
| Minimum charge | £180 residential, £350 commercial | Below this, quote manually |
| Volume bands | £ per ft³, banded 0–250 / 251–500 / 501–900 / 901–1400 / 1400+ | The primary driver |
| Distance | First 20 miles included, then £ per mile, road distance | Not straight-line |
| Crew | 2 movers included; £ per additional mover per hour | |
| Access | Per floor without a lift; long-carry over 25 m | Both flat additions |
| Packing | Full / part / materials-only | |
| Materials | Per unit, from the catalogue | |
| Date multipliers | Weekend ×1.15, bank holiday ×1.30, peak season ×1.10 | Peak = Jun–Sep plus the last 3 and first 2 days of any month |
| Congestion / ULEZ | Pass-through at cost, per vehicle per day | **Confirm the current TfL rates** — these change and are not guessed here |
| Fuel surcharge | Index, baseline 0% | Set monthly from your fuel card data |
| VAT | 20% | The UK standard rate |
| Deposit | 25%, minimum £100 | |

**Three things I recommend you keep regardless of what numbers you choose:**

1. **A minimum charge per service.** The most common margin leak in removals is
   a small job priced purely on volume.
2. **`requires_manual_pricing` as a real outcome.** Specialist handling
   (pianos, fine art, laboratory, server racks, medical), declared values above
   a threshold, international legs and multi-day jobs all route to a human.
   An engine that always returns a number will eventually return a wrong one
   with confidence, and someone will send it.
3. **Every input in the breakdown, including multipliers of ×1.0.** This is how
   "inconsistent margins between salespeople" gets fixed — not by policy, but by
   making every price explicable on screen.

Until you sign these off, the seeded card is marked
`-- VALUE REQUIRED FROM BUSINESS` and quotes generated from it carry a visible
`PROVISIONAL PRICING` watermark on the PDF. Remove the watermark flag in the
same seed file when the numbers are yours.

---

## 3. Integrations

| Concern | Recommendation | Why |
|---|---|---|
| Payments | **Stripe** | Already assumed in the brief; Payment Links need no card handling on your side, so your PCI scope stays minimal. |
| Email | **Resend** | Simplest React-template-to-email path, per-domain sending so six brands keep separate reputations. Postmark is the alternative if deliverability on transactional mail matters more than templating. |
| SMS | **Twilio** | Only worth turning on once WhatsApp is live; SMS is the fallback channel, not the primary. |
| WhatsApp | **Meta Cloud API direct**, not a reseller | Cheaper and you own the number and the templates. Start the verification now — it is the long pole. |
| PDF | Server-side React → PDF, no vendor | Deterministic output matters more than features here (see `SPEC.md` §7). |
| Geo | Ported from the marketplace app | Already working, already paid for. |

**Nothing blocks on any of these.** Every one has a stub that completes the flow
end to end: fake payment links you mark paid by hand, email rendered to disk,
WhatsApp and SMS queued as pre-drafted messages in a staff send queue. The
WhatsApp queue in particular is not a placeholder — it is how the workflow
should run for the weeks that Meta verification takes, and staff should be
trained on it either way.

Set the key, get the real provider. No code changes.

---

## 4. Retention periods — **needs legal sign-off**

Recommended starting positions. I am not your DPO and these are not legal
advice; they are the conservative defaults, chosen so that erring costs you
storage rather than compliance.

| Record class | Recommended | Action at expiry | Basis |
|---|---|---|---|
| Financial records: invoices, payments, completed jobs | 6 years from end of the relevant accounting period | Anonymise the person, keep the financial row | UK company and HMRC record-keeping |
| Contracts, signed quotes, damage claims | 6 years from completion | Retain | Contract limitation period (England & Wales; Scotland differs — confirm for the Edinburgh and Glasgow brands) |
| Leads that never converted | 24 months from last contact | Delete | No lawful basis to hold them longer |
| Marketing consent and contact data | Until withdrawn, or 24 months of no engagement | Delete | Consent is not indefinite |
| Behavioural data: opens, clicks, page views | 13 months | Delete | Analytics norm |
| Job photos and condition evidence | 6 years | Retain | Matches the claims window |
| Staff records | 6 years after leaving | Retain | Employment norm |
| Applicant data | 6 months | Delete | |
| Audit log | 7 years | Retain, never editable | |

Two points worth raising with whoever signs this off:

- **Scotland has a different prescription period from England & Wales.** Two of
  your six brands operate there. The table above uses the England & Wales figure
  throughout; confirm before it is relied on.
- **Cross-brand data sharing needs a stated lawful basis.** Until you have one,
  the system keeps a customer's record inside the brand that captured it and
  only tells managers that an overlap *exists* (`SPEC.md` §5). If you want six
  brands sharing one customer view, that is a privacy-notice change across six
  websites, not a settings toggle.

---

## How these are applied

All four live in seed migrations, as data. Changing any of them is a new seed
row plus a new `effective_from` — never a code change, never a redeploy of
business logic. That is deliberate: the things most likely to be wrong on day
one are the things easiest to correct on day two.
