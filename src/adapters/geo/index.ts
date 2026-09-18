import type { GeoProvider } from "../types";

/** Great-circle distance between UK outward codes, inflated by a routing
 *  factor. Deliberately approximate, and deliberately NOT presented as road
 *  distance anywhere in the UI: a quote priced on straight-line distance is
 *  wrong, so the stub's output is treated as an estimate that a real provider
 *  replaces. */
const OUTWARD_CENTROIDS: Record<string, readonly [number, number]> = {
  // A small sample so local development produces sane numbers. A real provider
  // replaces this entirely; extending the table is not the answer.
  EC: [51.517, -0.093], WC: [51.516, -0.12], SW: [51.462, -0.166], SE: [51.47, -0.06],
  NW: [51.548, -0.2], N: [51.567, -0.106], E: [51.535, -0.02], W: [51.51, -0.21],
  M: [53.479, -2.245], EH: [55.953, -3.188], G: [55.864, -4.252], B: [52.486, -1.89],
  LS: [53.801, -1.549], L: [53.408, -2.991], BS: [51.454, -2.588], CF: [51.481, -3.179],
};

const ROUTING_FACTOR = 1.25;

function area(outward: string): string {
  const match = /^[A-Z]{1,2}/.exec(outward.toUpperCase().replace(/\s+/g, ""));
  return match?.[0] ?? "";
}

export const stubGeoProvider: GeoProvider = {
  name: "stub",
  isStub: true,
  async roadDistanceMiles(origin, destination) {
    const a = OUTWARD_CENTROIDS[area(origin)];
    const b = OUTWARD_CENTROIDS[area(destination)];
    if (!a || !b) return null;

    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const [lat1, lon1] = a;
    const [lat2, lon2] = b;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const h =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    const miles = 3958.8 * 2 * Math.asin(Math.sqrt(h));
    return Math.round(miles * ROUTING_FACTOR * 10) / 10;
  },
};

export function getGeoProvider(): GeoProvider {
  return stubGeoProvider;
}
