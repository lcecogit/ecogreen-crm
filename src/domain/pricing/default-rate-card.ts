import type { RateCard, ServiceCategory } from "./types";

/* ─────────────────────────────────────────────────────────────────────────
   VALUES REQUIRED FROM BUSINESS

   Every money figure below is a PROVISIONAL recommendation, not a fact about
   this business. See DECISIONS.md §2 for the reasoning and for what to change.
   `provisional: true` puts a PROVISIONAL PRICING watermark on every quote PDF
   generated from this card; clear the flag when the numbers are signed off.

   The structure is the part worth keeping. The numbers are twenty values.
   ───────────────────────────────────────────────────────────────────────── */

const MATERIALS_MINOR: Record<string, number> = {
  box_small: 250,
  box_large: 350,
  wardrobe_box: 1200,
  bubble_wrap_roll: 1500,
  packing_paper_pack: 1200,
  tape_roll: 300,
  mattress_cover: 600,
  sofa_cover: 800,
  crate_rental_week: 800,
  eco_crate_rental_week: 900,
};

/** Bank holidays are loaded from the gov.uk feed rather than hard-coded —
 *  they differ between England & Wales and Scotland, and two of the six brands
 *  trade in Scotland. Seeded empty so nothing is silently wrong. */
const BANK_HOLIDAYS: readonly string[] = [];

interface CategoryOverrides {
  readonly minimumChargeMinor: number;
  readonly perFt3: readonly [number, number, number, number, number];
  readonly additionalMoverPerHourMinor: number;
}

const BY_CATEGORY: Record<ServiceCategory, CategoryOverrides> = {
  residential: { minimumChargeMinor: 18_000, perFt3: [90, 70, 55, 45, 38], additionalMoverPerHourMinor: 2_800 },
  commercial: { minimumChargeMinor: 35_000, perFt3: [110, 85, 68, 55, 46], additionalMoverPerHourMinor: 3_200 },
  office: { minimumChargeMinor: 35_000, perFt3: [110, 85, 68, 55, 46], additionalMoverPerHourMinor: 3_200 },
  specialist: { minimumChargeMinor: 50_000, perFt3: [140, 110, 90, 75, 60], additionalMoverPerHourMinor: 3_800 },
  clearance: { minimumChargeMinor: 15_000, perFt3: [70, 55, 44, 36, 30], additionalMoverPerHourMinor: 2_600 },
  storage: { minimumChargeMinor: 12_000, perFt3: [60, 48, 38, 32, 28], additionalMoverPerHourMinor: 2_600 },
};

export function defaultRateCard(
  brandSlug: string,
  serviceCategory: ServiceCategory,
  effectiveFrom = "2026-01-01",
): RateCard {
  const overrides = BY_CATEGORY[serviceCategory];
  const [b1, b2, b3, b4, b5] = overrides.perFt3;

  return {
    id: `${brandSlug}:${serviceCategory}:${effectiveFrom}`,
    brandSlug,
    serviceCategory,
    currency: "GBP",
    effectiveFrom,
    provisional: true,

    minimumChargeMinor: overrides.minimumChargeMinor,

    // Progressive bands, like tax bands: no cliff where 251 ft³ costs less
    // than 250 ft³.
    volumeBands: [
      { upToFt3: 250, perFt3Minor: b1 },
      { upToFt3: 500, perFt3Minor: b2 },
      { upToFt3: 900, perFt3Minor: b3 },
      { upToFt3: 1_400, perFt3Minor: b4 },
      { upToFt3: null, perFt3Minor: b5 },
    ],

    includedMiles: 20,
    perMileMinor: 180,

    includedMovers: 2,
    additionalMoverPerHourMinor: overrides.additionalMoverPerHourMinor,

    perFloorWithoutLiftMinor: 2_500,
    longCarryThresholdM: 25,
    longCarryMinor: 3_000,

    packingPerFt3Minor: { none: 0, materials_only: 0, part: 35, full: 75 },
    materialUnitMinor: MATERIALS_MINOR,

    weekendMultiplier: 1.15,
    bankHolidayMultiplier: 1.3,
    peakSeasonMultiplier: 1.1,
    peakMonths: [6, 7, 8, 9],
    peakMonthEndDays: 3,
    peakMonthStartDays: 2,
    bankHolidays: BANK_HOLIDAYS,

    // At cost, per vehicle per day. Zero until the current TfL rates are
    // confirmed — a stale congestion charge is a real loss on every London
    // job, so this is deliberately not guessed.
    congestionPerVehiclePerDayMinor: 0,
    ulezPerVehiclePerDayMinor: 0,

    // Set monthly from fuel card data. Baseline means no uplift, and the line
    // still appears on the breakdown at ×1.00.
    fuelSurchargeRate: 0,

    vatRate: 0.2,

    depositPercentage: 0.25,
    depositMinimumMinor: 10_000,

    manualPricing: {
      declaredValueOverMinor: 1_000_000,
      volumeOverFt3: 2_500,
      distanceOverMiles: 400,
    },
  };
}
