import Link from "next/link";
import { notFound } from "next/navigation";

import { StatusBadge } from "@/components/crm/StatusBadge";
import { formatDate, formatMoneyMinor, formatRelative } from "@/lib/format";
import { sampleLeads, sampleQuoteLines, sampleTimeline } from "@/lib/sample-data";

export const dynamic = "force-dynamic";

const NOW = new Date("2026-09-17T09:00:00Z");

export default function LeadDetailPage({ params }: { params: { id: string } }) {
  const lead = sampleLeads.find((l) => l.id === params.id);
  if (!lead) notFound();

  const net = sampleQuoteLines.reduce((total, line) => total + line.netMinor, 0);
  const vat = Math.round(net * 0.2);

  return (
    <div className="mx-auto w-full max-w-content">
      <nav aria-label="Breadcrumb" className="mb-4 text-caption text-ink-3">
        <Link href="/leads" className="underline-offset-4 hover:text-ink-1 hover:underline">
          Leads
        </Link>
        <span className="mx-2" aria-hidden>
          /
        </span>
        <span data-numeric className="font-mono">
          {lead.reference}
        </span>
      </nav>

      <header className="mb-8 flex flex-wrap items-start justify-between gap-6 border-b border-hairline pb-6">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-3">
            <h1 className="text-title-1 text-ink-1">{lead.organisation ?? lead.customer}</h1>
            <StatusBadge status={lead.status} />
          </div>
          <p className="mt-2 text-body text-ink-2">
            {lead.service} · {lead.brand} · owned by {lead.owner ?? "nobody"}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button type="button" className="h-9 border border-hairline px-4 text-caption font-medium uppercase tracking-[0.1em] text-ink-1 hover:bg-surface-sunken">
            Log a call
          </button>
          <button type="button" className="h-9 border border-hairline px-4 text-caption font-medium uppercase tracking-[0.1em] text-ink-1 hover:bg-surface-sunken">
            Stop chasing
          </button>
          <button type="button" className="h-9 border border-accent bg-accent px-5 text-caption font-medium uppercase tracking-[0.1em] text-accent-contrast">
            Send new quote
          </button>
        </div>
      </header>

      <div className="grid gap-8 xl:grid-cols-[1fr_20rem]">
        <div className="flex min-w-0 flex-col gap-8">
          {/* The quote breakdown is the reason this screen exists: a
              salesperson asked "why is this £1,480?" has to be able to read
              the answer off the screen, line by line. */}
          <section>
            <div className="mb-3 flex items-baseline justify-between gap-4">
              <h2 className="text-title-3 text-ink-1">Quote v1 · sent 2 days ago</h2>
              <span className="text-caption text-ink-3">Viewed, not accepted</span>
            </div>
            <div className="min-w-0 overflow-x-auto border border-hairline">
              <table className="w-full border-collapse text-body-dense">
                <caption className="sr-only">Quote price breakdown</caption>
                <tbody>
                  {sampleQuoteLines.map((line) => (
                    <tr key={line.rule} className="border-b border-hairline last:border-0">
                      <td className="h-9 px-3 text-ink-1">{line.label}</td>
                      <td className="h-9 px-3 text-ink-2">{line.detail}</td>
                      <td
                        data-numeric
                        className={`h-9 whitespace-nowrap px-3 text-right ${line.netMinor === 0 ? "text-ink-3" : "text-ink-1"}`}
                      >
                        {formatMoneyMinor(line.netMinor)}
                      </td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="border-t border-hairline-strong">
                    <td className="h-9 px-3 text-ink-2" colSpan={2}>
                      Net
                    </td>
                    <td data-numeric className="h-9 px-3 text-right text-ink-1">
                      {formatMoneyMinor(net)}
                    </td>
                  </tr>
                  <tr>
                    <td className="h-9 px-3 text-ink-2" colSpan={2}>
                      VAT at 20%
                    </td>
                    <td data-numeric className="h-9 px-3 text-right text-ink-1">
                      {formatMoneyMinor(vat)}
                    </td>
                  </tr>
                  <tr className="border-t border-hairline">
                    <td className="h-10 px-3 font-medium text-ink-1" colSpan={2}>
                      Total
                    </td>
                    <td data-numeric className="h-10 px-3 text-right font-medium text-ink-1">
                      {formatMoneyMinor(net + vat)}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
            <p className="mt-2 text-caption text-ink-3">
              Every rule appears, including the ones that added nothing — a surcharge you cannot see
              is how a margin dispute starts.
            </p>
          </section>

          <section>
            <h2 className="mb-3 text-title-3 text-ink-1">History</h2>
            <ol className="border-l border-hairline pl-5">
              {[...sampleTimeline].reverse().map((event) => (
                <li key={event.at} className="relative pb-5 last:pb-0">
                  <span
                    className="absolute -left-[1.4rem] top-1.5 h-1.5 w-1.5 rounded-full bg-ink-3"
                    aria-hidden
                  />
                  <p className="text-body-dense text-ink-1">{event.detail}</p>
                  <p className="mt-0.5 text-caption text-ink-3">
                    {event.actor ? `${event.actor} · ` : ""}
                    <time dateTime={event.at}>{formatRelative(event.at, NOW)}</time>
                  </p>
                </li>
              ))}
            </ol>
          </section>
        </div>

        <aside className="flex flex-col gap-6">
          <Panel title="Customer">
            <Row label="Name" value={lead.customer} />
            {lead.organisation ? <Row label="Organisation" value={lead.organisation} /> : null}
            <Row label="Email" value="jo.bloggs@example.com" />
            <Row label="Phone" value="07700 900123" numeric />
          </Panel>

          <Panel title="The move">
            <Row label="From" value={lead.origin} numeric />
            <Row label="To" value={lead.destination} numeric />
            <Row label="Date" value={formatDate(lead.moveDate)} />
            <Row label="Volume" value="830 ft³ · 23.5 m³" numeric />
            <Row label="Crew" value="3 movers, 6.5 hours" />
          </Panel>

          <Panel title="Access notes">
            <p className="text-body-dense text-ink-1">
              Third floor, no lift at the Manchester end. One upright piano — specialist handling
              flagged, priced manually.
            </p>
            <p className="mt-2 text-caption text-ink-3">
              Copied to the job sheet verbatim when this books.
            </p>
          </Panel>

          <Panel title="Source">
            <Row label="First touch" value={lead.source} />
            <Row label="Score" value={String(lead.score)} numeric />
          </Panel>
        </aside>
      </div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="border border-hairline p-4">
      <h2 className="mb-3 text-caption text-ink-3">{title}</h2>
      {children}
    </section>
  );
}

function Row({ label, value, numeric }: { label: string; value: string; numeric?: boolean }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-hairline py-1.5 last:border-0">
      <span className="shrink-0 text-caption text-ink-3">{label}</span>
      <span data-numeric={numeric ? "" : undefined} className="text-right text-body-dense text-ink-1">
        {value}
      </span>
    </div>
  );
}
