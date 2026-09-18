import { add, applyVat, formatMoney, max, money, multiply, subtract, sum, zero } from "../money";
import type { Money } from "../money";
import { isSpecialist } from "../inventory/catalogue";
import { ukParts, type Clock } from "../clock";
import type {
  BreakdownLine,
  ManualPricingReason,
  PricingResult,
  QuoteInput,
  RateCard,
} from "./types";

/** The pricing engine.
 *
 *  Pure: no I/O, no ambient clock, no environment. Given the same input, rate
 *  card and instant it returns byte-identical output forever, which is what
 *  makes a historical quote reproducible when a customer disputes it.
 *
 *  Order matters and is fixed:
 *    1. manual-pricing guards (return without a number rather than guess)
 *    2. transport: volume, distance
 *    3. labour: crew beyond the included pair
 *    4. access: floors, long carry
 *    5. packing and materials
 *    6. multipliers: weekend, bank holiday, peak season, fuel
 *    7. zone charges: congestion, ULEZ
 *    8. minimum charge top-up
 *    9. promotional discount
 *   10. VAT and deposit
 *
 *  Every rule appends a line even when it contributes nothing — a multiplier
 *  of ×1.00 shows as a £0.00 line with its inputs. A silent surcharge is how
 *  margin disputes start. */
