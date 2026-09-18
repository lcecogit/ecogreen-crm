import type { CurrencyCode, Money } from "../money";
import type { HandlingClass } from "../inventory/catalogue";

export type ServiceCategory =
  | "residential"
  | "commercial"
  | "office"
  | "specialist"
  | "clearance"
  | "storage";

export type PackingService = "none" | "materials_only" | "part" | "full";

export interface AccessDetails {
  /** Floors above ground with no usable lift. Ground floor is 0. */
  readonly floorsWithoutLift: number;
  /** Metres from the nearest parking to the door. */
  readonly carryDistanceM: number;
}

export interface QuoteInput {
  readonly serviceCategory: ServiceCategory;
  readonly moveDate: Date;
  readonly volumeFt3: number;
  readonly crewMinutes: number;
  readonly crewSize: number;
  readonly roadDistanceMiles: number;
  readonly origin: AccessDetails;
  readonly destination: AccessDetails;
  readonly packing: PackingService;
  readonly materials: readonly { readonly slug: string; readonly quantity: number }[];
  readonly handlingClasses: readonly HandlingClass[];
  readonly declaredValueMinor?: number;
  readonly isInternational?: boolean;
  readonly isMultiDay?: boolean;
  readonly congestionZoneDays?: number;
  readonly ulezDays?: number;
  readonly vehicleCount?: number;
  readonly promoCode?: PromoCode;
}

export interface PromoCode {
  readonly code: string;
  readonly kind: "percentage" | "fixed";
  /** Percentage as a fraction (0.1 = 10%), or minor units for `fixed`. */
  readonly value: number;
}

export interface VolumeBand {
  /** Upper bound of the band in ft³, or null for the final open band. */
  readonly upToFt3: number | null;
  readonly perFt3Minor: number;
}

export interface RateCard {
  readonly id: string;
  readonly brandSlug: string;
  readonly serviceCategory: ServiceCategory;
  readonly currency: CurrencyCode;
  readonly effectiveFrom: string;
  /** True until the business signs the numbers off. Drives the PROVISIONAL
   *  PRICING watermark on the quote PDF — see DECISIONS.md §2. */
  readonly provisional: boolean;
  readonly minimumChargeMinor: number;
  readonly volumeBands: readonly VolumeBand[];
  readonly includedMiles: number;
  readonly perMileMinor: number;
  readonly includedMovers: number;
  readonly additionalMoverPerHourMinor: number;
  readonly perFloorWithoutLiftMinor: number;
  readonly longCarryThresholdM: number;
  readonly longCarryMinor: number;
  readonly packingPerFt3Minor: Readonly<Record<PackingService, number>>;
  readonly materialUnitMinor: Readonly<Record<string, number>>;
  readonly weekendMultiplier: number;
  readonly bankHolidayMultiplier: number;
  readonly peakSeasonMultiplier: number;
  /** Calendar months (1-12) treated as peak. */
  readonly peakMonths: readonly number[];
  /** Month-end crunch: the last N and first M days of any month. */
  readonly peakMonthEndDays: number;
  readonly peakMonthStartDays: number;
  /** ISO dates (YYYY-MM-DD). Load from the gov.uk bank-holidays feed rather
   *  than maintaining by hand — see DECISIONS.md §2. */
  readonly bankHolidays: readonly string[];
  readonly congestionPerVehiclePerDayMinor: number;
  readonly ulezPerVehiclePerDayMinor: number;
  /** Fractional uplift on transport, set monthly from fuel card data. */
  readonly fuelSurchargeRate: number;
  readonly vatRate: number;
  readonly depositPercentage: number;
  readonly depositMinimumMinor: number;
  readonly manualPricing: {
    readonly declaredValueOverMinor: number;
    readonly volumeOverFt3: number;
    readonly distanceOverMiles: number;
  };
}

export type BreakdownKind =
  | "transport"
  | "labour"
  | "materials"
  | "surcharge"
  | "discount"
  | "storage";

/** Every line records the rule that produced it and the inputs it read. This
 *  is what makes a price explicable on screen, which is what stops margins
 *  drifting between salespeople. */
export interface BreakdownLine {
  readonly ruleId: string;
  readonly kind: BreakdownKind;
  readonly label: string;
  readonly detail: string;
  readonly inputs: Readonly<Record<string, number | string | boolean>>;
  readonly net: Money;
}

export type ManualPricingReason =
  | "specialist_handling"
  | "declared_value_above_threshold"
  | "international_leg"
  | "multi_day"
  | "volume_above_threshold"
  | "distance_above_threshold"
  | "no_inventory";

export interface ManualPricingRequired {
  readonly outcome: "requires_manual_pricing";
  readonly reasons: readonly ManualPricingReason[];
  readonly explanation: string;
}

export interface QuotePricing {
  readonly outcome: "priced";
  readonly rateCardId: string;
  readonly provisional: boolean;
  readonly currency: CurrencyCode;
  readonly lines: readonly BreakdownLine[];
  readonly net: Money;
  readonly vat: Money;
  readonly vatRate: number;
  readonly gross: Money;
  readonly deposit: Money;
  readonly balance: Money;
  readonly pricedAt: string;
}

export type PricingResult = QuotePricing | ManualPricingRequired;
