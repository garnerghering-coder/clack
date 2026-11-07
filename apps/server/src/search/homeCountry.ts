// Whose "home" a bare train number is read against: the country in this person's settings, else the country their
// first trip starts in, else the phone's region when it is one of ours, else Sweden. The same order the Passport uses
// (stats/passport.ts `homeCountryOf`), with the phone's region added for someone with no trips yet (user test
// 2026-11-07, run 2: on a new phone "421" gave only DSB 421, with no word that SJ 421 runs another day, because the
// rule needed a home country in the settings and a new phone has none).

import { asc, eq } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legs, stations, users } from '../db/schema.js';

const OURS = new Set(['SE', 'NO', 'FI', 'DK']);

const ours = (code: string | null | undefined): string | null => {
  const upper = code?.trim().toUpperCase();
  return upper && OURS.has(upper) ? upper : null;
};

/** The rule, apart from the database. */
export function pickHomeCountry(setting: string | null | undefined, firstTripCountry: string | null | undefined, region: string | null | undefined): string {
  return ours(setting) ?? ours(firstTripCountry) ?? ours(region) ?? 'SE';
}

/** This person's home country for reading a bare number; `region` is the phone's, as the app sends it. */
export function searchHomeCountry(db: Db, userId: string, region?: string | null): string {
  const row = db.select({ settings: users.settings }).from(users).where(eq(users.id, userId)).get();
  const setting = (row?.settings as { homeCountry?: string } | null)?.homeCountry;
  if (ours(setting)) return ours(setting)!;
  const first = db
    .select({ country: stations.country })
    .from(legs)
    .innerJoin(stations, eq(stations.id, legs.originStationId))
    .where(eq(legs.userId, userId))
    .orderBy(asc(legs.schedDep))
    .limit(1)
    .get();
  return pickHomeCountry(null, first?.country, region);
}
