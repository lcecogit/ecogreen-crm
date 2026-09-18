"use client";

import { useEffect, useState } from "react";

/** The one piece of chrome that is always present.
 *
 *  It carries the brand the user is looking at, a search field that doubles as
 *  the command palette entry point, and nothing else. Everything a CRM is
 *  tempted to put up here — notification bells, help menus, upgrade prompts —
 *  competes with the work. */
export function TopBar({
  brandName,
  brandCount,
  userName,
}: {
  brandName: string;
  brandCount: number;
  userName: string;
}) {
  const [shortcut, setShortcut] = useState("Ctrl K");

  useEffect(() => {
    // Rendered after mount so the server output does not depend on the
    // viewer's platform, which would mismatch on hydration.
    if (/Mac|iPhone|iPad/.test(navigator.platform)) setShortcut("⌘K");
  }, []);

  return (
    <header className="sticky top-0 z-20 flex h-14 items-center gap-4 border-b border-hairline bg-surface-canvas px-4 md:px-6">
      <div className="flex min-w-0 items-center gap-2">
        {/* The brand's own colour, at the one size where it identifies without
            competing with the data. */}
        <span
          className="h-2 w-2 shrink-0 rounded-full"
          style={{ background: "var(--brand-mark, var(--accent))" }}
          aria-hidden
        />
        <span className="truncate text-body-dense font-medium text-ink-1">{brandName}</span>
        {brandCount > 1 ? (
          <span className="shrink-0 text-caption text-ink-3">+{brandCount - 1} more</span>
        ) : null}
      </div>

      <label className="ml-auto hidden w-full max-w-sm items-center gap-2 border border-hairline px-3 py-1.5 text-body-dense text-ink-3 sm:flex">
        <span className="sr-only">Search leads, quotes, jobs and customers</span>
        <input
          type="search"
          placeholder="Search a reference, a name, a postcode…"
          className="w-full bg-transparent text-ink-1 outline-none placeholder:text-ink-3"
        />
        <kbd className="shrink-0 border border-hairline px-1.5 py-0.5 text-caption text-ink-3">
          {shortcut}
        </kbd>
      </label>

      <span className="shrink-0 text-body-dense text-ink-2">{userName}</span>
    </header>
  );
}
