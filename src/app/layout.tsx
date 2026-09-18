import type { Metadata, Viewport } from "next";
import { GeistMono } from "geist/font/mono";

// Inter — the typeface ecogreenmovers.co.uk uses for body, headings and
// buttons. Self-hosted from npm rather than Google Fonts, which is blocked
// both by this environment's egress policy and by the artifact CSP, and which
// would cost a third-party request and a layout shift either way.
import "@fontsource-variable/inter";
import "./globals.css";

/* One typeface across all six brands, deliberately. The group's other sites
   use different faces where they are branded at all (Glasgow Moving sets
   Instrument Sans, Removals Company Manchester sets Heebo), but a CRM that
   changes typeface when a user switches brand reads as six products rather
   than one platform. Brand identity travels through the accent, the logo and
   the document templates instead. Geist Mono stays for reference codes and
   figures — a need the marketing sites do not have. */

export const metadata: Metadata = {
  title: { default: "Operations", template: "%s · Operations" },
  description: "Internal operations platform.",
  // A private application. Never indexable, in any environment.
  robots: { index: false, follow: false, nocache: true },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en-GB" className={GeistMono.variable}>
      <body className="min-h-dvh bg-surface-canvas text-ink-1 antialiased">
        <a
          href="#main"
          className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-accent focus:px-4 focus:py-2 focus:text-accent-contrast"
        >
          Skip to main content
        </a>
        {children}
      </body>
    </html>
  );
}
