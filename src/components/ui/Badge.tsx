import { cn } from "@/lib/cn";

export type Tone = "neutral" | "good" | "warning" | "serious" | "critical" | "accent";

/* Status never rides on colour alone — every badge shows a text label, and the
   dot is a second channel rather than the only one (DESIGN.md §2). */
const DOT: Record<Tone, string> = {
  neutral: "bg-ink-3",
  good: "bg-status-good",
  warning: "bg-status-warning",
  serious: "bg-status-serious",
  critical: "bg-status-critical",
  accent: "bg-accent",
};

export function Badge({ tone = "neutral", children }: { tone?: Tone; children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center gap-2 rounded-sm border border-hairline px-2 py-1 text-caption text-ink-2">
      <span className={cn("h-1.5 w-1.5 shrink-0 rounded-full", DOT[tone])} aria-hidden />
      {children}
    </span>
  );
}
