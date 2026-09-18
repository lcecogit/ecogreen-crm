/** Money is integer minor units plus a currency. Never a float: a float
 *  penny error compounds across a quote's lines and surfaces as a customer
 *  dispute months later. Every arithmetic helper here rounds explicitly. */

export type CurrencyCode = "GBP" | "EUR" | "USD";

export interface Money {
  readonly minor: number;
  readonly currency: CurrencyCode;
}

export function money(minor: number, currency: CurrencyCode = "GBP"): Money {
  if (!Number.isInteger(minor)) {
    throw new Error(`Money must be integer minor units, received ${minor}`);
  }
  return { minor, currency };
}

export const zero = (currency: CurrencyCode = "GBP"): Money => money(0, currency);

function assertSameCurrency(a: Money, b: Money): void {
  if (a.currency !== b.currency) {
    throw new Error(`Cannot combine ${a.currency} with ${b.currency}`);
  }
}

export function add(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return money(a.minor + b.minor, a.currency);
}

export function subtract(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return money(a.minor - b.minor, a.currency);
}

export function sum(items: readonly Money[], currency: CurrencyCode = "GBP"): Money {
  return items.reduce<Money>((acc, item) => add(acc, item), zero(currency));
}

/** Half-up rounding, applied once per line rather than once per quote, so the
 *  printed lines always add up to the printed total. */
export function multiply(a: Money, factor: number): Money {
  return money(Math.round(a.minor * factor), a.currency);
}

export function max(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return a.minor >= b.minor ? a : b;
}

export function isZero(a: Money): boolean {
  return a.minor === 0;
}

const SYMBOLS: Record<CurrencyCode, string> = { GBP: "£", EUR: "€", USD: "$" };

/** One formatter for the whole product. Always two decimals, always a symbol,
 *  never abbreviated — DESIGN.md §1: abbreviation belongs on a chart axis, not
 *  beside a figure someone is about to invoice. */
export function formatMoney(value: Money): string {
  const negative = value.minor < 0;
  const abs = Math.abs(value.minor);
  const units = Math.floor(abs / 100);
  const pence = String(abs % 100).padStart(2, "0");
  const grouped = units.toLocaleString("en-GB");
  return `${negative ? "-" : ""}${SYMBOLS[value.currency]}${grouped}.${pence}`;
}

/** VAT is computed from the net line, never back-derived from a gross total,
 *  so a rounded net and its VAT always reconcile on the invoice. */
export interface VatSplit {
  readonly net: Money;
  readonly vat: Money;
  readonly gross: Money;
  readonly rate: number;
}

export function applyVat(net: Money, rate: number): VatSplit {
  const vat = multiply(net, rate);
  return { net, vat, gross: add(net, vat), rate };
}
