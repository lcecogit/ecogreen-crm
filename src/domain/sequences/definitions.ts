import type { Channel } from "./schedule";

/** Sequences are data, not code. Each step names a template and a delay; the
 *  scheduler in ./schedule.ts decides whether it may actually send.
 *
 *  Every step carries stop conditions. A sequence that keeps sending after the
 *  customer has booked is worse than not sending at all — "message fatigue"
 *  is on the problem list, and it is the fastest way to make a customer
 *  unsubscribe from a brand they had just bought from. */

export type StopCondition =
  | "quote_accepted"
  | "quote_expired"
  | "lead_lost"
  | "lead_booked"
  | "customer_replied"
  | "unsubscribed"
  | "job_completed"
  | "payment_received"
  | "manual_stop";

export interface SequenceStep {
  readonly order: number;
  /** Minutes after enrolment, not after the previous step — absolute offsets
   *  are far easier to reason about when a step is skipped or deferred. */
  readonly delayMinutes: number;
  readonly channel: Channel;
  readonly templateKey: string;
  readonly stopConditions: readonly StopCondition[];
  /** False for transactional messages that must go out at 3 a.m. if needed. */
  readonly respectQuietHours: boolean;
  /** False for messages exempt from the fair-use cap (acknowledgements,
   *  booking confirmations, payment receipts — a customer is never annoyed by
   *  being told their money arrived). */
  readonly countsTowardFrequencyCap: boolean;
}

export interface SequenceDefinition {
  readonly key: string;
  readonly name: string;
  readonly description: string;
  readonly steps: readonly SequenceStep[];
}

const ALWAYS_STOP: readonly StopCondition[] = ["unsubscribed", "manual_stop", "lead_lost"];

const HOUR = 60;
const DAY = 24 * HOUR;

export const SEQUENCES: readonly SequenceDefinition[] = [
  {
    key: "lead_acknowledgement",
    name: "Enquiry acknowledgement",
    description:
      "Sent immediately, at any hour. An enquiry that arrives at 2 a.m. is answered at 2 a.m. — this is the fix for overnight lead loss.",
    steps: [
      {
        order: 1,
        delayMinutes: 0,
        channel: "email",
        templateKey: "lead_acknowledgement",
        stopConditions: ["unsubscribed", "manual_stop"],
        respectQuietHours: false,
        countsTowardFrequencyCap: false,
      },
    ],
  },
  {
    key: "quote_chase",
    name: "48-hour quote chase",
    description:
      "The core of the brief: a quote viewed but not accepted within 48 hours is chased, then chased again, then handed to a human.",
    steps: [
      {
        order: 1,
        delayMinutes: 48 * HOUR,
        channel: "email",
        templateKey: "quote_chase_1",
        stopConditions: [...ALWAYS_STOP, "quote_accepted", "customer_replied", "quote_expired"],
        respectQuietHours: true,
        countsTowardFrequencyCap: true,
      },
      {
        order: 2,
        delayMinutes: 4 * DAY,
        channel: "whatsapp",
        templateKey: "quote_chase_2",
        stopConditions: [...ALWAYS_STOP, "quote_accepted", "customer_replied", "quote_expired"],
        respectQuietHours: true,
        countsTowardFrequencyCap: true,
      },
      {
        order: 3,
        delayMinutes: 7 * DAY,
        channel: "task",
        templateKey: "quote_chase_call_task",
        stopConditions: [...ALWAYS_STOP, "quote_accepted", "quote_expired"],
        respectQuietHours: false,
        countsTowardFrequencyCap: false,
      },
    ],
  },
  {
    key: "quote_expiry_warning",
    name: "Quote expiry warning",
    description: "Warns before a fixed price lapses, rather than letting it lapse silently.",
    steps: [
      {
        order: 1,
        delayMinutes: 0,
        channel: "email",
        templateKey: "quote_expiry_warning",
        stopConditions: [...ALWAYS_STOP, "quote_accepted", "quote_expired"],
        respectQuietHours: true,
        countsTowardFrequencyCap: true,
      },
    ],
  },
  {
    key: "abandoned_inventory",
    name: "Abandoned inventory recovery",
    description: "Recovers a half-finished inventory from the web form.",
    steps: [
      {
        order: 1,
        delayMinutes: 2 * HOUR,
        channel: "email",
        templateKey: "abandoned_inventory",
        stopConditions: [...ALWAYS_STOP, "quote_accepted", "customer_replied"],
        respectQuietHours: true,
        countsTowardFrequencyCap: true,
      },
    ],
  },
  {
    key: "booking_confirmation",
    name: "Booking confirmation",
    description: "Transactional. Goes out immediately regardless of hour or cap.",
    steps: [
      {
        order: 1,
        delayMinutes: 0,
        channel: "email",
        templateKey: "booking_confirmation",
        stopConditions: ["manual_stop"],
        respectQuietHours: false,
        countsTowardFrequencyCap: false,
      },
    ],
  },
  {
    key: "pre_move_reminder",
    name: "Pre-move reminder",
    description: "Three days out, then the evening before.",
    steps: [
      {
        order: 1,
        delayMinutes: 0,
        channel: "email",
        templateKey: "pre_move_reminder_3d",
        stopConditions: ["manual_stop", "unsubscribed"],
        respectQuietHours: true,
        countsTowardFrequencyCap: false,
      },
      {
        order: 2,
        delayMinutes: 2 * DAY,
        channel: "whatsapp",
        templateKey: "pre_move_reminder_1d",
        stopConditions: ["manual_stop", "unsubscribed"],
        respectQuietHours: true,
        countsTowardFrequencyCap: false,
      },
    ],
  },
  {
    key: "payment_retry",
    name: "Payment retry",
    description:
      "A failed or expired payment never silently cancels a booking — it chases, then raises a task.",
    steps: [
      {
        order: 1,
        delayMinutes: HOUR,
        channel: "email",
        templateKey: "payment_retry_1",
        stopConditions: ["payment_received", "manual_stop"],
        respectQuietHours: true,
        countsTowardFrequencyCap: false,
      },
      {
        order: 2,
        delayMinutes: DAY,
        channel: "task",
        templateKey: "payment_retry_task",
        stopConditions: ["payment_received", "manual_stop"],
        respectQuietHours: false,
        countsTowardFrequencyCap: false,
      },
    ],
  },
  {
    key: "review_request",
    name: "Review request",
    description:
      "Sent the day after completion, while the move is fresh. Review lag is on the problem list; the fix is timing, not nagging.",
    steps: [
      {
        order: 1,
        delayMinutes: DAY,
        channel: "email",
        templateKey: "review_request_1",
        stopConditions: [...ALWAYS_STOP, "customer_replied"],
        respectQuietHours: true,
        countsTowardFrequencyCap: true,
      },
      {
        order: 2,
        delayMinutes: 5 * DAY,
        channel: "whatsapp",
        templateKey: "review_request_2",
        stopConditions: [...ALWAYS_STOP, "customer_replied"],
        respectQuietHours: true,
        countsTowardFrequencyCap: true,
      },
    ],
  },
];

const INDEX = new Map(SEQUENCES.map((sequence) => [sequence.key, sequence] as const));

export function findSequence(key: string): SequenceDefinition | undefined {
  return INDEX.get(key);
}
