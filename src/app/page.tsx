import { brand, services, reasons } from "../lib/brand-content";
import { QuoteForm } from "../components/QuoteForm";

export default function HomePage() {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Header */}
      <header className="border-b border-[var(--hairline)] bg-[var(--surface-raised)] sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="font-bold text-lg text-[var(--accent)]">{brand.name}</span>
            <span className="text-xs text-[var(--ink-3)] hidden sm:inline">| {brand.tagline}</span>
          </div>
          <div className="flex items-center gap-4 text-sm font-medium text-[var(--ink-2)]">
            <a href={`mailto:${brand.email}`} className="hover:text-[var(--accent)] transition-colors">
              {brand.email}
            </a>
            <a
              href={`tel:${brand.branches[0].tel}`}
              className="px-4 py-2 rounded-xl bg-[var(--accent-wash)] text-[var(--accent)] hover:bg-[var(--accent)] hover:text-[var(--accent-contrast)] transition-colors"
            >
              {brand.branches[0].phone}
            </a>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <main className="flex-1">
        <section className="max-w-6xl mx-auto px-6 py-16 md:py-24 grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          <div className="flex flex-col gap-6">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[var(--teal-wash)] text-[var(--teal)] text-xs font-semibold w-fit">
              Eco-Friendly Removals Across the UK
            </div>
            <h1 className="text-4xl md:text-5xl font-bold tracking-tight text-[var(--ink-1)] leading-tight">
              {brand.headline}
            </h1>
            <p className="text-base text-[var(--ink-2)] leading-relaxed">
              {brand.subhead}
            </p>
            <ul className="flex flex-col gap-2.5 pt-2">
              {reasons.map((reason, index) => (
                <li key={index} className="flex items-center gap-2.5 text-sm text-[var(--ink-2)]">
                  <span className="w-1.5 h-1.5 rounded-full bg-[var(--accent-bright)]" />
                  {reason}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <QuoteForm />
          </div>
        </section>

        {/* Services Grid */}
        <section className="bg-[var(--surface-sunken)] py-16 border-t border-[var(--hairline)]">
          <div className="max-w-6xl mx-auto px-6 flex flex-col gap-10">
            <div className="text-center max-w-xl mx-auto flex flex-col gap-3">
              <h2 className="text-2xl font-bold text-[var(--ink-1)]">Our Relocation Services</h2>
              <p className="text-sm text-[var(--ink-2)]">Designed to make moving homes, offices, or commercial properties effortless and secure.</p>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
              {services.map((service) => (
                <div key={service.slug} className="p-6 rounded-2xl bg-[var(--surface-raised)] border border-[var(--hairline)] flex flex-col gap-3 shadow-[var(--shadow-1)]">
                  <span className="text-xs font-semibold text-[var(--teal)] bg-[var(--teal-wash)] px-2.5 py-1 rounded-md w-fit">
                    {service.tag}
                  </span>
                  <h3 className="font-semibold text-[var(--ink-1)] text-base">{service.name}</h3>
                  <p className="text-xs text-[var(--ink-2)] leading-relaxed">{service.description}</p>
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-[var(--hairline)] bg-[var(--surface-raised)] py-8">
        <div className="max-w-6xl mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-[var(--ink-3)]">
          <p>© {new Date().getFullYear()} {brand.name}. All rights reserved.</p>
          <div className="flex gap-6">
            {brand.branches.map((branch) => (
              <span key={branch.city}>
                <strong>{branch.city}:</strong> {branch.phone}
              </span>
            ))}
          </div>
        </div>
      </footer>
    </div>
  );
}
