// The change rule (decided with the owner, 2026-10-27/28): one function for whether a change between two trains is
// possible and how comfortable it is, used by the journey planner and by every change shown in the app, so they
// always agree. No walking time: it is only known at the few mapped stations.
//  - Minimum: the station's tier (hub 15, mid 10, default 7 min; data/station_tiers.json) or, for a change between
//    two countries' trains, 10 min (15 between Norway and Sweden or Sweden and Finland), whichever is larger. Never
//    the sum. The cross-border values were left to Claude by the owner.
//  - A train's country is where most of its stops are (geography, not which feed it came from).
//  - Comfort, from the spare time over that minimum: risky (below it), tight (under half the minimum spare), normal
//    (up to the minimum spare), relaxed (more). The planner never offers a risky change; saved trips show one when a
//    delay eats into the gap.
export type Tier = 'hub' | 'mid' | 'default';
export type Comfort = 'risky' | 'tight' | 'normal' | 'relaxed';

export const TIER_MIN: Record<Tier, number> = { hub: 15, mid: 10, default: 7 };

/** The minimum for a change of trains between two countries (or 0 within one). Pure. */
export function crossBorderMin(a: string | null, b: string | null): number {
  if (!a || !b || a === b) return 0;
  const pair = [a, b].sort().join('-');
  return pair === 'NO-SE' || pair === 'FI-SE' ? 15 : 10;
}

/** Minutes a change needs at a station of this tier between trains of these countries. Pure. */
export function minChangeMin(tier: Tier, fromCountry: string | null, toCountry: string | null): number {
  return Math.max(TIER_MIN[tier], crossBorderMin(fromCountry, toCountry));
}

/** How comfortable a change is: its real gap in minutes against the minimum. Pure. */
export function comfortOf(gapMin: number, minMin: number): Comfort {
  const spare = gapMin - minMin;
  if (spare < 0) return 'risky';
  if (spare < minMin / 2) return 'tight';
  if (spare <= minMin) return 'normal';
  return 'relaxed';
}

/** The country most of a train's stops are in (the first such when tied). Pure. */
export function countryOfStops(countries: (string | null | undefined)[]): string | null {
  const n = new Map<string, number>();
  for (const c of countries) if (c) n.set(c, (n.get(c) ?? 0) + 1);
  let best: string | null = null;
  for (const [c, k] of n) if (best === null || k > n.get(best)!) best = c;
  return best;
}
