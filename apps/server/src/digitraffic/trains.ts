// Finland's trains from Digitraffic Rail (FINLAND_DATA_FINDINGS.md, live checks 2026-10-24): one train on one day with
// every call (`timeTableRows`: scheduled, live estimate and actual time, platform, cancellation, causes), the trains
// at one station, and a train's composition (which locomotive or unit type runs it). Trains are keyed by
// (departureDate, trainNumber) like Trafikverket's, not by GTFS trip id. All times are UTC.
//
// Measured 2026-10-24: /trains/{date}/{number} answers for dates back to at least 2023-06-10 (the oldest tried), so
// a Finnish leg can get its actual times long after the ride, unlike Sweden's 4 days and Norway's operating day.
import type { Db } from '../db/client.js';
import { eq } from 'drizzle-orm';
import { stations } from '../db/schema.js';
import type { StopActuals, StopForMatch } from '../legs/actuals.js';
import { deviationTexts, digitrafficCauses, type DigitrafficCause } from '../legs/causes.js';
import { DigitrafficError, fetchJson, type DigitrafficOptions } from './client.js';
import { finnishProduct } from '../import/gtfs-fi.js';

/** How far back /trains/{date}/{number} was seen to answer (2023-06-10 was the oldest tried). One year is what we rely on. */
export const DIGITRAFFIC_HISTORY_MS = 365 * 86400_000;

export interface DtRow {
  type: 'ARRIVAL' | 'DEPARTURE';
  stationShortCode: string;
  stationUICCode?: number;
  countryCode?: string;
  /** The train stops here (false: it passes through; the row then carries the passing time). */
  trainStopping?: boolean;
  /** Passengers can get on or off. A stop with trainStopping and no commercialStop is a technical stop. */
  commercialStop?: boolean;
  commercialTrack?: string;
  cancelled?: boolean;
  scheduledTime: string;
  liveEstimateTime?: string;
  estimateSource?: string;
  actualTime?: string;
  differenceInMinutes?: number;
  causes?: DigitrafficCause[];
}

export interface DtTrain {
  trainNumber: number;
  departureDate: string;
  operatorShortCode?: string;
  trainType: string;
  trainCategory: string;
  commuterLineID?: string;
  runningCurrently?: boolean;
  cancelled?: boolean;
  version?: number;
  timetableType?: string;
  timeTableRows: DtRow[];
}

/** Passenger trains only: Long-distance and Commuter categories whose type letters are a passenger type. */
export const isPassengerTrain = (t: Pick<DtTrain, 'trainCategory' | 'trainType'>) =>
  (t.trainCategory === 'Long-distance' || t.trainCategory === 'Commuter') && finnishProduct(t.trainType).product !== null;

const time = (s: string | undefined) => (s ? Date.parse(s) : null);
const minute = (t: number | null) => (t === null ? null : Math.floor(t / 60_000));

export interface StopForDt extends StopForMatch {
  /** The station's Digitraffic short code (stations.fi_id): null for a station Digitraffic doesn't serve. */
  fi: string | null;
}

/** Where a stop in a leg is called at by this train: the row to take its times from. Commercial stops only. */
function rowFor(rows: DtRow[], used: Set<DtRow>, fi: string, type: DtRow['type'], sched: number): DtRow | undefined {
  const same = rows.filter((r) => !used.has(r) && r.stationShortCode === fi && r.type === type && r.commercialStop === true);
  const exact = same.find((r) => minute(time(r.scheduledTime)) === minute(sched));
  if (exact) return exact;
  // A retimed stop: the nearest call of that kind within ten minutes, when it's the only one.
  const near = same.filter((r) => Math.abs((time(r.scheduledTime) ?? Infinity) - sched) <= 10 * 60_000);
  return near.length === 1 ? near[0] : undefined;
}

