# RECOMMENDATIONS.md — what a centralised CRM for this business should cover

Everything below is scoped to a removals group running six brands, three
branches and an in-house crew. It is opinionated on purpose: a list that says
"you could also add X" for forty items is not advice.

Three labels, used throughout:

- **BUILD** — development work, sized in weeks of one person.
- **BUY** — a vendor does this better and cheaper than you will. Integrate.
- **DECIDE** — blocked on a business, legal or commercial decision, not code.

And one rule that governs the order: **build the thing that stops money
leaking before the thing that reports on it.** Every dashboard in this document
is worth less than the chase sequence that fills it.

---

## 1. The module map

What each item in the left panel is for, and why it exists. Modules already
built are marked ✅.

### Today
| Module | What it does |
|---|---|
| Dashboard ✅ | The five numbers a manager checks before 9am, each drilling into its rows |
| Send queue ✅ | Messages the scheduler drafted but cannot send itself |
| My tasks | Per-person work list: callbacks due, quotes to chase, surveys to book. The thing that stops "I thought you had it" |

### Sales
| Module | What it does |
|---|---|
| Leads ✅ | Every enquiry, owner and stage, across all six brands |
| Quotes | Versions, what was sent, what was viewed, what expired |
| Surveys & video | Book a survey, or take a customer video walkthrough and turn it into an inventory |
| Customers | One record per person, with every brand they have touched |
| Corporate accounts | Organisations, sites, POs, payment terms, SLAs, named contacts |
| Lead providers | Cost per lead, conversion, and cost per acquisition per provider |

### Pricing
| Module | What it does |
|---|---|
| Rate cards | The pricing matrix (§2), versioned by date, per brand and service |
| Item catalogue | Rooms and items with volumes, handling class and crew minutes |
| Packing materials | Stock, cost, sell price, reorder points |
| Promo codes | Discounts with limits, and what they actually cost you |

### Operations
| Module | What it does |
|---|---|
| Job calendar ✅ | Week board with crew and vehicle assignment |
| Job sheets | The frozen document the crew works from |
| Routes & loads | Multi-drop sequencing, load planning, which van fits what |
| Fleet & vehicles | MOT, insurance, service intervals, inspections, fuel |
| Storage | Units, pallets, archive boxes, occupancy, recurring billing |
| Subcontractors | Vetted carriers for remote legs, with rates and paperwork |

### People
| Module | What it does |
|---|---|
| Attendance | Clock in/out per department, with variance against job durations |
| Rota & availability | Who is on, who is off, who is certified for what |
| Staff & skills | The certification matrix — forklift, piano, IT, security clearance |
| Payroll export | Hours, overtime and bonuses, exported to a payroll provider |
| Training & compliance | Inductions, refreshers, expiring certificates |

### Money
| Module | What it does |
|---|---|
| Invoices | One document across transport, materials and storage |
| Payments | Stripe, bank transfer, card terminal, cash |
| Reconciliation | Matching money received to invoices raised |
| Purchasing | Materials, subcontractors, fuel — what you spend and against which job |
| Cash flow | Received, due, overdue, and forecast from pipeline probability |

### Communication
| Module | What it does |
|---|---|
| Sequences | The 48-hour chase and everything like it |
| Templates | Email, SMS and WhatsApp copy, per brand |
| Broadcasts | Bulk messages, with the fair-use cap enforced |
| Reviews | Requests, responses, and where the scores are going |

### Compliance
| Module | What it does |
|---|---|
| Documents | Waste transfer notes, certificates of insurance, method statements |
| Damage claims | Ticketed, with photo evidence and an escalation path |
| Health & safety | Risk assessments, incidents, near misses |
| Data requests | GDPR export and erasure, logged |

### Insight
| Module | What it does |
|---|---|
| Sales tracker | Daily, weekly, monthly against target by move size and by person |
| Branch scorecards | Edinburgh vs Manchester vs London on the same measures |
| Marketing attribution | First touch and last touch, side by side |
| Audit log | Who changed what, append-only |

---

## 2. The pricing matrix

This is the single highest-leverage thing in the system, because it is the
only module that is wrong on every job until it is right.

### The shape

Price is assembled from **seven independent components**, each of which can be
inspected on its own line. Nothing is bundled, because a bundled price cannot
be defended to a customer or diagnosed when margin slips.

| # | Component | Driver | Why it is separate |
|---|---|---|---|
| 1 | **Volume** | ft³, progressive bands | The primary driver. Progressive, not flat — a flat band means 251 ft³ costs less than 250 |
| 2 | **Distance** | road miles beyond an included radius | Straight-line distance under-prices every hilly or estuary route |
| 3 | **Labour** | crew size × billable hours | Lets you price a two-hour job and a two-day job from the same card |
| 4 | **Access** | floors without a lift, carry distance, parking | The most common cause of a job over-running |
| 5 | **Materials & packing** | per item, per ft³ | Sold, not absorbed |
| 6 | **Time multipliers** | weekend, bank holiday, peak season, month-end | Demand-based, and the thing most firms leave on the table |
| 7 | **Pass-throughs** | congestion, ULEZ, tolls, parking suspension, ferry | At cost, itemised, never margin |

