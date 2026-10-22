// Norway on the live map (NORWAY_DATA_FINDINGS.md): Entur's GTFS-RT vehicle positions and trip updates for the
// rail operators, polled every 20 s (Entur refreshes them every 15 s), joined to Norway's timetable by trip id.
// Trains without GPS (SJ Nord sends none at times) are placed from the timetable and the trip updates' delays,
// like Sweden's estimates. Nothing is written to the database.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { addDays, serviceTimeToUtc, todayIn, ymdToIso } from '../lib/time.js';
import { haversineM } from '../lib/geo.js';
import { segmentBetween, type StationPoint } from '../geo/trackSegments.js';
import type { RailGraph } from '../geo/railGraph.js';
import { cumulative, GPS_FRESH_MS, pointAt } from '../live/progress.js';
import { gtfsRt, RT_DATASOURCES, ScheduleRelationship, StopScheduleRelationship, type FeedMessage } from '../entur/client.js';

const TZ = 'Europe/Oslo';
export const NORWAY_POLL_MS = Number(process.env.LIVE_MAP_NORWAY_POLL_MS ?? 20_000);
/** A fix older than this is dropped, like Sweden's. */
const POSITION_MAX_AGE_MS = 10 * 60_000;
/** A train is on the map from a little before its first departure until a little after its last arrival. */
const BEFORE_MS = 2 * 60_000;
const AFTER_MS = 5 * 60_000;

interface Pos {
  lat: number;
  lon: number;
  bearing: number | null;
  speedKmh: number | null;
  at: number;
}

interface Update {
  canceled: boolean;
  /** stop_sequence → delay in seconds (arrival, departure); later stops without one inherit the last. */
  delays: Map<number, { arr: number | null; dep: number | null }>;
  skipped: Set<number>;
}

interface Stop {
  seq: number;
  stationId: string;
  name: string;
  lat: number;
  lon: number;
  country: string;
  arr: number | null;
  dep: number | null;
}

interface RunningTrip {
  key: string;
  tripId: string;
  date: string;
  number: string | null;
  operatorId: string | null;
  category: string;
  routeType: string;
  start: number;
  end: number;
}

export interface NorwayTrain {
  tripKey: string;
  tripId: string;
  date: string;
  number: string;
  operatorId: string | null;
  category: string;
  routeType: string;
  lat: number;
  lon: number;
  bearing: number | null;
  speedKmh: number | null;
  at: number;
  estimated: boolean;
  origin: string;
  destination: string;
  next: string | null;
  nextEta: number | null;
  delayMin: number | null;
  /** Calls at a Swedish station too, so Trafikverket may have the same train. */
  crossBorder: boolean;
}

/** GTFS-RT start dates come as "20261022" or "2026-10-22". */
export const rtDate = (d: string | null | undefined) => (!d ? null : d.includes('-') ? d : ymdToIso(d));

/** Expected arrival and departure per stop: the timetable plus the latest delay at or before each stop. Pure. */
export function expectedStops(stops: Pick<Stop, 'seq' | 'arr' | 'dep'>[], u: Update | undefined): { arr: number | null; dep: number | null; skipped: boolean }[] {
  let carry = 0;
  return stops.map((s) => {
    const d = u?.delays.get(s.seq);
    const arrDelay = d?.arr ?? d?.dep ?? carry;
    const depDelay = d?.dep ?? d?.arr ?? arrDelay;
    carry = depDelay;
    return { arr: s.arr === null ? null : s.arr + arrDelay * 1000, dep: s.dep === null ? null : s.dep + depDelay * 1000, skipped: u?.skipped.has(s.seq) ?? false };
  });
}

/** Bearing in degrees from a to b. */
function bearingOf(a: { lat: number; lon: number }, b: { lat: number; lon: number }) {
  const toRad = Math.PI / 180;
  const y = Math.sin((b.lon - a.lon) * toRad) * Math.cos(b.lat * toRad);
  const x = Math.cos(a.lat * toRad) * Math.sin(b.lat * toRad) - Math.sin(a.lat * toRad) * Math.cos(b.lat * toRad) * Math.cos((b.lon - a.lon) * toRad);
  return Math.round(((Math.atan2(y, x) * 180) / Math.PI + 360) % 360);
}

export class NorwayFeed {
  private positions = new Map<string, Pos>();
  /** The fix before the current one, for a heading when the feed sends none (only Flytoget does). */
  private previous = new Map<string, Pos>();
  private updates = new Map<string, Update>();
  private stopsCache = new Map<string, Stop[]>();
  private runningCache: { at: number; trips: RunningTrip[] } | null = null;
  upstreamAt = 0;
  polls = 0;