/**
 * Per-stop actuals from a Digitraffic train: a leg stop is matched to the call at its station (by short code), of the
 * same kind (arrival where you get off or pass through, departure where you board or pass through), at its scheduled
 * minute. Only commercial stops count: a technical stop or a pass-through is not a place anyone gets on or off, so
 * it is never reported as ridden. Pure, for tests.
 */
export function digitrafficStops(stops: StopForDt[], train: DtTrain, now = Date.now()): Map<number, StopActuals> {
  const out = new Map<number, StopActuals>();
  const used = new Set<DtRow>();
  for (const s of stops) {
    if (!s.fi) continue;
    const want: { type: DtRow['type']; sched: number }[] = [];
    if ((s.role === 'through' || s.role === 'alight') && s.schedArr !== null) want.push({ type: 'ARRIVAL', sched: s.schedArr });
    if ((s.role === 'board' || s.role === 'through') && s.schedDep !== null) want.push({ type: 'DEPARTURE', sched: s.schedDep });
    for (const w of want) {
      const row = rowFor(train.timeTableRows, used, s.fi, w.type, w.sched);
      if (!row) continue;
      used.add(row);
      const a =
        out.get(s.seq) ??
        out.set(s.seq, { seq: s.seq, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled: false, deviations: [], causes: [], trvTrainNumber: null, composition: null, onboard: null, source: 'digitraffic' }).get(s.seq)!;
      // An "actual" time that is still ahead of us is an estimate (the sanity rules in actuals.ts hold it back too).
      const actual = time(row.actualTime);
      const estimate = time(row.liveEstimateTime);
      if (w.type === 'ARRIVAL') {
        a.actualArr = actual !== null && actual <= now + 2 * 60_000 ? actual : null;
        a.estimatedArr = a.actualArr === null ? (estimate ?? actual) : null;
      } else {
        a.actualDep = actual !== null && actual <= now + 2 * 60_000 ? actual : null;
        a.estimatedDep = a.actualDep === null ? (estimate ?? actual) : null;
      }
      // The platform you board at wins; arrivals fill in when there is no departure platform.
      const track = row.commercialTrack?.trim();
      if (track && (w.type === 'DEPARTURE' || !a.platform)) a.platform = track;
      a.canceled ||= Boolean(row.cancelled || train.cancelled);
      a.causes = a.causes ?? [];
      for (const c of digitrafficCauses(row.causes)) if (!a.causes.some((x) => x.code === c.code)) a.causes.push(c);
      a.deviations = deviationTexts(a.causes);
    }
  }
  return out;
}

// ---------- Fetching ----------

const TRAIN_TTL_MS = 30_000;
const trainCache = new Map<string, { at: number; train: DtTrain | null }>();

/** One train on one departure date, or null when Digitraffic has none. Cached 30 s (Digitraffic itself caches 10 s). */
export async function fetchTrain(date: string, number: string, opts: DigitrafficOptions & { now?: number } = {}): Promise<DtTrain | null> {
  const now = opts.now ?? Date.now();
  const k = `${date}|${number}`;
  const hit = trainCache.get(k);
  if (hit && now - hit.at < TRAIN_TTL_MS) return hit.train;
  const list = await fetchJson<DtTrain[]>(`trains/${date}/${Number(number)}`, opts);
  const train = Array.isArray(list) ? (list.find((t) => t.timeTableRows?.length) ?? null) : null;
  trainCache.set(k, { at: now, train });
  if (trainCache.size > 300) trainCache.delete(trainCache.keys().next().value!);
  return train;
}

/** The Digitraffic short code of each station id (stations.fi_id); null for a station it doesn't serve. */
export function fiCodes(db: Db, stationIds: string[]): Map<string, string | null> {
  const out = new Map<string, string | null>();
  for (const id of new Set(stationIds)) out.set(id, db.select({ fi: stations.fiId }).from(stations).where(eq(stations.id, id)).get()?.fi ?? null);
  return out;
}