### The three bands to get right first

1. **Volume bands.** Five bands is enough: 0–250, 251–500, 501–900, 901–1400,
   1400+. Rate per ft³ falls as volume rises, because the fixed cost of
   turning up is spread further.
2. **Peak multipliers.** Friday, Saturday, the last three working days of the
   month and the first two are when demand concentrates in UK removals. If
   your price is identical on the 31st and the 12th, you are subsidising your
   busiest day with your quietest one.
3. **Minimum charge per service.** The most common margin leak in removals is
   a small job priced purely on volume.

### Five rules for the engine

1. **Every rule appears on the breakdown, including the ones that added
   nothing** — a ×1.00 multiplier shows as a £0.00 line with its inputs. A
   surcharge nobody can see is how margin disputes start.
2. **`requires_manual_pricing` is a real outcome.** Specialist handling,
   declared values above a threshold, international legs and multi-day jobs
   route to a human. An engine that always returns a number will eventually
   return a wrong one with confidence, and someone will send it.
3. **Rate cards are versioned by `effective_from` and never edited in place.**
   A quote stores the resolved card and the full computed breakdown, so
   re-pricing a historical quote can never produce a different number.
4. **Cost, not just price.** Store an estimated cost per job — crew hours,
   fuel, materials, subcontractor — so the system can report *margin* rather
   than revenue. Most removals CRMs never do this, and it is why firms grow
   turnover and not profit.
5. **A price-override needs a reason and is audited.** Discounting is fine;
   untracked discounting is how two salespeople end up 20% apart.

### What to measure once it runs

Quote-to-book conversion by band · average discount by salesperson · margin
per job type · the gap between quoted crew hours and actual crew hours. That
last one is the number that tells you whether the card is right.

---

## 3. People, time and payroll

The part most removals CRMs ignore, and the reason overtime is a surprise.

**What to build:**

- Clock in/out per department, from a phone, with the job attached where there
  is one.
- **Variance**: logged hours against scheduled job duration, per crew and per
  job type. This is how you find out that four-bed moves take nine hours, not
  seven — and fix the rate card.
- Rota with availability, holiday and sickness, so dispatch is not assigning
  people who are off.
- A **skills matrix**: forklift, heavy lifting, IT dismantling, piano, security
  clearance, driving categories. Jobs that need a certification cannot be
  assigned to crew who lack it — enforced, not advisory.
- Certificate expiry alerts. A lapsed licence is a stopped job.
- Overtime rules and bonus calculation from booked revenue and conversion.

**What NOT to build: payroll itself.** Record hours, departments and rates;
export to a payroll provider. Calculating PAYE, NI and statutory deductions
in-house converts a software bug into an HMRC liability. This boundary is
deliberate and should not move.

**DECIDE before building:** metrics attached to pay or discipline change their
character and need a policy staff have seen. Build the measurement; do not
build the consequence without the policy.

---

## 4. Fifty-four improvements

Ordered by return, not by module. The first ten are where the money is.

### Stop the leaks (do these first)

1. **BUILD · Response-time SLA with escalation.** Median first response is the
   single strongest predictor of conversion in this trade. Alert at 15 minutes
   unassigned, escalate at 60.
2. **BUILD · Out-of-hours auto-response with a booking link.** An enquiry at
   22:40 that gets an answer at 09:00 has already been quoted by someone else.
3. **BUILD · Abandoned-quote recovery.** Half-finished web inventories, chased
   two hours later.
4. **BUILD · Quote expiry warnings.** A fixed price that lapses silently is a
   lead you paid for and threw away.
5. **BUILD · Duplicate and cross-brand overlap detection.** Two of your brands
   bidding against each other is a commercial decision, not an accident.
6. **BUILD · Cost capture per job**, so you can report margin, not turnover.
7. **BUILD · Lost-reason analysis.** Mandatory reason on every lost lead, then
   report it. "Price" and "date unavailable" need completely different fixes.
8. **BUILD · Deposit-taking at the point of acceptance.** A booking without a
   deposit is a diary entry, not a job.
9. **BUILD · Survey-to-quote conversion tracking.** If surveys convert at 70%
   and phone quotes at 25%, you should be surveying far more.
10. **BUILD · Win-back for dormant corporate accounts.** The cheapest revenue
    you will ever get.

### Sell better

11. **BUILD · Video survey upload** with staff-assisted volume estimation.
12. **BUILD · Visual inventory builder** on every brand's web form.
13. **BUILD · Van-fit preview** — "this needs two vans" answered before the day.
14. **BUILD · Quote comparison view** — three options (economy, standard,
    full-service) on one PDF. Anchoring raises average order value.
