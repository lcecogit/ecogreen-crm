/** Realistic sample data for when no Supabase project is configured.
 *
 *  A CRM that opens as an empty shell shows nothing. These rows let every
 *  screen open in a working state so the design can be reviewed, the layout
 *  tested against realistic value lengths, and the whole thing demonstrated
 *  without provisioning anything.
 *
 *  It is always labelled as sample data in the UI. Numbers here are never
 *  presented as the business's own, and the money figures are deliberately
 *  ordinary rather than flattering. */

export const isSampleMode = !process.env.NEXT_PUBLIC_SUPABASE_URL;

export interface SampleLead {
  id: string;
  reference: string;
  brand: string;
  customer: string;
  organisation: string | null;
  service: string;
  origin: string;
  destination: string;
  moveDate: string | null;
  status: "new" | "qualifying" | "quoted" | "chasing" | "booked" | "completed" | "lost";
  owner: string | null;
  score: number;
  valueMinor: number | null;
  createdAt: string;
  source: string;
}

const now = Date.parse("2026-09-17T09:00:00Z");
const hoursAgo = (h: number) => new Date(now - h * 3_600_000).toISOString();

export const sampleLeads: SampleLead[] = [
  { id: "l1", reference: "EGM-2609-0412", brand: "EcoGreen Movers", customer: "Jo Bloggs", organisation: null, service: "Residential moves", origin: "M1 1AE", destination: "EH1 1AA", moveDate: "2026-10-04", status: "chasing", owner: "Hania", score: 82, valueMinor: 148_000, createdAt: hoursAgo(54), source: "Website enquiry form" },
  { id: "l2", reference: "EGM-2609-0411", brand: "EcoGreen Movers", customer: "Priya Raghunathan", organisation: "Northgate Property Partners", service: "Office removals", origin: "M2 3WQ", destination: "M15 4FN", moveDate: "2026-10-19", status: "quoted", owner: "Adara", score: 91, valueMinor: 1_240_000, createdAt: hoursAgo(26), source: "Referral" },
  { id: "l3", reference: "ELM-2609-0088", brand: "Eco London Movers", customer: "Sam Patel", organisation: null, service: "Residential moves", origin: "SW1A 1AA", destination: "SE1 9SG", moveDate: "2026-10-02", status: "booked", owner: "Hania", score: 74, valueMinor: 72_000, createdAt: hoursAgo(96), source: "Google Ads" },
  { id: "l4", reference: "EDM-2609-0031", brand: "Edinburgh Moving", customer: "Rhona Stewart", organisation: null, service: "Storage & packing", origin: "EH3 9DR", destination: "EH12 5EZ", moveDate: null, status: "new", owner: null, score: 38, valueMinor: null, createdAt: hoursAgo(1), source: "WhatsApp" },
  { id: "l5", reference: "EGM-2609-0410", brand: "EcoGreen Movers", customer: "Dr Alan Whitfield", organisation: "Clyde Valley NHS Trust", service: "Specialist relocations", origin: "G4 0SF", destination: "G51 4TF", moveDate: "2026-11-02", status: "qualifying", owner: "H", score: 88, valueMinor: null, createdAt: hoursAgo(7), source: "Inbound call" },
  { id: "l6", reference: "RCM-2609-0204", brand: "Removals Company Manchester", customer: "Leah Okoro", organisation: null, service: "Residential moves", origin: "M20 2RN", destination: "M33 6TA", moveDate: "2026-09-27", status: "quoted", owner: "Adara", score: 66, valueMinor: 54_000, createdAt: hoursAgo(72), source: "Google organic" },
  { id: "l7", reference: "GM-2609-0017", brand: "Glasgow Moving", customer: "Craig Sutherland", organisation: null, service: "Residential moves", origin: "G12 8QQ", destination: "G1 1AA", moveDate: "2026-10-11", status: "new", owner: null, score: 51, valueMinor: null, createdAt: hoursAgo(3), source: "Website enquiry form" },
  { id: "l8", reference: "EGM-2609-0409", brand: "EcoGreen Movers", customer: "Bethan Price", organisation: "Halliwell Chambers", service: "Commercial relocation", origin: "L1 8JQ", destination: "M1 4BT", moveDate: "2026-10-30", status: "chasing", owner: "Hania", score: 79, valueMinor: 486_000, createdAt: hoursAgo(120), source: "Lead provider" },
  { id: "l9", reference: "EGM-2609-0408", brand: "EcoGreen Movers", customer: "Tomasz Nowak", organisation: null, service: "Residential moves", origin: "EH7 5QY", destination: "NE1 7RU", moveDate: "2026-09-24", status: "booked", owner: "Adara", score: 70, valueMinor: 96_500, createdAt: hoursAgo(168), source: "Repeat customer" },
  { id: "l10", reference: "EGM-2609-0405", brand: "EcoGreen Movers", customer: "Marta Silva", organisation: null, service: "Residential moves", origin: "M4 1HN", destination: "M4 1HN", moveDate: "2026-09-20", status: "lost", owner: "Hania", score: 44, valueMinor: null, createdAt: hoursAgo(240), source: "Google Ads" },
];

