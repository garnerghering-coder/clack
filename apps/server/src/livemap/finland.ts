// Finland on the live map (FINLAND_DATA_FINDINGS.md): Digitraffic Rail's GPS for every running train
// (/train-locations/latest, refreshed about every 10 s) and every train's calls with live estimates and actual times
// (/live-trains, a full load and then only what changed since the highest `version` seen). Trains are keyed by
// (departure date, train number), the way Trafikverket's are. Trains without GPS are placed from their calls' times,
// like Norway's. Only passenger trains (VR long-distance and commuter, HSL): freight, shunting, locomotive moves,
// test and on-track machines never reach the map. Nothing is written to the database.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { fetchJson, type DigitrafficOptions } from '../digitraffic/client.js';
import { fetchDayVehicles, isPassengerTrain, type DtTrain } from '../digitraffic/trains.js';
import { finnishProduct } from '../import/gtfs-fi.js';
import { COUNTRIES } from '../lib/countries.js';
import { haversineM } from '../lib/geo.js';
import { addDays, todayIn } from '../lib/time.js';
import { segmentBetween, type StationPoint } from '../geo/trackSegments.js';
import type { RailGraph } from '../geo/railGraph.js';
import { cumulative, GPS_FRESH_MS, pointAt } from '../live/progress.js';
import { FixFilter, SPEED_FRESH_MS } from '../live/sanitize.js';
import type { Product } from '../search/timetable.js';
import { bearingOf } from './norway.js';

/** How often positions are asked for: Digitraffic's locations change every ~10 s (cache-control max-age=1). */
export const FINLAND_POLL_MS = Number(process.env.LIVE_MAP_FINLAND_POLL_MS ?? 10_000);
/** How often the calls are asked for (a version delta, small). The full /live-trains is cached 5 min by Digitraffic. */
const TRAINS_EVERY_MS = 30_000;
/** A full reload now and then, so a missed change can't linger. */
const FULL_EVERY_MS = 30 * 60_000;
/** A fix older than this is dropped, like Sweden's. */
const POSITION_MAX_AGE_MS = 10 * 60_000;
const BEFORE_MS = 2 * 60_000;
const AFTER_MS = 5 * 60_000;

interface Pos {
  lat: number;
  lon: number;
  speedKmh: number | null;
  at: number;
}

interface StationInfo {
  id: string;
  name: string;
  lat: number;
  lon: number;
  country: string;
}

/** One commercial call of a train, with its times in epoch ms (null where Digitraffic has none). */
interface Call {
  code: string;
  arr: number | null;
  dep: number | null;
  /** Actual, else the live estimate, else the schedule carried forward by the delay so far. */
  expArr: number | null;
  expDep: number | null;
  skipped: boolean;
}

interface Stored {
  number: string;
  date: string;
  type: string;
  line: string | null;
  operatorShort: string | null;
  cancelled: boolean;
  calls: Call[];
  /** Calls at a station in another country (Haparanda): Trafikverket may report the same train there. */
  crossBorder: boolean;
}

export interface FinlandTrain {
  tripKey: string | null;
  number: string;
  date: string;
  operatorId: string | null;
  product: Product;
  /** Digitraffic's type letters ("IC", "S", "HL"). */
  trainType: string;
  /** The commuter line letter ("A", "P"), when the train has one. */
  line: string | null;
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
  /** Calls at Haparanda, so Trafikverket may know the same train there. */
  crossBorder: boolean;
  /** The unit or locomotive type from /compositions (Sm5, Sr3), when known. */
  vehicle: string | null;
}

interface TripInfo {
  key: string;
  operatorId: string | null;
}

/**
 * A train's commercial calls with expected times. A call's expected time is the actual time if there is one, else
 * Digitraffic's live estimate, else its schedule plus the delay of the latest call before it that has either. Pure.
 */
