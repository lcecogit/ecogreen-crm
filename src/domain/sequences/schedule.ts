import { addMinutes, ukParts } from "../clock";
import { findSequence, type SequenceStep, type StopCondition } from "./definitions";

/** The scheduler. Decides, for one enrolment at one instant, whether the next
 *  step sends now, waits, or stops.
 *
 *  Pure and side-effect free, so the whole chasing policy — quiet hours, the
 *  fair-use cap, stop conditions, channel fallback — is unit-testable without
 *  a database, a clock or a provider. */

export type Channel = "email" | "sms" | "whatsapp" | "task";

/** Nothing automated outside these hours. A 6 a.m. marketing WhatsApp costs
 *  more goodwill than the booking is worth. Transactional steps opt out. */
export const QUIET_HOURS = { startHour: 8, endHour: 20 } as const;

/** Fair-use cap across every channel and every one of the six brands. A
 *  customer does not experience "EcoGreen" and "Edinburgh Moving" as separate
 *  senders — they experience six messages in a week. */
export const FREQUENCY_CAP = { messages: 3, windowDays: 7 } as const;

export interface EnrolmentState {
  readonly sequenceKey: string;
  readonly enrolledAt: string;
  readonly nextStepOrder: number;
  readonly satisfiedConditions: readonly StopCondition[];
  /** ISO timestamps of capped messages already sent to this customer, across
   *  all brands and channels. */
  readonly recentCappedSendsAt: readonly string[];
  /** Channels with a configured provider. A channel that is absent is not an
   *  error — the step is queued for a human to send instead. */
  readonly availableChannels: readonly Channel[];
}

export type ScheduleDecision =
  | { readonly action: "send"; readonly step: SequenceStep; readonly channel: Channel }
  | {
      readonly action: "queue_for_manual_send";
      readonly step: SequenceStep;
      readonly channel: Channel;
      readonly reason: string;
    }
  | { readonly action: "defer"; readonly step: SequenceStep; readonly until: Date; readonly reason: string }
  | { readonly action: "stop"; readonly reason: string; readonly condition?: StopCondition }
  | { readonly action: "complete"; readonly reason: string };

export function nextDecision(state: EnrolmentState, now: Date): ScheduleDecision {
  const sequence = findSequence(state.sequenceKey);
  if (!sequence) {
    return { action: "stop", reason: `Unknown sequence ${state.sequenceKey}` };
  }

  const step = sequence.steps.find((candidate) => candidate.order === state.nextStepOrder);
  if (!step) {
    return { action: "complete", reason: "All steps sent" };
  }

  // Stop conditions are evaluated at dispatch time, not at enrolment time.
  // The customer who books an hour before the chase is due must not receive it.
  const hit = step.stopConditions.find((condition) =>
    state.satisfiedConditions.includes(condition),
  );
  if (hit) {
    return { action: "stop", reason: stopReason(hit), condition: hit };
  }

  const dueAt = addMinutes(new Date(state.enrolledAt), step.delayMinutes);
  if (dueAt.getTime() > now.getTime()) {
    return { action: "defer", step, until: dueAt, reason: "Not due yet" };
  }

  // A task is internal work, not a message: it bypasses quiet hours and the cap.
  if (step.channel !== "task") {
    if (step.respectQuietHours) {
      const window = nextSendWindow(now);
      if (window.getTime() > now.getTime()) {
        return { action: "defer", step, until: window, reason: "Outside sending hours" };
      }
    }

    if (step.countsTowardFrequencyCap) {
      const capped = withinCapWindow(state.recentCappedSendsAt, now);
      if (capped.length >= FREQUENCY_CAP.messages) {
        const oldest = capped[0];
        const until = oldest
          ? new Date(Date.parse(oldest) + FREQUENCY_CAP.windowDays * 86_400_000)
          : addMinutes(now, 24 * 60);
        return {
          action: "defer",
          step,
          until,
          reason: `Fair-use cap reached (${FREQUENCY_CAP.messages} in ${FREQUENCY_CAP.windowDays} days)`,
        };
      }
    }

    if (!state.availableChannels.includes(step.channel)) {
      return {
        action: "queue_for_manual_send",
        step,
        channel: step.channel,
        reason: `No ${step.channel} provider configured — drafted for a human to send`,
      };
    }
  }

  return { action: "send", step, channel: step.channel };
}

/** The next instant inside the sending window, in UK wall-clock terms. */
export function nextSendWindow(from: Date): Date {
  const parts = ukParts(from);
  if (parts.hour >= QUIET_HOURS.startHour && parts.hour < QUIET_HOURS.endHour) {
    return from;
  }
  const minutesNow = parts.hour * 60 + parts.minute;
  const openMinutes = QUIET_HOURS.startHour * 60;
  const deltaMinutes =
    minutesNow < openMinutes
      ? openMinutes - minutesNow
      : 24 * 60 - minutesNow + openMinutes;
  return addMinutes(from, deltaMinutes);
}

function withinCapWindow(sends: readonly string[], now: Date): string[] {
  const cutoff = now.getTime() - FREQUENCY_CAP.windowDays * 86_400_000;
  return sends
    .filter((iso) => Date.parse(iso) >= cutoff)
    .sort((a, b) => Date.parse(a) - Date.parse(b));
}

const STOP_REASONS: Record<StopCondition, string> = {
  quote_accepted: "The customer accepted the quote",
  quote_expired: "The quote expired",
  lead_lost: "The lead was marked lost",
  lead_booked: "The move was booked",
  customer_replied: "The customer replied",
  unsubscribed: "The customer unsubscribed",
  job_completed: "The job was completed",
  payment_received: "Payment was received",
  manual_stop: "Stopped by a member of staff",
};

function stopReason(condition: StopCondition): string {
  return STOP_REASONS[condition];
}

/** Idempotency key for the outbox. One enrolment plus one step order can only
 *  ever produce one message, so concurrent cron ticks cannot double-send. */
export function idempotencyKey(enrolmentId: string, stepOrder: number): string {
  return `seq:${enrolmentId}:${stepOrder}`;
}
