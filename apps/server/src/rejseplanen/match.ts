// Rejseplanen journeys ↔ Clack's Danish timetable (gtfs_dk). A journey id names its first and last stop and their
// planned times, which pin down the trip on its date even where Rejseplanen gives no train number (S-tog). One query
// per service date builds the lookup, kept for the day: never a query per train (that froze the server once).
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import type { JourneyEnds } from './client.js';

/** Our station id → its UIC number ("860000626" → "8600626", "uic:7400003" → "7400003"); null when it has none. Pure. */
export function uicOfStation(id: string): string | null {
  const dk = /^86(\d{7})$/.exec(id);
  if (dk) return dk[1]!.startsWith('00') ? `86${dk[1]!.slice(2)}` : null;
  const other = /^uic:(\d{7})$/.exec(id);
  return other ? other[1]! : null;
}

export interface MatchedTrip { tripKey: string; trainNumber: string | null; operatorId: string | null }

const hhmm = (sec: number) => {
  const m = Math.floor((((sec % 86400) + 86400) % 86400) / 60);
  return `${String(Math.floor(m / 60)).padStart(2, '0')}${String(m % 60).padStart(2, '0')}`;
};
const keyOf = (e: JourneyEnds) => `${e.firstUic}|${e.firstHhmm}|${e.lastUic}|${e.lastHhmm}`;

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
      const k = `${a}|${hhmm(r.dep)}|${b}|${hhmm(r.arr)}`;
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
