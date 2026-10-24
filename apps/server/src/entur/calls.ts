// A Norwegian train's calls from Journey Planner (NORWAY_DATA_FINDINGS.md): aimed, expected and actual times,
// track and cancellation per stop. Only the current operating day has them, so they're fetched while a train runs
// and shortly after. Matched to our stops by scheduled minute, the way Trafikverket's reports are.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import type { StopActuals } from '../legs/actuals.js';
import { deviationTexts, enturCauses, type EnturSituation } from '../legs/causes.js';
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
  /** Entur's notices for this call, in every language it wrote them. */
  situations?: EnturSituation[];
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
  situations?: EnturSituation[];
  quay: { publicCode: string | null; stopPlace: { id: string } | null } | null;
}

const QUERY = `query($id: String!, $date: Date!) { serviceJourney(id: $id) { estimatedCalls(date: $date) {
  stopPositionInPattern aimedArrivalTime aimedDepartureTime expectedArrivalTime expectedDepartureTime
  actualArrivalTime actualDepartureTime cancellation realtime situations { summary { value language } } quay { publicCode stopPlace { id } } } } }`;

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
    situations: c.situations ?? [],
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

const causesOf = (c: NorwayCall, language: string) => enturCauses(c.situations, language);
const minute = (t: number | null) => (t === null ? null : Math.floor(t / 60_000));

/**
 * Per-stop actuals from the calls: a call belongs to a stop when its aimed arrival or departure is the stop's
 * scheduled minute (and it's the same stop place, when we know it). Expected times only count while the train runs
 * on real-time data. An "actual" time still in the future isn't one: Flytoget's calls carry them for stops the train
 * hasn't reached (seen 2026-10-22), so those count as expected times instead. Pure, for tests.
 */
export function callsToActuals(stops: StopForCalls[], calls: NorwayCall[], now = Date.now(), language = 'en'): Map<number, StopActuals> {
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
      deviations: deviationTexts(causesOf(c, language)),
      causes: causesOf(c, language),
      trvTrainNumber: null,
      composition: null,
      onboard: null,
      source: c.realtime || actualArr !== null || actualDep !== null ? 'entur' : null,
    });
  }
  return out;
}

export interface StopForPlace extends StopForCalls {
  nsrId: string | null;
}

/** How far a stop's time in another country's timetable may be from ours and still be the same call. */
const PLACE_MATCH_MS = 90 * 60_000;

/**
 * Per-stop data for a train from another feed (SJ, Snälltåget or Vy Tåg in Norway): calls matched to our stops by
 * stop place, in order, within 90 minutes of our time. The call's aimed time is that country's published time for
 * the stop (advertisedArr/Dep). Pure, for tests.
 */
export function callsByPlace(stops: StopForPlace[], calls: NorwayCall[], now = Date.now(), language = 'en'): Map<number, StopActuals> {
  const real = (t: number | null) => (t !== null && t <= now ? t : null);
  const out = new Map<number, StopActuals>();
  const ordered = [...calls].sort((a, b) => a.pos - b.pos);
  let from = 0;
  for (const s of stops) {
    if (!s.nsrId) continue;
    const ours = s.schedDep ?? s.schedArr;
    const i = ordered.findIndex((c, j) => j >= from && c.stopPlace === s.nsrId && (ours === null || Math.abs((c.aimedDep ?? c.aimedArr ?? ours) - ours) <= PLACE_MATCH_MS));
    if (i < 0) continue;
    from = i + 1;
    const c = ordered[i]!;
    const [actualArr, actualDep] = [real(c.actualArr), real(c.actualDep)];
    out.set(s.seq, {
      seq: s.seq,
      actualArr,
      actualDep,
      estimatedArr: actualArr === null && c.realtime ? (c.expectedArr ?? c.actualArr) : null,
      estimatedDep: actualDep === null && c.realtime ? (c.expectedDep ?? c.actualDep) : null,
      platform: c.platform,
      canceled: c.canceled,
      deviations: deviationTexts(causesOf(c, language)),
      causes: causesOf(c, language),
      trvTrainNumber: null,
      composition: null,
      onboard: null,
      source: c.realtime || actualArr !== null || actualDep !== null ? 'entur' : null,
      advertisedArr: c.aimedArr,
      advertisedDep: c.aimedDep,
    });
  }
  return out;
}

