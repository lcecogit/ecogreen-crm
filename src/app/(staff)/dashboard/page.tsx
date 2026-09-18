import Link from "next/link";

import { BarRows, LineChart, Sparkline, TargetBars } from "@/components/charts/Charts";
import { StatusBadge } from "@/components/crm/StatusBadge";
import { formatMoneyMinor } from "@/lib/format";
import {
  brandTargets,
  conversionTrend,
  crewToday,
  leadsLastYear,
  leadsThisYear,
  pipelineStages,
  responseTrend,
  revenueTrend,
  sampleJobs,
  sampleLeads,
  sampleOutbox,
  sourcePerformance,
  weekLabels,
} from "@/lib/sample-data";

export const dynamic = "force-dynamic";
export const metadata = { title: "Dashboard" };

export default function DashboardPage() {
  const open = sampleLeads.filter((l) => ["new", "qualifying", "quoted", "chasing"].includes(l.status));
  const unassigned = open.filter((l) => !l.owner);

  return (
    <div className="mx-auto flex w-full max-w-content flex-col gap-8">
      <header>
        <h1 className="text-title-1 text-ink-1">Wednesday, 17 September</h1>
        <p className="mt-1 text-body text-ink-2">
          {open.length} open leads · {sampleJobs.length} jobs on the board · 5 crew on shift
        </p>
      </header>

      {/* Headline figures carry a sparkline each: the number is the value, the
          line is the direction, and neither needs a chart of its own. */}
      <section className="grid min-w-0 grid-cols-1 gap-px border border-hairline bg-hairline sm:grid-cols-2 xl:grid-cols-4">
        <Figure
          label="Revenue booked, month to date"
          value={formatMoneyMinor(676_000)}
          delta="+18% on last month"
          deltaTone="good"
          trend={revenueTrend}
          trendLabel="Revenue booked by week, rising"
          href="/reports"
        />
        <Figure
          label="Quote conversion"
          value="33%"
          delta="+3 points on last month"
          deltaTone="good"
          trend={conversionTrend}
          trendLabel="Quote conversion by week, rising"
          href="/reports"
        />
        <Figure
          label="Median first response"
          value="2h 20m"
          delta="Target is under 1 hour"
          deltaTone="critical"
          trend={responseTrend}
          trendLabel="First response time by week, falling"
          href="/leads"
        />
        <Figure
          label="Unassigned leads"
          value={String(unassigned.length)}
          delta={unassigned.length > 0 ? "Oldest waiting 3 hours" : "All owned"}
          deltaTone={unassigned.length > 0 ? "critical" : "neutral"}
          href="/leads?owner=none"
        />
      </section>

      <section className="grid min-w-0 gap-px border border-hairline bg-hairline xl:grid-cols-[1.4fr_1fr]">
        <div className="min-w-0 bg-surface-canvas p-5">
          <LineChart
            title="Leads received each week"
            labels={weekLabels}
            series={[
              { name: "This year", colour: "var(--series-1)", values: leadsThisYear },
              { name: "Last year", colour: "var(--series-2)", values: leadsLastYear },
            ]}
          />
        </div>
        <div className="min-w-0 bg-surface-canvas p-5">
          <BarRows title="Pipeline by stage" rows={pipelineStages} />
          <p className="mt-3 text-caption text-ink-3">
            The drop from quoted to chasing is where the 48-hour rule earns its keep.
          </p>
        </div>
      </section>

      <section className="grid min-w-0 gap-px border border-hairline bg-hairline xl:grid-cols-2">
        <div className="min-w-0 bg-surface-canvas p-5">
          <TargetBars title="Booked against target, by brand" rows={brandTargets} />
        </div>
        <div className="min-w-0 bg-surface-canvas p-5">
          <BarRows title="Where leads come from" rows={sourcePerformance} />
          <p className="mt-3 text-caption text-ink-3">
            Volume is the bar; conversion is the figure beside it. Referrals are the smallest source
            and the best one.
          </p>
        </div>
      </section>

      <section className="grid min-w-0 gap-8 xl:grid-cols-[1.4fr_1fr]">
        <div className="min-w-0">
          <SectionHead title="Needs attention" action={{ href: "/leads", label: "All leads" }} />
          <div className="min-w-0 overflow-x-auto border border-hairline">
            <table className="w-full min-w-[40rem] border-collapse text-body-dense">
              <caption className="sr-only">Open leads needing attention, unassigned first</caption>
              <thead>
                <tr className="border-b border-hairline">
                  {["Reference", "Customer", "Route", "Owner", "Status"].map((h) => (
                    <th key={h} scope="col" className="whitespace-nowrap px-3 py-2 text-left text-caption font-normal text-ink-3">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {[...open]
                  .sort((a, b) => Number(Boolean(a.owner)) - Number(Boolean(b.owner)))
                  .slice(0, 7)
                  .map((lead) => (
                    <tr key={lead.id} className="border-b border-hairline last:border-0 hover:bg-surface-sunken">
                      <td className="h-9 whitespace-nowrap px-3">
                        <Link href={`/leads/${lead.id}`} data-numeric className="font-mono text-ink-1 underline-offset-4 hover:underline">
                          {lead.reference}
                        </Link>
                      </td>
                      <td className="h-9 px-3 text-ink-1">
                        <span className="block max-w-[20ch] truncate">{lead.organisation ?? lead.customer}</span>
                      </td>
                      <td className="h-9 whitespace-nowrap px-3 text-ink-2" data-numeric>
                        {lead.origin} → {lead.destination}
                      </td>
                      <td className="h-9 whitespace-nowrap px-3">
                        {lead.owner ?? <span className="text-status-critical-text">Unassigned</span>}
                      </td>
                      <td className="h-9 whitespace-nowrap px-3">
                        <StatusBadge status={lead.status} />
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="flex min-w-0 flex-col gap-8">
          <div>
            <SectionHead title="Today on the road" action={{ href: "/calendar", label: "Calendar" }} />
            <ul className="flex flex-col gap-px border border-hairline bg-hairline">
              {sampleJobs.slice(0, 3).map((job) => (
                <li key={job.id} className="bg-surface-canvas p-4">
                  <div className="flex items-baseline justify-between gap-3">
                    <span className="text-body-dense font-medium text-ink-1">{job.customer}</span>
                    <span data-numeric className="text-caption text-ink-3">
                      {new Date(job.start).toUTCString().slice(17, 22)} · {job.durationHours}h
                    </span>
                  </div>
                  <p className="mt-1 text-caption text-ink-2">
                    {job.crew.join(", ")} · {job.vehicle}
                  </p>
                  <p className="mt-2 border-l-2 border-accent pl-2 text-caption text-ink-2">{job.accessNotes}</p>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <SectionHead title="Crew on shift" action={{ href: "/attendance", label: "Attendance" }} />
            <ul className="flex flex-col gap-px border border-hairline bg-hairline">
              {crewToday.map((person) => (
                <li key={person.name} className="flex items-baseline justify-between gap-3 bg-surface-canvas px-4 py-2.5">
                  <span className="text-body-dense text-ink-1">
                    {person.name}
                    <span className="ml-2 text-caption text-ink-3">{person.role}</span>
                  </span>
                  <span
                    data-numeric
                    className={`text-caption ${person.hours === 0 ? "text-status-critical-text" : "text-ink-2"}`}
                  >
                    {person.hours === 0 ? person.status : `${person.hours.toFixed(1)}h · ${person.status}`}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          <div>
            <SectionHead title="Waiting to send" action={{ href: "/inbox", label: "Send queue" }} />
            <ul className="flex flex-col gap-px border border-hairline bg-hairline">
              {sampleOutbox.slice(0, 2).map((message) => (
                <li key={message.id} className="bg-surface-canvas p-4">
                  <div className="flex items-baseline justify-between gap-3">
                    <span className="text-body-dense text-ink-1">{message.customer}</span>
                    <span className="text-caption text-ink-3">{message.channel}</span>
                  </div>
                  <p className="mt-1 line-clamp-2 text-caption text-ink-2">{message.body}</p>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>
    </div>
  );
}

function SectionHead({ title, action }: { title: string; action?: { href: string; label: string } }) {
  return (
    <div className="mb-3 flex items-baseline justify-between gap-4">
      <h2 className="text-title-3 text-ink-1">{title}</h2>
      {action ? (
        <Link href={action.href} className="text-body-dense text-ink-2 underline-offset-4 hover:text-ink-1 hover:underline">
          {action.label}
        </Link>
      ) : null}
    </div>
  );
}

function Figure({
  label,
  value,
  delta,
  deltaTone = "neutral",
  trend,
  trendLabel,
  href,
}: {
  label: string;
  value: string;
  delta: string;
  deltaTone?: "neutral" | "good" | "critical";
  trend?: readonly number[];
  trendLabel?: string;
  href: string;
}) {
  return (
    <Link href={href} className="bg-surface-canvas p-5 transition-colors duration-instant ease-standard hover:bg-surface-sunken">
      <p className="text-caption text-ink-3">{label}</p>
      <p data-numeric className="mt-2 text-display text-ink-1">
        {value}
      </p>
      <div className="mt-2 flex items-end justify-between gap-3">
        <p
          className={`text-caption ${
            deltaTone === "good"
              ? "text-status-good-text"
              : deltaTone === "critical"
                ? "text-status-critical-text"
                : "text-ink-2"
          }`}
        >
          {delta}
        </p>
        {trend && trendLabel ? <Sparkline points={trend} label={trendLabel} /> : null}
      </div>
    </Link>
  );
}