export function calculateQuote(
  input: QuoteInput,
  rateCard: RateCard,
  clock: Clock,
): PricingResult {
  const manual = manualPricingReasons(input, rateCard);
  if (manual.length > 0) {
    return {
      outcome: "requires_manual_pricing",
      reasons: manual,
      explanation: explainManual(manual),
    };
  }

  const currency = rateCard.currency;
  const lines: BreakdownLine[] = [];
  const push = (line: BreakdownLine): void => {
    lines.push(line);
  };

  // --- 2. Transport -------------------------------------------------------
  const volumeCharge = volumeChargeMinor(input.volumeFt3, rateCard);
  push({
    ruleId: "transport.volume",
    kind: "transport",
    label: "Volume",
    detail: `${input.volumeFt3.toLocaleString("en-GB")} ft³, banded`,
    inputs: { volumeFt3: input.volumeFt3, bands: rateCard.volumeBands.length },
    net: money(volumeCharge, currency),
  });

  const chargeableMiles = Math.max(0, input.roadDistanceMiles - rateCard.includedMiles);
  push({
    ruleId: "transport.distance",
    kind: "transport",
    label: "Distance",
    detail:
      chargeableMiles === 0
        ? `${input.roadDistanceMiles} miles — within the ${rateCard.includedMiles} included`
        : `${chargeableMiles} chargeable miles beyond the ${rateCard.includedMiles} included`,
    inputs: {
      roadDistanceMiles: input.roadDistanceMiles,
      includedMiles: rateCard.includedMiles,
      chargeableMiles,
    },
    net: money(Math.round(chargeableMiles * rateCard.perMileMinor), currency),
  });

  // --- 3. Labour ----------------------------------------------------------
  const additionalMovers = Math.max(0, input.crewSize - rateCard.includedMovers);
  // Hours on site, derived from handling minutes spread across the whole crew
  // and rounded up to the half hour the crew is actually paid for.
  const rawHours = input.crewSize > 0 ? input.crewMinutes / input.crewSize / 60 : 0;
  const billableHours = Math.ceil(rawHours * 2) / 2;
  push({
    ruleId: "labour.additional_movers",
    kind: "labour",
    label: "Additional crew",
    detail:
      additionalMovers === 0
        ? `Crew of ${input.crewSize} — ${rateCard.includedMovers} included`
        : `${additionalMovers} mover(s) beyond the ${rateCard.includedMovers} included, ${billableHours} h`,
    inputs: {
      crewSize: input.crewSize,
      includedMovers: rateCard.includedMovers,
      additionalMovers,
      billableHours,
    },
    net: money(
      Math.round(additionalMovers * billableHours * rateCard.additionalMoverPerHourMinor),
      currency,
    ),
  });

  // --- 4. Access ----------------------------------------------------------
  const floors = input.origin.floorsWithoutLift + input.destination.floorsWithoutLift;
  push({
    ruleId: "access.floors",
    kind: "labour",
    label: "Stairs",
    detail:
      floors === 0
        ? "Ground floor or lift at both addresses"
        : `${floors} floor(s) without a lift across both addresses`,
    inputs: {
      originFloors: input.origin.floorsWithoutLift,
      destinationFloors: input.destination.floorsWithoutLift,
      floors,
    },
    net: money(floors * rateCard.perFloorWithoutLiftMinor, currency),
  });

  const longCarries =
    (input.origin.carryDistanceM > rateCard.longCarryThresholdM ? 1 : 0) +
    (input.destination.carryDistanceM > rateCard.longCarryThresholdM ? 1 : 0);
  push({
    ruleId: "access.long_carry",
    kind: "labour",
    label: "Long carry",
    detail:
      longCarries === 0
        ? `Parking within ${rateCard.longCarryThresholdM} m at both addresses`
        : `${longCarries} address(es) over ${rateCard.longCarryThresholdM} m from parking`,
    inputs: {
      originCarryM: input.origin.carryDistanceM,
      destinationCarryM: input.destination.carryDistanceM,
      thresholdM: rateCard.longCarryThresholdM,
      longCarries,
    },
    net: money(longCarries * rateCard.longCarryMinor, currency),
  });

  // --- 5. Packing and materials ------------------------------------------
  const packingRate = rateCard.packingPerFt3Minor[input.packing] ?? 0;
  push({
    ruleId: "packing.service",
    kind: "labour",
    label: "Packing",
    detail: packingLabel(input.packing),
    inputs: { packing: input.packing, perFt3Minor: packingRate, volumeFt3: input.volumeFt3 },
    net: money(Math.round(packingRate * input.volumeFt3), currency),
  });

  let materialsMinor = 0;
  const unpricedMaterials: string[] = [];
  for (const line of input.materials) {
    const unit = rateCard.materialUnitMinor[line.slug];
    if (unit === undefined) {
      unpricedMaterials.push(line.slug);
      continue;
    }
    materialsMinor += unit * line.quantity;
  }
  push({
    ruleId: "materials.supply",
    kind: "materials",
    label: "Packing materials",
    detail:
      input.materials.length === 0
        ? "None"
        : `${input.materials.reduce((n, m) => n + m.quantity, 0)} item(s)`,
    inputs: {
      lineCount: input.materials.length,
      unpriced: unpricedMaterials.join(",") || "none",
    },
    net: money(materialsMinor, currency),
  });

  // --- 6. Multipliers -----------------------------------------------------
  // Applied against the subtotal so far, each as its own line, each stated
  // even at ×1.00.
  const subtotal = sum(
    lines.map((line) => line.net),
    currency,
  );

  const parts = ukParts(input.moveDate);
  const isoDate = `${parts.year}-${String(parts.month).padStart(2, "0")}-${String(parts.day).padStart(2, "0")}`;
  const weekend = parts.weekday === 0 || parts.weekday === 6;
  const bankHoliday = rateCard.bankHolidays.includes(isoDate);
  const peak = isPeakDate(parts, rateCard);

  const surcharges: readonly {
    ruleId: string;
    label: string;
    applies: boolean;
    multiplier: number;
    detail: string;
    inputs: Record<string, number | string | boolean>;
  }[] = [
    {
      ruleId: "surcharge.weekend",
      label: "Weekend",
      applies: weekend,
      multiplier: rateCard.weekendMultiplier,
      detail: weekend ? "Saturday or Sunday move" : "Weekday move — no uplift",
      inputs: { date: isoDate, weekday: parts.weekday },
    },
    {
      ruleId: "surcharge.bank_holiday",
      label: "Bank holiday",
      applies: bankHoliday,
      multiplier: rateCard.bankHolidayMultiplier,
      detail: bankHoliday ? "UK bank holiday" : "Not a bank holiday — no uplift",
      inputs: { date: isoDate },
    },
    {
      ruleId: "surcharge.peak_season",
      label: "Peak period",
      applies: peak,
      multiplier: rateCard.peakSeasonMultiplier,
      detail: peak ? "Peak season or month-end" : "Off-peak — no uplift",
      inputs: { date: isoDate, month: parts.month, day: parts.day },
    },
    {
      ruleId: "surcharge.fuel",
      label: "Fuel surcharge",
      applies: rateCard.fuelSurchargeRate !== 0,
      multiplier: 1 + rateCard.fuelSurchargeRate,
      detail:
        rateCard.fuelSurchargeRate === 0
          ? "Fuel index at baseline — no uplift"
          : `Fuel index ${(rateCard.fuelSurchargeRate * 100).toFixed(1)}%`,
      inputs: { rate: rateCard.fuelSurchargeRate },
    },
  ];

  for (const surcharge of surcharges) {
    const effective = surcharge.applies ? surcharge.multiplier : 1;
    const amount = subtract(multiply(subtotal, effective), subtotal);
    push({
      ruleId: surcharge.ruleId,
      kind: "surcharge",
      label: surcharge.label,
      detail: surcharge.detail,
      inputs: { ...surcharge.inputs, multiplier: effective, applied: surcharge.applies },
      net: amount,
    });
  }

  // --- 7. Zone charges ----------------------------------------------------
  const vehicles = Math.max(1, input.vehicleCount ?? 1);
  const congestionDays = input.congestionZoneDays ?? 0;
  const ulezDays = input.ulezDays ?? 0;
  push({
    ruleId: "zone.congestion",
    kind: "surcharge",
    label: "Congestion Charge",
    detail:
      congestionDays === 0
        ? "Route does not enter the Congestion Charge zone"
        : `${vehicles} vehicle(s) × ${congestionDays} day(s), at cost`,
    inputs: { vehicles, days: congestionDays },
    net: money(vehicles * congestionDays * rateCard.congestionPerVehiclePerDayMinor, currency),
  });
  push({
    ruleId: "zone.ulez",
    kind: "surcharge",
    label: "ULEZ",
    detail:
      ulezDays === 0
        ? "Route does not enter a ULEZ"
        : `${vehicles} vehicle(s) × ${ulezDays} day(s), at cost`,
    inputs: { vehicles, days: ulezDays },
    net: money(vehicles * ulezDays * rateCard.ulezPerVehiclePerDayMinor, currency),
  });

  // --- 8. Minimum charge --------------------------------------------------
  const beforeMinimum = sum(
    lines.map((line) => line.net),
    currency,
  );
  const minimum = money(rateCard.minimumChargeMinor, currency);
  const topUp = subtract(max(beforeMinimum, minimum), beforeMinimum);
  push({
    ruleId: "minimum.charge",
    kind: "surcharge",
    label: "Minimum charge",
    detail:
      topUp.minor === 0
        ? `Above the ${formatMoney(minimum)} minimum`
        : `Brought up to the ${formatMoney(minimum)} minimum for this service`,
    inputs: { minimumMinor: rateCard.minimumChargeMinor, subtotalMinor: beforeMinimum.minor },
    net: topUp,
  });

  // --- 9. Promotional discount -------------------------------------------
  const beforeDiscount = sum(
    lines.map((line) => line.net),
    currency,
  );
  const discount = promoDiscount(beforeDiscount, input, currency);
  if (discount) push(discount);

  // --- 10. VAT and deposit ------------------------------------------------
  const net = sum(
    lines.map((line) => line.net),
    currency,
  );
  const vatSplit = applyVat(net, rateCard.vatRate);
  const depositFromPercentage = multiply(vatSplit.gross, rateCard.depositPercentage);
  const depositFloor = money(rateCard.depositMinimumMinor, currency);
  // Never ask for a deposit larger than the job itself on very small moves.
  const deposit =
    vatSplit.gross.minor <= depositFloor.minor
      ? vatSplit.gross
      : max(depositFromPercentage, depositFloor);

  return {
    outcome: "priced",
    rateCardId: rateCard.id,
    provisional: rateCard.provisional,
    currency,
    lines,
    net: vatSplit.net,
    vat: vatSplit.vat,
    vatRate: vatSplit.rate,
    gross: vatSplit.gross,
    deposit,
    balance: subtract(vatSplit.gross, deposit),
    pricedAt: clock.now().toISOString(),
  };
}

