import { createHash } from "node:crypto";

import type { PaymentProvider } from "../types";

/** Produces a local link that an accounts user marks paid by hand — the same
 *  path a bank transfer takes in Phase 1. The whole quote-to-booking flow runs
 *  end to end with no Stripe account. */
export const stubPaymentProvider: PaymentProvider = {
  name: "stub",
  isStub: true,
  async createPaymentLink(input) {
    const reference = `stub_${createHash("sha256").update(`${input.quoteId}:${input.amountMinor}`).digest("hex").slice(0, 24)}`;
    return {
      provider: "stub",
      providerReference: reference,
      url: `/payments/stub/${reference}`,
      amountMinor: input.amountMinor,
      currency: input.currency,
      expiresAt: null,
    };
  },
  async parseWebhook(rawBody) {
    const parsed: unknown = JSON.parse(rawBody);
    const event = parsed as Record<string, unknown>;
    const id = typeof event.id === "string" ? event.id : null;
    if (!id) throw new Error("Webhook payload has no event id");
    return {
      eventId: id,
      type: typeof event.type === "string" ? event.type : "unknown",
      providerReference: typeof event.reference === "string" ? event.reference : null,
      amountMinor: typeof event.amount_minor === "number" ? event.amount_minor : null,
      currency: typeof event.currency === "string" ? event.currency : null,
    };
  },
};

export function getPaymentProvider(): PaymentProvider {
  if (!process.env.STRIPE_SECRET_KEY) return stubPaymentProvider;
  return stubPaymentProvider;
}