/** What `digitrafficStops` needs for a leg's or a trip's stops, plus the train from Digitraffic (null: no such train). */
export async function digitrafficFor(
  db: Db,
  ref: { trainNumber: string | null; serviceDate: string; stops: (StopForMatch & { stationId: string })[] },
  opts: DigitrafficOptions & { now?: number } = {},
): Promise<Map<number, StopActuals>> {
  if (!ref.trainNumber) return new Map();
  const codes = fiCodes(db, ref.stops.map((s) => s.stationId));
  const forDt: StopForDt[] = ref.stops.map((s) => ({ seq: s.seq, role: s.role, sig: s.sig, schedArr: s.schedArr, schedDep: s.schedDep, fi: codes.get(s.stationId) ?? null }));
  if (!forDt.some((s) => s.fi)) return new Map();
  const train = await fetchTrain(ref.serviceDate, ref.trainNumber, opts);
  return train ? digitrafficStops(forDt, train, opts.now) : new Map();
}

// ---------- Compositions (train types) ----------

export interface DtComposition {
  trainNumber: number;
  departureDate: string;
  journeySections?: {
    beginTimeTableRow?: { stationShortCode: string };
    endTimeTableRow?: { stationShortCode: string };
    locomotives?: { location?: number; locomotiveType?: string; powerType?: string }[];
    /** The coaches or unit cars, each with its length in cm and sales number (verified 2026-10-28 in /compositions/2026-10-28/27: Sr2 + 6 Ed, totalLength 178). */
    wagons?: { location?: number; salesNumber?: number; length?: number; wagonType?: string }[];
    /** Metres. */
    totalLength?: number;
    maximumSpeed?: number;
  }[];
}

/** What a day's composition says about one train: its lead vehicle, how many cars (wagons, the locomotive not counted) and its length. */
export interface DayComposition {
  vehicle: string | null;
  cars: number | null;
  lengthM: number | null;
}

/**
 * Cars in one "wagon" of a composition, by wagon type. For these multiple units Digitraffic lists the whole unit as one
 * wagon (verified 2026-10-30 in /compositions/2026-10-30: train 1527 one Sm5 wagon 75.2 m long, 9704 three Sm4 wagons
 * 54.4 m, 1760 one Sm2 wagon 53 m), so counting wagons drew a 4-car Flirt as one car. Sm3 (Pendolino) and Dm12 list
 * each car (9: twelve Sm3 wagons 25.9–28.1 m; 428: two Dm12 of 25.2 m). Other types count one.
 * Sources: en.wikipedia.org/wiki/JKOY_Class_Sm5 ("all the four cars"), /VR_Class_Sm4 ("two powered cars"),
 * /VR_Class_Sm2 ("each Sm2 unit consists of two cars", as the Sm1), read 2026-10-30.
 */
const CARS_PER_WAGON: Record<string, number> = { Sm1: 2, Sm2: 2, Sm4: 2, Sm5: 4 };

/** The first section's cars and length. Pure. */
export function compositionOf(c: DtComposition | null | undefined): DayComposition {
  const s = c?.journeySections?.[0];
  const cars = (s?.wagons ?? []).reduce((n, w) => n + (CARS_PER_WAGON[w.wagonType?.trim() ?? ''] ?? 1), 0);
  return { vehicle: vehicleOf(c), cars: cars > 0 ? cars : null, lengthM: s?.totalLength ?? null };
}

/**
 * The vehicle running a train: its first locomotive's type, which for a multiple unit is the unit type ("Sm5",
 * "Sm3"; verified 2026-10-24 in /compositions/2026-10-24/8192 and /27). The section that serves `at` (a station short
 * code) when given, else the first one. Wagon types are deliberately not used: which wagon types mean which coach is
 * not verified. Pure.
 */
