// Rejseplanen journeys ↔ Clack's Danish timetable (gtfs_dk). A journey id names its first and last stop and their
// planned times, which pin down the trip on its date even where Rejseplanen gives no train number (S-tog). One query
// per service date builds the lookup, kept for the day: never a query per train (that froze the server once).
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import type { JourneyEnds } from './client.js';

/**
 * Our station id → its UIC number, in either form our feeds use: "<country>00<station>" ("860000626" → "8600626",
 * "740000003" → "7400003", "800010102" → "8010102") or "uic:<number>" ("uic:8020400"). Null when it has none
 * ("fi:HKI"). Pure.
 */
export function uicOfStation(id: string): string | null {
  const plain = /^(\d{2})00(\d{5})$/.exec(id);
  if (plain) return `${plain[1]}${plain[2]}`;
  const other = /^uic:(\d{7})$/.exec(id);
  return other ? other[1]! : null;
}

/** The two ids a UIC number can have in our stations table, the plain form first. Pure. */
export const stationIdsOfUic = (uic: string): string[] => [`${uic.slice(0, 2)}00${uic.slice(2)}`, `uic:${uic}`];

const names = new WeakMap<Db, Map<string, { id: string; name: string } | null>>();
/** Our station for a UIC number (any country), cached; null when we don't have it. */
export function stationOfUic(db: Db, uic: string): { id: string; name: string } | null {
  const cache = names.get(db) ?? names.set(db, new Map()).get(db)!;
  if (!cache.has(uic)) {
    const [a, b] = stationIdsOfUic(uic);
    const row = db.all<{ id: string; name: string }>(sql`select id, name from stations where id in (${a}, ${b}) order by id = ${a} desc limit 1`)[0];
    cache.set(uic, row ?? null);
  }
  return cache.get(uic)!;
}

export interface MatchedTrip { tripKey: string; trainNumber: string | null; operatorId: string | null }

// Both sides in whole minutes after the service day's midnight, never folded back into one day: a train ending after
// midnight is "1501", not "0101" (that fold made every such train unmatched, 112 of 130 at 23:45 on 27 Oct).
const keyOf = (e: JourneyEnds) => `${e.firstUic}|${e.firstMin}|${e.lastUic}|${e.lastMin}`;

export class TripMatcher {
  private days = new Map<string, Map<string, MatchedTrip>>();
  constructor(private readonly db: Db) {}

  /** The Danish timetable trip a journey is, on its date; null when the timetable doesn't have it. */
  match(date: string, ends: JourneyEnds | null): MatchedTrip | null {
    if (!ends) return null;
    return this.day(date).get(keyOf(ends)) ?? null;
  }

  private day(date: string): Map<string, MatchedTrip> {
    const hit = this.days.get(date);
    if (hit) return hit;
    const rows = this.db.all<{ key: string; train_number: string | null; operator_id: string | null; fs: string; dep: number | null; ls: string; arr: number | null }>(sql`
      select t.key, t.train_number, t.operator_id, f.station_id as fs, f.dep_sec as dep, l.station_id as ls, l.arr_sec as arr
      from timetable_trip_dates d
      join timetable_trips t on t.key = d.trip_key and t.source = 'gtfs_dk'
      join timetable_stop_times f on f.trip_key = t.key and f.seq = (select min(seq) from timetable_stop_times where trip_key = t.key)
      join timetable_stop_times l on l.trip_key = t.key and l.seq = (select max(seq) from timetable_stop_times where trip_key = t.key)
      where d.service_date = ${date}`);
    const map = new Map<string, MatchedTrip>();
    const clash = new Set<string>();
    for (const r of rows) {
      const a = uicOfStation(r.fs);
      const b = uicOfStation(r.ls);
      if (!a || !b || r.dep === null || r.arr === null) continue;
      const k = `${a}|${Math.floor(r.dep / 60)}|${b}|${Math.floor(r.arr / 60)}`;
      // Two trips with the same ends and times can't be told apart: match neither rather than guess.
      if (map.has(k)) clash.add(k);
      map.set(k, { tripKey: r.key, trainNumber: r.train_number, operatorId: r.operator_id });
    }
    for (const k of clash) map.delete(k);
    this.days.set(date, map);
    for (const d of this.days.keys()) if (this.days.size > 3 && d !== date) this.days.delete(d);
    return map;
  }
}
