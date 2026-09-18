import { createHmac, timingSafeEqual } from "node:crypto";

/** HMAC verification for lead posts from the six brand websites.
 *
 *  Pure and separately testable, because this is the only thing standing
 *  between a public endpoint and the pipeline. Two properties matter and both
 *  are easy to get wrong:
 *
 *   - a constant-time compare, so the signature cannot be discovered a byte at
 *     a time;
 *   - a timestamp window, so a captured request cannot be replayed forever. */

export const REPLAY_WINDOW_SECONDS = 300;

export type VerifyResult =
  | { valid: true }
  | { valid: false; reason: "missing_signature" | "missing_timestamp" | "stale_timestamp" | "bad_signature" };

export function sign(rawBody: string, timestamp: string, secret: string): string {
  return createHmac("sha256", secret).update(`${timestamp}.${rawBody}`).digest("hex");
}

export function verifySignature(input: {
  rawBody: string;
  signature: string | null;
  timestamp: string | null;
  secret: string;
  now: Date;
}): VerifyResult {
  if (!input.signature) return { valid: false, reason: "missing_signature" };
  if (!input.timestamp) return { valid: false, reason: "missing_timestamp" };

  const sent = Number(input.timestamp);
  if (!Number.isFinite(sent)) return { valid: false, reason: "missing_timestamp" };

  const ageSeconds = Math.abs(input.now.getTime() / 1000 - sent);
  if (ageSeconds > REPLAY_WINDOW_SECONDS) return { valid: false, reason: "stale_timestamp" };

  const expected = sign(input.rawBody, input.timestamp, input.secret);
  const a = Buffer.from(expected, "utf8");
  const b = Buffer.from(input.signature, "utf8");
  // timingSafeEqual throws on a length mismatch, which would itself leak the
  // expected length, so the lengths are compared first and both paths return
  // the same reason.
  if (a.length !== b.length) return { valid: false, reason: "bad_signature" };
  return timingSafeEqual(a, b) ? { valid: true } : { valid: false, reason: "bad_signature" };
}