export function vehicleOf(c: DtComposition | null | undefined, at?: string | null): string | null {
  const sections = c?.journeySections ?? [];
  if (!sections.length) return null;
  const covering = at ? sections.find((s) => s.beginTimeTableRow?.stationShortCode === at) : undefined;
  const type = (covering ?? sections[0]!).locomotives?.[0]?.locomotiveType;
  return type?.trim() || null;
}

const COMP_TTL_MS = 10 * 60_000;
const compCache = new Map<string, { at: number; vehicle: string | null }>();

/** The vehicle type of one train on one day (cached 10 minutes; null when Digitraffic has no composition for it). */
export async function fetchVehicle(date: string, number: string, at?: string | null, opts: DigitrafficOptions & { now?: number } = {}): Promise<string | null> {
  const now = opts.now ?? Date.now();
  const k = `${date}|${number}|${at ?? ''}`;
  const hit = compCache.get(k);
  if (hit && now - hit.at < COMP_TTL_MS) return hit.vehicle;
  let vehicle: string | null = null;
  try {
    vehicle = vehicleOf(await fetchJson<DtComposition>(`compositions/${date}/${Number(number)}`, opts), at);
  } catch (e) {
    // No composition published (an older day, a train without one): the typical type stands. Other errors too.
    if (!(e instanceof DigitrafficError && e.status === 404)) throw e;
  }
  compCache.set(k, { at: now, vehicle });
  if (compCache.size > 1000) compCache.delete(compCache.keys().next().value!);
  return vehicle;
}

const dayCache = new Map<string, { at: number; byNumber: Map<string, DayComposition> }>();

/**
 * Every train's vehicle for one day in a single request (/compositions/{date}, 0.8 MB, Digitraffic caches it 15
 * minutes): what the live map uses instead of one request per train. Cached 15 minutes.
 */
export async function fetchDayVehicles(date: string, opts: DigitrafficOptions & { now?: number } = {}): Promise<Map<string, DayComposition>> {
  const now = opts.now ?? Date.now();
  const hit = dayCache.get(date);
  if (hit && now - hit.at < 15 * 60_000) return hit.byNumber;
  const list = await fetchJson<DtComposition[]>(`compositions/${date}`, opts);
  const byNumber = new Map<string, DayComposition>();
  for (const c of Array.isArray(list) ? list : []) {
    const comp = compositionOf(c);
    if (comp.vehicle || comp.cars) byNumber.set(String(c.trainNumber), comp);
  }
  dayCache.set(date, { at: now, byNumber });
  if (dayCache.size > 4) dayCache.delete(dayCache.keys().next().value!);
  return byNumber;
}

// ---------- Station boards ----------

const STATION_TTL_MS = 30_000;
const stationCache = new Map<string, { at: number; trains: DtTrain[] }>();

/**
 * The trains calling at one station: the next 200 departures and arrivals and the last 40 of each (a station's
 * whole day is too heavy: Helsinki's 400+100 each is 11 MB). Cached 30 s, which is Digitraffic's own cache time.
 */
export async function fetchStationTrains(shortCode: string, opts: DigitrafficOptions & { now?: number } = {}): Promise<DtTrain[]> {
  const now = opts.now ?? Date.now();
  const hit = stationCache.get(shortCode);
  if (hit && now - hit.at < STATION_TTL_MS) return hit.trains;
  const trains = await fetchJson<DtTrain[]>(
    `live-trains/station/${encodeURIComponent(shortCode)}?departing_trains=200&departed_trains=40&arriving_trains=200&arrived_trains=40&include_nonstopping=false`,
    opts,
  );
  const list = Array.isArray(trains) ? trains : [];
  stationCache.set(shortCode, { at: now, trains: list });
  if (stationCache.size > 50) stationCache.delete(stationCache.keys().next().value!);
  return list;
}

/** Forget everything cached (for tests, which share this module's caches). */
export function resetDigitrafficCaches() {
  trainCache.clear();
  compCache.clear();
  dayCache.clear();
  stationCache.clear();
}
