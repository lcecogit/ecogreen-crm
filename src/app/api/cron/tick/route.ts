import { NextResponse, type NextRequest } from "next/server";

import { createAdminClient } from "@/lib/supabase/admin";
import { availableChannels, getMessagingProvider } from "@/adapters/messaging";
import { getEmailProvider } from "@/adapters/email";
import { idempotencyKey, nextDecision, type EnrolmentState } from "@/domain/sequences/schedule";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** The single scheduler. Runs every 5 minutes via Vercel Cron.
 *
 *  One tick, two passes:
 *    1. advance due sequence enrolments into the outbox;
 *    2. dispatch due outbox rows.
 *
 *  Safe to run concurrently: enrolments are claimed with FOR UPDATE SKIP
 *  LOCKED inside claim_due_enrolments, and every outbox row carries a unique
 *  idempotency key, so a double tick cannot double-send. */
export async function GET(request: NextRequest) {
  const secret = process.env.CRON_SECRET;
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "unauthorised" }, { status: 401 });
  }

  const supabase = createAdminClient();
  const now = new Date();
  const channels = availableChannels();

  const { data: due, error } = await supabase.rpc("claim_due_enrolments", { p_limit: 200 });
  if (error) return NextResponse.json({ error: "claim_failed" }, { status: 500 });

  interface DueRow {
    enrolment_id: string;
    brand_id: string;
    customer_id: string | null;
    sequence_key: string;
    enrolled_at: string;
    next_step_order: number;
    satisfied_conditions: string[];
    recent_capped_sends_at: string[];
    to_address: string | null;
  }

  let queued = 0;
  let stopped = 0;
  let deferred = 0;

  for (const row of (due ?? []) as DueRow[]) {
    const state: EnrolmentState = {
      sequenceKey: row.sequence_key,
      enrolledAt: row.enrolled_at,
      nextStepOrder: row.next_step_order,
      satisfiedConditions: row.satisfied_conditions as EnrolmentState["satisfiedConditions"],
      recentCappedSendsAt: row.recent_capped_sends_at ?? [],
      availableChannels: channels,
    };

    const decision = nextDecision(state, now);

    if (decision.action === "stop" || decision.action === "complete") {
      stopped += 1;
      await supabase
        .from("sequence_enrolments")
        .update({
          status: decision.action === "stop" ? "stopped" : "completed",
          stopped_reason: decision.action === "stop" ? decision.reason : null,
          stopped_at: now.toISOString(),
        })
        .eq("id", row.enrolment_id);
      continue;
    }

    if (decision.action === "defer") {
      deferred += 1;
      await supabase
        .from("sequence_enrolments")
        .update({ next_run_at: decision.until.toISOString() })
        .eq("id", row.enrolment_id);
      continue;
    }

    // send or queue_for_manual_send: both become an outbox row. The difference
    // is the status, so a missing WhatsApp provider produces a drafted message
    // in a staff queue rather than an error.
    queued += 1;
    await supabase.from("outbox").upsert(
      {
        brand_id: row.brand_id,
        enrolment_id: row.enrolment_id,
        customer_id: row.customer_id,
        channel: decision.step.channel,
        to_address: row.to_address,
        template_key: decision.step.templateKey,
        send_after: now.toISOString(),
        status: decision.action === "send" ? "queued" : "needs_manual_send",
        counts_toward_frequency_cap: decision.step.countsTowardFrequencyCap,
        idempotency_key: idempotencyKey(row.enrolment_id, decision.step.order),
      },
      { onConflict: "idempotency_key", ignoreDuplicates: true },
    );

    await supabase
      .from("sequence_enrolments")
      .update({
        next_step_order: decision.step.order + 1,
        next_run_at: now.toISOString(),
      })
      .eq("id", row.enrolment_id);
  }

  const dispatched = await dispatchOutbox(supabase, now);

  return NextResponse.json({ queued, stopped, deferred, ...dispatched });
}

async function dispatchOutbox(
  supabase: ReturnType<typeof createAdminClient>,
  now: Date,
): Promise<{ sent: number; failed: number }> {
  const { data: rows } = await supabase.rpc("claim_due_outbox", { p_limit: 100 });

  interface OutboxRow {
    id: string;
    channel: "email" | "sms" | "whatsapp" | "task";
    to_address: string | null;
    template_key: string;
    brand_id: string;
    customer_id: string | null;
    counts_toward_frequency_cap: boolean;
    subject: string | null;
    body: string | null;
    from_address: string | null;
    reply_to: string | null;
  }

  let sent = 0;
  let failed = 0;

  for (const row of (rows ?? []) as OutboxRow[]) {
    try {
      let providerMessageId: string | null = null;

      if (row.channel === "email") {
        if (!row.to_address) throw new Error("No email address on the outbox row");
        const result = await getEmailProvider().send({
          to: row.to_address,
          from: row.from_address ?? "noreply@example.invalid",
          replyTo: row.reply_to ?? undefined,
          subject: row.subject ?? "",
          html: row.body ?? "",
          text: (row.body ?? "").replace(/<[^>]+>/g, " "),
        });
        providerMessageId = result.providerMessageId;
      } else if (row.channel === "sms" || row.channel === "whatsapp") {
        const result = await getMessagingProvider(row.channel).send({
          to: row.to_address ?? "",
          body: row.body ?? "",
          templateKey: row.template_key,
        });
        if (result.queuedForManualSend) {
          await supabase.from("outbox").update({ status: "needs_manual_send" }).eq("id", row.id);
          continue;
        }
        providerMessageId = result.providerMessageId;
      } else {
        // A task is internal work: it is "sent" the moment it exists in the queue.
        providerMessageId = null;
      }

      await supabase.rpc("mark_outbox_sent", {
        p_outbox_id: row.id,
        p_provider_message_id: providerMessageId,
      });
      sent += 1;
    } catch (cause) {
      failed += 1;
      await supabase
        .from("outbox")
        .update({
          status: "failed",
          error: cause instanceof Error ? cause.message : "Unknown error",
        })
        .eq("id", row.id);
    }
  }

  void now;
  return { sent, failed };
}
