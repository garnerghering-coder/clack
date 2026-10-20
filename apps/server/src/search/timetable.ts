// Timetable search for Add trip (SPEC §9 step 3): by train number or by route, on one local date.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { addDays, serviceTimeToUtc, todayIn } from '../lib/time.js';

export type Product = 'high_speed' | 'intercity' | 'night' | 'regional' | 'commuter' | 'heritage';

export interface StopRef {
  seq: number;
  stationId: string;
  name: string;
  code: string | null;
  country: string;
  tz: string;
  /** UTC epoch ms */
  time: number;
}

export interface TripResult {
  key: string;
  serviceDate: string;
  trainNumber: string | null;
  operatorId: string | null;
  category: string;
  product: Product;
  routeName: string | null;
  from: StopRef;
  to: StopRef;
  durationMin: number;
  stopsBetween: number;
  /** Other numbers the same physical train runs under for this segment (e.g. Snälltåget 3943 = Berlin train 10301). */
  alsoKnownAs: string[];
}

export interface TripStop {
  seq: number;
  stationId: string;
  name: string;
  code: string | null;
  country: string;
  tz: string;
  lat: number;
  lon: number;
  arr: number | null;
  dep: number | null;
  noPickup: boolean;
  noDropoff: boolean;
}

export function productOf(routeType: string, category: string): Product {
  if (routeType === '101') return 'high_speed';
  if (routeType === '105') return 'night';
  return category as Product;
}

interface StopRow {
  trip_key: string;
  seq: number;
  station_id: string;
  arr_sec: number | null;
  dep_sec: number | null;
  no_pickup: number;
  no_dropoff: number;
  name: string;
  code: string | null;
  country: string;
  stz: string;
  lat: number;
  lon: number;
}

interface TripRow {
  key: string;
  service_date: string;
  train_number: string | null;
  operator_id: string | null;
  category: string;
  route_type: string;
  route_name: string | null;
  tz: string;
}

function loadStops(db: Db, keys: string[]): Map<string, StopRow[]> {
  const out = new Map<string, StopRow[]>();
  for (let i = 0; i < keys.length; i += 500) {
    const chunk = keys.slice(i, i + 500);
    const rows = db.all<StopRow>(sql`
      select st.trip_key, st.seq, st.station_id, st.arr_sec, st.dep_sec, st.no_pickup, st.no_dropoff,
             s.name, s.trv_signature as code, s.country, s.tz as stz, s.lat, s.lon
      from timetable_stop_times st join stations s on s.id = st.station_id
      where st.trip_key in (${sql.join(chunk.map((k) => sql`${k}`), sql`, `)})
      order by st.trip_key, st.seq`);
    for (const r of rows) (out.get(r.trip_key) ?? out.set(r.trip_key, []).get(r.trip_key)!).push(r);
  }
  return out;
}

const utc = (trip: TripRow, sec: number | null) => (sec === null ? null : serviceTimeToUtc(trip.service_date, sec, trip.tz));

function toResult(trip: TripRow, stops: StopRow[], from: StopRow, to: StopRow): TripResult {
  const ref = (s: StopRow, time: number): StopRef => ({ seq: s.seq, stationId: s.station_id, name: s.name, code: s.code, country: s.country, tz: s.stz, time });
  const dep = utc(trip, from.dep_sec ?? from.arr_sec)!;
  const arr = utc(trip, to.arr_sec ?? to.dep_sec)!;
  return {
    key: trip.key,
    serviceDate: trip.service_date,
    trainNumber: trip.train_number,
    operatorId: trip.operator_id,
    category: trip.category,
    product: productOf(trip.route_type, trip.category),
    routeName: trip.route_name,
    from: ref(from, dep),
    to: ref(to, arr),
    durationMin: Math.round((arr - dep) / 60000),
    stopsBetween: stops.filter((s) => s.seq > from.seq && s.seq < to.seq).length,
    alsoKnownAs: [],
  };
}

/** Trips on service day D or D-1 (after-midnight runs), as candidate rows. */
function candidateTrips(db: Db, date: string, where: ReturnType<typeof sql>): TripRow[] {
  return db.all<TripRow>(sql`
    select t.key, d.service_date, t.train_number, t.operator_id, t.category, t.route_type, t.route_name, t.tz
    from timetable_trips t join timetable_trip_dates d on d.trip_key = t.key
    where d.service_date in (${addDays(date, -1)}, ${date}) and ${where}`);
}

/**
 * Trains with this number running on local date `date`. GTFS sometimes files a variant under a 5-digit number with a
 * prefix digit (Phase 0: 51168 = 1168), so those match too. Optionally limited to trains that call at from/to.
 */
