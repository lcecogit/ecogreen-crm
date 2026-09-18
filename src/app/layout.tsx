import type { Metadata } from "next";
import "../styles/tokens.css";

export const metadata: Metadata = {
  title: "EcoGreen Movers & Removals CRM",
  description: "National and international moving services management system.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-[var(--surface-canvas)] text-[var(--ink-1)] antialiased font-sans">
        {mainLayoutWrapper(children)}
      </body>
    </html>
  );
}

function mainLayoutWrapper(children: React.ReactNode) {
  return (
    <div className="min-h-screen flex flex-col selection:bg-[var(--accent-wash)] selection:text-[var(--accent)]">
      <header className="border-b border-[var(--hairline)] bg-[var(--surface-raised)] sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="font-bold text-lg text-[var(--accent)] tracking-tight">EcoGreen CRM</span>
          </div>
          <nav className="flex items-center gap-6 text-sm font-medium text-[var(--ink-2)]">
            <span className="hover:text-[var(--accent)] cursor-pointer transition-colors">Operations</span>
            <span className="hover:text-[var(--accent)] cursor-pointer transition-colors">Leads</span>
            <span className="hover:text-[var(--accent)] cursor-pointer transition-colors">Quotations</span>
          </nav>
        </div>
      </header>
      <main className="flex-1">
        {children}
      </main>
      <footer className="border-t border-[var(--hairline)] bg-[var(--surface-sunken)] py-6 text-center text-xs text-[var(--ink-3)]">
        EcoGreen Movers & Removals &copy; 2026. All rights reserved.
      </footer>
    </div>
  );
}
