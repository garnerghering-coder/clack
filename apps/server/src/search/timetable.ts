// Timetable search for Add trip (SPEC §9 step 3): by train number or by route, on one local date.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { addDays, serviceTimeToUtc, todayIn } from '../lib/time.js';
import { typicalTrainType } from '../legs/trainTypes.js';

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
  /** Typical rolling stock (data/train_types.json). */
  trainType: string | null;
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
    trainType: typicalTrainType(trip.operator_id, productOf(trip.route_type, trip.category), trip.train_number),
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
  // Five-digit numbers carry a prefix digit on one side but not the other: Trafikverket's 1378 can be GTFS's 21378,
  // and (Öresundståg via Denmark) Trafikverket's 21378 is GTFS's 1378. Exact matches are listed first.
  const variant =
    number.length <= 4
      ? sql`or (length(t.train_number) = 5 and cast(substr(t.train_number, 2) as integer) = ${Number(number)})`
      : number.length === 5
        ? sql`or t.train_number = ${String(Number(number.slice(1)))}`
        : sql``;
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
  return dedupe(results).sort((a, b) => Number(b.trainNumber === number) - Number(a.trainNumber === number));
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

export interface Connection {
  /** The first train, from your station to the change. */
  first: TripResult;
  /** The second train, from the change to your destination. */
  second: TripResult;
  changeAt: { stationId: string; name: string };
  changeMin: number;
}

/** Shortest change counted as possible between two trains at the same station (most Swedish stations allow 4–5). */
export const MIN_CHANGE_MIN = 5;
export const MAX_CHANGE_MIN = 120;

/**
 * Two trains with one change, when no single train runs between the stations: every train from `fromId` that day,
 * every train into `toId`, joined at a shared station with 5–120 minutes to change. For each first train, the
 * earliest arrival (at the station with the most time to change); options that leave earlier and arrive later than
 * another are dropped. Timetable only: whether a change works on the day is for live data to say.
 */
export function searchConnections(db: Db, fromId: string, toId: string, date: string, opts: { operatorId?: string; limit?: number; minChangeMin?: number } = {}): Connection[] {
  if (fromId === toId) return [];
  const minChange = (opts.minChangeMin ?? MIN_CHANGE_MIN) * 60_000;
  const callsAt = (station: string, flag: 'no_pickup' | 'no_dropoff') =>
    sql`t.key in (select trip_key from timetable_stop_times where station_id = ${station} and ${sql.raw(flag)} = 0)`;
  const firsts = candidateTrips(db, date, callsAt(fromId, 'no_pickup'));
  // Second trains may run into the next day (a late change), or have started the day before.
  const seconds = [...candidateTrips(db, date, callsAt(toId, 'no_dropoff')), ...candidateTrips(db, addDays(date, 1), callsAt(toId, 'no_dropoff'))];
  const stops = loadStops(db, [...new Set([...firsts, ...seconds].map((x) => x.key))]);
  // Arrivals of first trains at each possible change station.
  const arrivals = new Map<string, { trip: TripRow; from: StopRow; at: StopRow; time: number }[]>();
  for (const trip of firsts) {
    const ss = stops.get(trip.key) ?? [];
    const from = ss.find((s) => s.station_id === fromId && !s.no_pickup);
    if (!from || todayIn(from.stz, utc(trip, from.dep_sec ?? from.arr_sec)!) !== date) continue;
    if (ss.some((s) => s.seq > from.seq && s.station_id === toId && !s.no_dropoff)) continue; // direct
    for (const s of ss) {
      if (s.seq <= from.seq || s.no_dropoff || s.station_id === toId) continue;
      const time = utc(trip, s.arr_sec ?? s.dep_sec);
      if (time === null) continue;
      (arrivals.get(s.station_id) ?? arrivals.set(s.station_id, []).get(s.station_id)!).push({ trip, from, at: s, time });
    }
  }
  // Cheap comparisons first; the full results only for the winners (building them is most of the cost).
  type Cand = { a: { trip: TripRow; from: StopRow; at: StopRow; time: number }; trip: TripRow; ss: StopRow[]; s: StopRow; to: StopRow; gap: number; arr: number };
  const best = new Map<string, Cand>();
  const seen = new Set<string>();
  for (const trip of seconds) {
    const id = `${trip.key}|${trip.service_date}`;
    if (seen.has(id)) continue;
    seen.add(id);
    const ss = stops.get(trip.key) ?? [];
    const to = [...ss].reverse().find((s) => s.station_id === toId && !s.no_dropoff);
    if (!to) continue;
    let arr: number | null = null;
    for (const s of ss) {
      if (s.seq >= to.seq || s.no_pickup || s.station_id === fromId) continue;
      const here = arrivals.get(s.station_id);
      if (!here) continue;
      const dep = utc(trip, s.dep_sec ?? s.arr_sec);
      if (dep === null) continue;
      for (const a of here) {
        const gap = dep - a.time;
        if (a.trip.key === trip.key || gap < minChange || gap > MAX_CHANGE_MIN * 60_000) continue;
        if (opts.operatorId && a.trip.operator_id !== opts.operatorId && trip.operator_id !== opts.operatorId) continue;
        arr ??= utc(trip, to.arr_sec ?? to.dep_sec)!;
        const k = `${a.trip.key}|${a.trip.service_date}`;
        const cur = best.get(k);
        // The earliest arrival; between changes onto the same train, the first place they meet with time to change.
        if (!cur || arr < cur.arr || (arr === cur.arr && cur.trip.key === trip.key ? s.seq < cur.s.seq : arr === cur.arr && gap > cur.gap)) best.set(k, { a, trip, ss, s, to, gap, arr });
      }
    }
  }
  const results: Connection[] = [...best.values()].map((c) => ({
    first: toResult(c.a.trip, stops.get(c.a.trip.key) ?? [], c.a.from, c.a.at),
    second: toResult(c.trip, c.ss, c.s, c.to),
    changeAt: { stationId: c.s.station_id, name: c.s.name },
    changeMin: Math.round(c.gap / 60_000),
  }));
  const all = results.sort((x, y) => x.first.from.time - y.first.from.time || x.second.to.time - y.second.to.time);
  // Drop options that another beats: it leaves no earlier and arrives earlier (or the same, leaving later).
  const kept = all.filter((c) => !all.some((d) => d !== c && d.first.from.time >= c.first.from.time && d.second.to.time <= c.second.to.time && (d.first.from.time > c.first.from.time || d.second.to.time < c.second.to.time)));
  return kept.slice(0, opts.limit ?? 12);
}

