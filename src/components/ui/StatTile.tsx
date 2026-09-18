import type { ReactNode } from "react";

import { cn } from "@/lib/cn";

/** A single KPI is a number, not a chart (DESIGN.md §7). The comparison sits
 *  beneath it in caption type, and the whole tile links through to the rows
 *  behind the figure — a KPI that cannot be drilled into gets distrusted and
 *  then ignored (SPEC.md §12). */
export function StatTile({
  label,
  value,
  comparison,
  tone = "neutral",
  href,
}: {
  label: string;
  value: string;
  comparison?: string;
  tone?: "neutral" | "good" | "critical";
  href?: string;
}) {
  const body = (
    <>
      <p className="text-label text-ink-2">{label}</p>
      <p
        data-numeric
        className={cn(
          "mt-2 text-title-1",
          tone === "good" && "text-status-good",
          tone === "critical" && "text-status-critical",
          tone === "neutral" && "text-ink-1",
        )}
      >
        {value}
      </p>
      {comparison ? <p className="mt-1 text-caption text-ink-2">{comparison}</p> : null}
    </>
  );

  const className =
    "block rounded-lg border border-hairline bg-surface-raised p-5 transition-colors duration-instant ease-standard";

  return href ? (
    <a href={href} className={cn(className, "hover:bg-surface-sunken")}>
      {body}
    </a>
  ) : (
    <div className={className}>{body}</div>
  );
}
