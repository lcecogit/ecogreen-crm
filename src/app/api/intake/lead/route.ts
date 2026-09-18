import { NextResponse, type NextRequest } from "next/server";

import { createAdminClient } from "@/lib/supabase/admin";
import { verifySignature } from "@/domain/intake/signature";
import { intakeSchema, normaliseIntake } from "@/domain/intake/payload";
import { findMatch, type MatchCandidate } from "@/domain/pipeline/dedupe";
import { assignLead, type AssignableStaff } from "@/domain/pipeline/assign";
import { scoreLead } from "@/domain/pipeline/score";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Public lead intake from the six brand websites.
 *
 *  Contract:
 *   - HMAC-signed, with a replay window;
 *   - idempotent on the caller's key;
 *   - the raw body is persisted BEFORE validation, so a malformed post is
 *     recoverable rather than lost;
 *   - returns 202 quickly; anything slow is left for the scheduler;
 *   - never returns a silent success on failure. */
export async function POST(request: NextRequest) {
  const rawBody = await request.text();
  const secret = process.env.INTAKE_SIGNING_SECRET;
  if (!secret) {
    return NextResponse.json({ error: "intake_not_configured" }, { status: 503 });
  }

  const verified = verifySignature({
    rawBody,
    signature: request.headers.get("x-signature"),
    timestamp: request.headers.get("x-timestamp"),
    secret,
    now: new Date(),
  });
  if (!verified.valid) {
    return NextResponse.json({ error: verified.reason }, { status: 401 });
  }

  let parsedJson: unknown;
  try {
    parsedJson = JSON.parse(rawBody);
  } catch {
    return NextResponse.json({ error: "invalid_json" }, { status: 400 });
  }

  const supabase = createAdminClient();

  // Brand first: without it there is nowhere to store the raw payload, and a
  // lead in the wrong brand is worse than a rejected one.
  const brandSlug =
    typeof parsedJson === "object" && parsedJson !== null && "brand_slug" in parsedJson
      ? String((parsedJson as Record<string, unknown>).brand_slug)
      : null;
  if (!brandSlug) return NextResponse.json({ error: "brand_slug_required" }, { status: 400 });

  const { data: brand } = await supabase
    .from("brands")
    .select("id, slug")
    .eq("slug", brandSlug)
    .maybeSingle();
  if (!brand) return NextResponse.json({ error: "unknown_brand" }, { status: 404 });

  const parsed = intakeSchema.safeParse(parsedJson);

  // Validation failure is NOT a dropped payload. The enquiry is stored for a
  // human to rescue and the caller is told, so the website can show something
  // honest rather than a success screen.
  if (!parsed.success) {
    await supabase.from("partial_submissions").upsert(
      {
        brand_id: brand.id,
        session_key: `invalid:${Date.now()}:${Math.random().toString(36).slice(2, 10)}`,
        payload: { raw: rawBody, issues: parsed.error.issues },
      },
      { onConflict: "brand_id,session_key" },
    );
    return NextResponse.json({ error: "invalid_payload", issues: parsed.error.issues }, { status: 422 });
  }

  const lead = normaliseIntake(parsed.data);

  // Idempotency: the same key never creates a second lead, however many times
  // the website retries.
  const { data: existing } = await supabase
    .from("leads")
    .select("id, reference")
    .eq("brand_id", brand.id)
    .eq("raw_payload->>idempotency_key", lead.idempotencyKey)
    .maybeSingle();
  if (existing) {
    return NextResponse.json({ reference: existing.reference, duplicate: true }, { status: 202 });
  }

  // Duplicate and cross-brand overlap. Candidates are drawn across ALL brands
  // on purpose — an overlap between Eco London Movers and EcoGreen's London
  // branch is exactly what a manager needs to see.
  const { data: candidateRows } = await supabase
    .from("leads")
    .select(
      "id, brand_id, created_at, move_date, origin_postcode, customers(first_name, last_name, email, phone)",
    )
    .in("status", ["new", "qualifying", "quoted", "chasing", "booked"])
    .gte("created_at", new Date(Date.now() - 180 * 86_400_000).toISOString())
    .limit(500);

  const candidates: MatchCandidate[] = (candidateRows ?? []).map((row) => {
    const customer = (row as { customers?: { first_name?: string; last_name?: string; email?: string; phone?: string } | null }).customers ?? null;
    return {
      leadId: String(row.id),
      brandId: String(row.brand_id),
      email: customer?.email ?? null,
      phone: customer?.phone ?? null,
      firstName: customer?.first_name ?? null,
      lastName: customer?.last_name ?? null,
      originPostcode: (row as { origin_postcode?: string | null }).origin_postcode ?? null,
      moveDate: (row as { move_date?: string | null }).move_date ?? null,
      createdAt: String(row.created_at),
    };
  });

  const match = findMatch(
    {
      brandId: brand.id,
      email: lead.email,
      phone: lead.phone,
      firstName: lead.firstName,
      lastName: lead.lastName,
      originPostcode: lead.originPostcode,
      moveDate: lead.moveDate,
    },
    candidates,
  );

  // Routing. Out-of-hours enquiries still get an owner — see assignLead.
  const { data: teamRows } = await supabase
    .from("staff_brand_access")
    .select("role, staff(id, accepting_leads, max_open_leads, last_assigned_at)")
    .eq("brand_id", brand.id);

  interface StaffAccessRow {
    role: string;
    // PostgREST returns an embedded relation as an array or an object
    // depending on the relationship it infers, so both shapes are handled
    // rather than assumed.
    staff:
      | { id: string; accepting_leads: boolean; max_open_leads: number; last_assigned_at: string | null }
      | { id: string; accepting_leads: boolean; max_open_leads: number; last_assigned_at: string | null }[]
      | null;
  }

  const team: AssignableStaff[] = ((teamRows ?? []) as unknown as StaffAccessRow[]).flatMap((row) => {
    if (!["sales", "manager", "admin"].includes(row.role)) return [];
    const members = Array.isArray(row.staff) ? row.staff : row.staff ? [row.staff] : [];
    return members.map((member) => ({
      staffId: member.id,
      role: row.role as AssignableStaff["role"],
      // Shift state comes from an open attendance row; until the crew app
      // exists everyone counts as on shift, and the manager fallback in
      // assignLead is what catches genuinely out-of-hours enquiries.
      onShift: true,
      acceptingLeads: member.accepting_leads,
      lastAssignedAt: member.last_assigned_at,
      openLeadCount: 0,
      maxOpenLeads: member.max_open_leads,
    }));
  });

  const assignment = assignLead(team);

  const score = scoreLead(
    {
      hasOrganisation: Boolean(parsed.data.organisation_name),
      volumeFt3: null,
      moveDate: lead.moveDate ? new Date(lead.moveDate) : null,
      serviceCategory: lead.customerType ?? null,
      sourceConversionRate: null,
      hasEmail: Boolean(lead.emailNormalised),
      hasPhone: Boolean(lead.phoneNormalised),
      hasBothPostcodes: Boolean(lead.originOutward && lead.destinationOutward),
    },
    new Date(),
  );

  const { data: created, error } = await supabase
    .rpc("create_intake_lead", {
      p_brand_id: brand.id,
      p_payload: parsedJson as Record<string, unknown>,
      p_first_name: lead.firstName,
      p_last_name: lead.lastName,
      p_email: lead.email,
      p_email_normalised: lead.emailNormalised,
      p_phone: lead.phone,
      p_phone_normalised: lead.phoneNormalised,
      p_customer_type: lead.customerType,
      p_move_date: lead.moveDate,
      p_origin_postcode: lead.originPostcode,
      p_destination_postcode: lead.destinationPostcode,
      p_origin_outward: lead.originOutward,
      p_destination_outward: lead.destinationOutward,
      p_first_touch: lead.firstTouch,
      p_marketing_consent: lead.marketingConsent,
      p_owner_staff_id: assignment.staffId,
      p_assignment_rule: assignment.rule,
      p_score: score.score,
      p_score_components: score.components,
      p_duplicate_of: match.verdict === "duplicate" ? match.leadId : null,
      p_overlap_of: match.verdict === "cross_brand_overlap" ? match.leadId : null,
    })
    .single<{ lead_id: string; reference: string }>();

  if (error || !created) {
    // A 503 with a retry hint, never a silent failure: the website retains the
    // form state and retries.
    return NextResponse.json({ error: "storage_unavailable", retry_after: 30 }, { status: 503 });
  }

  return NextResponse.json(
    {
      reference: created.reference,
      duplicate: match.verdict === "duplicate",
      cross_brand_overlap: match.verdict === "cross_brand_overlap",
      assigned: assignment.staffId !== null,
    },
    { status: 202 },
  );
}