export function searchByNumber(db: Db, number: string, date: string, opts: { operatorId?: string; fromId?: string; toId?: string } = {}): TripResult[] {
  const variant = number.length <= 4 ? sql`or (length(t.train_number) = 5 and cast(substr(t.train_number, 2) as integer) = ${Number(number)})` : sql``;
  const op = opts.operatorId ? sql`and t.operator_id = ${opts.operatorId}` : sql``;
  const trips = candidateTrips(db, date, sql`(t.train_number = ${number} ${variant}) ${op}`);
  const stopsByTrip = loadStops(db, trips.map((t) => t.key));
  const results: TripResult[] = [];
  for (const trip of trips) {
    const stops = stopsByTrip.get(trip.key) ?? [];
    const from = opts.fromId ? stops.find((s) => s.station_id === opts.fromId && !s.no_pickup) : stops.find((s) => !s.no_pickup && s.dep_sec !== null);
    const to = opts.toId ? [...stops].reverse().find((s) => s.station_id === opts.toId && !s.no_dropoff) : [...stops].reverse().find((s) => !s.no_dropoff && s.arr_sec !== null);
    if (!from || !to || from.seq >= to.seq) continue;
    // Keep it if the train is on the requested local date at the boarding stop, or (for runs that started the day
    // before) anywhere on that date.
    const depLocal = todayIn(from.stz, utc(trip, from.dep_sec ?? from.arr_sec)!);
    const touchesDate = stops.some((s) => todayIn(s.stz, utc(trip, s.dep_sec ?? s.arr_sec)!) === date);
    if (depLocal !== date && !(trip.service_date !== date && touchesDate)) continue;
    results.push(toResult(trip, stops, from, to));
  }
  return dedupe(results);
}

/** Direct trains calling at `fromId` and later at `toId`, departing on local date `date`. */
export function searchByRoute(db: Db, fromId: string, toId: string, date: string, opts: { operatorId?: string } = {}): TripResult[] {
  if (fromId === toId) return [];
  const op = opts.operatorId ? sql`and t.operator_id = ${opts.operatorId}` : sql``;
  const trips = candidateTrips(
    db,
    date,
    sql`t.key in (
      select a.trip_key from timetable_stop_times a
      join timetable_stop_times b on b.trip_key = a.trip_key and b.seq > a.seq and b.station_id = ${toId} and b.no_dropoff = 0
      where a.station_id = ${fromId} and a.no_pickup = 0) ${op}`,
  );
  const stopsByTrip = loadStops(db, [...new Set(trips.map((t) => t.key))]);
  const results: TripResult[] = [];
  for (const trip of trips) {
    const stops = stopsByTrip.get(trip.key) ?? [];
    const from = stops.find((s) => s.station_id === fromId && !s.no_pickup);
    const to = from && stops.find((s) => s.station_id === toId && s.seq > from.seq && !s.no_dropoff);
    if (!from || !to) continue;
    if (todayIn(from.stz, utc(trip, from.dep_sec ?? from.arr_sec)!) !== date) continue;
    results.push(toResult(trip, stops, from, to));
  }
  return dedupe(results);
}

/**
 * One physical train can appear several times for the same segment: as duplicate GTFS patterns, or under two numbers
 * (Snälltåget's Berlin night train is 10301 abroad and 3943 within Sweden). Keep one, preferring the plain (≤ 4 digit)
 * number, and list the others.
 */
function dedupe(results: TripResult[]): TripResult[] {
  const groups = new Map<string, TripResult[]>();
  for (const r of results) {
    const k = `${r.operatorId}|${r.from.stationId}|${r.from.time}|${r.to.stationId}|${r.to.time}`;
    (groups.get(k) ?? groups.set(k, []).get(k)!).push(r);
  }
  const out: TripResult[] = [];
  for (const group of groups.values()) {
    const rank = (r: TripResult) => (r.trainNumber && r.trainNumber.length <= 4 ? 0 : 1);
    group.sort((a, b) => rank(a) - rank(b));
    const keep = { ...group[0]! };
    keep.alsoKnownAs = [...new Set(group.slice(1).map((r) => r.trainNumber).filter((n): n is string => !!n && n !== keep.trainNumber))];
    out.push(keep);
  }
  return out.sort((a, b) => a.from.time - b.from.time);
}

/** Full stop list of one trip pattern on one service date, for the "Where did you get on and off?" step. */
export function tripStops(db: Db, key: string, serviceDate: string): { trip: TripRow; stops: TripStop[] } | null {
  const trip = db.all<TripRow>(sql`
    select t.key, d.service_date, t.train_number, t.operator_id, t.category, t.route_type, t.route_name, t.tz
    from timetable_trips t join timetable_trip_dates d on d.trip_key = t.key
    where t.key = ${key} and d.service_date = ${serviceDate}`)[0];
  if (!trip) return null;
  const stops = (loadStops(db, [key]).get(key) ?? []).map((s) => ({
    seq: s.seq,
    stationId: s.station_id,
    name: s.name,
    code: s.code,
    country: s.country,
    tz: s.stz,
    lat: s.lat,
    lon: s.lon,
    arr: utc(trip, s.arr_sec),
    dep: utc(trip, s.dep_sec),
    noPickup: Boolean(s.no_pickup),
    noDropoff: Boolean(s.no_dropoff),
  }));
  return { trip, stops };
}
