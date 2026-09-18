import type { ReactNode } from "react";

/** DESIGN.md §8 requires two distinct empty states, and they are genuinely
 *  different situations: "nothing exists yet, here is how to make the first
 *  one" and "your filters match nothing, here is how to clear them". Sharing
 *  one message for both is the most common version of this mistake. */
export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center px-6 py-14 text-center">
      <h3 className="text-title-3 text-ink-1">{title}</h3>
      <p className="mt-2 max-w-md text-body text-ink-2 text-balance">{description}</p>
      {action ? <div className="mt-6">{action}</div> : null}
    </div>
  );
}

export function FilteredEmptyState({ onClear }: { onClear?: ReactNode }) {
  return (
    <EmptyState
      title="Nothing matches these filters"
      description="Widen the date range or clear a filter to see more."
      action={onClear}
    />
  );
}

export function ErrorState({ title, description, action }: { title: string; description: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center px-6 py-14 text-center">
      <h3 className="text-title-3 text-ink-1">{title}</h3>
      <p className="mt-2 max-w-md text-body text-ink-2 text-balance">{description}</p>
      {action ? <div className="mt-6">{action}</div> : null}
    </div>
  );
}
