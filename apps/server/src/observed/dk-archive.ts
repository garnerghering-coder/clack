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
import zlib from 'node:zlib';
import type { Db } from '../db/client.js';
import { addDays, todayIn, zonedToUtc } from '../lib/time.js';
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

/** One day's rows as runs. Pure given the lookups. */
export function project(date: string, rows: ArchiveRow[], trips: Map<string, { number: string | null; operator: string | null }>, known: Set<string>, final: boolean): ObservedRun[] {
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
    const t = trips.get(tripId);
    runs.push({
      country: 'DK',
      serviceDate: date,
      runId: tripId,
      trainNumber: t?.number ?? null,
      source: SOURCE,
      operator: t?.operator ?? null,
      product: list[0]!.route!.trim() || null,
      canceled: cancelLevel(calls, cancelledTrip),
      info: { routeId: list[0]!.route_id, timetableVersion: list[0]!.timetable_version, tripStatus: list[0]!.trip_status },
      passages: [],
      calls,
      final,
    });
  }
  return runs;
}

function lookups(db: Db, tripIds: string[]) {
  const trips = new Map<string, { number: string | null; operator: string | null }>();
  const q = db.$client.prepare(`select train_number, gtfs_operator from timetable_trips where source = 'gtfs_dk' and trip_id = ? limit 1`);
  for (const id of tripIds) {
    const r = q.get(id) as { train_number: string | null; gtfs_operator: string | null } | undefined;
    if (r) trips.set(id, { number: r.train_number, operator: r.gtfs_operator });
  }
  const known = new Set((db.$client.prepare(`select id from stations where id like '8600%' or id like 'uic:%'`).all() as { id: string }[]).map((r) => r.id));
  return { trips, known };
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
  const file = writeRaw(SOURCE, date, 'tripupdate', rows, { now });
  const { trips, known } = lookups(db, [...new Set(rows.map((r) => r.trip_id!))]);
  const runs = project(date, rows, trips, known, true);
  const written = await saveInChunks(db, runs, now);
  recordFetch(db, { source: SOURCE, kind: 'tripupdate', date, records: rows.length, runs: written, file, final: true }, now);
  opts.log?.(`observed DK ${date}: ${rows.length} rows, ${runs.length} runs`);
  return runs.length;
}

/** Project a day already in the raw archive, without fetching again. */
export function projectFromRaw(db: Db, date: string): number {
  const f = rawFiles(SOURCE, date, 'tripupdate').at(-1);
  if (!f) return 0;
  const rows = readRaw<ArchiveRow>(f);
  const { trips, known } = lookups(db, [...new Set(rows.map((r) => r.trip_id!))]);
  return saveRuns(db, project(date, rows, trips, known, true));
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
