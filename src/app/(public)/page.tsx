import { BrandPhoto } from "@/components/media/BrandPhoto";
import { brand, caseStudies, photos, reasons, services, testimonials } from "@/lib/brand-content";

import { QuoteForm } from "./QuoteForm";

export const metadata = { title: brand.name };

/** The customer-facing quote funnel.
 *
 *  This is the page the six brand websites link into and the embeddable widget
 *  frames. It is not a replacement for ecogreenmovers.co.uk — those pages rank
 *  and stay where they are (SPEC.md §1, decision 4). This is the surface where
 *  an enquiry becomes a lead, so it is built against the intake API and styled
 *  from the same brand kit the marketing site uses: a customer arriving here
 *  from the site should not feel the type or the colour change under them.
 *
 *  No price appears anywhere. The rate card is still provisional
 *  (DECISIONS.md §2), and this business quotes a fixed price rather than
 *  publishing one — inventing a "from £X" would be both wrong and off-brand.
 */
export default function QuotePage() {
  return (
    <div className="bg-surface-canvas">
      <SiteHeader />

      {/* ── Hero ─────────────────────────────────────────────────────────── */}
      <section className="border-b border-hairline">
        <Shell className="grid gap-10 py-14 lg:grid-cols-[1.05fr_0.95fr] lg:items-center lg:py-20">
          <div>
            <p className="text-eyebrow uppercase text-accent-text">
              Residential · Commercial · Office
            </p>
            <h1 className="mt-5 max-w-[18ch] text-hero-sm text-ink-1 text-balance md:text-hero">
              {brand.headline}
            </h1>
            <p className="mt-6 max-w-[54ch] text-prose-lg text-ink-2">{brand.subhead}</p>

            <div className="mt-8 flex flex-wrap gap-3">
              <a
                href="#quote-form"
                className="inline-flex h-12 items-center border border-accent bg-accent px-8 text-label font-medium uppercase tracking-[0.1em] text-accent-contrast transition-colors duration-instant ease-standard hover:border-accent-hover hover:bg-accent-hover"
              >
                Get your moving quote
              </a>
              <a
                href="#services"
                className="inline-flex h-12 items-center border border-hairline-strong px-8 text-label font-medium uppercase tracking-[0.1em] text-ink-1 transition-colors duration-instant ease-standard hover:bg-surface-sunken"
              >
                What we move
              </a>
            </div>

            <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-2 text-body-dense text-ink-2">
              <span className="flex items-center gap-2">
                <Stars />
                Rated five stars by movers across the UK
              </span>
              <span className="hidden h-4 w-px bg-hairline sm:block" aria-hidden />
              <span>Fixed price agreed before the move</span>
            </div>
          </div>

          {/* The floating detail card, the one piece of the reference layout
              worth keeping literally: it answers "can you actually do my move"
              before the visitor has scrolled. */}
          <div className="relative">
            <BrandPhoto
              className="aspect-[4/3] w-full"
              src={photos.hero.src}
              alt={photos.hero.alt}
              sizes="(max-width: 1024px) 100vw, 46vw"
              priority
            />
            <div className="mt-4 border border-hairline bg-surface-raised p-5 lg:absolute lg:-bottom-8 lg:left-6 lg:mt-0 lg:w-[22rem] lg:shadow-2">
              <p className="text-eyebrow uppercase text-ink-3">Speak to your nearest branch</p>
              <ul className="mt-3 flex flex-col gap-2">
                {brand.branches.map((branch) => (
                  <li key={branch.city} className="flex items-baseline justify-between gap-4">
                    <span className="text-body text-ink-1">{branch.city}</span>
                    <a
                      href={`tel:${branch.tel}`}
                      data-numeric
                      className="text-body text-accent-text underline-offset-4 hover:underline"
                    >
                      {branch.phone}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </Shell>
      </section>

      {/* ── Services ─────────────────────────────────────────────────────── */}
      <Section id="services" eyebrow="Our services" title="Moves we take on" lead="Four services, each with its own crew, kit and method — not one team doing everything.">
        <div className="grid gap-px border border-hairline bg-hairline sm:grid-cols-2">
          {services.map((service, index) => {
            const image =
              index === 0 ? photos.residential : index === 3 ? photos.packing : null;
            return (
              <article key={service.slug} className="flex flex-col bg-surface-canvas">
                {image ? (
                  <BrandPhoto
                    className="aspect-[16/9] w-full"
                    src={image.src}
                    alt={image.alt}
                    sizes="(max-width: 640px) 100vw, 50vw"
                  />
                ) : null}
                <div className="flex flex-col gap-3 p-7">
                  <p className="text-eyebrow uppercase text-ink-3">{service.tag}</p>
                  <h3 className="text-title-2 text-ink-1">{service.name}</h3>
                  <p className="text-prose text-ink-2">{service.description}</p>
                </div>
              </article>
            );
          })}
        </div>
      </Section>

      {/* ── Why ──────────────────────────────────────────────────────────── */}
      <section className="border-y border-hairline bg-surface-sunken">
        <Shell className="grid gap-10 py-14 lg:grid-cols-2 lg:py-20">
          <div>
            <p className="text-eyebrow uppercase text-accent-text">Why choose us</p>
            <h2 className="mt-4 max-w-[20ch] text-title-1 text-ink-1 text-balance">
              A removals company that actually turns up
            </h2>
            <ul className="mt-7 flex flex-col gap-4">
              {reasons.map((reason) => (
                <li key={reason} className="flex gap-3 text-prose text-ink-2">
                  <Tick />
                  <span>{reason}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="flex flex-col gap-4">
            {testimonials.map((item) => (
              <figure key={item.author} className="border border-hairline bg-surface-canvas p-6">
                <Stars />
                <blockquote className="mt-3 text-prose text-ink-1">“{item.quote}”</blockquote>
                <figcaption className="mt-4 text-caption text-ink-3">
                  {item.author} · {item.context}
                </figcaption>
              </figure>
            ))}
          </div>
        </Shell>
      </section>

      {/* ── Specialist work ──────────────────────────────────────────────── */}
      <Section
        id="specialist"
        eyebrow="Specialist work"
        title="The moves other firms turn down"
        lead="Medical equipment, fine art, server racks and pianos, handled under their own protocols."
      >
        <BrandPhoto
          className="mb-px aspect-[21/9] w-full"
          src={photos.specialist.src}
          alt={photos.specialist.alt}
          sizes="100vw"
        />
        <div className="grid gap-px border border-hairline bg-hairline sm:grid-cols-2 lg:grid-cols-4">
          {caseStudies.map((study) => (
            <article key={study.title} className="flex flex-col gap-2 bg-surface-canvas p-6">
              <p className="text-eyebrow uppercase text-ink-3">{study.place}</p>
              <h3 className="text-title-3 text-ink-1">{study.title}</h3>
              <p className="text-body-dense text-ink-2">{study.detail}</p>
            </article>
          ))}
        </div>
      </Section>

      {/* ── How pricing works ────────────────────────────────────────────── */}
      <section id="pricing" className="scroll-mt-20 border-y border-hairline bg-surface-sunken">
        <Shell className="py-14 lg:py-20">
          <p className="text-eyebrow uppercase text-accent-text">How pricing works</p>
          <h2 className="mt-4 max-w-[24ch] text-title-1 text-ink-1 text-balance">
            One fixed price, agreed before we load anything
          </h2>
          <div className="mt-8 grid gap-px border border-hairline bg-hairline md:grid-cols-3">
            {[
              {
                step: "01",
                title: "Tell us what you're moving",
                body: "Room by room, or send a video walkthrough. The more we see, the tighter the price.",
              },
              {
                step: "02",
                title: "We price it properly",
                body: "Volume, distance, access and crew — every line itemised, so you can see what you're paying for.",
              },
              {
                step: "03",
                title: "The price is locked",
                body: "Accept it and that is what you pay. No day-of surprises, no rounding up at the door.",
              },
            ].map((item) => (
              <article key={item.step} className="flex flex-col gap-3 bg-surface-canvas p-7">
                <span data-numeric className="text-eyebrow text-accent-text">
                  {item.step}
                </span>
                <h3 className="text-title-3 text-ink-1">{item.title}</h3>
                <p className="text-prose text-ink-2">{item.body}</p>
              </article>
            ))}
          </div>
        </Shell>
      </section>

      {/* ── Quote form ───────────────────────────────────────────────────── */}
      <Section
        id="quote-form"
        eyebrow="Get a quote"
        title="Tell us about your move"
        lead="We'll come back with a fixed price. No obligation, and no call centre."
      >
        <QuoteForm />
      </Section>

      <SiteFooter />
    </div>
  );
}

function Shell({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <div className={`mx-auto w-full max-w-content px-4 md:px-6 ${className}`}>{children}</div>;
}

function Section({
  id,
  eyebrow,
  title,
  lead,
  children,
}: {
  id?: string;
  eyebrow: string;
  title: string;
  lead: string;
  children: React.ReactNode;
}) {
  return (
    <section id={id} className="scroll-mt-20">
      <Shell className="py-14 lg:py-20">
        <p className="text-eyebrow uppercase text-accent-text">{eyebrow}</p>
        <h2 className="mt-4 max-w-[22ch] text-title-1 text-ink-1 text-balance">{title}</h2>
        <p className="mt-3 max-w-[60ch] text-prose text-ink-2">{lead}</p>
        <div className="mt-8">{children}</div>
      </Shell>
    </section>
  );
}

function SiteHeader() {
  return (
    <header className="sticky top-0 z-20 border-b border-hairline bg-surface-canvas/95 backdrop-blur">
      <Shell className="flex h-16 items-center gap-6">
        <span className="text-body font-medium tracking-[-0.01em] text-ink-1">{brand.name}</span>
        <nav aria-label="Sections" className="hidden items-center gap-6 md:flex">
          {[
            ["Services", "#services"],
            ["Specialist work", "#specialist"],
            ["How pricing works", "#pricing"],
          ].map(([label, href]) => (
            <a
              key={label}
              href={href}
              className="text-body-dense text-ink-2 transition-colors duration-instant ease-standard hover:text-ink-1"
            >
              {label}
            </a>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-4">
          <a
            href="/login"
            className="hidden text-body-dense text-ink-2 transition-colors duration-instant ease-standard hover:text-ink-1 md:block"
          >
            Staff login
          </a>
          <a
            href={`tel:${brand.branches[0].tel}`}
            data-numeric
            className="hidden text-body-dense text-ink-1 sm:block"
          >
            {brand.branches[0].phone}
          </a>
          <a
            href="#quote-form"
            className="inline-flex h-10 items-center border border-accent bg-accent px-6 text-caption font-medium uppercase tracking-[0.1em] text-accent-contrast transition-colors duration-instant ease-standard hover:border-accent-hover hover:bg-accent-hover"
          >
            Get a quote
          </a>
        </div>
      </Shell>
    </header>
  );
}

function SiteFooter() {
  return (
    <footer className="border-t border-hairline bg-surface-raised">
      <Shell className="flex flex-col gap-8 py-12 md:flex-row md:justify-between">
        <div className="max-w-sm">
          <p className="text-body font-medium text-ink-1">{brand.name}</p>
          <p className="mt-2 text-body-dense text-ink-2">{brand.tagline}</p>
          <a
            href={`mailto:${brand.email}`}
            className="mt-3 inline-block text-body-dense text-accent-text underline-offset-4 hover:underline"
          >
            {brand.email}
          </a>
        </div>
        <div>
          <p className="text-eyebrow uppercase text-ink-3">Branches</p>
          <ul className="mt-3 flex flex-col gap-2">
            {brand.branches.map((b) => (
              <li key={b.city} className="flex gap-3 text-body-dense">
                <span className="w-24 text-ink-2">{b.city}</span>
                <a href={`tel:${b.tel}`} data-numeric className="text-ink-1">
                  {b.phone}
                </a>
              </li>
            ))}
          </ul>
        </div>
        <div>
          <p className="text-eyebrow uppercase text-ink-3">Staff</p>
          <a
            href="/login"
            className="mt-3 inline-block text-body-dense text-ink-1 underline-offset-4 hover:underline"
          >
            Staff login →
          </a>
        </div>
      </Shell>
    </footer>
  );
}

function Stars() {
  return (
    <span className="inline-flex gap-0.5" role="img" aria-label="Five out of five stars">
      {[0, 1, 2, 3, 4].map((i) => (
        <svg key={i} width="14" height="14" viewBox="0 0 20 20" aria-hidden className="fill-accent">
          <path d="M10 1.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L10 14.9 4.8 17.6l1-5.8L1.5 7.7l5.9-.9L10 1.5z" />
        </svg>
      ))}
    </span>
  );
}

function Tick() {
  return (
    <svg width="18" height="18" viewBox="0 0 20 20" aria-hidden className="mt-1 shrink-0 fill-accent-text">
      <path d="M8.1 14.4L3.7 10l1.4-1.4 3 3 6.8-6.8L16.3 6z" />
    </svg>
  );
}
