import { formatMoneyMinor } from "@/lib/format";

/** Charts, built as inline SVG with no library.
 *
 *  Rules these follow, each of which is a common way charts go wrong:
 *   · one axis, never two — two measures at different scales become two
 *     charts or a reference rule, never a second y-scale;
 *   · marks are thin, grids recessive, and text always wears an ink token
 *     rather than the series colour;
 *   · a legend appears for two or more series and the last point of each is
 *     directly labelled, so identity is never carried by colour alone;
 *   · every chart ships a table view, so the numbers are readable without
 *     colour vision or a pointer;
 *   · categorical colours are assigned in the fixed validated order, never
 *     cycled.
 *
 *  Tooltips use native SVG <title>: no JavaScript, and announced by screen
 *  readers. A richer hover layer is a later upgrade, not a prerequisite. */

const AXIS = "var(--ink-3)";
const GRID = "var(--hairline)";

function niceMax(value: number): number {
  const magnitude = 10 ** Math.floor(Math.log10(Math.max(value, 1)));
  return Math.ceil(value / magnitude) * magnitude;
}

export function Sparkline({ points, label }: { points: readonly number[]; label: string }) {
  const w = 96;
  const h = 24;
  const max = Math.max(...points);
  const min = Math.min(...points);
  const span = max - min || 1;
  const d = points
    .map((p, i) => `${i === 0 ? "M" : "L"}${(i / (points.length - 1)) * w},${h - ((p - min) / span) * (h - 4) - 2}`)
    .join(" ");
  const last = points[points.length - 1] ?? 0;

  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} role="img" aria-label={label}>
      <title>{label}</title>
      <path d={d} fill="none" stroke="var(--accent)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={w - 1} cy={h - ((last - min) / span) * (h - 4) - 2} r="2.5" fill="var(--accent)" />
    </svg>
  );
}

export interface Series {
  name: string;
  colour: string;
  values: readonly number[];
}

export function LineChart({
  title,
  labels,
  series,
  unit = "",
}: {
  title: string;
  labels: readonly string[];
  series: readonly Series[];
  unit?: string;
}) {
  const w = 640;
  const h = 200;
  const pad = { top: 12, right: 30, bottom: 26, left: 40 };
  const innerW = w - pad.left - pad.right;
  const innerH = h - pad.top - pad.bottom;
  const max = niceMax(Math.max(...series.flatMap((s) => [...s.values])));
  const x = (i: number) => pad.left + (i / Math.max(1, labels.length - 1)) * innerW;
  const y = (v: number) => pad.top + innerH - (v / max) * innerH;

  return (
    <figure className="m-0">
      <figcaption className="mb-3 flex flex-wrap items-baseline justify-between gap-3">
        <span className="text-title-3 text-ink-1">{title}</span>
        {series.length > 1 ? (
          <span className="flex flex-wrap gap-4">
            {series.map((s) => (
              <span key={s.name} className="flex items-center gap-1.5 text-caption text-ink-2">
                <span className="h-0.5 w-4" style={{ background: s.colour }} aria-hidden />
                {s.name}
              </span>
            ))}
          </span>
        ) : null}
      </figcaption>

      <svg viewBox={`0 0 ${w} ${h}`} className="w-full" role="img" aria-label={title}>
        {[0, max / 2, max].map((t) => (
          <g key={t}>
            <line x1={pad.left} x2={w - pad.right} y1={y(t)} y2={y(t)} stroke={GRID} strokeWidth="1" />
            <text x={pad.left - 8} y={y(t) + 3} textAnchor="end" fontSize="10" fill={AXIS}>
              {Math.round(t)}
            </text>
          </g>
        ))}
        {labels.map((l, i) =>
          i % 2 === 0 ? (
            <text key={l} x={x(i)} y={h - 8} textAnchor="middle" fontSize="10" fill={AXIS}>
              {l}
            </text>
          ) : null,
        )}
        {series.map((s) => (
          <g key={s.name}>
            <path
              d={s.values.map((v, i) => `${i === 0 ? "M" : "L"}${x(i)},${y(v)}`).join(" ")}
              fill="none"
              stroke={s.colour}
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            {s.values.map((v, i) => (
              <circle key={i} cx={x(i)} cy={y(v)} r="4" fill={s.colour} stroke="var(--surface-canvas)" strokeWidth="2">
                <title>{`${s.name} · ${labels[i]}: ${v}${unit}`}</title>
              </circle>
            ))}
            <text
              x={x(s.values.length - 1) + 7}
              y={y(s.values[s.values.length - 1] ?? 0) + 3}
              fontSize="10"
              fill="var(--ink-2)"
            >
              {s.values[s.values.length - 1]}
            </text>
          </g>
        ))}
      </svg>

      <TableView
        caption={title}
        head={["", ...labels]}
        rows={series.map((s) => [s.name, ...s.values.map((v) => `${v}${unit}`)])}
      />
    </figure>
  );
}