/** Bands are progressive, like tax bands: the first N ft³ at the first rate,
 *  the next at the second, and so on. Flat banding produces a cliff where
 *  251 ft³ costs less than 250, which customers find and salespeople exploit. */
function volumeChargeMinor(volumeFt3: number, rateCard: RateCard): number {
  let remaining = volumeFt3;
  let lower = 0;
  let total = 0;

  for (const band of rateCard.volumeBands) {
    if (remaining <= 0) break;
    const bandCeiling = band.upToFt3 ?? Number.POSITIVE_INFINITY;
    const bandSize = bandCeiling - lower;
    const taken = Math.min(remaining, bandSize);
    total += taken * band.perFt3Minor;
    remaining -= taken;
    lower = bandCeiling;
  }

  return Math.round(total);
}

function isPeakDate(parts: ReturnType<typeof ukParts>, rateCard: RateCard): boolean {
  if (rateCard.peakMonths.includes(parts.month)) return true;
  if (parts.day <= rateCard.peakMonthStartDays) return true;
  const daysInMonth = new Date(Date.UTC(parts.year, parts.month, 0)).getUTCDate();
  return parts.day > daysInMonth - rateCard.peakMonthEndDays;
}

function promoDiscount(
  base: Money,
  input: QuoteInput,
  currency: Money["currency"],
): BreakdownLine | null {
  const promo = input.promoCode;
  if (!promo) return null;
  const amount =
    promo.kind === "percentage"
      ? multiply(base, -promo.value)
      : money(-Math.min(promo.value, base.minor), currency);
  return {
    ruleId: "discount.promo",
    kind: "discount",
    label: `Promotion ${promo.code}`,
    detail:
      promo.kind === "percentage"
        ? `${(promo.value * 100).toFixed(0)}% off`
        : `${formatMoney(money(promo.value, currency))} off`,
    inputs: { code: promo.code, kind: promo.kind, value: promo.value },
    net: amount,
  };
}

