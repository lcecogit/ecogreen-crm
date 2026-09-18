/** Brand identity inside the CRM.
 *
 *  Deliberately narrow. An earlier version set `--accent` per brand, which
 *  meant the whole interface changed colour on a brand switch and, because the
 *  inline value outranked the theme, silently overrode dark mode — the charts
 *  rendered in the light-mode brand colour on a dark ground.
 *
 *  The product's palette now owns the interface: deep green for actions,
 *  blue-green for support, one set of chart colours everywhere. A brand is
 *  identified by its mark — a small dot beside its name — not by repainting
 *  every button. That is what keeps six brands looking like one platform, and
 *  it is why the same dashboard stays legible whichever brand is selected.
 *
 *  Per-brand colour still drives what customers see: quote PDFs, emails and
 *  the public site. Those read `brands.accent_hex` directly. */
export function BrandTheme({
  mark,
  children,
}: {
  /** The brand's own colour, used for its identifying mark only. */
  mark: string;
  children: React.ReactNode;
}) {
  return (
    <div style={{ "--brand-mark": mark } as React.CSSProperties} className="contents">
      {children}
    </div>
  );
}
