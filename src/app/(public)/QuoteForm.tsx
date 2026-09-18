"tsx"
"use client";

import React, { useState } from "react";
import { Field } from "@/components/ui/Field";

export function QuoteForm() {
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitted(true);
  };

  if (submitted) {
    return (
      <div className="p-8 rounded-2xl bg-[var(--surface-sunken)] border border-[var(--hairline)] text-center">
        <h3 className="text-xl font-bold text-[var(--accent)] mb-2">Maraming Salamat!</h3>
        <p className="text-sm text-[var(--ink-2)]">
          Natanggap na namin ang iyong kahilingan para sa quotation. Susuriin ito ng aming team at makikipag-ugnayan kami sa iyo sa lalong madaling panahon.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="p-8 rounded-2xl bg-[var(--surface-raised)] border border-[var(--hairline)] shadow-sm flex flex-col gap-6">
      <div>
        <h2 className="text-2xl font-bold text-[var(--ink-1)]">Kumuha ng Quotation</h2>
        <p className="text-sm text-[var(--ink-2)] mt-1">Punan ang mga detalye sa ibaba para sa iyong paglipat sa UK.</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Field label="Buong Pangalan" placeholder="Juan Dela Cruz" required />
        <Field label="Numero ng Telepono" type="tel" placeholder="+44 7000 000000" required />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Field label="Mula sa (Current Address / Postcode)" placeholder="Hal. London SW1A 1AA" required />
        <Field label="Patungo sa (New Address / Postcode)" placeholder="Hal. Manchester M1 1AE" required />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Field label="Petsa ng Paglipat" type="date" required />
        <Field label="Laki ng Bahay" placeholder="Hal. 3 Bedrooms" required />
      </div>

      <button
        type="submit"
        className="mt-2 h-12 px-6 rounded-xl bg-[var(--accent)] text-white font-medium hover:opacity-90 transition-opacity"
      >
        Ipadala ang Kahilingan
      </button>
    </form>
  );
}