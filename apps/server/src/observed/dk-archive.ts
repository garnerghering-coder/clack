// Denmark's observed record from train-archive.eu (DENMARK_DATA_FINDINGS.md). The archive records Rejseplanen's live
// feed from 2026-09-30; for each finished service day it builds a file with one row per train and planned stop: the
// scheduled times, the final delay in minutes, the predicted times, trip and stop status, and whether the delay came
// from the feed or was carried over from the previous stop (delay_source 'propagated'). Permission to use any of the
// archive's data, without limits, was given by phone on 2026-10-27; the files carry the licence of their source.
//
// Raw days are kept as the archive sent them, write-once, under data/observed/train_archive_dk/ (writeRaw). The
// projection matches each trip to the Danish timetable by GTFS trip id (the archive's trip_id is Rejseplanen's) for the
// train number and operator, and fills observed_runs / observed_calls. A time counts as actual only where the feed
// reported it (delay_source 'feed'); carried-over delays stay in `extra`. The token (.env, TRAIN_ARCHIVE_TOKEN) goes in
// the X-Api-Key header and is never logged.
//
// Trains also in Sweden's feed (Öresundståg, SJ and Snälltåget to Copenhagen) are not in gtfs_dk (import/gtfs-dk.ts
// leaves them to Sweden's feed), so their trip id matches nothing and the run had no train number: a Swedish trip's
// Danish stops could never find it in the record (observed/lookup.ts looks up by number and day). Since 2026-11-07 such
// a run is matched a second way, by its Danish calls: the gtfs_se3 trip that calls at the same Danish stations at the
// same scheduled minutes (±1 min, at least 2 calls, one candidate only) gives the number and operator, and
// `info.matchedBy` says which way a run was matched ('gtfs_dk' or 'se-stop-times'). Its Swedish calls, whose
// Rejseplanen stop ids are not our station ids, then get their station from the same trip's stop at that minute.
import zlib from 'node:zlib';
import type { Db } from '../db/client.js';
import { COUNTRIES } from '../lib/countries.js';
import { addDays, serviceTimeToUtc, todayIn, zonedToUtc } from '../lib/time.js';
import { danishStationId, uicOf } from '../import/gtfs-dk.js';
import { writeRaw, rawFiles, readRaw } from './archive.js';
import { cancelLevel, fetchOf, recordFetch, saveRuns, type ObservedCall, type ObservedRun } from './store.js';

export const SOURCE = 'train_archive_dk';
const PROVIDER = 'dk-rejseplanen';
const TZ = 'Europe/Copenhagen';
/** The archive's first day for Denmark (checked 2026-10-27). */
export const HISTORY_START = '2026-09-30';

export type ArchiveRow = Record<string, string>;

/** CSV with quoted fields (RFC 4180), as the archive writes it. Pure. */
export function parseCsv(text: string): ArchiveRow[] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i]!;
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') (field += '"', i++);
        else quoted = false;
      } else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') (row.push(field), (field = ''));
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      field = '';
      if (row.length > 1 || row[0] !== '') rows.push(row);
      row = [];
    } else field += c;
  }
  if (field !== '' || row.length) (row.push(field), rows.push(row));
  const head = rows.shift() ?? [];
  return rows.map((r) => Object.fromEntries(head.map((h, i) => [h, r[i] ?? ''])));
}

/** "2026-10-26 20:58:00" (Danish local time) → epoch ms; null for empty. Pure. */
export function localMs(s: string | undefined): number | null {
  const m = /^(\d{4})-(\d\d)-(\d\d)[ T](\d\d):(\d\d):(\d\d)/.exec(s ?? '');
  return m ? zonedToUtc(+m[1]!, +m[2]!, +m[3]!, +m[4]!, +m[5]!, +m[6]!, TZ) : null;
}

/** Our station for a Rejseplanen stop id ("000008600858"): the Danish UIC id Clack uses, else uic:… as the timetable import. */
export function stationOfStop(stopId: string, known: Set<string>): string | null {
  const uic = uicOf(stopId);
  if (!uic) return null;
  const id = uic.startsWith('86') ? danishStationId(uic) : `uic:${uic}`;
  return known.has(id) ? id : null;
}

