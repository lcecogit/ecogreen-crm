export default function NotFound() {
  return (
    <main id="main" className="flex min-h-dvh flex-col items-center justify-center px-4 text-center">
      <h1 className="text-title-1">We couldn&rsquo;t find that</h1>
      <p className="mt-2 max-w-md text-body text-ink-2 text-balance">
        The page or record you followed a link to doesn&rsquo;t exist, or you don&rsquo;t have
        access to it. A 404 here is often a permissions boundary rather than a missing page.
      </p>
      <a
        href="/dashboard"
        className="mt-6 inline-flex h-11 items-center rounded-md bg-accent px-8 text-label font-medium uppercase tracking-[0.1em] text-accent-contrast transition-opacity duration-instant ease-standard hover:opacity-90"
      >
        Back to the dashboard
      </a>
    </main>
  );
}
