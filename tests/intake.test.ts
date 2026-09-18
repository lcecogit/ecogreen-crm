import assert from "node:assert/strict";
import { test } from "node:test";

import { REPLAY_WINDOW_SECONDS, sign, verifySignature } from "../src/domain/intake/signature";
import { intakeSchema, normaliseIntake } from "../src/domain/intake/payload";

const SECRET = "test-secret";
const NOW = new Date("2026-03-02T10:00:00Z");
const stamp = String(Math.floor(NOW.getTime() / 1000));

function verify(over: Partial<Parameters<typeof verifySignature>[0]> = {}) {
  const rawBody = over.rawBody ?? '{"brand_slug":"ecogreen-movers"}';
  return verifySignature({
    rawBody,
    timestamp: stamp,
    signature: sign(rawBody, stamp, SECRET),
    secret: SECRET,
    now: NOW,
    ...over,
  });
}

test("a correctly signed request is accepted", () => {
  assert.deepEqual(verify(), { valid: true });
});

test("a tampered body is rejected", () => {
  const body = '{"brand_slug":"ecogreen-movers"}';
  const result = verifySignature({
    rawBody: '{"brand_slug":"glasgow-moving"}',
    timestamp: stamp,
    signature: sign(body, stamp, SECRET),
    secret: SECRET,
    now: NOW,
  });
  assert.deepEqual(result, { valid: false, reason: "bad_signature" });
});

test("the wrong secret is rejected", () => {
  assert.equal(verify({ secret: "other-secret" }).valid, false);
});

test("a missing signature or timestamp is rejected, each distinctly", () => {
  assert.deepEqual(verify({ signature: null }), { valid: false, reason: "missing_signature" });
  assert.deepEqual(verify({ timestamp: null }), { valid: false, reason: "missing_timestamp" });
  assert.deepEqual(verify({ timestamp: "not-a-number" }), { valid: false, reason: "missing_timestamp" });
});

test("a captured request cannot be replayed indefinitely", () => {
  const body = '{"brand_slug":"ecogreen-movers"}';
  const old = String(Math.floor(NOW.getTime() / 1000) - REPLAY_WINDOW_SECONDS - 1);
  const result = verifySignature({
    rawBody: body,
    timestamp: old,
    signature: sign(body, old, SECRET),
    secret: SECRET,
    now: NOW,
  });
  assert.deepEqual(result, { valid: false, reason: "stale_timestamp" });
});

test("a signature of the wrong length fails as a bad signature, not a crash", () => {
  // timingSafeEqual throws on a length mismatch; a crash here would be a 500
  // on a public endpoint and would leak the expected length.
  assert.deepEqual(verify({ signature: "abc" }), { valid: false, reason: "bad_signature" });
});

test("a clock a little ahead is still accepted", () => {
  const skewed = new Date(NOW.getTime() - 60_000);
  assert.equal(verify({ now: skewed }).valid, true);
});

test("the payload schema requires only a brand and an idempotency key", () => {
  const result = intakeSchema.safeParse({
    brand_slug: "ecogreen-movers",
    idempotency_key: "web-12345678",
  });
  assert.equal(result.success, true);
});

test("unknown fields are preserved rather than stripped", () => {
  const result = intakeSchema.parse({
    brand_slug: "ecogreen-movers",
    idempotency_key: "web-12345678",
    how_did_you_hear: "a neighbour",
  });
  assert.equal((result as Record<string, unknown>).how_did_you_hear, "a neighbour");
});

test("normalisation produces the matching keys the duplicate detector needs", () => {
  const lead = normaliseIntake(
    intakeSchema.parse({
      brand_slug: "ecogreen-movers",
      idempotency_key: "web-12345678",
      first_name: "  Jo ",
      email: " JO@Example.COM ",
      phone: "07700 900123",
      origin_postcode: "sw1a 1aa",
      move_date: "2026-06-06",
      utm: { utm_source: "google", utm_medium: "cpc" },
      referrer: "https://example.com/",
    }),
  );

  assert.equal(lead.firstName, "Jo");
  assert.equal(lead.emailNormalised, "jo@example.com");
  assert.equal(lead.phoneNormalised, "+447700900123");
  assert.equal(lead.originOutward, "SW1A");
  assert.equal(lead.moveDate, "2026-06-06");
  assert.equal(lead.firstTouch.utm_source, "google");
  assert.equal(lead.firstTouch.referrer, "https://example.com/");
});

test("an unparseable move date is left null rather than guessed", () => {
  const lead = normaliseIntake(
    intakeSchema.parse({
      brand_slug: "ecogreen-movers",
      idempotency_key: "web-12345678",
      move_date: "next Tuesday",
    }),
  );
  // The original string survives in raw_payload for a human to read.
  assert.equal(lead.moveDate, null);
});

test("marketing consent defaults to false, never to true", () => {
  const lead = normaliseIntake(
    intakeSchema.parse({ brand_slug: "ecogreen-movers", idempotency_key: "web-12345678" }),
  );
  assert.equal(lead.marketingConsent, false);
});
