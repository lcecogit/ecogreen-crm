/** Lead routing.
 *
 *  Two rules, in order:
 *   1. round-robin across the brand's sales staff who are on shift, by who has
 *      waited longest for a lead — not by lowest total, which starves anyone
 *      returning from leave;
 *   2. if nobody is on shift, the brand's manager, so out-of-hours enquiries
 *      still have an owner by morning.
 *
 *  An enquiry is never left unowned. "Overnight lead loss" and "unassigned
 *  leads at busy times" are both on the problem list, and both are this
 *  function returning null. */

export interface AssignableStaff {
  readonly staffId: string;
  readonly role: "sales" | "manager" | "admin";
  readonly onShift: boolean;
  readonly acceptingLeads: boolean;
  /** ISO timestamp of their most recent assignment, or null if never. */
  readonly lastAssignedAt: string | null;
  readonly openLeadCount: number;
  /** Hard ceiling; 0 means no cap. */
  readonly maxOpenLeads: number;
}

export interface AssignmentResult {
  readonly staffId: string | null;
  readonly rule: "round_robin" | "manager_fallback" | "unassigned";
  readonly reason: string;
}

function hasCapacity(staff: AssignableStaff): boolean {
  return staff.maxOpenLeads === 0 || staff.openLeadCount < staff.maxOpenLeads;
}

function longestWaiting(candidates: readonly AssignableStaff[]): AssignableStaff | null {
  let best: AssignableStaff | null = null;
  let bestTime = Number.POSITIVE_INFINITY;
  for (const candidate of candidates) {
    const time = candidate.lastAssignedAt ? Date.parse(candidate.lastAssignedAt) : -1;
    if (time < bestTime) {
      best = candidate;
      bestTime = time;
    }
  }
  return best;
}

export function assignLead(team: readonly AssignableStaff[]): AssignmentResult {
  const available = team.filter(
    (member) =>
      member.role === "sales" && member.onShift && member.acceptingLeads && hasCapacity(member),
  );
  const chosen = longestWaiting(available);
  if (chosen) {
    return {
      staffId: chosen.staffId,
      rule: "round_robin",
      reason: "Longest since their last lead, on shift and under their cap",
    };
  }

  const managers = team.filter(
    (member) => (member.role === "manager" || member.role === "admin") && member.acceptingLeads,
  );
  const manager = longestWaiting(managers);
  if (manager) {
    return {
      staffId: manager.staffId,
      rule: "manager_fallback",
      reason: "No sales staff on shift — routed to a manager for the morning",
    };
  }

  return {
    staffId: null,
    rule: "unassigned",
    reason: "Nobody is accepting leads for this brand — raise on the ops dashboard",
  };
}

/** Minutes after which an unowned lead raises an alert. */
export const UNASSIGNED_ALERT_MINUTES = 15;
