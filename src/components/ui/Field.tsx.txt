import React from "react";

interface FieldProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
}

export function Field({ label, id, ...props }: FieldProps) {
  const fieldId = id || label.toLowerCase().replace(/\s+/g, "-");
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={fieldId} className="text-xs font-semibold text-[var(--ink-2)]">
        {label}
      </label>
      <input
        id={fieldId}
        {...props}
        className="h-11 px-4 rounded-xl bg-[var(--surface-sunken)] border border-[var(--hairline)] text-[var(--ink-1)] text-sm placeholder:text-[var(--ink-4)] focus:outline-none focus:border-[var(--accent)] focus:bg-[var(--surface-canvas)] transition-colors"
      />
    </div>
  );
}