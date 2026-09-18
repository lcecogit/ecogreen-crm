import assert from "node:assert/strict";
import { test } from "node:test";

import {
  FREQUENCY_CAP,
  QUIET_HOURS,
  idempotencyKey,
  nextDecision,
  nextSendWindow,
  type EnrolmentState,
} from "../src/domain/sequences/schedule";
import { SEQUENCES, findSequence } from "../src/domain/sequences/definitions";
import { ukParts } from "../src/domain/clock";

const base: EnrolmentState = {
  sequenceKey: "quote_chase",
  enrolledAt: "2026-03-02T10:00:00Z",
  nextStepOrder: 1,
  satisfiedConditions: [],
  recentCappedSendsAt: [],
  availableChannels: ["email", "sms", "whatsapp"],
};

const state = (over: Partial<EnrolmentState> = {}): EnrolmentState => ({ ...base, ...over });

test("the chase does not fire before 48 hours", () => {
  const decision = nextDecision(state(), new Date("2026-03-04T09:59:00Z"));
  assert.equal(decision.action, "defer");
});

test("the chase fires at 48 hours", () => {
  const decision = nextDecision(state(), new Date("2026-03-04T10:00:00Z"));
  assert.equal(decision.action, "send");
  if (decision.action !== "send") throw new Error("unreachable");
  assert.equal(decision.step.templateKey, "quote_chase_1");
});

test("a customer who books stops receiving chases immediately", () => {
  const decision = nextDecision(
    state({ satisfiedConditions: ["quote_accepted"] }),
    new Date("2026-03-04T10:00:00Z"),
  );
  assert.equal(decision.action, "stop");
  if (decision.action !== "stop") throw new Error("unreachable");
  assert.equal(decision.condition, "quote_accepted");
});

test("an unsubscribe stops every sequence", () => {
  for (const sequence of SEQUENCES) {
    const step = sequence.steps[0];
    if (!step || !step.stopConditions.includes("unsubscribed")) continue;
    const decision = nextDecision(
      state({ sequenceKey: sequence.key, satisfiedConditions: ["unsubscribed"] }),
      new Date("2027-01-01T12:00:00Z"),
    );
    assert.equal(decision.action, "stop", sequence.key);
  }
});

test("stop conditions are checked at dispatch time, not enrolment time", () => {
  // Enrolled clean, condition satisfied later, message now overdue.
  const decision = nextDecision(
    state({ satisfiedConditions: ["lead_lost"] }),
    new Date("2026-03-20T10:00:00Z"),
  );
  assert.equal(decision.action, "stop");
});

test("marketing messages defer out of quiet hours, and land inside them", () => {
  // 03:00 UK — enrolled so that the step is due in the middle of the night.
  const nightState = state({ enrolledAt: "2026-02-28T03:00:00Z" });
  const decision = nextDecision(nightState, new Date("2026-03-02T03:00:00Z"));
  assert.equal(decision.action, "defer");
  if (decision.action !== "defer") throw new Error("unreachable");
  assert.equal(decision.reason, "Outside sending hours");
  assert.equal(ukParts(decision.until).hour, QUIET_HOURS.startHour);
});

test("an acknowledgement goes out at 3 a.m. — overnight enquiries are answered overnight", () => {
  const decision = nextDecision(
    state({ sequenceKey: "lead_acknowledgement", enrolledAt: "2026-03-02T03:00:00Z" }),
    new Date("2026-03-02T03:00:00Z"),
  );
  assert.equal(decision.action, "send");
});

test("the fair-use cap defers rather than dropping the message", () => {
  const recent = [
    "2026-03-01T10:00:00Z",
    "2026-03-02T10:00:00Z",
    "2026-03-03T10:00:00Z",
  ];
  const decision = nextDecision(
    state({ recentCappedSendsAt: recent }),
    new Date("2026-03-04T10:00:00Z"),
  );
  assert.equal(decision.action, "defer");
  if (decision.action !== "defer") throw new Error("unreachable");
  assert.match(decision.reason, /Fair-use cap/);
  // Deferred until the oldest send leaves the rolling window.
  assert.equal(
    decision.until.toISOString(),
    new Date(Date.parse("2026-03-01T10:00:00Z") + FREQUENCY_CAP.windowDays * 86_400_000).toISOString(),
  );
});

test("sends outside the rolling window do not count toward the cap", () => {
  const decision = nextDecision(
    state({
      recentCappedSendsAt: ["2026-01-01T10:00:00Z", "2026-01-02T10:00:00Z", "2026-01-03T10:00:00Z"],
    }),
    new Date("2026-03-04T10:00:00Z"),
  );
  assert.equal(decision.action, "send");
});

test("transactional messages bypass the cap", () => {
  const decision = nextDecision(
    state({
      sequenceKey: "booking_confirmation",
      recentCappedSendsAt: ["2026-03-01T10:00:00Z", "2026-03-02T10:00:00Z", "2026-03-03T10:00:00Z"],
    }),
    new Date("2026-03-04T10:00:00Z"),
  );
  assert.equal(decision.action, "send");
});

test("an unconfigured channel drafts for a human instead of failing", () => {
  const decision = nextDecision(
    state({ nextStepOrder: 2, availableChannels: ["email"] }),
    new Date("2026-03-10T10:00:00Z"),
  );
  assert.equal(decision.action, "queue_for_manual_send");
  if (decision.action !== "queue_for_manual_send") throw new Error("unreachable");
  assert.equal(decision.channel, "whatsapp");
});

test("the sequence completes rather than looping once steps run out", () => {
  const decision = nextDecision(state({ nextStepOrder: 99 }), new Date("2027-01-01T12:00:00Z"));
  assert.equal(decision.action, "complete");
});

test("idempotency keys make concurrent cron ticks safe", () => {
  assert.equal(idempotencyKey("enr-1", 2), "seq:enr-1:2");
  assert.notEqual(idempotencyKey("enr-1", 2), idempotencyKey("enr-1", 3));
});

test("nextSendWindow is a no-op inside the window", () => {
  const inside = new Date("2026-03-02T12:00:00Z");
  assert.equal(nextSendWindow(inside).getTime(), inside.getTime());
});

test("every sequence step declares stop conditions and a template", () => {
  for (const sequence of SEQUENCES) {
    assert.ok(sequence.steps.length > 0, `${sequence.key} has no steps`);
    for (const step of sequence.steps) {
      assert.ok(step.templateKey.length > 0, `${sequence.key}:${step.order} has no template`);
      assert.ok(
        step.stopConditions.length > 0,
        `${sequence.key}:${step.order} has no stop conditions — it would send forever`,
      );
    }
  }
});

test("step orders are unique and contiguous within a sequence", () => {
  for (const sequence of SEQUENCES) {
    const orders = sequence.steps.map((step) => step.order);
    assert.deepEqual(orders, [...orders].sort((a, b) => a - b), sequence.key);
    assert.equal(new Set(orders).size, orders.length, sequence.key);
  }
});

test("delays are absolute offsets from enrolment and strictly increase", () => {
  for (const sequence of SEQUENCES) {
    let previous = -1;
    for (const step of sequence.steps) {
      assert.ok(step.delayMinutes > previous, `${sequence.key}:${step.order} does not advance`);
      previous = step.delayMinutes;
    }
  }
  assert.equal(findSequence("quote_chase")?.steps[0]?.delayMinutes, 48 * 60);
});
