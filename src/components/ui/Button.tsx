import { forwardRef } from "react";
import type { ButtonHTMLAttributes } from "react";

import { cn } from "@/lib/cn";

type Variant = "primary" | "secondary" | "ghost" | "destructive";
type Size = "sm" | "md";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
}

/* One primary per view (DESIGN.md §5). Separation is a hairline first; the
   secondary variant carries no fill at all.

   The primary follows ecogreenmovers.co.uk exactly — the brand lime, square,
   with a 1px border of its own colour — except for the label, which is navy
   rather than white. White on that lime measures 2.38:1 and fails AA; the
   brand's own navy on the same lime is 7.14:1. The hue is the site's; only
   the thing sitting on top of it changed. */
const VARIANTS: Record<Variant, string> = {
  primary:
    "bg-accent text-accent-contrast border border-accent hover:bg-accent-hover hover:border-accent-hover",
  secondary:
    "bg-transparent text-ink-1 border border-hairline hover:bg-surface-sunken active:bg-surface-sunken",
  ghost: "bg-transparent text-ink-2 hover:bg-surface-sunken hover:text-ink-1",
  destructive:
    "bg-transparent text-status-critical-text border border-hairline hover:bg-surface-sunken",
};

const SIZES: Record<Size, string> = {
  // 44px and 36px: the first clears the touch-target floor, the second is for
  // dense staff toolbars where a pointer is a given. The generous horizontal
  // padding follows the site, which sets 42px on its buttons.
  md: "h-11 px-8 text-label",
  sm: "h-9 px-5 text-caption",
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = "secondary", size = "md", className, type = "button", ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-md",
        // Uppercase with wide tracking is banned on micro-labels (DESIGN.md
        // §1) but is the brand's signature on buttons, where the string is
        // short enough that legibility is unaffected. A documented exception,
        // scoped to this component.
        "font-medium uppercase tracking-[0.1em]",
        "transition-colors duration-instant ease-standard",
        "disabled:cursor-not-allowed disabled:opacity-40",
        VARIANTS[variant],
        SIZES[size],
        className,
      )}
      {...props}
    />
  );
});
