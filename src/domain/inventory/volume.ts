import { findItem, isSpecialist, type HandlingClass } from "./catalogue";

/** A line the customer built in the inventory selector. `customVolumeFt3`
 *  carries the "other item" case — never silently dropped, because an
 *  unpriced item is how a van turns up too small. */
export interface InventoryLine {
  readonly itemSlug: string;
  readonly quantity: number;
  readonly customName?: string;
  readonly customVolumeFt3?: number;
}

export interface InventorySummary {
  readonly volumeFt3: number;
  readonly volumeM3: number;
  readonly itemCount: number;
  readonly crewMinutes: number;
  readonly fragileCount: number;
  readonly dismantleCount: number;
  readonly handlingClasses: readonly HandlingClass[];
  readonly hasSpecialist: boolean;
  readonly unknownSlugs: readonly string[];
  readonly estimatedVanLoads: number;
}

const FT3_PER_M3 = 35.3147;

/** A Luton box van's usable load, allowing for how furniture actually stacks
 *  rather than its nominal capacity. Used only to show the customer the
 *  consequence of their inventory — it never prices anything. */
export const USABLE_VAN_FT3 = 550;

export function summariseInventory(lines: readonly InventoryLine[]): InventorySummary {
  let volumeFt3 = 0;
  let itemCount = 0;
  let crewMinutes = 0;
  let fragileCount = 0;
  let dismantleCount = 0;
  const handling = new Set<HandlingClass>();
  const unknown: string[] = [];

  for (const line of lines) {
    if (line.quantity <= 0) continue;
    const entry = findItem(line.itemSlug);

    if (!entry) {
      // Custom item: trust the declared volume, assume standard handling and
      // a conservative 5 minutes per unit rather than discarding the line.
      if (typeof line.customVolumeFt3 === "number" && line.customVolumeFt3 > 0) {
        volumeFt3 += line.customVolumeFt3 * line.quantity;
        crewMinutes += 5 * line.quantity;
        itemCount += line.quantity;
        handling.add("standard");
      } else {
        unknown.push(line.itemSlug);
      }
      continue;
    }

    volumeFt3 += entry.volumeFt3 * line.quantity;
    crewMinutes += entry.crewMinutes * line.quantity;
    itemCount += line.quantity;
    if (entry.isFragile) fragileCount += line.quantity;
    if (entry.requiresDismantle) dismantleCount += line.quantity;
    handling.add(entry.handling);
  }

  const classes = Array.from(handling);
  const rounded = Math.round(volumeFt3 * 10) / 10;

  return {
    volumeFt3: rounded,
    volumeM3: Math.round((rounded / FT3_PER_M3) * 100) / 100,
    itemCount,
    crewMinutes,
    fragileCount,
    dismantleCount,
    handlingClasses: classes,
    hasSpecialist: classes.some(isSpecialist),
    unknownSlugs: unknown,
    estimatedVanLoads: rounded === 0 ? 0 : Math.max(1, Math.ceil(rounded / USABLE_VAN_FT3)),
  };
}

/** Crew size from handling minutes against a target working day. Returns at
 *  least two — a single mover is not a removal, it is a man-with-a-van job
 *  that should have been quoted as a different service. */
export function recommendedCrewSize(crewMinutes: number, targetMinutesPerMover = 300): number {
  if (crewMinutes <= 0) return 2;
  return Math.min(8, Math.max(2, Math.ceil(crewMinutes / targetMinutesPerMover)));
}
