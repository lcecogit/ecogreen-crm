import assert from "node:assert/strict";
import { test } from "node:test";

import { calculateQuote } from "../src/domain/pricing/calculate";
import { defaultRateCard } from "../src/domain/pricing/default-rate-card";
import type { QuoteInput, RateCard } from "../src/domain/pricing/types";
import { fixedClock } from "../src/domain/clock";
import { formatMoney } from "../src/domain/money";

const clock = fixedClock("2026-03-02T10:00:00Z");
const card = defaultRateCard("ecogreen-movers", "residential");

// A Wednesday in March: no weekend, no bank holiday, no peak, mid-month.
const NEUTRAL_DATE = new Date("2026-03-11T09:00:00Z");

function input(overrides: Partial<QuoteInput> = {}): QuoteInput {
  return {
    serviceCategory: "residential",
    moveDate: NEUTRAL_DATE,
    volumeFt3: 500,
    crewMinutes: 600,
    crewSize: 2,
    roadDistanceMiles: 20,
    origin: { floorsWithoutLift: 0, carryDistanceM: 10 },
    destination: { floorsWithoutLift: 0, carryDistanceM: 10 },
    packing: "none",
    materials: [],
    handlingClasses: ["standard"],
    ...overrides,
  };
}

function priced(overrides: Partial<QuoteInput> = {}, rateCard: RateCard = card) {
  const result = calculateQuote(input(overrides), rateCard, clock);
  assert.equal(result.outcome, "priced", "expected a priced result");
  if (result.outcome !== "priced") throw new Error("unreachable");
  return result;
}

test("prices a baseline 500 ft³ local move and reconciles net + VAT = gross", () => {
  const result = priced();
  // 250 ft³ @ 90p = £225.00, next 250 @ 70p = £175.00.
  assert.equal(formatMoney(result.net), "£400.00");
  assert.equal(formatMoney(result.vat), "£80.00");
  assert.equal(formatMoney(result.gross), "£480.00");
  assert.equal(result.net.minor + result.vat.minor, result.gross.minor);
});

test("the printed lines always add up to the printed net", () => {
  const result = priced({ volumeFt3: 1200, roadDistanceMiles: 140, crewSize: 4, crewMinutes: 1800 });
  const lineTotal = result.lines.reduce((total, line) => total + line.net.minor, 0);
  assert.equal(lineTotal, result.net.minor);
});

test("volume bands are progressive, so there is no cliff at a band edge", () => {
  const justUnder = priced({ volumeFt3: 250 }).net.minor;
  const justOver = priced({ volumeFt3: 251 }).net.minor;
  assert.ok(justOver > justUnder, "251 ft³ must not cost less than 250 ft³");
  assert.equal(justOver - justUnder, 70, "the 251st cubic foot is charged at the second band rate");
});

test("every rule appears in the breakdown even when it contributes nothing", () => {
  const result = priced();
  const ruleIds = result.lines.map((line) => line.ruleId);
  for (const expected of [
    "transport.volume",
    "transport.distance",
    "labour.additional_movers",
    "access.floors",
    "access.long_carry",
    "packing.service",
    "materials.supply",
    "surcharge.weekend",
    "surcharge.bank_holiday",
    "surcharge.peak_season",
    "surcharge.fuel",
    "zone.congestion",
    "zone.ulez",
    "minimum.charge",
  ]) {
    assert.ok(ruleIds.includes(expected), `breakdown is missing ${expected}`);
  }
  // A multiplier that did not apply is stated at ×1.00 with a £0.00 amount,
  // rather than being silently absent.
  const weekend = result.lines.find((line) => line.ruleId === "surcharge.weekend");
  assert.equal(weekend?.net.minor, 0);
  assert.equal(weekend?.inputs.multiplier, 1);
  assert.equal(weekend?.inputs.applied, false);
});

