/** Presentation formatting. One place, so a date or a price never renders two
 *  ways in the same product. DESIGN.md §1 is the contract these implement. */

const CURRENCY_SYMBOL: Record<string, string> = { GBP: "£", EUR: "€", USD: "$" };

/** Always two decimals, always a symbol, never abbreviated. */
export function formatMoneyMinor(minor: number, currency = "GBP"): string {
  const negative = minor < 0;
  const abs = Math.abs(minor);
  const units = Math.floor(abs / 100).toLocaleString("en-GB");
  const pence = String(abs % 100).padStart(2, "0");
  return `${negative ? "-" : ""}${CURRENCY_SYMBOL[currency] ?? ""}${units}.${pence}`;
}

const DATE = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/London",
  day: "numeric",
  month: "short",
  year: "numeric",
});

const DATE_TIME = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/London",
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});

export function formatDate(value: string | Date | null | undefined): string {
  if (!value) return "—";
  const date = typeof value === "string" ? new Date(value) : value;
  return Number.isNaN(date.getTime()) ? "—" : DATE.format(date);
}

export function formatDateTime(value: string | Date | null | undefined): string {
  if (!value) return "—";
  const date = typeof value === "string" ? new Date(value) : value;
  return Number.isNaN(date.getTime()) ? "—" : DATE_TIME.format(date);
}

/** "2 hours ago" / "in 3 days". Used beside, never instead of, the absolute
 *  time — a relative stamp alone is useless in a dispute. */
const RELATIVE = new Intl.RelativeTimeFormat("en-GB", { numeric: "auto" });

export function formatRelative(value: string | Date, now = new Date()): string {
  const date = typeof value === "string" ? new Date(value) : value;
  const seconds = (date.getTime() - now.getTime()) / 1000;
  const units: [Intl.RelativeTimeFormatUnit, number][] = [
    ["year", 31_536_000],
    ["month", 2_592_000],
    ["day", 86_400],
    ["hour", 3_600],
    ["minute", 60],
  ];
  for (const [unit, size] of units) {
    if (Math.abs(seconds) >= size) return RELATIVE.format(Math.round(seconds / size), unit);
  }
  return RELATIVE.format(Math.round(seconds), "second");
}

export function formatVolume(ft3: number): string {
  const m3 = ft3 / 35.3147;
  return `${ft3.toLocaleString("en-GB")} ft³ · ${m3.toFixed(1)} m³`;
}

export function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}