export function callsOf(train: DtTrain, stationOf: (code: string) => unknown): Call[] {
  const calls: Call[] = [];
  let carry = 0;
  let cur: Call | null = null;
  for (const r of train.timeTableRows) {
    const sched = Date.parse(r.scheduledTime);
    const known = r.actualTime ? Date.parse(r.actualTime) : r.liveEstimateTime ? Date.parse(r.liveEstimateTime) : null;
    const exp = known ?? sched + carry;
    // Every row says how late the train is, passing points too; only commercial stops become calls.
    if (known !== null) carry = known - sched;
    if (r.commercialStop !== true || !stationOf(r.stationShortCode)) continue;
    if (r.type === 'ARRIVAL' || !cur || cur.code !== r.stationShortCode || cur.dep !== null) {
      cur = { code: r.stationShortCode, arr: null, dep: null, expArr: null, expDep: null, skipped: Boolean(r.cancelled) };
      calls.push(cur);
    }
    if (r.type === 'ARRIVAL') [cur.arr, cur.expArr] = [sched, exp];
    else [cur.dep, cur.expDep] = [sched, exp];
    cur.skipped = cur.skipped && Boolean(r.cancelled);
  }
  return calls;
}

export class FinlandFeed {
  private positions = new Map<string, Pos>();
  readonly fixes = new FixFilter();
  private previous = new Map<string, Pos>();
  private trains_ = new Map<string, Stored>();
  private version = 0;
  private loadedAt = 0;
  private trainsAt = 0;
  private stationIdx: Map<string, StationInfo> | null = null;
  private trips = new Map<string, { at: number; trip: TripInfo | null }>();
  private vehicles = new Map<string, string>();
  private vehiclesAt = new Map<string, number>();
  upstreamAt = 0;
  polls = 0;

  constructor(
    private db: Db,
    private opts: { fetchImpl?: typeof fetch; now?: () => number; log?: (m: string) => void; graph?: () => RailGraph | null } = {},
  ) {}

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  private dt(): DigitrafficOptions & { now: number } {
    return { fetchImpl: this.opts.fetchImpl, now: this.now() };
  }

  /** Digitraffic short code → our station (fi_id), loaded once. */
  private station = (code: string): StationInfo | undefined => {
    if (!this.stationIdx) {
      this.stationIdx = new Map();
      for (const r of this.db.all<{ fi: string; id: string; name: string; lat: number; lon: number; country: string }>(sql`select fi_id as fi, id, name, lat, lon, country from stations where fi_id is not null`))
        this.stationIdx.set(r.fi, { id: r.id, name: r.name, lat: r.lat, lon: r.lon, country: r.country });
    }
    return this.stationIdx.get(code);
  };

  /** Positions every call, the calls every 30 s, vehicle types every 15 minutes. One feed failing doesn't stop the others. */
  async poll() {
    this.polls++;
    const now = this.now();
    const jobs: Promise<unknown>[] = [this.pollLocations()];
    if (now - this.trainsAt >= TRAINS_EVERY_MS) jobs.push(this.pollTrains());
    jobs.push(this.pollVehicles());
    const results = await Promise.allSettled(jobs);
    const failed = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    if (failed.length < results.length) this.upstreamAt = this.now();
    if (failed.length) this.opts.log?.(`live map: Digitraffic ${failed.length}/${results.length} requests failed: ${(failed[0]!.reason as Error).message}`);
  }

  async pollLocations() {
    this.ingestLocations(await fetchJson<Location[]>('train-locations/latest', this.dt()));
  }

  /** The full list first (and every 30 minutes), after that only the trains that changed since the highest version seen. */
  async pollTrains() {
    const now = this.now();
    const full = !this.version || now - this.loadedAt >= FULL_EVERY_MS;
    const list = await fetchJson<DtTrain[]>(full ? 'live-trains' : `live-trains?version=${this.version}`, this.dt());
    this.trainsAt = now;
    if (full) {
      this.loadedAt = now;
      this.trains_.clear();
    }
    this.ingestTrains(list);
  }

