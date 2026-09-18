import { formatRelative } from "@/lib/format";
import { sampleOutbox } from "@/lib/sample-data";

export const dynamic = "force-dynamic";
export const metadata = { title: "Send queue" };

const NOW = new Date("2026-09-17T09:00:00Z");

/** The manual-send queue.
 *
 *  Not a placeholder for a missing integration: WhatsApp Business verification
 *  takes weeks, and the chase workflow has to work in the meantime. The
 *  scheduler drafts the message, a person sends it, and the send is logged
 *  either way — so the pipeline reporting is the same before and after the API
 *  is connected. */
export default function InboxPage() {
  return (
    <div className="mx-auto w-full max-w-3xl">
      <header className="mb-6">
        <h1 className="text-title-1 text-ink-1">Send queue</h1>
        <p className="mt-1 max-w-[60ch] text-body text-ink-2">
          Messages the scheduler has drafted but cannot send itself. Send them from the business
          number, then mark them off — the chase sequence continues either way.
        </p>
      </header>

      <ul className="flex flex-col gap-px border border-hairline bg-hairline">
        {sampleOutbox.map((message) => (
          <li key={message.id} className="bg-surface-canvas p-5">
            <div className="flex flex-wrap items-baseline justify-between gap-3">
              <div>
                <span className="text-body-dense font-medium text-ink-1">{message.customer}</span>
                <span data-numeric className="ml-2 font-mono text-caption text-ink-3">
                  {message.reference}
                </span>
              </div>
              <span className="text-caption text-ink-3">
                {message.channel} · queued <time dateTime={message.queuedAt}>{formatRelative(message.queuedAt, NOW)}</time>
              </span>
            </div>

            <p className="mt-3 border-l-2 border-hairline-strong pl-3 text-body-dense text-ink-1">
              {message.body}
            </p>

            <div className="mt-4 flex flex-wrap items-center gap-2">
              <button
                type="button"
                className="h-9 border border-accent bg-accent px-5 text-caption font-medium uppercase tracking-[0.1em] text-accent-contrast"
              >
                Mark as sent
              </button>
              <button
                type="button"
                className="h-9 border border-hairline px-4 text-caption font-medium uppercase tracking-[0.1em] text-ink-1 hover:bg-surface-sunken"
              >
                Copy text
              </button>
              <button
                type="button"
                className="h-9 px-3 text-caption font-medium uppercase tracking-[0.1em] text-ink-2 hover:text-ink-1"
              >
                Skip
              </button>
              <span data-numeric className="ml-auto text-caption text-ink-3">
                {message.to}
              </span>
            </div>
          </li>
        ))}
      </ul>

      <p className="mt-3 text-caption text-ink-3">
        This queue empties itself once a WhatsApp Business number is connected. Nothing about the
        sequences changes when it does.
      </p>
    </div>
  );
}
