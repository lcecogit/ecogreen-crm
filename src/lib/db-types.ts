/** Hand-written row types for what the UI reads today.
 *
 *  Replace with `supabase gen types typescript` output once a Supabase project
 *  exists — `npm run types:generate` is wired for it. Keeping these narrow and
 *  explicit in the meantime is deliberate: a wrong generated type is harder to
 *  notice than a missing one. */

export type LeadStatus =
  | "new" | "qualifying" | "quoted" | "chasing"
  | "booked" | "completed" | "reviewed" | "lost" | "duplicate";

export interface BrandRow {
  id: string;
  slug: string;
  code: string;
  name: string;
  accent_hex: string;
  accent_dark_hex: string;
  accent_text_hex: string | null;
  accent_text_dark_hex: string | null;
  accent_contrast_hex: string | null;
  brand_identity_confirmed: boolean;
}

export interface LeadRow {
  id: string;
  reference: string;
  brand_id: string;
  status: LeadStatus;
  score: number | null;
  move_date: string | null;
  origin_postcode: string | null;
  destination_postcode: string | null;
  created_at: string;
  customers: { first_name: string | null; last_name: string | null; email: string | null } | null;
  staff: { full_name: string } | null;
  services: { name: string } | null;
}

export interface StaffRow {
  id: string;
  full_name: string;
  email: string;
  department: string;
}