/** A Swedish-feed trip's identity and its stops, for matching a Danish run without a Danish timetable trip. */
export interface SwedishTrip {
  key: string;
  number: string | null;
  operator: string | null;
  /** Each stop's station and its scheduled arrival and departure as epoch ms (null where the feed has none). */
  stops: { stationId: string; arr: number | null; dep: number | null }[];
}

const minuteOf = (ms: number | null) => (ms === null ? null : Math.floor(ms / 60_000));
/** Two scheduled times within a minute of each other (the archive and the feed may round differently). */
const sameMinute = (a: number | null, b: number | null) => a !== null && b !== null && Math.abs(minuteOf(a)! - minuteOf(b)!) <= 1;

/** A call and a stop are the same event: same station, and the arrival or the departure at the same minute. */
const callMatches = (c: Pick<ObservedCall, 'stationId' | 'schedArr' | 'schedDep'>, s: SwedishTrip['stops'][number]) =>
  c.stationId === s.stationId && (sameMinute(c.schedArr, s.arr) || sameMinute(c.schedDep, s.dep));

/**
 * The one Swedish trip whose stops agree with a run's Danish calls (at least `MIN_CALLS`), or null when none or more
 * than one does. Only the Danish calls (our `86…` stations) are used: the archive's stop ids for Swedish stations are
 * Rejseplanen's own and are not ours. Pure.
 */
export const MIN_CALLS = 2;
export function matchSwedish(calls: ObservedCall[], swedish: SwedishTrip[]): { trip: SwedishTrip; calls: number } | null {
  const danish = calls.filter((c) => c.stationId?.startsWith('86'));
  if (danish.length < MIN_CALLS) return null;
  let best: { trip: SwedishTrip; calls: number }[] = [];
  for (const t of swedish) {
    const n = danish.filter((c) => t.stops.some((s) => callMatches(c, s))).length;
    if (n < MIN_CALLS || (best[0] && n < best[0].calls)) continue;
    if (best[0] && n === best[0].calls) best.push({ trip: t, calls: n });
    else best = [{ trip: t, calls: n }];
  }
  return best.length === 1 ? best[0]! : null;
}

/** One day's rows as runs. Pure given the lookups. */
export function project(date: string, rows: ArchiveRow[], trips: Map<string, { number: string | null; operator: string | null }>, known: Set<string>, final: boolean, swedish: SwedishTrip[] = []): ObservedRun[] {
  const byTrip = new Map<string, ArchiveRow[]>();
  for (const r of rows) (byTrip.get(r.trip_id!) ?? byTrip.set(r.trip_id!, []).get(r.trip_id!)!).push(r);
  const runs: ObservedRun[] = [];
  for (const [tripId, list] of byTrip) {
    list.sort((a, b) => Number(a.stop_sequence) - Number(b.stop_sequence));
    const cancelledTrip = list[0]!.trip_status === 'cancelled';
    const calls: ObservedCall[] = list.map((r, i) => {
      const skipped = cancelledTrip || r.stop_status === 'skipped';
      const fed = !skipped && r.delay_source === 'feed';
      const schedArr = localMs(r.scheduled_arrival);
      const schedDep = localMs(r.scheduled_departure);
      return {
        seq: i + 1,
        location: r.stop_id!,
        stationId: stationOfStop(r.stop_id!, known),
        schedArr,
        schedDep,
        estArr: null,
        estDep: null,
        actualArr: fed && schedArr !== null ? localMs(r.predicted_arrival) : null,
        actualDep: fed && schedDep !== null ? localMs(r.predicted_departure) : null,
        platform: null,
        canceledArr: skipped && schedArr !== null,
        canceledDep: skipped && schedDep !== null,
        causes: [],
        extra: { name: r.stop_name, delaySource: r.delay_source || null, arrDelayMin: r.arrival_delay_min || null, depDelayMin: r.departure_delay_min || null, observedAt: r.observed_at || null },
      };
    });
    let t = trips.get(tripId);
    const info: Record<string, unknown> = { routeId: list[0]!.route_id, timetableVersion: list[0]!.timetable_version, tripStatus: list[0]!.trip_status };
    if (t) info.matchedBy = 'gtfs_dk';
    else {
      const m = matchSwedish(calls, swedish);
      if (m) {
        t = { number: m.trip.number, operator: m.trip.operator };
        Object.assign(info, { matchedBy: 'se-stop-times', timetableTripKey: m.trip.key, matchedCalls: m.calls });
        // The Swedish calls' stations, from the trip's stop at the same minute (one stop only, else left unknown).
        for (const c of calls) {
          if (c.stationId) continue;
          const hits = m.trip.stops.filter((s) => sameMinute(c.schedArr, s.arr) || sameMinute(c.schedDep, s.dep));
          if (hits.length === 1 && new Set(hits.map((h) => h.stationId)).size === 1) {
            c.stationId = hits[0]!.stationId;
            c.extra.stationFrom = 'se-stop-times';
          }
        }
      }
    }
    runs.push({
      country: 'DK',
      serviceDate: date,
      runId: tripId,
      trainNumber: t?.number ?? null,
      source: SOURCE,
      operator: t?.operator ?? null,
      product: list[0]!.route!.trim() || null,
      canceled: cancelLevel(calls, cancelledTrip),
      info,
      passages: [],
      calls,
      final,
    });
  }
  return runs;
}