const FIND_QUERY = `query($id: String!, $start: DateTime!) { stopPlace(id: $id) { estimatedCalls(startTime: $start, timeRange: 10800,
  numberOfDepartures: 500, arrivalDeparture: both, whiteListedModes: [rail], includeCancelledTrips: true) {
  date aimedArrivalTime aimedDepartureTime serviceJourney { id privateCode } } } }`;
const found = new Map<string, { at: number; hit: { id: string; date: string } | null }>();

/**
 * A train's Entur service journey: its own trip id for Norway's feed; otherwise looked up at its first Norwegian stop
 * by train number, the call nearest our time (within 90 minutes). Covers every operator Entur knows (SJ, Snälltåget,
 * Vy Tåg), not just the four feeds we import. Cached 30 minutes.
 */
export async function enturJourneyFor(
  db: Db,
  ref: { tripKey: string | null; trainNumber: string | null; serviceDate: string; stops: { nsrId: string | null; country: string; schedArr: number | null; schedDep: number | null }[] },
  opts: { now?: number; fetchImpl?: typeof fetch } = {},
): Promise<{ id: string; date: string; own: boolean } | null> {
  if (ref.tripKey) {
    const own = db.all<{ source: string; trip_id: string }>(sql`select source, trip_id from timetable_trips where key = ${ref.tripKey}`)[0];
    if (own?.source === 'gtfs_no') return { id: own.trip_id, date: ref.serviceDate, own: true };
  }
  const at = ref.stops.find((s) => s.nsrId && s.country === 'NO' && (s.schedDep ?? s.schedArr) !== null);
  if (!at || !ref.trainNumber) return null;
  const ours = (at.schedDep ?? at.schedArr)!;
  const now = opts.now ?? Date.now();
  const key = `${at.nsrId}|${ref.trainNumber}|${ref.serviceDate}`;
  const hit = found.get(key);
  if (hit && now - hit.at < 30 * 60_000) return hit.hit ? { ...hit.hit, own: false } : null;
  const data = await jpQuery<{ stopPlace: { estimatedCalls: { date: string; aimedArrivalTime: string | null; aimedDepartureTime: string | null; serviceJourney: { id: string; privateCode: string | null } }[] } | null }>(
    FIND_QUERY,
    { id: at.nsrId, start: new Date(ours - PLACE_MATCH_MS).toISOString() },
    opts.fetchImpl,
  );
  const number = String(Number(ref.trainNumber));
  const best = (data.stopPlace?.estimatedCalls ?? [])
    .filter((c) => c.serviceJourney.privateCode && String(Number(c.serviceJourney.privateCode)) === number)
    .map((c) => ({ c, d: Math.abs((ms(c.aimedDepartureTime) ?? ms(c.aimedArrivalTime) ?? 0) - ours) }))
    .filter((x) => x.d <= PLACE_MATCH_MS)
    .sort((a, b) => a.d - b.d)[0];
  const result = best ? { id: best.c.serviceJourney.id, date: best.c.date } : null;
  found.set(key, { at: now, hit: result });
  if (found.size > 500) found.delete(found.keys().next().value!);
  return result ? { ...result, own: false } : null;
}

/**
 * Entur's data for a train's stops: an own Norwegian trip by its calls' minutes, any other train by stop place
 * (so SJ's Oslo S gets Norway's published time and, where Entur has it, live data).
 */
export async function enturStops(
  db: Db,
  ref: { tripKey: string | null; trainNumber: string | null; serviceDate: string; stops: (StopForPlace & { country: string })[] },
  opts: { now?: number; fetchImpl?: typeof fetch } = {},
): Promise<Map<number, StopActuals>> {
  if (!ref.stops.some((s) => s.nsrId)) return new Map();
  const j = await enturJourneyFor(db, ref, opts);
  if (!j) return new Map();
  const calls = await serviceJourneyCalls(j.id, j.date, opts);
  return j.own ? callsToActuals(ref.stops, calls, opts.now) : callsByPlace(ref.stops, calls, opts.now);
}