  async pollVehicles() {
    const now = this.now();
    const today = todayIn(COUNTRIES.FI.tz, now);
    for (const date of [today, addDays(today, -1)]) {
      // Yesterday's only matters for night trains still running after midnight: once an hour is plenty.
      if (now - (this.vehiclesAt.get(date) ?? 0) < (date === today ? 15 : 60) * 60_000) continue;
      this.vehiclesAt.set(date, now);
      for (const [n, v] of await fetchDayVehicles(date, this.dt())) this.vehicles.set(`${date}|${n}`, v);
    }
    if (this.vehicles.size > 4000) for (const k of [...this.vehicles.keys()].slice(0, this.vehicles.size - 3000)) this.vehicles.delete(k);
  }

  ingestLocations(list: Location[]) {
    for (const l of Array.isArray(list) ? list : []) {
      if (l.isGpsLocation === false || l.location?.type !== 'Point') continue;
      const [lon, lat] = l.location.coordinates;
      const k = `${l.trainNumber}|${l.departureDate}`;
      const at = Date.parse(l.timestamp);
      if (!Number.isFinite(at) || lat === undefined || lon === undefined) continue;
      const old = this.positions.get(k);
      if (old && old.at >= at) continue;
      // Digitraffic's speed is km/h; 0 is a standing train (or none reported), so it goes through the same check as Sweden's.
      if (!this.fixes.push(k, { lat, lon, at, bearing: null, speedKmh: l.speed ?? null })) continue;
      const pos: Pos = { lat, lon, at, speedKmh: this.fixes.current(k)?.speedKmh ?? null };
      if (old && haversineM(old.lat, old.lon, pos.lat, pos.lon) > 25) this.previous.set(k, old);
      this.positions.set(k, pos);
    }
  }

  ingestTrains(list: DtTrain[]) {
    for (const t of Array.isArray(list) ? list : []) {
      if (typeof t.version === 'number' && t.version > this.version) this.version = t.version;
      const k = `${t.trainNumber}|${t.departureDate}`;
      if (!isPassengerTrain(t)) {
        this.trains_.delete(k);
        continue;
      }
      const calls = callsOf(t, this.station);
      if (calls.length < 2) {
        this.trains_.delete(k);
        continue;
      }
      this.trains_.set(k, {
        number: String(t.trainNumber),
        date: t.departureDate,
        type: t.trainType,
        line: t.commuterLineID || null,
        operatorShort: t.operatorShortCode ?? null,
        cancelled: Boolean(t.cancelled),
        calls,
        crossBorder: calls.some((c) => (this.station(c.code)?.country ?? 'FI') !== 'FI'),
      });
    }
  }

  /** The GTFS trip of this train and day: its key (for "my trains" and the train's route) and its operator. */
  private trip(number: string, date: string, now: number): TripInfo | null {
    const k = `${number}|${date}`;
    const hit = this.trips.get(k);
    if (hit && now - hit.at < 10 * 60_000) return hit.trip;
    const row = this.db.all<{ key: string; operator_id: string | null }>(sql`
      select t.key, t.operator_id from timetable_trips t
      join timetable_trip_dates d on d.trip_key = t.key and d.service_date = ${date}
      where t.source = 'gtfs_fi' and t.train_number = ${number} order by t.key limit 1`)[0];
    const trip = row ? { key: row.key, operatorId: row.operator_id } : null;
    this.trips.set(k, { at: now, trip });
    if (this.trips.size > 3000) this.trips.delete(this.trips.keys().next().value!);
    return trip;
  }

