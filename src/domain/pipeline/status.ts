/** The lead pipeline from the brief, as a state machine.
 *
 *  Website → Location → Customer Type → Service → Lead Status → Follow-up →
 *  Booking → Completed → Review
 *
 *  The first four are attributes of a lead, not stages; the stages are below.
 *  No route updates `leads.status` directly — every move comes through
 *  `transition()`, which validates it and produces the event to append. That
 *  is what makes the pipeline auditable and stops a lead reaching `booked`
 *  without a quote behind it. */

export const LEAD_STATUSES = [
  "new",
  "qualifying",
  "quoted",
  "chasing",
  "booked",
  "completed",
  "reviewed",
  "lost",
  "duplicate",
] as const;

export type LeadStatus = (typeof LEAD_STATUSES)[number];

const TRANSITIONS: Readonly<Record<LeadStatus, readonly LeadStatus[]>> = {
  new: ["qualifying", "quoted", "lost", "duplicate"],
  // A lead can be re-quoted from `quoted` (a new version) or go straight to
  // booked when the customer accepts on the call.
  qualifying: ["quoted", "lost", "duplicate"],
  quoted: ["chasing", "booked", "quoted", "lost"],
  chasing: ["booked", "quoted", "lost"],
  booked: ["completed", "lost"],
  completed: ["reviewed"],
  reviewed: [],
  lost: ["qualifying"], // a win-back reopens rather than creating a new lead
  duplicate: [],
};

export const TERMINAL_STATUSES: readonly LeadStatus[] = ["reviewed", "duplicate"];

export interface TransitionContext {
  readonly hasQuote: boolean;
  readonly hasAcceptedQuote: boolean;
  readonly hasCompletedJob: boolean;
  readonly lostReasonId?: string;
}

export interface TransitionEvent {
  readonly type: "status_changed";
  readonly from: LeadStatus;
  readonly to: LeadStatus;
  readonly at: string;
  readonly actorStaffId: string | null;
  readonly payload: Readonly<Record<string, unknown>>;
}

export type TransitionResult =
  | { readonly ok: true; readonly status: LeadStatus; readonly event: TransitionEvent }
  | { readonly ok: false; readonly error: string };

export function canTransition(from: LeadStatus, to: LeadStatus): boolean {
  return (TRANSITIONS[from] ?? []).includes(to);
}

export function allowedTransitions(from: LeadStatus): readonly LeadStatus[] {
  return TRANSITIONS[from] ?? [];
}

export function transition(
  from: LeadStatus,
  to: LeadStatus,
  context: TransitionContext,
  at: Date,
  actorStaffId: string | null,
): TransitionResult {
  if (from === to) {
    return { ok: false, error: `Lead is already ${from}.` };
  }
  if (!canTransition(from, to)) {
    const allowed = allowedTransitions(from);
    return {
      ok: false,
      error:
        allowed.length === 0
          ? `A ${from} lead cannot change status.`
          : `A ${from} lead can only move to ${allowed.join(", ")}.`,
    };
  }

  // Guards that express what the stage actually means, so the pipeline cannot
  // report a conversion that never happened.
  if (to === "quoted" && !context.hasQuote) {
    return { ok: false, error: "Send a quote before moving the lead to quoted." };
  }
  if (to === "booked" && !context.hasAcceptedQuote) {
    return { ok: false, error: "A lead can only be booked from an accepted quote." };
  }
  if (to === "completed" && !context.hasCompletedJob) {
    return { ok: false, error: "Mark the job complete before completing the lead." };
  }
  if (to === "lost" && !context.lostReasonId) {
    return {
      ok: false,
      error: "Choose a reason before marking the lead lost — the analysis depends on it.",
    };
  }

  return {
    ok: true,
    status: to,
    event: {
      type: "status_changed",
      from,
      to,
      at: at.toISOString(),
      actorStaffId,
      payload: context.lostReasonId ? { lostReasonId: context.lostReasonId } : {},
    },
  };
}

/** Stages that count as open work for a salesperson's queue. */
export function isOpen(status: LeadStatus): boolean {
  return ["new", "qualifying", "quoted", "chasing"].includes(status);
}

/** Stages that count as won for conversion reporting. Counting `booked` and
 *  above (rather than only `completed`) matches how sales targets are set. */
export function isWon(status: LeadStatus): boolean {
  return ["booked", "completed", "reviewed"].includes(status);
}