export function BarRows({
  title,
  rows,
  format = (v: number) => String(v),
}: {
  title: string;
  rows: readonly { label: string; value: number; note?: string }[];
  format?: (value: number) => string;
}) {
  const max = Math.max(...rows.map((r) => r.value)) || 1;

  return (
    <figure className="m-0">
      <figcaption className="mb-3 text-title-3 text-ink-1">{title}</figcaption>
      <ul className="flex flex-col gap-2.5">
        {rows.map((row) => (
          <li key={row.label} className="grid grid-cols-[8rem_1fr_auto] items-center gap-3">
            <span className="truncate text-body-dense text-ink-2">{row.label}</span>
            <span className="h-2.5 bg-hairline" aria-hidden>
              <span
                className="block h-2.5 rounded-r-[3px] bg-accent"
                style={{ width: `${Math.max(2, (row.value / max) * 100)}%` }}
              />
            </span>
            <span data-numeric className="whitespace-nowrap text-right text-body-dense text-ink-1">
              {format(row.value)}
              {row.note ? <span className="ml-2 text-caption text-ink-3">{row.note}</span> : null}
            </span>
          </li>
        ))}
      </ul>
      <TableView caption={title} head={["", "Value"]} rows={rows.map((r) => [r.label, format(r.value)])} />
    </figure>
  );
}

export function TargetBars({
  title,
  rows,
}: {
  title: string;
  rows: readonly { label: string; actualMinor: number; targetMinor: number }[];
}) {
  const max = Math.max(...rows.map((r) => Math.max(r.actualMinor, r.targetMinor))) || 1;

  return (
    <figure className="m-0">
      <figcaption className="mb-3 flex flex-wrap items-baseline justify-between gap-3">
        <span className="text-title-3 text-ink-1">{title}</span>
        <span className="flex gap-4 text-caption text-ink-2">
          <span className="flex items-center gap-1.5">
            <span className="h-2.5 w-3 bg-accent" aria-hidden />
            Booked
          </span>
          <span className="flex items-center gap-1.5">
            <span className="h-3 w-0.5 bg-ink-2" aria-hidden />
            Target
          </span>
        </span>
      </figcaption>

      {/* One measure, one scale. The target is a reference rule on the same
          axis — never a second y-scale. */}
      <ul className="flex flex-col gap-3">
        {rows.map((row) => {
          const pct = Math.round((row.actualMinor / row.targetMinor) * 100);
          const met = row.actualMinor >= row.targetMinor;
          return (
            <li key={row.label} className="grid grid-cols-[6.5rem_1fr_3.5rem] items-center gap-3">
              <span className="truncate text-body-dense text-ink-2">{row.label}</span>
              <span className="relative h-3 bg-hairline">
                <span
                  className="absolute left-0 top-0 block h-3 rounded-r-[3px] bg-accent"
                  style={{ width: `${(row.actualMinor / max) * 100}%` }}
                />
                <span
                  className="absolute top-[-3px] block h-[1.125rem] w-0.5 bg-ink-2"
                  style={{ left: `${(row.targetMinor / max) * 100}%` }}
                  aria-hidden
                />
              </span>
              <span
                data-numeric
                className={`text-right text-body-dense ${met ? "text-status-good-text" : "text-ink-1"}`}
              >
                {pct}%
              </span>
            </li>
          );
        })}
      </ul>
      <TableView
        caption={title}
        head={["", "Booked", "Target"]}
        rows={rows.map((r) => [r.label, formatMoneyMinor(r.actualMinor), formatMoneyMinor(r.targetMinor)])}
      />
    </figure>
  );
}

function TableView({
  caption,
  head,
  rows,
}: {
  caption: string;
  head: readonly string[];
  rows: readonly (readonly string[])[];
}) {
  return (
    <details className="mt-3">
      <summary className="cursor-pointer text-caption text-ink-3 hover:text-ink-1">Show the numbers</summary>
      <div className="mt-2 min-w-0 overflow-x-auto">
        <table className="w-full border-collapse text-caption">
          <caption className="sr-only">{caption}</caption>
          <thead>
            <tr>
              {head.map((h, i) => (
                <th
                  key={h + String(i)}
                  scope="col"
                  className={`whitespace-nowrap border-b border-hairline px-2 py-1 font-normal text-ink-3 ${i === 0 ? "text-left" : "text-right"}`}
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row[0]}>
                {row.map((cell, i) => (
                  <td
                    key={i}
                    data-numeric={i > 0 ? "" : undefined}
                    className={`whitespace-nowrap border-b border-hairline px-2 py-1 text-ink-1 ${i === 0 ? "text-left" : "text-right"}`}
                  >
                    {cell}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </details>
  );
}
