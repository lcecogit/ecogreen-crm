import { z } from "zod";

import { normaliseEmail, normalisePhone, outwardCode } from "../pipeline/dedupe";

/** Lead intake payload.
 *
 *  Deliberately forgiving. Everything except the brand and an idempotency key
 *  is optional, and unknown fields are preserved rather than stripped: the
 *  route stores the raw body BEFORE this schema runs, so a malformed
 *  submission from a brand site is recoverable instead of lost. Dropping a
 *  payload because it failed a schema check is the "integration timeouts /
 *  abandoned forms" problem in the brief, and it is worse than a messy row. */

export const intakeSchema = z
  .object({
    brand_slug: z.string().min(1),
    idempotency_key: z.string().min(8).max(200),
    first_name: z.string().max(100).optional(),
    last_name: z.string().max(100).optional(),
    email: z.string().max(320).optional(),
    phone: z.string().max(40).optional(),
    customer_type: z
      .enum(["residential", "commercial", "office", "specialist", "clearance", "storage"])
      .optional(),
    service_slug: z.string().max(100).optional(),
    move_date: z.string().max(40).optional(),
    move_date_flexible: z.boolean().optional(),
    origin_postcode: z.string().max(12).optional(),
    destination_postcode: z.string().max(12).optional(),
    message: z.string().max(5000).optional(),
    source_name: z.string().max(120).optional(),
    utm: z.record(z.string()).optional(),
    referrer: z.string().max(500).optional(),
    landing_page: z.string().max(500).optional(),
    organisation_name: z.string().max(200).optional(),
    marketing_consent: z.boolean().optional(),
  })
  .passthrough();

export type IntakePayload = z.infer<typeof intakeSchema>;

export interface NormalisedLead {
  readonly brandSlug: string;
  readonly idempotencyKey: string;
  readonly firstName: string | null;
  readonly lastName: string | null;
  readonly email: string | null;
  readonly emailNormalised: string | null;
  readonly phone: string | null;
  readonly phoneNormalised: string | null;
  readonly customerType: IntakePayload["customer_type"] | null;
  readonly serviceSlug: string | null;
  readonly moveDate: string | null;
  readonly moveDateFlexible: boolean;
  readonly originPostcode: string | null;
  readonly destinationPostcode: string | null;
  readonly originOutward: string | null;
  readonly destinationOutward: string | null;
  readonly marketingConsent: boolean;
  readonly firstTouch: Record<string, string>;
}

/** ISO date only. A move date the customer typed as "next Tuesday" is kept in
 *  the raw payload for a human, not guessed at here. */
function isoDate(value: string | undefined): string | null {
  if (!value) return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value.trim());
  if (!match) return null;
  const date = new Date(`${match[1]}-${match[2]}-${match[3]}T00:00:00Z`);
  return Number.isNaN(date.getTime()) ? null : `${match[1]}-${match[2]}-${match[3]}`;
}

export function normaliseIntake(payload: IntakePayload): NormalisedLead {
  const touch: Record<string, string> = {};
  for (const [key, value] of Object.entries(payload.utm ?? {})) touch[key] = value;
  if (payload.referrer) touch.referrer = payload.referrer;
  if (payload.landing_page) touch.landing_page = payload.landing_page;
  if (payload.source_name) touch.source_name = payload.source_name;

  return {
    brandSlug: payload.brand_slug,
    idempotencyKey: payload.idempotency_key,
    firstName: payload.first_name?.trim() || null,
    lastName: payload.last_name?.trim() || null,
    email: payload.email?.trim() || null,
    emailNormalised: normaliseEmail(payload.email ?? null),
    phone: payload.phone?.trim() || null,
    phoneNormalised: normalisePhone(payload.phone ?? null),
    customerType: payload.customer_type ?? null,
    serviceSlug: payload.service_slug ?? null,
    moveDate: isoDate(payload.move_date),
    moveDateFlexible: payload.move_date_flexible ?? false,
    originPostcode: payload.origin_postcode?.toUpperCase().trim() || null,
    destinationPostcode: payload.destination_postcode?.toUpperCase().trim() || null,
    originOutward: outwardCode(payload.origin_postcode ?? null),
    destinationOutward: outwardCode(payload.destination_postcode ?? null),
    marketingConsent: payload.marketing_consent ?? false,
    firstTouch: touch,
  };
}
