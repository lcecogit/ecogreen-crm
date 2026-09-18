import { Badge } from "@/components/ui/Badge";
import { Button } from "@/components/ui/Button";
import { DataTable, type Column } from "@/components/ui/DataTable";
import { EmptyState, ErrorState, FilteredEmptyState } from "@/components/ui/EmptyState";
import { Field, TextInput } from "@/components/ui/Field";
import { Panel, PanelHeader } from "@/components/ui/Surface";
import { Skeleton, TableSkeleton } from "@/components/ui/Skeleton";
import { StatTile } from "@/components/ui/StatTile";
import { BrandPhoto } from "@/components/media/BrandPhoto";
import { formatDate, formatMoneyMinor, formatRelative, formatVolume } from "@/lib/format";

export const metadata = { title: "Design system" };

/** Every primitive and every state on one page, with static data and no
 *  database. This is the surface the DESIGN.md §9 audit is run against — a
 *  design system nobody can look at in one place drifts within a month, and
 *  the five states in §8 are exactly the ones that never get built because
 *  they are hard to reach in the real app. */
export default function StyleguidePage() {
  return (
    <main id="main" className="mx-auto w-full max-w-content px-4 py-14 md:px-6">
      <header className="mb-14">
        <h1 className="text-title-1">Design system</h1>
        <p className="mt-2 max-w-xl text-body-lg text-ink-2 text-balance">
          Every primitive and every state, rendered from the same tokens the
          product uses. If something here looks wrong, it is wrong everywhere.
        </p>
      </header>

      <Section title="Type" description="Weight drops and tracking tightens as size grows. That pairing is the whole scale.">
        <div className="space-y-6">
          <div>
            <p className="text-display">£48,290.00</p>
            <Note>display · 48/52 · 400 · −0.032em — a hero figure, nothing else</Note>
          </div>
          <div>
            <p className="text-title-1">Leads needing attention</p>
            <Note>title-1 · 32/38 · 500 · −0.024em</Note>
          </div>
          <div>
            <p className="text-title-2">This week</p>
            <Note>title-2 · 24/30 · 500</Note>
          </div>
          <div>
            <p className="text-title-3">Move protection</p>
            <Note>title-3 · 19/26 · 500</Note>
          </div>
          <div>
            <p className="max-w-xl text-body-lg">
              Reading copy sits at 17px. A quote PDF and any paragraph a customer
              is expected to read properly use this size, not the dense UI size.
            </p>
            <Note>body-lg · 17/26 · 400</Note>
          </div>
          <div>
            <p className="max-w-xl text-body">
              Default interface text. Sentence case throughout, no exclamation
              marks, and buttons that name their action in the user&rsquo;s words.
            </p>
            <Note>body · 15/22 · 400</Note>
          </div>
          <div>
            <p className="text-label text-ink-2">Owner</p>
            <Note>label · 13/18 · 500 — never uppercase with wide tracking</Note>
          </div>
        </div>
      </Section>

      <Section title="Numerals" description="Tabular figures with a slashed zero, everywhere a number can be compared or invoiced.">
        <div className="grid gap-6 sm:grid-cols-2">
          <div>
            <p className="text-label text-ink-2">Aligned (tabular)</p>
            {/* Any table, even a four-row sample, gets its own scroll box.
                Without one it pushes the whole page wide at 320px — which is
                exactly what the audit caught here. */}
            <div className="mt-2 overflow-x-auto">
            <table className="text-body-dense">
              <tbody>
                {[1_240_00, 48_090, 9_00, 102_450_00].map((minor) => (
                  <tr key={minor}>
                    <td data-numeric className="py-1 pr-6 text-right">{formatMoneyMinor(minor)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            </div>
            <Note>Columns line up because the figures are the same width</Note>
          </div>
          <div>
            <p className="text-label text-ink-2">Reference codes</p>
            <p className="mt-2 font-mono text-body-dense" data-numeric>EGM-2609-0412</p>
            <p className="font-mono text-body-dense" data-numeric>ELM-2609-0088</p>
            <Note>Read aloud over the phone — never a UUID</Note>
          </div>
        </div>
      </Section>

      <Section title="Colour" description="Near-monochrome, one accent per brand, status reserved.">
        <div className="flex flex-wrap gap-3">
          <Swatch name="accent" className="bg-accent" />
          <Swatch name="ink-1" className="bg-ink-1" />
          <Swatch name="ink-2" className="bg-ink-2" />
          <Swatch name="ink-3" className="bg-ink-3" />
          <Swatch name="sunken" className="bg-surface-sunken" bordered />
          <Swatch name="good" className="bg-status-good" />
          <Swatch name="warning" className="bg-status-warning" />
          <Swatch name="serious" className="bg-status-serious" />
          <Swatch name="critical" className="bg-status-critical" />
        </div>
        <p className="mt-4 max-w-xl text-body-dense text-ink-2">
          Chart series are fixed and deliberately <em>not</em> brand-themed. Six
          accent-tinted palettes would make the same dashboard legible in one
          brand and muddy in five.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          {/* Written out rather than interpolated: Tailwind scans source text,
              so a `bg-series-${n}` template would compile to nothing and ship a
              row of invisible swatches. */}
          {SERIES.map(({ slot, className }) => (
            <div key={slot} className="flex items-center gap-2 rounded-sm border border-hairline px-2 py-1">
              <span className={`h-3 w-3 rounded-full ${className}`} aria-hidden />
              <span className="text-caption text-ink-2" data-numeric>{slot}</span>
            </div>
          ))}
        </div>
      </Section>

      <Section title="Buttons" description="One primary per view. Separation is a hairline first.">
        <div className="flex flex-wrap items-center gap-3">
          <Button variant="primary">Send quote</Button>
          <Button variant="secondary">Save draft</Button>
          <Button variant="ghost">Cancel</Button>
          <Button variant="destructive">Mark lost</Button>
          <Button variant="primary" disabled>Sending…</Button>
          <Button variant="secondary" size="sm">Small</Button>
        </div>
      </Section>

      <Section title="Status" description="Never colour alone — every badge carries a text label.">
        <div className="flex flex-wrap gap-2">
          <Badge>new</Badge>
          <Badge tone="accent">quoted</Badge>
          <Badge tone="warning">chasing</Badge>
          <Badge tone="good">booked</Badge>
          <Badge tone="serious">payment failed</Badge>
          <Badge tone="critical">unassigned</Badge>
        </div>
      </Section>

      <Section title="Figures" description="A single KPI is a number, not a chart. Each one links through to the rows behind it.">
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatTile label="Open leads" value="47" comparison="12 more than this time last week" href="#" />
          <StatTile label="Unassigned" value="3" comparison="Anything here over 15 minutes is a problem" tone="critical" href="#" />
          <StatTile label="Booked this week" value={formatMoneyMinor(4_829_000)} href="#" />
          <StatTile label="Conversion" value="31%" comparison="Target 35%" href="#" />
        </div>
      </Section>

      <Section title="Fields" description="Label above and always visible. The helper line is reserved, so validation never shifts the layout.">
        <div className="grid max-w-2xl gap-6 sm:grid-cols-2">
          <Field label="Customer email" htmlFor="sg-email" hint="We send the quote here.">
            <TextInput id="sg-email" defaultValue="jo@example.com" />
          </Field>
          <Field label="Origin postcode" htmlFor="sg-postcode" error="We don't recognise that postcode. Check it and try again.">
            <TextInput id="sg-postcode" defaultValue="SW1A 9ZZ" invalid />
          </Field>
        </div>
      </Section>

      <Section title="Table" description="Dense, hairline-separated, zebra-free. Numeric columns right-aligned with tabular figures.">
        <Panel padded={false}>
          <DataTable caption="Sample leads" columns={COLUMNS} rows={SAMPLE} getKey={(row) => row.reference} />
        </Panel>
      </Section>

      <Section title="States" description="All five ship for every list. A screen is not done until each has been built and seen.">
        <div className="grid gap-4 lg:grid-cols-2">
          <Panel padded={false}>
            <PanelBadge>1 · Empty, first run</PanelBadge>
            <EmptyState
              title="No leads yet"
              description="Enquiries from the brand websites, phone and WhatsApp appear here the moment they arrive."
              action={<Button variant="primary">Add a lead</Button>}
            />
          </Panel>
          <Panel padded={false}>
            <PanelBadge>2 · Empty, filtered</PanelBadge>
            <FilteredEmptyState onClear={<Button variant="secondary">Show all leads</Button>} />
          </Panel>
          <Panel padded={false}>
            <PanelBadge>3 · Loading</PanelBadge>
            <div className="px-3 pb-3">
              <TableSkeleton rows={5} columns={5} />
            </div>
          </Panel>
          <Panel padded={false}>
            <PanelBadge>4 · Error</PanelBadge>
            <ErrorState
              title="Couldn't load leads"
              description="Nothing was changed. Reload to try again — if it keeps happening, raise it on the internal ticket channel."
              action={<Button variant="secondary">Reload</Button>}
            />
          </Panel>
          <Panel className="lg:col-span-2">
            <PanelHeader title="5 · Partial" description="When one panel fails, that panel says so and the rest of the page still works." />
            <div className="grid gap-4 sm:grid-cols-3">
              <StatTile label="Open leads" value="47" />
              <div className="rounded-lg border border-hairline bg-surface-raised p-5">
                <p className="text-label text-ink-2">Revenue booked</p>
                <p className="mt-2 text-body text-ink-2">Couldn&rsquo;t load.</p>
                <button type="button" className="mt-2 text-body-dense text-ink-1 underline underline-offset-4">Retry</button>
              </div>
              <StatTile label="Conversion" value="31%" />
            </div>
          </Panel>
        </div>
      </Section>

      <Section title="Photography" description="Three surfaces only, never inside data UI. Shown here in its no-asset state.">
        <div className="grid gap-4 sm:grid-cols-2">
          <BrandPhoto className="aspect-[4/3] rounded-lg" />
          <div className="flex flex-col justify-center gap-2">
            <p className="max-w-md text-body text-ink-2">
              No licensed asset is committed yet, so the slot renders a quiet
              tonal surface rather than a grey box or a broken frame. The page
              looks finished now and better once photography lands.
            </p>
            <p className="text-caption text-ink-3">
              Sourcing rules and the credits register: public/photos/CREDITS.md
            </p>
          </div>
        </div>
      </Section>

      <Section title="Loading primitives" description="Skeleton geometry matches the real content, so nothing moves when data arrives.">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-3 w-48" />
          <Skeleton className="h-3 w-32" />
          <Skeleton className="h-3 w-40" />
        </div>
      </Section>

      <footer className="mt-14 border-t border-hairline pt-6 text-caption text-ink-2">
        <p data-numeric>
          Sample formatting · {formatDate("2026-06-06")} · {formatRelative("2026-06-04T09:00:00Z", new Date("2026-06-06T09:00:00Z"))} · {formatVolume(830)}
        </p>
      </footer>
    </main>
  );
}

function Section({ title, description, children }: { title: string; description: string; children: React.ReactNode }) {
  return (
    <section className="mb-14">
      <h2 className="text-title-2">{title}</h2>
      <p className="mb-6 mt-1 max-w-xl text-body-dense text-ink-2">{description}</p>
      {children}
    </section>
  );
}

function Note({ children }: { children: React.ReactNode }) {
  return <p className="mt-1 text-caption text-ink-3">{children}</p>;
}

function PanelBadge({ children }: { children: React.ReactNode }) {
  return <p className="border-b border-hairline px-5 py-3 text-label text-ink-2">{children}</p>;
}

function Swatch({ name, className, bordered }: { name: string; className: string; bordered?: boolean }) {
  return (
    <div className="flex flex-col gap-2">
      <div className={`h-12 w-20 rounded-md ${className} ${bordered ? "border border-hairline" : ""}`} />
      <span className="text-caption text-ink-2">{name}</span>
    </div>
  );
}

const SERIES = [
  { slot: 1, className: "bg-series-1" },
  { slot: 2, className: "bg-series-2" },
  { slot: 3, className: "bg-series-3" },
  { slot: 4, className: "bg-series-4" },
  { slot: 5, className: "bg-series-5" },
  { slot: 6, className: "bg-series-6" },
  { slot: 7, className: "bg-series-7" },
  { slot: 8, className: "bg-series-8" },
] as const;

interface SampleRow {
  reference: string;
  customer: string;
  service: string;
  moveDate: string;
  value: number;
  status: "new" | "quoted" | "chasing" | "booked";
}

const SAMPLE: SampleRow[] = [
  { reference: "EGM-2609-0412", customer: "Jo Bloggs", service: "Home removals", moveDate: "2026-06-06", value: 48_000, status: "quoted" },
  { reference: "EGM-2609-0411", customer: "Northgate Property Partners Limited", service: "Office relocation", moveDate: "2026-06-19", value: 1_240_000, status: "chasing" },
  { reference: "ELM-2609-0088", customer: "Sam Patel", service: "Home removals", moveDate: "2026-07-02", value: 72_000, status: "booked" },
  { reference: "EDM-2609-0031", customer: "Rhona Stewart", service: "Storage", moveDate: "2026-07-14", value: 9_00, status: "new" },
];

const TONE = { new: "neutral", quoted: "accent", chasing: "warning", booked: "good" } as const;

const COLUMNS: readonly Column<SampleRow>[] = [
  { key: "reference", header: "Reference", width: "9rem", render: (row) => <span className="font-mono text-body-dense" data-numeric>{row.reference}</span> },
  { key: "customer", header: "Customer", render: (row) => row.customer },
  { key: "service", header: "Service", render: (row) => row.service },
  { key: "moveDate", header: "Move date", render: (row) => formatDate(row.moveDate) },
  { key: "status", header: "Status", render: (row) => <Badge tone={TONE[row.status]}>{row.status}</Badge> },
  { key: "value", header: "Quote", numeric: true, render: (row) => formatMoneyMinor(row.value) },
];
