import type { InputHTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/cn";

export function Field({ label, htmlFor, hint, error, required, children }: { label: string; htmlFor: string; hint?: string; error?: string; required?: boolean; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-2">
      <label htmlFor={htmlFor} className="text-label text-ink-1">
        {label}{required ? <span className="ml-1 text-ink-3">(required)</span> : null}
      </label>
      {children}
      <p id={`${htmlFor}-hint`} className={cn("min-h-4 text-caption", error ? "text-status-critical-text" : "text-ink-2")}>
        {error ?? hint ?? " "}
      </p>
    </div>
  );
}

export function TextInput({ invalid, className, ...props }: InputHTMLAttributes<HTMLInputElement> & { invalid?: boolean }) {
  return <input aria-invalid={invalid || undefined} aria-describedby={props.id ? `${props.id}-hint` : undefined} className={cn("h-11 w-full rounded-md border bg-surface-raised px-4 text-body text-ink-1", "placeholder:text-ink-3", "transition-colors duration-instant ease-standard", invalid ? "border-status-critical-text" : "border-hairline", className)} {...props} />;
}