test("distance is only charged beyond the included miles", () => {
  assert.equal(priced({ roadDistanceMiles: 20 }).lines.find((l) => l.ruleId === "transport.distance")?.net.minor, 0);
  // 60 miles: 40 chargeable at £1.80.
  assert.equal(priced({ roadDistanceMiles: 60 }).lines.find((l) => l.ruleId === "transport.distance")?.net.minor, 7_200);
});

test("weekend, peak and fuel multipliers compound on the subtotal, not on each other's output", () => {
  // Saturday 4 July 2026 — weekend and peak month.
  const saturdayInJuly = priced({ moveDate: new Date("2026-07-04T09:00:00Z") });
  const weekend = saturdayInJuly.lines.find((l) => l.ruleId === "surcharge.weekend");
  const peak = saturdayInJuly.lines.find((l) => l.ruleId === "surcharge.peak_season");
  assert.equal(weekend?.net.minor, 6_000, "15% of the £400 subtotal");
  assert.equal(peak?.net.minor, 4_000, "10% of the same £400 subtotal, not of £460");
});

test("the minimum charge tops a small move up rather than leaving it underpriced", () => {
  const result = priced({ volumeFt3: 40, crewMinutes: 60 });
  const topUp = result.lines.find((line) => line.ruleId === "minimum.charge");
  assert.ok(topUp && topUp.net.minor > 0);
  assert.equal(result.net.minor, card.minimumChargeMinor);
});

test("access charges read both addresses", () => {
  const result = priced({
    origin: { floorsWithoutLift: 2, carryDistanceM: 60 },
    destination: { floorsWithoutLift: 1, carryDistanceM: 5 },
  });
  assert.equal(result.lines.find((l) => l.ruleId === "access.floors")?.net.minor, 7_500);
  assert.equal(result.lines.find((l) => l.ruleId === "access.long_carry")?.net.minor, 3_000);
});

test("specialist handling refuses to guess a price", () => {
  const result = calculateQuote(input({ handlingClasses: ["standard", "piano"] }), card, clock);
  assert.equal(result.outcome, "requires_manual_pricing");
  if (result.outcome !== "requires_manual_pricing") throw new Error("unreachable");
  assert.ok(result.reasons.includes("specialist_handling"));
  assert.match(result.explanation, /surveyor/);
});

test("an empty inventory is a manual-pricing case, not a £0 quote", () => {
  const result = calculateQuote(input({ volumeFt3: 0 }), card, clock);
  assert.equal(result.outcome, "requires_manual_pricing");
});

test("international, multi-day and over-threshold moves route to a human", () => {
  for (const override of [
    { isInternational: true },
    { isMultiDay: true },
    { volumeFt3: 3_000 },
    { roadDistanceMiles: 500 },
    { declaredValueMinor: 2_000_000 },
  ] satisfies Partial<QuoteInput>[]) {
    const result = calculateQuote(input(override), card, clock);
    assert.equal(result.outcome, "requires_manual_pricing", JSON.stringify(override));
  }
});

test("the deposit never exceeds the job on a very small move", () => {
  const tiny = defaultRateCard("ecogreen-movers", "residential");
  const result = priced({ volumeFt3: 40 }, { ...tiny, minimumChargeMinor: 5_000, depositMinimumMinor: 10_000 });
  assert.ok(result.deposit.minor <= result.gross.minor);
  assert.equal(result.deposit.minor + result.balance.minor, result.gross.minor);
});

test("a percentage promotion discounts the whole subtotal and never goes below zero", () => {
  const result = priced({ promoCode: { code: "SPRING10", kind: "percentage", value: 0.1 } });
  const discount = result.lines.find((line) => line.ruleId === "discount.promo");
  assert.ok(discount && discount.net.minor < 0);
  assert.ok(result.net.minor > 0);
});

test("pricing is deterministic — the same inputs reproduce the same quote", () => {
  const a = priced({ volumeFt3: 830, roadDistanceMiles: 73, crewSize: 3, crewMinutes: 900 });
  const b = priced({ volumeFt3: 830, roadDistanceMiles: 73, crewSize: 3, crewMinutes: 900 });
  assert.deepEqual(a, b);
});
