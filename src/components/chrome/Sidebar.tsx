"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/cn";

export interface NavItem {
  href: string;
  label: string;
  /** Routed but not built. Shown greyed rather than hidden: the shape of the
   *  system should be visible from day one, and a nav that grows one module at
   *  a time never gets grouped properly. */
  soon?: boolean;
}

export interface NavGroup {
  label: string;
  items: readonly NavItem[];
}

/** Grouped navigation for a centralised CRM.
 *
 *  Twenty-odd modules in one flat list is unscannable, so they are grouped by
 *  the part of the business that owns them — which is also how the team is
 *  organised. Sentence case, no icons competing with the labels, and one quiet
 *  accent mark on the active item. The group headings are not uppercase: at
 *  11px, tracked-out capitals are the least legible thing on the screen and
 *  the first thing that dates an interface. */
export function Sidebar({ groups }: { groups: readonly NavGroup[] }) {
  const pathname = usePathname();

  return (
    <nav aria-label="Main" className="flex flex-col gap-6 px-3 py-5">
      {groups.map((group) => (
        <div key={group.label} className="flex flex-col gap-0.5">
          <p className="px-3 pb-2 text-caption text-ink-3">{group.label}</p>
          {group.items.map((item) => {
            const active = pathname === item.href || pathname.startsWith(`${item.href}/`);

            if (item.soon) {
              // ink-3, not the disabled step: greyed nav labels that cannot be
              // read are a contrast failure, and "planned" is carried by the
              // word beside the label rather than by colour alone.
              return (
                <span
                  key={item.href}
                  className="flex items-baseline justify-between gap-2 px-3 py-1.5 text-body-dense text-ink-3"
                >
                  {item.label}
                  <span className="text-caption text-ink-3">soon</span>
                </span>
              );
            }

            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "relative px-3 py-1.5 text-body-dense transition-colors duration-instant ease-standard",
                  active ? "font-medium text-ink-1" : "text-ink-2 hover:text-ink-1",
                )}
              >
                {active ? (
                  <span className="absolute left-0 top-1/2 h-4 w-0.5 -translate-y-1/2 bg-accent" aria-hidden />
                ) : null}
                {item.label}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );
}