  constructor(
    private db: Db,
    private opts: { fetchImpl?: typeof fetch; now?: () => number; log?: (m: string) => void; graph?: () => RailGraph | null } = {},
  ) {}

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  /** Both feeds for every rail operator: 8 small requests, well inside Entur's limits. */
  async poll() {
    this.polls++;
    const results = await Promise.allSettled(
      RT_DATASOURCES.flatMap((ds) => [gtfsRt('vehicle-positions', ds, this.opts.fetchImpl).then((f) => this.ingestPositions(f)), gtfsRt('trip-updates', ds, this.opts.fetchImpl).then((f) => this.ingestUpdates(f))]),
    );
    const failed = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    if (failed.length < results.length) this.upstreamAt = this.now();
    if (failed.length) this.opts.log?.(`live map: Entur ${failed.length}/${results.length} feeds failed: ${(failed[0]!.reason as Error).message}`);
  }

  ingestPositions(feed: FeedMessage) {
    for (const e of feed.entity) {
      const v = e.vehicle;
      const tripId = v?.trip?.tripId;
      const date = rtDate(v?.trip?.startDate);
      if (!v?.position || !tripId || !date) continue;
      const k = `${tripId}|${date}`;
      const at = Number(v.timestamp ?? 0) * 1000 || this.now();
      const old = this.positions.get(k);
      if (old && old.at >= at) continue;
      // Protobuf sends 0 for a missing bearing; only Flytoget sends real ones, so 0 is treated as none.
      const pos: Pos = { lat: v.position.latitude, lon: v.position.longitude, bearing: v.position.bearing || null, speedKmh: v.position.speed ? Math.round(v.position.speed * 3.6) : null, at };
      if (old && haversineM(old.lat, old.lon, pos.lat, pos.lon) > 25) this.previous.set(k, old);
      this.positions.set(k, pos);
    }
  }

  ingestUpdates(feed: FeedMessage) {
    for (const e of feed.entity) {
      const t = e.tripUpdate;
      const tripId = t?.trip?.tripId;
      const date = rtDate(t?.trip?.startDate);
      if (!t || !tripId || !date) continue;
      const u: Update = { canceled: t.trip.scheduleRelationship === ScheduleRelationship.CANCELED, delays: new Map(), skipped: new Set() };
      for (const s of t.stopTimeUpdate ?? []) {
        const seq = s.stopSequence ?? null;
        if (seq === null) continue;
        if (s.scheduleRelationship === StopScheduleRelationship.SKIPPED) u.skipped.add(seq);
        const arr = s.arrival?.delay ?? null;
        const dep = s.departure?.delay ?? null;
        if (arr !== null || dep !== null) u.delays.set(seq, { arr, dep });
      }
      this.updates.set(`${tripId}|${date}`, u);
    }
  }

  /** Norway's trips that could be running now (yesterday's and today's), refreshed every 10 minutes. */
  private running(now: number): RunningTrip[] {
    if (this.runningCache && now - this.runningCache.at < 10 * 60_000) return this.runningCache.trips;
    const today = todayIn(TZ, now);
    const trips: RunningTrip[] = [];
    for (const date of [addDays(today, -1), today]) {
      // Service time is "noon minus 12 h" plus seconds: one time-zone lookup per date, not per trip.
      const base = serviceTimeToUtc(date, 0, TZ);
      const rows = this.db.all<{ key: string; trip_id: string; train_number: string | null; operator_id: string | null; category: string; route_type: string; first: number | null; last: number | null }>(sql`
        select t.key, t.trip_id, t.train_number, t.operator_id, t.category, t.route_type,
               (select coalesce(dep_sec, arr_sec) from timetable_stop_times where trip_key = t.key order by seq limit 1) as first,
               (select coalesce(arr_sec, dep_sec) from timetable_stop_times where trip_key = t.key order by seq desc limit 1) as last
        from timetable_trips t
        join timetable_trip_dates d on d.trip_key = t.key and d.service_date = ${date}
        where t.source = 'gtfs_no'`);
      for (const r of rows)
        if (r.first !== null && r.last !== null)
          trips.push({ key: r.key, tripId: r.trip_id, date, number: r.train_number, operatorId: r.operator_id, category: r.category, routeType: r.route_type, start: base + r.first * 1000, end: base + r.last * 1000 });
    }
    this.runningCache = { at: now, trips };
    return trips;
  }

  private stops(trip: RunningTrip): Stop[] {
    const k = `${trip.key}|${trip.date}`;
    const hit = this.stopsCache.get(k);
    if (hit) return hit;
    const rows = this.db.all<{ seq: number; station_id: string; name: string; lat: number; lon: number; country: string; arr_sec: number | null; dep_sec: number | null }>(sql`
      select st.seq, st.station_id, s.name, s.lat, s.lon, s.country, st.arr_sec, st.dep_sec
      from timetable_stop_times st join stations s on s.id = st.station_id
      where st.trip_key = ${trip.key} order by st.seq`);
    const base = serviceTimeToUtc(trip.date, 0, TZ);
    const stops = rows.map((r) => ({
      seq: r.seq,
      stationId: r.station_id,
      name: r.name,
      lat: r.lat,
      lon: r.lon,
      country: r.country,
      arr: r.arr_sec === null ? null : base + r.arr_sec * 1000,
      dep: r.dep_sec === null ? null : base + r.dep_sec * 1000,
    }));
    this.stopsCache.set(k, stops);
    if (this.stopsCache.size > 3000) this.stopsCache.delete(this.stopsCache.keys().next().value!);
    return stops;
  }