/**
 * The Swedish feed's trips with a Danish stop that run on `date` or the day before (a train that left Sweden before
 * midnight is on the earlier Swedish service day), their stops as epoch ms. A day has ~150 of them (2026-10-26).
 */
export function swedishTripsWithDanishStops(db: Db, date: string): SwedishTrip[] {
  const tz = COUNTRIES.SE.tz;
  const rows = db.$client
    .prepare(
      `select t.key, t.train_number, t.gtfs_operator, d.service_date, s.seq, s.station_id, s.arr_sec, s.dep_sec
       from timetable_trips t
       join timetable_trip_dates d on d.trip_key = t.key and d.service_date in (?, ?)
       join timetable_stop_times s on s.trip_key = t.key
       where t.source = ? and exists (select 1 from timetable_stop_times x where x.trip_key = t.key and x.station_id like '86%')
       order by t.key, d.service_date, s.seq`,
    )
    .all(date, addDays(date, -1), COUNTRIES.SE.timetableSource) as { key: string; train_number: string | null; gtfs_operator: string | null; service_date: string; seq: number; station_id: string; arr_sec: number | null; dep_sec: number | null }[];
  const out = new Map<string, SwedishTrip>();
  for (const r of rows) {
    const k = `${r.key}|${r.service_date}`;
    const t = out.get(k) ?? out.set(k, { key: r.key, number: r.train_number, operator: r.gtfs_operator, stops: [] }).get(k)!;
    t.stops.push({ stationId: r.station_id, arr: r.arr_sec === null ? null : serviceTimeToUtc(r.service_date, r.arr_sec, tz), dep: r.dep_sec === null ? null : serviceTimeToUtc(r.service_date, r.dep_sec, tz) });
  }
  return [...out.values()];
}

function lookups(db: Db, date: string, tripIds: string[]) {
  const trips = new Map<string, { number: string | null; operator: string | null }>();
  const q = db.$client.prepare(`select train_number, gtfs_operator from timetable_trips where source = 'gtfs_dk' and trip_id = ? limit 1`);
  for (const id of tripIds) {
    const r = q.get(id) as { train_number: string | null; gtfs_operator: string | null } | undefined;
    if (r) trips.set(id, { number: r.train_number, operator: r.gtfs_operator });
  }
  const known = new Set((db.$client.prepare(`select id from stations where id like '8600%' or id like 'uic:%'`).all() as { id: string }[]).map((r) => r.id));
  return { trips, known, swedish: swedishTripsWithDanishStops(db, date) };
}

/** Download one day's CSV (the archive redirects to its storage bucket). Null when the day isn't ready. */
export async function fetchDay(date: string, fetchImpl: typeof fetch = fetch): Promise<ArchiveRow[] | null> {
  const token = process.env.TRAIN_ARCHIVE_TOKEN;
  if (!token) throw new Error('TRAIN_ARCHIVE_TOKEN is not set');
  const res = await fetchImpl(`https://data.train-archive.eu/daily/provider=${PROVIDER}/service=TripUpdate/date=${date}.csv.gz`, { headers: { 'X-Api-Key': token }, signal: AbortSignal.timeout(180_000) });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`train-archive.eu ${date}: HTTP ${res.status}`);
  // The bucket may send Content-Encoding: gzip (fetch has then unpacked it already) or the .gz file as it is.
  const body = Buffer.from(await res.arrayBuffer());
  return parseCsv((body[0] === 0x1f && body[1] === 0x8b ? zlib.gunzipSync(body) : body).toString('utf8'));
}

