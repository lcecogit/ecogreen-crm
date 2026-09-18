import { cn } from "@/lib/cn";

/** Lead score as a number with a quiet track behind it.
 *
 *  The number is the value; the bar exists only so a column of scores can be
 *  compared without reading each one. Deliberately not colour-coded by band —
 *  a red score reads as "bad lead" when it usually means "small job, still
 *  worth an hour". */
export function ScoreBar({ score }: { score: number }) {
  return (
    <span className="inline-flex items-center gap-2">
      <span data-numeric className="w-6 text-right text-body-dense text-ink-1">
        {score}
      </span>
      <span className="h-1 w-10 bg-hairline" aria-hidden>
        <span
          className={cn("block h-1", score >= 70 ? "bg-accent" : "bg-ink-3")}
          style={{ width: `${score}%` }}
        />
      </span>
    </span>
  );
}
