"use client";

import { Button } from "@/components/ui/Button";

/** Says what happened and what to do, in that order. No raw exception, no bare
 *  status code (DESIGN.md §8). */
export default function GlobalError({ reset }: { error: Error; reset: () => void }) {
  return (
    <main id="main" className="flex min-h-dvh flex-col items-center justify-center px-4 text-center">
      <h1 className="text-title-1">Something went wrong</h1>
      <p className="mt-2 max-w-md text-body text-ink-2 text-balance">
        This page didn&rsquo;t load. Nothing you were working on has been lost — try again, and if
        it keeps happening, raise it on the internal ticket channel.
      </p>
      <Button variant="primary" className="mt-6" onClick={reset}>
        Try again
      </Button>
    </main>
  );
}