/**
 * One physical train can appear several times for the same segment: as duplicate GTFS patterns, or under two numbers
 * (Snälltåget's Berlin night train is 10301 abroad and 3943 within Sweden), or in both countries' feeds (Vy's
 * Oslo–Göteborg trains). Keep one, preferring the feed of the country you board in, then the plain (≤ 4 digit)
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
    const foreignFeed = (r: TripResult) => Number(r.key.startsWith('no:') !== (r.from.country === 'NO'));
    const rank = (r: TripResult) => foreignFeed(r) * 2 + (r.trainNumber && r.trainNumber.length <= 4 ? 0 : 1);
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

export interface StationCall {
  tripKey: string;
  serviceDate: string;
  seq: number;
  trainNumber: string | null;
  operatorId: string | null;
  product: Product;
  category: string;
  arr: number | null;
  dep: number | null;
}

/** Every timetabled call at a station on these local dates (and after-midnight runs of the day before). */
export function callsAtStation(db: Db, stationId: string, dates: string[]): StationCall[] {
  const all = [...new Set(dates.flatMap((d) => [addDays(d, -1), d]))];
  const rows = db.all<TripRow & { seq: number; arr_sec: number | null; dep_sec: number | null }>(sql`
    select t.key, d.service_date, t.train_number, t.operator_id, t.category, t.route_type, t.route_name, t.tz,
           st.seq, st.arr_sec, st.dep_sec
    from timetable_stop_times st
    join timetable_trips t on t.key = st.trip_key
    join timetable_trip_dates d on d.trip_key = t.key
    where st.station_id = ${stationId} and d.service_date in (${sql.join(all.map((d) => sql`${d}`), sql`, `)})`);
  return rows.map((r) => ({
    tripKey: r.key,
    serviceDate: r.service_date,
    seq: r.seq,
    trainNumber: r.train_number,
    operatorId: r.operator_id,
    product: productOf(r.route_type, r.category),
    category: r.category,
    arr: utc(r, r.arr_sec),
    dep: utc(r, r.dep_sec),
  }));
}
