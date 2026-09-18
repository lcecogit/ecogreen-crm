import { redirect } from "next/navigation";

import { BrandTheme } from "@/components/chrome/BrandTheme";
import { SampleBanner } from "@/components/chrome/SampleBanner";
import { Sidebar, type NavGroup } from "@/components/chrome/Sidebar";
import { TopBar } from "@/components/chrome/TopBar";
import { isSampleMode } from "@/lib/sample-data";
import { createClient } from "@/lib/supabase/server";
import type { BrandRow } from "@/lib/db-types";

export const dynamic = "force-dynamic";

/** Grouped by the part of the business that owns each module, which is also
 *  how the team is split. A flat list of twenty modules cannot be scanned. */
/** The full module set for a centralised CRM, grouped by the part of the
 *  business that owns each one — which is also how the team is split.
 *
 *  Modules marked `soon` are routed but not built; they appear because the
 *  shape of the system should be visible from day one, and because a nav that
 *  grows module by module never gets grouped properly. RECOMMENDATIONS.md
 *  explains what each one is for and the order to build them in. */
const NAV: readonly NavGroup[] = [
  {
    label: "Today",
    items: [
      { href: "/dashboard", label: "Dashboard" },
      { href: "/inbox", label: "Send queue" },
      { href: "/tasks", label: "My tasks", soon: true },
    ],
  },
  {
    label: "Sales",
    items: [
      { href: "/leads", label: "Leads" },
      { href: "/quotes", label: "Quotes", soon: true },
      { href: "/surveys", label: "Surveys & video", soon: true },
      { href: "/customers", label: "Customers", soon: true },
      { href: "/accounts", label: "Corporate accounts", soon: true },
      { href: "/providers", label: "Lead providers", soon: true },
    ],
  },
  {
    label: "Pricing",
    items: [
      { href: "/rate-cards", label: "Rate cards", soon: true },
      { href: "/inventory", label: "Item catalogue", soon: true },
      { href: "/materials", label: "Packing materials", soon: true },
      { href: "/promos", label: "Promo codes", soon: true },
    ],
  },
  {
    label: "Operations",
    items: [
      { href: "/calendar", label: "Job calendar" },
      { href: "/jobs", label: "Job sheets", soon: true },
      { href: "/routes", label: "Routes & loads", soon: true },
      { href: "/fleet", label: "Fleet & vehicles", soon: true },
      { href: "/storage", label: "Storage", soon: true },
      { href: "/subcontractors", label: "Subcontractors", soon: true },
    ],
  },
  {
    label: "People",
    items: [
      { href: "/attendance", label: "Attendance", soon: true },
      { href: "/rota", label: "Rota & availability", soon: true },
      { href: "/staff", label: "Staff & skills", soon: true },
      { href: "/payroll", label: "Payroll export", soon: true },
      { href: "/training", label: "Training & compliance", soon: true },
    ],
  },
  {
    label: "Money",
    items: [
      { href: "/invoices", label: "Invoices", soon: true },
      { href: "/payments", label: "Payments", soon: true },
      { href: "/reconciliation", label: "Reconciliation", soon: true },
      { href: "/purchasing", label: "Purchasing", soon: true },
      { href: "/cashflow", label: "Cash flow", soon: true },
    ],
  },
  {
    label: "Communication",
    items: [
      { href: "/sequences", label: "Sequences", soon: true },
      { href: "/templates", label: "Templates", soon: true },
      { href: "/broadcasts", label: "Broadcasts", soon: true },
      { href: "/reviews", label: "Reviews", soon: true },
    ],
  },
  {
    label: "Compliance",
    items: [
      { href: "/documents", label: "Documents", soon: true },
      { href: "/claims", label: "Damage claims", soon: true },
      { href: "/incidents", label: "Health & safety", soon: true },
      { href: "/gdpr", label: "Data requests", soon: true },
    ],
  },
  {
    label: "Insight",
    items: [
      { href: "/reports", label: "Sales tracker", soon: true },
      { href: "/branches", label: "Branch scorecards", soon: true },
      { href: "/attribution", label: "Marketing attribution", soon: true },
      { href: "/audit", label: "Audit log", soon: true },
    ],
  },
  {
    label: "Settings",
    items: [
      { href: "/brands", label: "Brands", soon: true },
      { href: "/users", label: "Users & access", soon: true },
      { href: "/integrations", label: "Integrations", soon: true },
    ],
  },
];

export default async function StaffLayout({ children }: { children: React.ReactNode }) {
  let brands: BrandRow[] = [];
  let userName = "Sample user";

  // Without a Supabase project there is nothing to authenticate against, so
  // the app opens in sample mode rather than bouncing to a login it cannot
  // complete. With one configured, the session is enforced here and by RLS.
  if (!isSampleMode) {
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) redirect("/login");
    userName = user.email ?? "Signed in";

    const { data } = await supabase
      .from("brands")
      .select(
        "id, slug, code, name, accent_hex, accent_dark_hex, accent_text_hex, accent_text_dark_hex, accent_contrast_hex, brand_identity_confirmed",
      )
      .order("name")
      .returns<BrandRow[]>();
    brands = data ?? [];
  }

  const brand = brands[0];

  return (
    <BrandTheme mark={brand?.accent_hex ?? "#7DB903"}>
      <div className="flex min-h-dvh bg-surface-canvas">
        <aside className="hidden w-56 shrink-0 border-r border-hairline bg-surface-sunken lg:block">
          <div className="sticky top-0 flex h-14 items-center px-6">
            <span className="text-body-dense font-medium tracking-[-0.01em] text-ink-1">
              EcoGreen Group
            </span>
          </div>
          <Sidebar groups={NAV} />
        </aside>

        <div className="flex min-w-0 flex-1 flex-col">
          <TopBar
            brandName={brand?.name ?? "EcoGreen Movers"}
            brandCount={brands.length || 6}
            userName={userName}
          />
          {isSampleMode ? <SampleBanner /> : null}
          <main id="main" className="min-w-0 flex-1 px-4 py-8 md:px-6">
            {children}
          </main>
        </div>
      </div>
    </BrandTheme>
  );
}
