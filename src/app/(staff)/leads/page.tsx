import Link from "next/link";

import { ScoreBar } from "@/components/crm/ScoreBar";
import { StatusBadge } from "@/components/crm/StatusBadge";
import { EmptyState, FilteredEmptyState } from "@/components/ui/EmptyState";
import { formatDate, formatMoneyMinor, formatRelative } from "@/lib/format";
import { sampleLeads } from "@/lib/sample-data";

export const dynamic = "force-dynamic";
export const metadata = { title: "Leads" };

const NOW = new Date("2026-09-17T09:00:00Z");
const OPEN = ["new", "qualifying", "quoted", "chasing"];

const FILTERS = [
  { key: "open", label: "Open" },
  { key: "new", label: "New" },
  { key: "chasing", label: "Chasing" },
  { key: "booked", label: "Booked" },
  { key: "lost", label: "Lost" },
  { key: "all", label: "All" },
] as const;

export default function LeadsPage({
  searchParams,
}: {
  searchParams: { status?: string; owner?: string };
}) {
  const status = searchParams.status ?? "open";
  const ownerFilter = searchParams.owner;

  const rows = sampleLeads.filter((lead) => {
    if (ownerFilter === "none" && lead.owner) return false;
    if (status === "all") return true;
    if (status === "open") return OPEN.includes(lead.status);
    return lead.status === status;
  });

  return (
    <div className="mx-auto w-full max-w-content">
      <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-title-1 text-ink-1">Leads</h1>
          <p className="mt-1 text-body text-ink-2">
            Every enquiry across the six brands, its owner and its stage.
          </p>
        </div>
        <button
          type="button"
          className="h-9 border border-accent bg-accent px-5 text-caption font-medium uppercase tracking-[0.1em] text-accent-contrast"
        >
          Add a lead
        </button>
      </header>

      <div className="mb-4 flex flex-wrap items-center gap-2" role="group" aria-label="Filter by status">
        {FILTERS.map((filter) => {
          const active = status === filter.key && !ownerFilter;
          return (
            <Link
              key={filter.key}
              href={`/leads?status=${filter.key}`}
              aria-current={active ? "true" : undefined}
              className={
                active
                  ? "border border-ink-1 px-3 py-1.5 text-body-dense font-medium text-ink-1"
                  : "border border-hairline px-3 py-1.5 text-body-dense text-ink-2 transition-colors duration-instant ease-standard hover:border-hairline-strong hover:text-ink-1"
              }
            >
              {filter.label}
            </Link>
          );
        })}
        <Link
          href="/leads?owner=none"
          aria-current={ownerFilter === "none" ? "true" : undefined}
          className={
            ownerFilter === "none"
              ? "border border-ink-1 px-3 py-1.5 text-body-dense font-medium text-ink-1"
              : "border border-hairline px-3 py-1.5 text-body-dense text-ink-2 hover:border-hairline-strong hover:text-ink-1"
          }
        >
          Unassigned
        </Link>
        <span className="ml-auto text-caption text-ink-3" data-numeric>
          {rows.length} of {sampleLeads.length}
        </span>
      </div>

      <div className="border border-hairline">
        {rows.length === 0 ? (
          status === "all" && !ownerFilter ? (
            <EmptyState
              title="No leads yet"
              description="Enquiries from the brand websites, phone and WhatsApp appear here the moment they arrive."
            />
          ) : (
            <FilteredEmptyState
              onClear={
                <Link href="/leads?status=all" className="text-body text-ink-1 underline underline-offset-4">
                  Show all leads
                </Link>
              }
            />
          )
        ) : (
          <div className="min-w-0 overflow-x-auto">
            <table className="w-full border-collapse text-body-dense">
              <caption className="sr-only">Leads</caption>
              <thead>
                <tr className="border-b border-hairline">
                  {[
                    ["Reference", false],
                    ["Customer", false],
                    ["Brand", false],
                    ["Service", false],
                    ["Route", false],
                    ["Move date", false],
                    ["Owner", false],
                    ["Status", false],
                    ["Value", true],
                    ["Score", true],
                    ["Received", true],
                  ].map(([label, numeric]) => (
                    <th
                      key={String(label)}
                      scope="col"
                      className={`whitespace-nowrap px-3 py-2 text-caption font-normal text-ink-3 ${numeric ? "text-right" : "text-left"}`}
                    >
                      {label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((lead) => (
                  <tr key={lead.id} className="border-b border-hairline last:border-0 hover:bg-surface-sunken">
                    <td className="h-9 whitespace-nowrap px-3">
                      <Link href={`/leads/${lead.id}`} data-numeric className="font-mono text-ink-1 underline-offset-4 hover:underline">
                        {lead.reference}
                      </Link>
                    </td>
                    <td className="h-9 px-3 text-ink-1">
                      <span className="block max-w-[22ch] truncate">{lead.organisation ?? lead.customer}</span>
                    </td>
                    <td className="h-9 px-3 text-ink-2">
                      <span className="block max-w-[16ch] truncate">{lead.brand}</span>
                    </td>
                    <td className="h-9 whitespace-nowrap px-3 text-ink-2">{lead.service}</td>
                    <td className="h-9 whitespace-nowrap px-3 text-ink-2" data-numeric>
                      {lead.origin} → {lead.destination}
                    </td>
                    <td className="h-9 whitespace-nowrap px-3 text-ink-2">{formatDate(lead.moveDate)}</td>
                    <td className="h-9 whitespace-nowrap px-3">
                      {lead.owner ?? <span className="text-status-critical-text">Unassigned</span>}
                    </td>
                    <td className="h-9 px-3">
                      <StatusBadge status={lead.status} />
                    </td>
                    <td className="h-9 whitespace-nowrap px-3 text-right text-ink-1" data-numeric>
                      {lead.valueMinor === null ? "—" : formatMoneyMinor(lead.valueMinor)}
                    </td>
                    <td className="h-9 px-3 text-right">
                      <ScoreBar score={lead.score} />
                    </td>
                    <td className="h-9 whitespace-nowrap px-3 text-right text-ink-2">
                      <time dateTime={lead.createdAt}>{formatRelative(lead.createdAt, NOW)}</time>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
