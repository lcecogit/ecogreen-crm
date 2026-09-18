"use client";

import { useState, type FormEvent } from "react";

import { Field, TextInput } from "@/components/ui/Field";
import { services } from "@/lib/brand-content";

/** The enquiry form. This is the real front door of the pipeline: on submit it
 *  posts the same shape `/api/intake/lead` accepts, so a submission becomes a
 *  routed, scored, de-duplicated lead with an acknowledgement — at any hour.
 *
 *  Two behaviours matter more than the styling:
 *
 *   1. It never claims success it did not get. A failure says so and keeps
 *      everything the customer typed, because a form that silently loses an
 *      enquiry is the leak this whole platform exists to close.
 *   2. Only the name and one way of contacting them are required. Every field
 *      we insist on costs enquiries, and the rest can be asked on the call. */
export function QuoteForm() {
  const [status, setStatus] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [reference, setReference] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setStatus("sending");

    const payload = {
      brand_slug: "ecogreen-movers",
      idempotency_key: `web-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`,
      first_name: String(data.get("first_name") ?? ""),
      last_name: String(data.get("last_name") ?? ""),
      email: String(data.get("email") ?? ""),
      phone: String(data.get("phone") ?? ""),
      service_slug: String(data.get("service") ?? ""),
      move_date: String(data.get("move_date") ?? ""),
      origin_postcode: String(data.get("origin_postcode") ?? ""),
      destination_postcode: String(data.get("destination_postcode") ?? ""),
      message: String(data.get("message") ?? ""),
      source_name: "Quote page",
      landing_page: typeof window === "undefined" ? undefined : window.location.pathname,
    };

    try {
      const response = await fetch("/api/intake/lead", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!response.ok) throw new Error(String(response.status));
      const body: { reference?: string } = await response.json();
      setReference(body.reference ?? null);
      setStatus("sent");
      form.reset();
    } catch {
      // Deliberately leaves the form populated: the customer should never have
      // to retype a move they have already described.
      setStatus("error");
    }
  }

  if (status === "sent") {
    return (
      <div className="border border-hairline bg-surface-sunken p-8">
        <p className="text-eyebrow uppercase text-accent-text">Enquiry received</p>
        <h3 className="mt-3 text-title-2 text-ink-1">We&rsquo;ve got it — thank you.</h3>
        <p className="mt-3 max-w-[52ch] text-prose text-ink-2">
          A member of the team will come back to you with a fixed price. If your move is urgent,
          call your nearest branch and quote{" "}
          {reference ? (
            <span data-numeric className="font-mono text-ink-1">
              {reference}
            </span>
          ) : (
            "your name"
          )}
          .
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="border border-hairline bg-surface-raised p-6 md:p-8">
      <div className="grid gap-x-6 sm:grid-cols-2">
        <Field label="First name" htmlFor="first_name" required>
          <TextInput id="first_name" name="first_name" autoComplete="given-name" required />
        </Field>
        <Field label="Last name" htmlFor="last_name">
          <TextInput id="last_name" name="last_name" autoComplete="family-name" />
        </Field>
        <Field label="Email" htmlFor="email" hint="We send your written quote here.">
          <TextInput id="email" name="email" type="email" autoComplete="email" />
        </Field>
        <Field label="Phone" htmlFor="phone" hint="Either email or phone is enough.">
          <TextInput id="phone" name="phone" type="tel" autoComplete="tel" />
        </Field>
        <Field label="Moving from" htmlFor="origin_postcode" hint="Postcode is enough to start.">
          <TextInput id="origin_postcode" name="origin_postcode" placeholder="M1 1AE" />
        </Field>
        <Field label="Moving to" htmlFor="destination_postcode">
          <TextInput id="destination_postcode" name="destination_postcode" placeholder="EH1 1AA" />
        </Field>
        <Field label="What kind of move" htmlFor="service">
          <select
            id="service"
            name="service"
            aria-describedby="service-hint"
            className="h-11 w-full border border-hairline bg-surface-raised px-4 text-body text-ink-1"
            defaultValue={services[0].slug}
          >
            {services.map((service) => (
              <option key={service.slug} value={service.slug}>
                {service.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Preferred date" htmlFor="move_date" hint="Approximate is fine.">
          <TextInput id="move_date" name="move_date" type="date" />
        </Field>
      </div>

      <Field
        label="Anything we should know"
        htmlFor="message"
        hint="Narrow stairs, no lift, a piano, parking restrictions — the things that change the price."
      >
        <textarea
          id="message"
          name="message"
          rows={4}
          aria-describedby="message-hint"
          className="w-full border border-hairline bg-surface-raised p-4 text-body text-ink-1 placeholder:text-ink-3"
          placeholder="Third floor, no lift. One upright piano."
        />
      </Field>

      <div className="mt-2 flex flex-wrap items-center gap-4">
        <button
          type="submit"
          disabled={status === "sending"}
          className="inline-flex h-12 items-center border border-accent bg-accent px-8 text-label font-medium uppercase tracking-[0.1em] text-accent-contrast transition-colors duration-instant ease-standard hover:border-accent-hover hover:bg-accent-hover disabled:cursor-not-allowed disabled:opacity-50"
        >
          {status === "sending" ? "Sending…" : "Send my enquiry"}
        </button>
        <p className="text-caption text-ink-3">No obligation. We don&rsquo;t pass your details on.</p>
      </div>

      <p role="status" aria-live="polite" className="mt-4 text-body-dense text-status-critical-text">
        {status === "error"
          ? "That didn't send. Nothing you typed has been lost — try again, or call your nearest branch and we'll take the details over the phone."
          : ""}
      </p>
    </form>
  );
}