export const sampleTimeline = [
  { at: hoursAgo(54), type: "created", actor: null, detail: "Enquiry received from the website form · routed to Hania" },
  { at: hoursAgo(53), type: "message", actor: "System", detail: "Acknowledgement email sent" },
  { at: hoursAgo(50), type: "note", actor: "Hania", detail: "Called — third floor, no lift at the Manchester end. One upright piano, confirmed." },
  { at: hoursAgo(49), type: "status", actor: "Hania", detail: "Moved to qualifying" },
  { at: hoursAgo(48), type: "quote", actor: "Hania", detail: "Quote EGM-2609-0412 v1 sent · £1,480.00" },
  { at: hoursAgo(46), type: "view", actor: "Customer", detail: "Quote opened" },
  { at: hoursAgo(2), type: "sequence", actor: "System", detail: "48-hour chase sent · quote viewed but not accepted" },
] as const;

export const sampleQuoteLines = [
  { rule: "transport.volume", label: "Volume", detail: "830 ft³, banded", netMinor: 60_650 },
  { rule: "transport.distance", label: "Distance", detail: "196 chargeable miles beyond the 20 included", netMinor: 35_280 },
  { rule: "labour.additional_movers", label: "Additional crew", detail: "1 mover beyond the 2 included, 6.5 h", netMinor: 18_200 },
  { rule: "access.floors", label: "Stairs", detail: "3 floors without a lift across both addresses", netMinor: 7_500 },
  { rule: "access.long_carry", label: "Long carry", detail: "Parking within 25 m at both addresses", netMinor: 0 },
  { rule: "packing.service", label: "Packing", detail: "Part packing — fragile items only", netMinor: 29_050 },
  { rule: "materials.supply", label: "Packing materials", detail: "34 items", netMinor: 9_800 },
  { rule: "surcharge.weekend", label: "Weekend", detail: "Weekday move — no uplift", netMinor: 0 },
  { rule: "surcharge.peak_season", label: "Peak period", detail: "Off-peak — no uplift", netMinor: 0 },
  { rule: "surcharge.fuel", label: "Fuel surcharge", detail: "Fuel index at baseline — no uplift", netMinor: 0 },
  { rule: "minimum.charge", label: "Minimum charge", detail: "Above the £180.00 minimum", netMinor: 0 },
] as const;

export interface SampleJob {
  id: string;
  reference: string;
  customer: string;
  service: string;
  start: string;
  durationHours: number;
  crew: string[];
  vehicle: string;
  status: "scheduled" | "in_progress" | "completed";
  accessNotes: string;
}

export const sampleJobs: SampleJob[] = [
  { id: "j1", reference: "EGM-J-2609-0088", customer: "Sam Patel", service: "Residential", start: "2026-09-17T08:00:00Z", durationHours: 7, crew: ["Ash", "Ayualyssa"], vehicle: "AB12 CDE", status: "in_progress", accessNotes: "Narrow stairs, no lift. Low bridge on Mill Lane — avoid." },
  { id: "j2", reference: "EGM-J-2609-0089", customer: "Tomasz Nowak", service: "Residential", start: "2026-09-18T07:30:00Z", durationHours: 9, crew: ["Ash", "H"], vehicle: "AB12 CDE", status: "scheduled", accessNotes: "Loading bay booked 07:30–09:00 only." },
  { id: "j3", reference: "EGM-J-2609-0090", customer: "Northgate Property Partners", service: "Office", start: "2026-09-18T18:00:00Z", durationHours: 12, crew: ["David", "Ash", "Ayualyssa", "H"], vehicle: "GH34 JKL", status: "scheduled", accessNotes: "Out of hours. Security sign-in at reception, photo ID for every crew member." },
  { id: "j4", reference: "EGM-J-2609-0091", customer: "Bethan Price", service: "Commercial", start: "2026-09-19T08:00:00Z", durationHours: 8, crew: ["David", "Ayualyssa"], vehicle: "MN56 PQR", status: "scheduled", accessNotes: "Server rack — asset tags to be photographed before disconnection." },
];