function manualPricingReasons(input: QuoteInput, rateCard: RateCard): ManualPricingReason[] {
  const reasons: ManualPricingReason[] = [];
  if (input.volumeFt3 <= 0) reasons.push("no_inventory");
  if (input.handlingClasses.some(isSpecialist)) reasons.push("specialist_handling");
  if (
    typeof input.declaredValueMinor === "number" &&
    input.declaredValueMinor > rateCard.manualPricing.declaredValueOverMinor
  ) {
    reasons.push("declared_value_above_threshold");
  }
  if (input.isInternational) reasons.push("international_leg");
  if (input.isMultiDay) reasons.push("multi_day");
  if (input.volumeFt3 > rateCard.manualPricing.volumeOverFt3) reasons.push("volume_above_threshold");
  if (input.roadDistanceMiles > rateCard.manualPricing.distanceOverMiles) {
    reasons.push("distance_above_threshold");
  }
  return reasons;
}

const MANUAL_EXPLANATIONS: Record<ManualPricingReason, string> = {
  no_inventory: "no items have been added yet",
  specialist_handling: "the inventory includes specialist items that need a surveyor",
  declared_value_above_threshold: "the declared value is above the automatic limit",
  international_leg: "the move crosses a border",
  multi_day: "the move runs across more than one day",
  volume_above_threshold: "the volume is above the automatic limit",
  distance_above_threshold: "the distance is above the automatic limit",
};

function explainManual(reasons: readonly ManualPricingReason[]): string {
  const listed = reasons.map((reason) => MANUAL_EXPLANATIONS[reason]);
  const joined =
    listed.length === 1
      ? listed[0]
      : `${listed.slice(0, -1).join(", ")} and ${listed[listed.length - 1]}`;
  return `This move needs a price from the team because ${joined}.`;
}

function packingLabel(packing: QuoteInput["packing"]): string {
  switch (packing) {
    case "full":
      return "Full packing service";
    case "part":
      return "Part packing — fragile items only";
    case "materials_only":
      return "Materials supplied, customer packs";
    case "none":
      return "No packing service";
  }
}

export { volumeChargeMinor as __volumeChargeMinorForTest };
