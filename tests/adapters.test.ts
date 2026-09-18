import assert from "node:assert/strict";
import { test } from "node:test";

import { stubEmailProvider } from "../src/adapters/email";
import { stubPaymentProvider } from "../src/adapters/payments";
import { stubWhatsAppProvider, stubSmsProvider, availableChannels } from "../src/adapters/messaging";
import { stubGeoProvider } from "../src/adapters/geo";

/** Contract tests. Every adapter — stub or real — must satisfy these, so
 *  swapping a provider in cannot change the shape of what the domain sees. */

test("the email stub returns an id and never throws", async () => {
  const result = await stubEmailProvider.send({
    to: "jo@example.com",
    from: "quotes@example.com",
    subject: "Your quote",
    html: "<p>Hello</p>",
    text: "Hello",
  });
  assert.ok(result.providerMessageId.length > 0);
});

test("messaging stubs queue for a human rather than failing", async () => {
  for (const provider of [stubWhatsAppProvider, stubSmsProvider]) {
    const result = await provider.send({ to: "+447700900123", body: "Hi", templateKey: "quote_chase_2" });
    assert.equal(result.queuedForManualSend, true);
  }
});

test("email is always an available channel; the rest depend on credentials", () => {
  const channels = availableChannels();
  assert.ok(channels.includes("email"));
  assert.equal(channels.includes("whatsapp"), Boolean(process.env.WHATSAPP_ACCESS_TOKEN));
});

test("the payment stub produces a deterministic reference for the same quote", async () => {
  const input = {
    quoteId: "quote-1",
    reference: "EGM-2609-0001",
    amountMinor: 12_000,
    currency: "GBP",
    description: "Deposit",
    successUrl: "/done",
  };
  const a = await stubPaymentProvider.createPaymentLink(input);
  const b = await stubPaymentProvider.createPaymentLink(input);
  assert.equal(a.providerReference, b.providerReference);
  assert.equal(a.amountMinor, 12_000);
});

test("a different amount produces a different payment reference", async () => {
  const base = { quoteId: "quote-1", reference: "EGM-2609-0001", currency: "GBP", description: "Deposit", successUrl: "/done" };
  const a = await stubPaymentProvider.createPaymentLink({ ...base, amountMinor: 12_000 });
  const b = await stubPaymentProvider.createPaymentLink({ ...base, amountMinor: 24_000 });
  assert.notEqual(a.providerReference, b.providerReference);
});

test("webhook parsing rejects a payload with no event id", async () => {
  await assert.rejects(() => stubPaymentProvider.parseWebhook('{"type":"payment"}', null));
  const parsed = await stubPaymentProvider.parseWebhook(
    '{"id":"evt_1","type":"payment.succeeded","reference":"stub_abc","amount_minor":12000,"currency":"GBP"}',
    null,
  );
  assert.equal(parsed.eventId, "evt_1");
  assert.equal(parsed.amountMinor, 12_000);
});

test("the geo stub returns null for an unknown area rather than a wrong number", async () => {
  assert.equal(await stubGeoProvider.roadDistanceMiles("ZZ99", "SW1A"), null);
});

test("the geo stub is symmetric and non-zero between real areas", async () => {
  const there = await stubGeoProvider.roadDistanceMiles("SW1A 1AA", "M1 1AE");
  const back = await stubGeoProvider.roadDistanceMiles("M1 1AE", "SW1A 1AA");
  assert.ok(there && there > 100, `expected a London-Manchester distance, got ${there}`);
  assert.equal(there, back);
});

test("every stub declares itself a stub, so the UI can say so", () => {
  for (const provider of [stubEmailProvider, stubPaymentProvider, stubWhatsAppProvider, stubGeoProvider]) {
    assert.equal(provider.isStub, true);
  }
});