15. **BUILD · Instant indicative price** for simple residential moves, with a
    firm quote to follow. Speed beats precision at first contact.
16. **BUILD · Lead scoring** visible to the salesperson with its reasoning.
17. **BUILD · Callback scheduling** rather than "I'll ring you back".
18. **BUILD · Referral and estate-agent attribution** with commission tracking.
19. **BUILD · Repeat-customer detection** at intake, with their history surfaced.
20. **BUY · Call recording** attached to the lead record, for dispute resolution.

### Run the jobs

21. **BUILD · Job sheets that carry access notes verbatim** — already done, and
    the single highest-value thing on the sheet.
22. **BUILD · Crew mobile app**: today's jobs, check in/out, condition photos.
23. **BUILD · Signature capture** on completion and damage waivers.
24. **BUILD · Skills-matched assignment** that refuses uncertified crew.
25. **BUILD · Double-booking prevention as a database constraint** — done; a
    check in the form is bypassed by a second browser tab.
26. **BUILD · Multi-drop route sequencing** for clearances and office moves.
27. **BUILD · Load planning** — which items go in which van, in what order.
28. **BUILD · Shift handover notes** between dispatch and morning crew leads.
29. **BUILD · Crew workload balancing**, so heavy jobs are visibly distributed.
30. **BUILD · Pre-trip vehicle inspection checklists**, with defects blocking
    dispatch.
31. **BUILD · Parking suspension and loading bay reminders** with lead times per
    council.
32. **BUY · GPS telematics**, then integrate read-only. Do not build this.
33. **BUILD · Crate and box return tracking.** Unreturned rental crates are pure
    loss and nobody chases them.

### Get paid

34. **BUILD · One invoice across transport, materials and storage.**
35. **BUILD · Automatic bank-transfer matching** by reference.
36. **BUILD · Payment retry sequence** that never silently cancels a booking.
37. **BUILD · Recurring billing for storage.**
38. **BUILD · Overdue-invoice chasing** on the same engine as quote chasing.
39. **BUILD · Cash-flow forecast** from pipeline probability.
40. **BUY · Open Banking feed** for reconciliation.
41. **DECIDE · Accounting package** (Xero / QuickBooks / Sage), then export to it.

### Keep customers

42. **BUILD · Review request timed to the day after completion**, while it is
    fresh — timing, not nagging, is the fix for review volume.
43. **BUILD · NPS on completed moves**, with detractors routed to a manager.
44. **BUILD · Customer portal**: quote, pay, track, documents, review.
45. **BUILD · Proactive delay notification** — a call before the customer rings
    you is worth more than any apology after.
46. **BUILD · Damage claims with photo evidence** and a stated response time.
47. **BUILD · Unified inbox** — email, WhatsApp, SMS and web chat in one thread.
48. **BUILD · Fair-use cap across all six brands.** A customer experiences one
    sender, not six.

### Know what is happening

49. **BUILD · Branch scorecards** on identical measures.
50. **BUILD · Cost per acquisition per website**, not just per provider.
51. **BUILD · Salesperson conversion and average discount**, visible to them.
52. **BUILD · Quoted-vs-actual crew hours**, the number that corrects the rate
    card.
53. **BUILD · Seasonality view** — 18 months of bookings by week, so next
    summer is staffed from evidence.
54. **BUILD · Every dashboard figure drills through to its rows.** A KPI that
    cannot be opened gets distrusted, then ignored.

---

## 5. What not to build

Each of these will be suggested. Each costs more than it returns.

| Item | Why not |
|---|---|
| Payroll calculation | HMRC liability. Export hours instead. |
| Tachograph / drivers' hours | Regulated telematics. Buy certified. |
| Customs declarations | Dedicated software with HMRC CDS access. Store references only. |
| Facial-recognition clock-in | Special-category biometric data under UK GDPR, needs a DPIA and a fallback for anyone who refuses — so you build the fallback anyway. GPS geofence achieves the same thing. |
| 3D room visualiser | Months of 3D work with unproven return for this business. |
| Council permit auto-submission | Every council differs and most have no API. Build the reminder; a human submits. |
| Competitor price scraping | Legally grey, operationally brittle. |
| An in-house accounting ledger | Integrate with a package. |

---

## 6. The order I would build in

1. **Pricing matrix and cost capture** — everything downstream is wrong without it.
2. **Response-time SLA, out-of-hours acknowledgement, chase sequences.**
3. **Quotes, deposits, invoices, reconciliation.**
4. **Crew app, job sheets, skills-matched assignment.**
5. **Attendance, rota, payroll export.**
6. **Reviews, portal, unified inbox.**
7. **Scorecards, attribution, seasonality.**

Storage, subcontractors and compliance documents slot in wherever the business
actually needs them — they are real modules, but none of them is losing you
money this week.
