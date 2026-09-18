import assert from "node:assert/strict";
import { test } from "node:test";

import { allowedTransitions, canTransition, isWon, transition } from "../src/domain/pipeline/status";
import { findMatch, normalisePhone, normaliseEmail, outwardCode } from "../src/domain/pipeline/dedupe";
import { assignLead, type AssignableStaff } from "../src/domain/pipeline/assign";
import { scoreLead } from "../src/domain/pipeline/score";

const NOW = new Date("2026-03-02T10:00:00Z");
const FULL = {
  hasQuote: true,
  hasAcceptedQuote: true,
  hasCompletedJob: true,
  lostReasonId: "reason-1",
};

test("the pipeline only allows the transitions the business actually has", () => {
  assert.ok(canTransition("new", "qualifying"));
  assert.ok(canTransition("quoted", "chasing"));
  assert.ok(canTransition("chasing", "booked"));
  assert.ok(!canTransition("new", "completed"), "a lead cannot skip from new to completed");
  assert.ok(!canTransition("completed", "booked"), "the pipeline does not run backwards");
  assert.deepEqual(allowedTransitions("reviewed"), []);
});

test("a lead cannot be marked quoted without a quote behind it", () => {
  const result = transition("qualifying", "quoted", { ...FULL, hasQuote: false }, NOW, "staff-1");
  assert.equal(result.ok, false);
  if (result.ok) throw new Error("unreachable");
  assert.match(result.error, /Send a quote/);
});

test("a lead cannot be booked without an accepted quote", () => {
  const result = transition("chasing", "booked", { ...FULL, hasAcceptedQuote: false }, NOW, "staff-1");
  assert.equal(result.ok, false);
});

test("marking a lead lost requires a reason, because the analysis depends on it", () => {
  const withoutReason = transition("quoted", "lost", { ...FULL, lostReasonId: undefined }, NOW, "staff-1");
  assert.equal(withoutReason.ok, false);

  const withReason = transition("quoted", "lost", FULL, NOW, "staff-1");
  assert.equal(withReason.ok, true);
  if (!withReason.ok) throw new Error("unreachable");
  assert.equal(withReason.event.payload.lostReasonId, "reason-1");
});

test("every successful transition produces an auditable event", () => {
  const result = transition("new", "qualifying", FULL, NOW, "staff-7");
  assert.equal(result.ok, true);
  if (!result.ok) throw new Error("unreachable");
  assert.deepEqual(
    { from: result.event.from, to: result.event.to, actor: result.event.actorStaffId },
    { from: "new", to: "qualifying", actor: "staff-7" },
  );
  assert.equal(result.event.at, NOW.toISOString());
});

test("a lost lead can be reopened rather than re-created, so its history survives", () => {
  assert.ok(canTransition("lost", "qualifying"));
});

test("conversion counts booked and beyond", () => {
  assert.ok(isWon("booked") && isWon("completed") && isWon("reviewed"));
  assert.ok(!isWon("quoted") && !isWon("lost"));
});

test("phone normalisation treats the same UK number written five ways as one person", () => {
  const forms = ["07700 900123", "+447700900123", "447700900123", "0044 7700 900 123", "07700-900-123"];
  const normalised = new Set(forms.map((form) => normalisePhone(form)));
  assert.equal(normalised.size, 1, [...normalised].join(" | "));
  assert.equal(normalisePhone("07700 900123"), "+447700900123");
});

test("email and postcode normalisation", () => {
  assert.equal(normaliseEmail("  Jo.Bloggs@Example.CO.UK "), "jo.bloggs@example.co.uk");
  assert.equal(outwardCode("sw1a 1aa"), "SW1A");
  assert.equal(outwardCode("M1 1AE"), "M1");
  assert.equal(outwardCode(null), null);
});

const existing = {
  leadId: "lead-1",
  brandId: "brand-eco",
  email: "jo@example.com",
  phone: "07700 900123",
  firstName: "Jo",
  lastName: "Bloggs",
  originPostcode: "SW1A 1AA",
  moveDate: "2026-04-10",
  createdAt: "2026-03-01T09:00:00Z",
};

test("a repeat submission to the same brand is a duplicate, not a second lead", () => {
  const result = findMatch(
    {
      brandId: "brand-eco",
      email: "JO@example.com",
      phone: null,
      firstName: "Jo",
      lastName: "Bloggs",
      originPostcode: "SW1A 2BB",
      moveDate: "2026-04-11",
    },
    [existing],
  );
  assert.equal(result.verdict, "duplicate");
  assert.equal(result.leadId, "lead-1");
  assert.ok(result.signals.includes("email"));
});

