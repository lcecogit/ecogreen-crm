import { daysBetween } from "../clock";

/** Duplicate and cross-brand overlap detection.
 *
 *  Two distinct problems share one matcher:
 *   - same brand, same person → a genuine duplicate; do not create a second
 *     pipeline entry, or two salespeople chase one customer.
 *   - different brand, same person → an overlap, e.g. Eco London Movers and
 *     EcoGreen's London branch. Never merged automatically: which brand takes
 *     the job is a commercial decision for a manager, and silently discarding
 *     one side would hide it. */

export interface MatchCandidate {
  readonly leadId: string;
  readonly brandId: string;
  readonly email: string | null;
  readonly phone: string | null;
  readonly firstName: string | null;
  readonly lastName: string | null;
  readonly originPostcode: string | null;
  readonly moveDate: string | null;
  readonly createdAt: string;
}

export interface MatchSubject {
  readonly brandId: string;
  readonly email: string | null;
  readonly phone: string | null;
  readonly firstName: string | null;
  readonly lastName: string | null;
  readonly originPostcode: string | null;
  readonly moveDate: string | null;
}

export type MatchVerdict = "duplicate" | "cross_brand_overlap" | "no_match";

export interface MatchResult {
  readonly verdict: MatchVerdict;
  readonly leadId: string | null;
  readonly score: number;
  readonly signals: readonly string[];
}

export function normaliseEmail(value: string | null): string | null {
  if (!value) return null;
  const trimmed = value.trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

/** UK numbers to E.164-ish. Deliberately forgiving: `07700 900 123`,
 *  `+447700900123` and `447700900123` are the same person, and a lead lost to
 *  a space in a phone number is a lead lost. */
export function normalisePhone(value: string | null): string | null {
  if (!value) return null;
  const digits = value.replace(/[^\d+]/g, "");
  if (digits.length === 0) return null;
  let national = digits.startsWith("+") ? digits.slice(1) : digits;
  if (national.startsWith("00")) national = national.slice(2);
  if (national.startsWith("44")) national = national.slice(2);
  else if (national.startsWith("0")) national = national.slice(1);
  return national.length >= 9 ? `+44${national}` : null;
}

/** Outward code only — `SW1A 1AA` and `sw1a1aa` both give `SW1A`. Matching on
 *  the full postcode misses the common case of a mistyped inward code. */
export function outwardCode(value: string | null): string | null {
  if (!value) return null;
  const cleaned = value.toUpperCase().replace(/\s+/g, "");
  if (cleaned.length < 5) return cleaned.length > 0 ? cleaned : null;
  return cleaned.slice(0, cleaned.length - 3);
}

function nameKey(first: string | null, last: string | null): string | null {
  const joined = `${first ?? ""} ${last ?? ""}`.trim().toLowerCase().replace(/\s+/g, " ");
  return joined.length > 0 ? joined : null;
}

const STRONG_MATCH_SCORE = 60;

export function scoreMatch(subject: MatchSubject, candidate: MatchCandidate): {
  score: number;
  signals: string[];
} {
  const signals: string[] = [];
  let score = 0;

  const subjectEmail = normaliseEmail(subject.email);
  const candidateEmail = normaliseEmail(candidate.email);
  if (subjectEmail && candidateEmail && subjectEmail === candidateEmail) {
    score += 60;
    signals.push("email");
  }

  const subjectPhone = normalisePhone(subject.phone);
  const candidatePhone = normalisePhone(candidate.phone);
  if (subjectPhone && candidatePhone && subjectPhone === candidatePhone) {
    score += 60;
    signals.push("phone");
  }

  const subjectName = nameKey(subject.firstName, subject.lastName);
  const candidateName = nameKey(candidate.firstName, candidate.lastName);
  if (subjectName && candidateName && subjectName === candidateName) {
    score += 25;
    signals.push("name");
  }

  const subjectOutward = outwardCode(subject.originPostcode);
  const candidateOutward = outwardCode(candidate.originPostcode);
  if (subjectOutward && candidateOutward && subjectOutward === candidateOutward) {
    score += 15;
    signals.push("origin_area");
  }

  if (subject.moveDate && candidate.moveDate) {
    const gap = Math.abs(daysBetween(new Date(candidate.moveDate), new Date(subject.moveDate)));
    if (gap <= 3) {
      score += 15;
      signals.push("move_date");
    }
  }

  return { score, signals };
}

export function findMatch(
  subject: MatchSubject,
  candidates: readonly MatchCandidate[],
): MatchResult {
  let best: MatchResult = { verdict: "no_match", leadId: null, score: 0, signals: [] };

  for (const candidate of candidates) {
    const { score, signals } = scoreMatch(subject, candidate);
    if (score < STRONG_MATCH_SCORE || score <= best.score) continue;
    best = {
      verdict: candidate.brandId === subject.brandId ? "duplicate" : "cross_brand_overlap",
      leadId: candidate.leadId,
      score,
      signals,
    };
  }

  return best;
}
