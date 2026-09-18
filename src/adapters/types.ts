/** Provider interfaces.
 *
 *  Nothing in src/domain or the route handlers imports a vendor SDK. Each
 *  concern has one interface and a stub that completes the whole flow with no
 *  credentials, so the build never blocks on procurement and the workflow is
 *  usable — by hand where it has to be — from day one.
 *
 *  Swapping a stub for the real thing is one env var. See DECISIONS.md §3. */

export interface PaymentLink {
  readonly provider: string;
  readonly providerReference: string;
  readonly url: string;
  readonly amountMinor: number;
  readonly currency: string;
  readonly expiresAt: string | null;
}

export interface PaymentProvider {
  readonly name: string;
  readonly isStub: boolean;
  createPaymentLink(input: {
    quoteId: string;
    reference: string;
    amountMinor: number;
    currency: string;
    description: string;
    successUrl: string;
  }): Promise<PaymentLink>;
  /** Verifies the signature and returns the event, or throws. Never trust
   *  amounts from the body over the stored quote total. */
  parseWebhook(rawBody: string, signature: string | null): Promise<{
    eventId: string;
    type: string;
    providerReference: string | null;
    amountMinor: number | null;
    currency: string | null;
  }>;
}

export interface EmailMessage {
  readonly to: string;
  readonly from: string;
  readonly replyTo?: string;
  readonly subject: string;
  readonly html: string;
  readonly text: string;
}

export interface EmailProvider {
  readonly name: string;
  readonly isStub: boolean;
  send(message: EmailMessage): Promise<{ providerMessageId: string }>;
}

export interface MessagingProvider {
  readonly name: string;
  readonly channel: "sms" | "whatsapp";
  readonly isStub: boolean;
  /** A stub returns `queuedForManualSend`, which is not a failure: the message
   *  is drafted and a human sends it. That is the intended workflow for the
   *  weeks WhatsApp Business verification takes. */
  send(input: { to: string; body: string; templateKey: string }): Promise<
    { providerMessageId: string; queuedForManualSend: false } | { queuedForManualSend: true }
  >;
}

export interface PdfRenderer {
  readonly name: string;
  readonly isStub: boolean;
  render(input: { documentType: string; reference: string; html: string }): Promise<{
    bytes: Uint8Array;
    contentType: string;
  }>;
}

export interface GeoProvider {
  readonly name: string;
  readonly isStub: boolean;
  roadDistanceMiles(origin: string, destination: string): Promise<number | null>;
}
