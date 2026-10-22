// A Norwegian train's calls from Journey Planner (NORWAY_DATA_FINDINGS.md): aimed, expected and actual times,
// track and cancellation per stop. Only the current operating day has them, so they're fetched while a train runs
// and shortly after. Matched to our stops by scheduled minute, the way Trafikverket's reports are.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import type { StopActuals } from '../legs/actuals.js';
import { jpQuery } from './client.js';

export interface NorwayCall {
  pos: number;
  stopPlace: string;
  aimedArr: number | null;
  aimedDep: number | null;
  expectedArr: number | null;
  expectedDep: number | null;
  actualArr: number | null;
  actualDep: number | null;
  platform: string | null;
  canceled: boolean;
  realtime: boolean;
}

interface JpCall {
  stopPositionInPattern: number;
  aimedArrivalTime: string | null;
  aimedDepartureTime: string | null;
  expectedArrivalTime: string | null;
  expectedDepartureTime: string | null;
  actualArrivalTime: string | null;
  actualDepartureTime: string | null;
  cancellation: boolean;
  realtime: boolean;
  quay: { publicCode: string | null; stopPlace: { id: string } | null } | null;
}

const QUERY = `query($id: String!, $date: Date!) { serviceJourney(id: $id) { estimatedCalls(date: $date) {
  stopPositionInPattern aimedArrivalTime aimedDepartureTime expectedArrivalTime expectedDepartureTime
  actualArrivalTime actualDepartureTime cancellation realtime quay { publicCode stopPlace { id } } } } }`;

const ms = (s: string | null) => (s ? Date.parse(s) : null);
const TTL_MS = 30_000;
const cache = new Map<string, { at: number; calls: NorwayCall[] }>();

/** One service journey's calls on one date ([] when Journey Planner no longer has that day). Cached 30 s. */
export async function serviceJourneyCalls(id: string, date: string, opts: { now?: number; fetchImpl?: typeof fetch } = {}): Promise<NorwayCall[]> {
  const now = opts.now ?? Date.now();
  const k = `${id}|${date}`;
  const hit = cache.get(k);
  if (hit && now - hit.at < TTL_MS) return hit.calls;
  const data = await jpQuery<{ serviceJourney: { estimatedCalls: JpCall[] } | null }>(QUERY, { id, date }, opts.fetchImpl);
  const calls = (data.serviceJourney?.estimatedCalls ?? []).map((c) => ({
    pos: c.stopPositionInPattern,
    stopPlace: c.quay?.stopPlace?.id ?? '',
    aimedArr: ms(c.aimedArrivalTime),
    aimedDep: ms(c.aimedDepartureTime),
    expectedArr: ms(c.expectedArrivalTime),
    expectedDep: ms(c.expectedDepartureTime),
    actualArr: ms(c.actualArrivalTime),
    actualDep: ms(c.actualDepartureTime),
    platform: c.quay?.publicCode || null,
    canceled: c.cancellation,
    realtime: c.realtime,
  }));
  cache.set(k, { at: now, calls });
  if (cache.size > 300) cache.delete(cache.keys().next().value!);
  return calls;
}

export interface StopForCalls {
  seq: number;
  schedArr: number | null;
  schedDep: number | null;
  /** The stop's Entur stop place, when known: a second check on the match. */
  nsrId?: string | null;
}

const minute = (t: number | null) => (t === null ? null : Math.floor(t / 60_000));

/**
 * Per-stop actuals from the calls: a call belongs to a stop when its aimed arrival or departure is the stop's
 * scheduled minute (and it's the same stop place, when we know it). Expected times only count while the train runs
 * on real-time data. An "actual" time still in the future isn't one: Flytoget's calls carry them for stops the train
 * hasn't reached (seen 2026-10-22), so those count as expected times instead. Pure, for tests.
 */
export function callsToActuals(stops: StopForCalls[], calls: NorwayCall[], now = Date.now()): Map<number, StopActuals> {
  const real = (t: number | null) => (t !== null && t <= now ? t : null);
  const out = new Map<number, StopActuals>();
  const used = new Set<NorwayCall>();
  for (const s of stops) {
    const c = calls.find(
      (c) =>
        !used.has(c) &&
        (!s.nsrId || !c.stopPlace || s.nsrId === c.stopPlace) &&
        ((s.schedDep !== null && minute(c.aimedDep) === minute(s.schedDep)) || (s.schedArr !== null && minute(c.aimedArr) === minute(s.schedArr))),
    );
    if (!c) continue;
    used.add(c);
    const [actualArr, actualDep] = [real(c.actualArr), real(c.actualDep)];
    out.set(s.seq, {
      seq: s.seq,
      actualArr,
      actualDep,
      estimatedArr: actualArr === null && (c.realtime || c.actualArr !== null) ? (c.expectedArr ?? c.actualArr) : null,
      estimatedDep: actualDep === null && (c.realtime || c.actualDep !== null) ? (c.expectedDep ?? c.actualDep) : null,
      platform: c.platform,
      canceled: c.canceled,
      deviations: [],
      trvTrainNumber: null,
      composition: null,
      onboard: null,
    });
  }
  return out;
}

/**
 * The Entur service journey for a timetable trip: its own id for Norway's feed, or the Norwegian twin of a
 * cross-border train in Sweden's feed: same number, same day, and a stop at the same station and minute (so SJ 103
 * is never taken for Vy 103).
 */
export function serviceJourneyFor(db: Db, tripKey: string | null, trainNumber: string | null, serviceDate: string): string | null {
  if (!tripKey) return null;
  const own = db.all<{ source: string; trip_id: string }>(sql`select source, trip_id from timetable_trips where key = ${tripKey}`)[0];
  if (own?.source === 'gtfs_no') return own.trip_id;
  if (!own || !trainNumber) return null;
  const twin = db.all<{ trip_id: string }>(sql`
    select t.trip_id from timetable_trips t
    join timetable_trip_dates d on d.trip_key = t.key and d.service_date = ${serviceDate}
    join timetable_stop_times a on a.trip_key = t.key
    join timetable_stop_times b on b.trip_key = ${tripKey} and b.station_id = a.station_id
      and coalesce(b.dep_sec, b.arr_sec) = coalesce(a.dep_sec, a.arr_sec)
    where t.source = 'gtfs_no' and t.train_number = ${trainNumber} limit 1`)[0];
  return twin?.trip_id ?? null;
}
