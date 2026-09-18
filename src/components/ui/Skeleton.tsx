import { cn } from "@/lib/cn";

/** Skeletons match the geometry of the real content so nothing moves when the
 *  data lands — the CLS budget in DESIGN.md §9 is what this is protecting. */
export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn("animate-pulse rounded-sm bg-surface-sunken", className)}
      aria-hidden
    />
  );
}

export function TableSkeleton({ rows = 8, columns = 5 }: { rows?: number; columns?: number }) {
  return (
    <div role="status" aria-label="Loading" className="min-w-0 overflow-hidden">
      {Array.from({ length: rows }).map((_, rowIndex) => (
        <div key={rowIndex} className="flex h-9 items-center gap-6 border-b border-hairline px-3">
          {Array.from({ length: columns }).map((__, columnIndex) => (
            <Skeleton key={columnIndex} className={columnIndex === 0 ? "h-3 w-32" : "h-3 w-20"} />
          ))}
        </div>
      ))}
    </div>
  );
}
