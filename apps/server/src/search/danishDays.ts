// The days Denmark's timetable has trains on (every imported copy keeps its dates: import/gtfs-dk.ts and the old copies
// of import/gtfs-dk-history.ts), and the stretches without any, for search's "Denmark's record" message.
import type { Db } from '../db/client.js';
import { COUNTRIES } from '../lib/countries.js';
import { addDays } from '../lib/time.js';

export interface DanishDays {
  /** Every service date with at least one Danish train (YYYY-MM-DD). */
  days: Set<string>;
  /** The first and last of them; null with no Danish timetable at all. */
  from: string | null;
  to: string | null;
  /** Inclusive stretches between `from` and `to` with no Danish train on any day. */
  gaps: { from: string; to: string }[];
}

/**
 * The distinct service dates with a Danish trip. A plain DISTINCT over the trip dates reads the whole index (18 s on
 * the 4 GB database of 2026-11-15); this walks it a date at a time instead (each step one index seek, 0.4 s cold) and
 * checks each date for a Danish trip by its key prefix ("dk:", which only gtfs_dk uses) and source.
 */
export function danishServiceDates(db: Db): string[] {
  const { timetableSource, keyPrefix } = COUNTRIES.DK;
  const lo = `${keyPrefix}:`;
  const hi = `${keyPrefix};`; // ';' sorts right after ':'
  const rows = db.$client
    .prepare(
      `WITH RECURSIVE days(s) AS (
         SELECT min(service_date) FROM timetable_trip_dates
         UNION ALL
         SELECT (SELECT min(service_date) FROM timetable_trip_dates WHERE service_date > days.s) FROM days WHERE days.s IS NOT NULL
       )
       SELECT s FROM days WHERE s IS NOT NULL AND EXISTS (
         SELECT 1 FROM timetable_trip_dates d JOIN timetable_trips t ON t.key = d.trip_key
         WHERE d.service_date = days.s AND d.trip_key >= ? AND d.trip_key < ? AND t.source = ?)`,
    )
    .all(lo, hi, timetableSource) as { s: string }[];
  return rows.map((r) => r.s);
}

/** The gaps in a sorted list of dates: each run of missing days as an inclusive range. */
export function gapsIn(sorted: string[]): { from: string; to: string }[] {
  const gaps: { from: string; to: string }[] = [];
  for (let i = 1; i < sorted.length; i++) {
    const next = addDays(sorted[i - 1]!, 1);
    if (next < sorted[i]!) gaps.push({ from: next, to: addDays(sorted[i]!, -1) });
  }
  return gaps;
}

const REFRESH_MS = 60 * 60_000;
const cache = new WeakMap<Db, { at: number; value: DanishDays }>();

/** The Danish days, kept for an hour (or until the next Danish import: forgetDanishDays). */
export function danishDays(db: Db, now = Date.now()): DanishDays {
  const hit = cache.get(db);
  if (hit && now - hit.at < REFRESH_MS) return hit.value;
  const list = danishServiceDates(db);
  const value: DanishDays = { days: new Set(list), from: list[0] ?? null, to: list.at(-1) ?? null, gaps: gapsIn(list) };
  cache.set(db, { at: now, value });
  return value;
}

/** After an import that adds Danish days (the daily one, or an old copy). */
export function forgetDanishDays(db: Db) {
  cache.delete(db);
}