test("the same person enquiring at two brands is an overlap, never an automatic merge", () => {
  const result = findMatch(
    {
      brandId: "brand-london",
      email: null,
      phone: "+44 7700 900123",
      firstName: "Jo",
      lastName: "Bloggs",
      originPostcode: "SW1A 1AA",
      moveDate: "2026-04-10",
    },
    [existing],
  );
  assert.equal(result.verdict, "cross_brand_overlap", "a manager decides which brand takes it");
  assert.equal(result.leadId, "lead-1");
});

test("a different person is not matched on a shared postcode alone", () => {
  const result = findMatch(
    {
      brandId: "brand-eco",
      email: "someone.else@example.com",
      phone: "07900 000000",
      firstName: "Sam",
      lastName: "Patel",
      originPostcode: "SW1A 1AA",
      moveDate: "2026-04-10",
    },
    [existing],
  );
  assert.equal(result.verdict, "no_match");
});

const member = (over: Partial<AssignableStaff> & { staffId: string }): AssignableStaff => ({
  role: "sales",
  onShift: true,
  acceptingLeads: true,
  lastAssignedAt: null,
  openLeadCount: 0,
  maxOpenLeads: 0,
  ...over,
});

test("routing picks whoever has waited longest, not whoever has fewest leads", () => {
  const result = assignLead([
    member({ staffId: "a", lastAssignedAt: "2026-03-02T09:00:00Z", openLeadCount: 2 }),
    member({ staffId: "b", lastAssignedAt: "2026-03-01T09:00:00Z", openLeadCount: 40 }),
  ]);
  assert.equal(result.staffId, "b");
  assert.equal(result.rule, "round_robin");
});

test("someone at their cap is skipped", () => {
  const result = assignLead([
    member({ staffId: "a", lastAssignedAt: "2026-03-01T09:00:00Z", openLeadCount: 10, maxOpenLeads: 10 }),
    member({ staffId: "b", lastAssignedAt: "2026-03-02T09:00:00Z" }),
  ]);
  assert.equal(result.staffId, "b");
});

test("an out-of-hours enquiry still gets an owner", () => {
  const result = assignLead([
    member({ staffId: "a", onShift: false }),
    member({ staffId: "m", role: "manager", onShift: false }),
  ]);
  assert.equal(result.staffId, "m");
  assert.equal(result.rule, "manager_fallback");
});

test("nobody available is reported, never silently swallowed", () => {
  const result = assignLead([member({ staffId: "a", acceptingLeads: false })]);
  assert.equal(result.staffId, null);
  assert.equal(result.rule, "unassigned");
});

test("lead scoring explains itself and stays inside 0-100", () => {
  const hot = scoreLead(
    {
      hasOrganisation: true,
      volumeFt3: 1_400,
      moveDate: new Date("2026-03-09T09:00:00Z"),
      serviceCategory: "office",
      sourceConversionRate: 0.9,
      hasEmail: true,
      hasPhone: true,
      hasBothPostcodes: true,
    },
    NOW,
  );
  assert.equal(hot.band, "hot");
  assert.ok(hot.score <= 100 && hot.score >= 70);
  assert.equal(hot.components.length, 6, "every weight is reported, so the score is explicable");

  const cold = scoreLead(
    {
      hasOrganisation: false,
      volumeFt3: null,
      moveDate: null,
      serviceCategory: null,
      sourceConversionRate: 0.05,
      hasEmail: true,
      hasPhone: false,
      hasBothPostcodes: false,
    },
    NOW,
  );
  assert.equal(cold.band, "cold");
  assert.ok(cold.score >= 0);
});

test("an unknown source scores mid, so a new provider is not starved before it converts", () => {
  const unknown = scoreLead(
    {
      hasOrganisation: false, volumeFt3: 500, moveDate: null, serviceCategory: "residential",
      sourceConversionRate: null, hasEmail: true, hasPhone: true, hasBothPostcodes: true,
    },
    NOW,
  );
  const component = unknown.components.find((part) => part.key === "sourceQuality");
  assert.equal(component?.points, 8);
  assert.match(component?.reason ?? "", /New source/);
});