  /** Every Norwegian train to draw now: GPS where fresh, otherwise placed from the timetable and its delays. */
  trains(): NorwayTrain[] {
    const now = this.now();
    for (const [k, p] of this.positions)
      if (now - p.at > POSITION_MAX_AGE_MS) {
        this.positions.delete(k);
        this.previous.delete(k);
      }
    const graph = this.opts.graph?.() ?? null;
    const out: NorwayTrain[] = [];
    for (const trip of this.running(now)) {
      // Cheap window check with an hour's slack for delays, before looking at stops.
      if (now < trip.start - BEFORE_MS || now > trip.end + AFTER_MS + 3600_000) continue;
      const rk = `${trip.tripId}|${trip.date}`;
      const u = this.updates.get(rk);
      if (u?.canceled) continue;
      const stops = this.stops(trip);
      if (stops.length < 2) continue;
      const exp = expectedStops(stops, u);
      const lastArr = exp.at(-1)!.arr ?? stops.at(-1)!.arr!;
      const firstDep = exp[0]!.dep ?? stops[0]!.dep!;
      const gps = this.positions.get(rk);
      const fresh = gps && now - gps.at <= GPS_FRESH_MS;
      // Without GPS, only trains Entur reports on (a trip update) are placed: a timetable alone could be a train
      // that isn't running.
      if (!gps && (!u || now < firstDep - BEFORE_MS || now > lastArr + AFTER_MS)) continue;
      if (gps && now > lastArr + AFTER_MS + 30 * 60_000) continue;
      // The next stop it hasn't left yet (skipped stops don't count).
      let i = exp.findIndex((e, j) => !e.skipped && (j === exp.length - 1 ? (e.arr ?? 0) > now : (e.dep ?? e.arr ?? 0) > now));
      if (i < 0) i = exp.length - 1;
      const next = stops[i]!;
      const nextEta = exp[i]!.arr ?? exp[i]!.dep;
      const delayMs = u ? (exp[i]!.arr ?? exp[i]!.dep ?? 0) - (next.arr ?? next.dep ?? 0) : null;

      let fix: Pick<NorwayTrain, 'lat' | 'lon' | 'bearing' | 'speedKmh' | 'at' | 'estimated'>;
      if (fresh) {
        const prev = this.previous.get(rk);
        fix = { lat: gps.lat, lon: gps.lon, bearing: gps.bearing ?? (prev ? bearingOf(prev, gps) : bearingOf(gps, next)), speedKmh: gps.speedKmh, at: gps.at, estimated: false };
      } else {
        let j = i - 1;
        while (j > 0 && exp[j]!.skipped) j--;
        const prevStop = j >= 0 ? stops[j]! : null;
        const left = j >= 0 ? (exp[j]!.dep ?? exp[j]!.arr) : null;
        const arriving = exp[i]!.arr ?? exp[i]!.dep!;
        if (!prevStop || left === null || now >= arriving || now < left) {
          // Waiting at its first stop, or standing at the next one (its dwell time).
          fix = { lat: next.lat, lon: next.lon, bearing: null, speedKmh: null, at: now, estimated: true };
        } else {
          const a: StationPoint = { id: prevStop.stationId, lat: prevStop.lat, lon: prevStop.lon };
          const b: StationPoint = { id: next.stationId, lat: next.lat, lon: next.lon };
          const seg = segmentBetween(this.db, a, b, graph);
          const cum = cumulative(seg.points);
          const f = Math.min(0.95, Math.max(0, (now - left) / Math.max(1, arriving - left)));
          const pt = pointAt(seg.points, cum, f * cum.at(-1)!);
          fix = { lat: pt.lat, lon: pt.lon, bearing: Math.round(pt.bearing), speedKmh: null, at: now, estimated: true };
        }
      }
      out.push({
        tripKey: trip.key,
        tripId: trip.tripId,
        date: trip.date,
        number: trip.number ?? trip.tripId,
        operatorId: trip.operatorId,
        category: trip.category,
        routeType: trip.routeType,
        ...fix,
        origin: stops[0]!.name,
        destination: stops.at(-1)!.name,
        next: now > lastArr ? null : next.name,
        nextEta: now > lastArr ? null : nextEta,
        delayMin: delayMs === null ? null : Math.round(delayMs / 60_000),
        crossBorder: stops.some((s) => s.country !== 'NO'),
      });
    }
    return out;
  }
}
