import { daysBetween } from "../clock";
import type { ServiceCategory } from "../pricing/types";

/** Lead scoring, 0-100.
 *
 *  No model, no black box. A salesperson looking at a score of 78 must be able
 *  to read why, so every weight is named, bounded and explained, and the
 *  function returns its own reasoning. Weights are the one thing here that
 *  should be tuned from real conversion data after a few months — the shape
 *  should not. */

export const SCORE_WEIGHTS = {
  /** Corporate and public-sector work is worth more and closes more reliably. */
  organisation: 20,
  /** Bigger jobs justify more chasing effort. */
  volume: 25,
  /** Urgency converts: a move three weeks out is a live decision. */
  urgency: 20,
  /** Some services are structurally higher value. */
  serviceCategory: 15,
  /** How well the source has converted historically. */
  sourceQuality: 15,
  /** A complete enquiry signals a serious enquirer. */
  completeness: 5,
} as const;

export interface ScoreInput {
  readonly hasOrganisation: boolean;
  readonly volumeFt3: number | null;
  readonly moveDate: Date | null;
  readonly serviceCategory: ServiceCategory | null;
  /** Historical booked ÷ received for this source, 0-1. Null when unknown. */
  readonly sourceConversionRate: number | null;
  readonly hasEmail: boolean;
  readonly hasPhone: boolean;
  readonly hasBothPostcodes: boolean;
}

export interface ScoreComponent {
  readonly key: keyof typeof SCORE_WEIGHTS;
  readonly points: number;
  readonly outOf: number;
  readonly reason: string;
}

export interface ScoreResult {
  readonly score: number;
  readonly band: "cold" | "warm" | "hot";
  readonly components: readonly ScoreComponent[];
}

const SERVICE_VALUE: Record<ServiceCategory, number> = {
  office: 1,
  commercial: 0.9,
  specialist: 0.8,
  storage: 0.6,
  residential: 0.5,
  clearance: 0.4,
};

export function scoreLead(input: ScoreInput, now: Date): ScoreResult {
  const components: ScoreComponent[] = [];

  components.push({
    key: "organisation",
    points: input.hasOrganisation ? SCORE_WEIGHTS.organisation : 0,
    outOf: SCORE_WEIGHTS.organisation,
    reason: input.hasOrganisation ? "Business account" : "Private customer",
  });

  // Saturates at 1200 ft³ — roughly a four-bedroom house. Beyond that the job
  // is already worth full attention and extra volume adds no signal.
  const volumeFraction = input.volumeFt3 === null ? 0 : Math.min(1, input.volumeFt3 / 1200);
  components.push({
    key: "volume",
    points: Math.round(SCORE_WEIGHTS.volume * volumeFraction),
    outOf: SCORE_WEIGHTS.volume,
    reason:
      input.volumeFt3 === null
        ? "No inventory yet"
        : `${input.volumeFt3.toLocaleString("en-GB")} ft³ declared`,
  });

  let urgencyFraction = 0;
  let urgencyReason = "No move date given";
  if (input.moveDate) {
    const days = daysBetween(now, input.moveDate);
    if (days < 0) {
      urgencyFraction = 0;
      urgencyReason = "Move date has passed";
    } else if (days <= 7) {
      urgencyFraction = 1;
      urgencyReason = `Moving in ${days} day(s)`;
    } else if (days <= 28) {
      urgencyFraction = 0.8;
      urgencyReason = `Moving in ${days} days`;
    } else if (days <= 90) {
      urgencyFraction = 0.5;
      urgencyReason = `Moving in ${days} days`;
    } else {
      urgencyFraction = 0.2;
      urgencyReason = "Moving in over three months";
    }
  }
  components.push({
    key: "urgency",
    points: Math.round(SCORE_WEIGHTS.urgency * urgencyFraction),
    outOf: SCORE_WEIGHTS.urgency,
    reason: urgencyReason,
  });

  const serviceFraction = input.serviceCategory ? SERVICE_VALUE[input.serviceCategory] : 0;
  components.push({
    key: "serviceCategory",
    points: Math.round(SCORE_WEIGHTS.serviceCategory * serviceFraction),
    outOf: SCORE_WEIGHTS.serviceCategory,
    reason: input.serviceCategory ? `${input.serviceCategory} enquiry` : "Service not identified",
  });

  // An unknown source scores mid rather than zero: a new lead provider should
  // not be starved of attention before it has had a chance to convert.
  const sourceFraction = input.sourceConversionRate ?? 0.5;
  components.push({
    key: "sourceQuality",
    points: Math.round(SCORE_WEIGHTS.sourceQuality * Math.min(1, Math.max(0, sourceFraction))),
    outOf: SCORE_WEIGHTS.sourceQuality,
    reason:
      input.sourceConversionRate === null
        ? "New source, no history yet"
        : `Source converts at ${(input.sourceConversionRate * 100).toFixed(0)}%`,
  });

  const completenessSignals = [input.hasEmail, input.hasPhone, input.hasBothPostcodes];
  const completeCount = completenessSignals.filter(Boolean).length;
  components.push({
    key: "completeness",
    points: Math.round((SCORE_WEIGHTS.completeness * completeCount) / completenessSignals.length),
    outOf: SCORE_WEIGHTS.completeness,
    reason: `${completeCount} of ${completenessSignals.length} contact details supplied`,
  });

  const score = Math.min(100, components.reduce((total, part) => total + part.points, 0));
  return {
    score,
    band: score >= 70 ? "hot" : score >= 40 ? "warm" : "cold",
    components,
  };
}