export const sampleOutbox = [
  { id: "o1", channel: "whatsapp" as const, to: "+44 7700 900123", template: "quote_chase_2", customer: "Jo Bloggs", reference: "EGM-2609-0412", queuedAt: hoursAgo(2), body: "Hi Jo — just checking you got the quote for your move on 4 October. Happy to talk through the piano handling if that helps. — Hania, EcoGreen Movers" },
  { id: "o2", channel: "whatsapp" as const, to: "+44 7700 900456", template: "review_request_2", customer: "Marta Silva", reference: "EGM-2609-0405", queuedAt: hoursAgo(20), body: "Hi Marta — hope the move went well. If you have a minute, a quick review really helps us. — EcoGreen Movers" },
  { id: "o3", channel: "sms" as const, to: "+44 7700 900789", template: "pre_move_reminder_1d", customer: "Tomasz Nowak", reference: "EGM-2609-0408", queuedAt: hoursAgo(1), body: "Reminder: your move is tomorrow, crew arriving 07:30. Any questions, call 0161 768 2055." },
];

export const sampleTargets = [
  { size: "Small", bookedMinor: 412_000, targetMinor: 500_000, count: 9 },
  { size: "Medium", bookedMinor: 688_000, targetMinor: 750_000, count: 7 },
  { size: "Large", bookedMinor: 940_000, targetMinor: 900_000, count: 4 },
  { size: "Commercial", bookedMinor: 1_486_000, targetMinor: 2_000_000, count: 3 },
  { size: "Office", bookedMinor: 1_240_000, targetMinor: 1_500_000, count: 2 },
] as const;

/* ── Chart data ──────────────────────────────────────────────────────────── */

export const weekLabels = ["W29", "W30", "W31", "W32", "W33", "W34", "W35", "W36", "W37"] as const;

export const leadsThisYear = [34, 41, 38, 52, 47, 61, 58, 66, 72] as const;
export const leadsLastYear = [29, 33, 36, 40, 44, 42, 49, 51, 55] as const;

export const conversionTrend = [22, 24, 23, 27, 26, 29, 31, 30, 33] as const;
export const responseTrend = [310, 280, 240, 260, 210, 190, 160, 150, 140] as const;
export const revenueTrend = [186, 204, 198, 241, 233, 288, 301, 322, 356] as const;

/** Stage counts, in pipeline order. Order is carried by position, not by a
 *  colour ramp — a five-step ramp cannot clear the contrast floor against
 *  both a white and a near-black surface. */
export const pipelineStages = [
  { label: "New", value: 38 },
  { label: "Qualifying", value: 29 },
  { label: "Quoted", value: 24 },
  { label: "Chasing", value: 17 },
  { label: "Booked", value: 11 },
] as const;

export const sourcePerformance = [
  { label: "Website form", value: 41, note: "32% conv" },
  { label: "Google Ads", value: 28, note: "24% conv" },
  { label: "Google organic", value: 23, note: "35% conv" },
  { label: "Lead provider", value: 19, note: "11% conv" },
  { label: "Referral", value: 14, note: "48% conv" },
  { label: "WhatsApp", value: 9, note: "29% conv" },
] as const;

export const brandTargets = [
  { label: "EcoGreen", actualMinor: 3_120_000, targetMinor: 3_500_000 },
  { label: "Eco London", actualMinor: 1_480_000, targetMinor: 1_200_000 },
  { label: "Manchester", actualMinor: 890_000, targetMinor: 1_000_000 },
  { label: "Edinburgh", actualMinor: 640_000, targetMinor: 900_000 },
  { label: "Glasgow", actualMinor: 410_000, targetMinor: 400_000 },
  { label: "Continuum", actualMinor: 220_000, targetMinor: 600_000 },
] as const;

export const crewToday = [
  { name: "Ash", role: "Driver", hours: 7.5, status: "On a job" },
  { name: "Ayualyssa", role: "Field logistics", hours: 7.5, status: "On a job" },
  { name: "David", role: "Dispatch", hours: 8.0, status: "Depot" },
  { name: "H", role: "Specialist", hours: 6.0, status: "On a job" },
  { name: "Sam", role: "Dispatch", hours: 0, status: "Not clocked in" },
] as const;
