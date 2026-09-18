/** Time is injected, never read from the ambient environment, so every
 *  pricing, chasing and expiry decision is reproducible in a test and
 *  re-derivable months later when a customer queries a quote. */
export interface Clock {
  now(): Date;
}

export const systemClock: Clock = { now: () => new Date() };

export function fixedClock(iso: string): Clock {
  const at = new Date(iso);
  if (Number.isNaN(at.getTime())) throw new Error(`Invalid fixed clock: ${iso}`);
  return { now: () => new Date(at) };
}

/** UK wall-clock parts for a given instant. The whole business runs in one
 *  timezone; quiet hours, peak-season dates and job scheduling all resolve
 *  against Europe/London rather than the server's locale. */
export interface UkParts {
  readonly year: number;
  readonly month: number; // 1-12
  readonly day: number; // 1-31
  readonly weekday: number; // 0 = Sunday
  readonly hour: number; // 0-23
  readonly minute: number;
}

const UK_FORMAT = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/London",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  weekday: "short",
  hour12: false,
});

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] as const;

export function ukParts(at: Date): UkParts {
  const parts = new Map(
    UK_FORMAT.formatToParts(at).map((part) => [part.type, part.value] as const),
  );
  const read = (key: Intl.DateTimeFormatPartTypes): string => parts.get(key) ?? "0";
  const weekdayIndex = WEEKDAYS.indexOf(read("weekday") as (typeof WEEKDAYS)[number]);
  return {
    year: Number(read("year")),
    month: Number(read("month")),
    day: Number(read("day")),
    weekday: weekdayIndex === -1 ? 0 : weekdayIndex,
    // Intl renders midnight as "24" in some en-GB/hour12:false combinations.
    hour: Number(read("hour")) % 24,
    minute: Number(read("minute")),
  };
}

export function isWeekend(at: Date): boolean {
  const day = ukParts(at).weekday;
  return day === 0 || day === 6;
}

export function addMinutes(at: Date, minutes: number): Date {
  return new Date(at.getTime() + minutes * 60_000);
}

export function addHours(at: Date, hours: number): Date {
  return addMinutes(at, hours * 60);
}

export function addDays(at: Date, days: number): Date {
  return addHours(at, days * 24);
}

export function daysBetween(from: Date, to: Date): number {
  return Math.round((to.getTime() - from.getTime()) / 86_400_000);
}