/** Lets the server answer requests between batches: this runs inside it, and SQLite calls block. */
const breathe = () => new Promise<void>((r) => setImmediate(r));

/** A day is ~3,400 runs and ~100,000 calls; written a few hundred runs per transaction, with a pause between. */
async function saveInChunks(db: Db, runs: ObservedRun[], now: number, size = 300): Promise<number> {
  let written = 0;
  for (let i = 0; i < runs.length; i += size) {
    written += saveRuns(db, runs.slice(i, i + size), now);
    await breathe();
  }
  return written;
}

/** Fetch, archive raw and project one finished day. */
export async function collectDay(db: Db, date: string, opts: { now?: number; log?: (m: string) => void; fetchImpl?: typeof fetch } = {}) {
  const now = opts.now ?? Date.now();
  const rows = await fetchDay(date, opts.fetchImpl);
  if (!rows?.length) {
    opts.log?.(`observed DK ${date}: the archive has nothing for this day`);
    return 0;
  }
  const file = await writeRaw(SOURCE, date, 'tripupdate', rows, { now });
  const { trips, known, swedish } = lookups(db, date, [...new Set(rows.map((r) => r.trip_id!))]);
  const runs = project(date, rows, trips, known, true, swedish);
  const written = await saveInChunks(db, runs, now);
  recordFetch(db, { source: SOURCE, kind: 'tripupdate', date, records: rows.length, runs: written, file, final: true }, now);
  const bySe = runs.filter((r) => r.info.matchedBy === 'se-stop-times').length;
  opts.log?.(`observed DK ${date}: ${rows.length} rows, ${runs.length} runs (${bySe} matched to Sweden's feed by stop times)`);
  return runs.length;
}

/** Project a day already in the raw archive, without fetching again. */
export function projectFromRaw(db: Db, date: string): number {
  const f = rawFiles(SOURCE, date, 'tripupdate').at(-1);
  if (!f) return 0;
  const rows = readRaw<ArchiveRow>(f);
  const { trips, known, swedish } = lookups(db, date, [...new Set(rows.map((r) => r.trip_id!))]);
  return saveRuns(db, project(date, rows, trips, known, true, swedish));
}

/**
 * Project every raw day in a range again (after a change to how days are read, such as the Swedish match of
 * 2026-11-07), oldest first: `npm run import -- denmark-archive --reproject [--from= --to=]`. Returns the days done, so
 * the caller can refresh the trips saved for them (legs/actuals.ts refreshLegsOnDay).
 */
export function reprojectRange(db: Db, opts: { from?: string; to?: string; log?: (m: string) => void } = {}): string[] {
  const log = opts.log ?? console.log;
  const to = opts.to ?? addDays(todayIn(TZ), -1);
  const done: string[] = [];
  for (let d = opts.from ?? HISTORY_START; d <= to; d = addDays(d, 1)) {
    const n = projectFromRaw(db, d);
    if (!n) continue;
    done.push(d);
    log(`observed DK ${d}: ${n} runs projected again`);
  }
  return done;
}

/** Every finished day from the archive's first to yesterday that isn't in yet (npm run import -- observed-backfill --country=DK). */
export async function backfillRange(db: Db, opts: { from?: string; to?: string; log?: (m: string) => void; fetchImpl?: typeof fetch } = {}) {
  const log = opts.log ?? console.log;
  const to = opts.to ?? addDays(todayIn(TZ), -1);
  for (let d = opts.from ?? HISTORY_START; d <= to; d = addDays(d, 1)) {
    if (fetchOf(db, SOURCE, 'tripupdate', d)?.final) continue;
    await collectDay(db, d, { log, fetchImpl: opts.fetchImpl }).catch((e) => log(`observed DK ${d} failed: ${(e as Error).message}`));
    await breathe();
  }
}