  /** Every Finnish passenger train to draw now: GPS where fresh, otherwise placed from its calls and their estimates. */
  trains(): FinlandTrain[] {
    const now = this.now();
    for (const [k, p] of this.positions)
      if (now - p.at > POSITION_MAX_AGE_MS) {
        this.positions.delete(k);
        this.previous.delete(k);
      }
    this.fixes.prune(now - 60 * 60_000);
    // Trains that ended long ago leave the store (the next delta won't mention them).
    for (const [k, s] of this.trains_) if (now > (s.calls.at(-1)!.expArr ?? s.calls.at(-1)!.expDep ?? 0) + 6 * 3600_000) this.trains_.delete(k);
    const graph = this.opts.graph?.() ?? null;
    const out: FinlandTrain[] = [];
    for (const [rk, s] of this.trains_) {
      if (s.cancelled) continue;
      // Calls Digitraffic marks cancelled are skipped stops, not stops the train makes.
      const calls = s.calls;
      const first = calls[0]!;
      const last = calls.at(-1)!;
      const firstDep = first.expDep ?? first.expArr!;
      const lastArr = last.expArr ?? last.expDep!;
      const gps = this.positions.get(rk);
      const fresh = gps && now - gps.at <= GPS_FRESH_MS;
      const inWindow = now >= firstDep - BEFORE_MS && now <= lastArr + AFTER_MS;
      if (!inWindow && !(gps && now >= firstDep - BEFORE_MS && now <= lastArr + AFTER_MS + 30 * 60_000)) continue;
      let i = calls.findIndex((c, j) => !c.skipped && (j === calls.length - 1 ? (c.expArr ?? 0) > now : (c.expDep ?? c.expArr ?? 0) > now));
      if (i < 0) i = calls.length - 1;
      const nextCall = calls[i]!;
      const next = this.station(nextCall.code)!;
      const nextEta = nextCall.expArr ?? nextCall.expDep;
      const planned = nextCall.arr ?? nextCall.dep;
      const delayMs = nextEta !== null && planned !== null ? nextEta - planned : null;

      let fix: Pick<FinlandTrain, 'lat' | 'lon' | 'bearing' | 'speedKmh' | 'at' | 'estimated'>;
      if (fresh) {
        const prev = this.previous.get(rk);
        fix = { lat: gps.lat, lon: gps.lon, bearing: prev ? bearingOf(prev, gps) : bearingOf(gps, next), speedKmh: now - gps.at <= SPEED_FRESH_MS ? gps.speedKmh : null, at: gps.at, estimated: false };
      } else {
        let j = i - 1;
        while (j > 0 && calls[j]!.skipped) j--;
        const prevCall = j >= 0 ? calls[j]! : null;
        const left = prevCall ? (prevCall.expDep ?? prevCall.expArr) : null;
        const arriving = nextCall.expArr ?? nextCall.expDep!;
        if (!prevCall || left === null || now >= arriving || now < left) {
          // Waiting at its first stop, or standing at the next one (its dwell time).
          fix = { lat: next.lat, lon: next.lon, bearing: null, speedKmh: null, at: now, estimated: true };
        } else {
          const p = this.station(prevCall.code)!;
          const a: StationPoint = { id: p.id, lat: p.lat, lon: p.lon };
          const b: StationPoint = { id: next.id, lat: next.lat, lon: next.lon };
          const seg = segmentBetween(this.db, a, b, graph);
          const cum = cumulative(seg.points);
          const f = Math.min(0.95, Math.max(0, (now - left) / Math.max(1, arriving - left)));
          const pt = pointAt(seg.points, cum, f * cum.at(-1)!);
          fix = { lat: pt.lat, lon: pt.lon, bearing: Math.round(pt.bearing), speedKmh: null, at: now, estimated: true };
        }
      }
      const trip = this.trip(s.number, s.date, now);
      const product = (finnishProduct(s.type).product ?? 'regional') as Product;
      const origin = this.station(first.code)!.name;
      const destination = this.station(last.code)!.name;
      const done = now > lastArr;
      out.push({
        tripKey: trip?.key ?? null,
        number: s.number,
        date: s.date,
        operatorId: trip?.operatorId ?? (s.operatorShort === 'vr' ? 'vr-fi' : null),
        product,
        trainType: s.type,
        line: s.line,
        ...fix,
        origin,
        destination,
        next: done ? null : next.name,
        nextEta: done ? null : nextEta,
        delayMin: delayMs === null ? null : Math.round(delayMs / 60_000),
        crossBorder: s.crossBorder,
        vehicle: this.vehicles.get(`${s.date}|${s.number}`) ?? null,
      });
    }
    return out;
  }
}

interface Location {
  trainNumber: number;
  departureDate: string;
  timestamp: string;
  location: { type: string; coordinates: number[] };
  speed?: number;
  accuracy?: number;
  isGpsLocation?: boolean;
}
