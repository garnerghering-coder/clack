// Norway's past, from Entur's public BigQuery table (NORWAY_DATA_FINDINGS.md): one row per stop of every journey since
// early 2020, with planned and actual times and cancellations, refreshed every morning ~04:00 UTC. Licence NLOD 2.0
// ("Contains data under the Norwegian licence for Open Government data (NLOD) distributed by Entur AS"). Queried from
// our own free sandbox project with a service-account key (GOOGLE_APPLICATION_CREDENTIALS).
//
// Checked 2026-10-26 with one query per year: trains are there every year (2020: NSB, GOA, FLT, GJB; 2022 and 2024:
// all under Bane NOR, BNR; 2026: VYG, GOA, FLT, BNR). Before each operator had its own stream, the operator comes
// from the journey id's codespace. Some operators copy the planned time into a missing actual one, so the rows'
// `estimated` flag is kept and an estimated time is never stored as an actual.
//
// The sandbox gives 1 TiB of queries a month and refuses (never bills) past it; each day is dry-run first, and a
// monthly count keeps the backfill well under the limit.
import fs from 'node:fs';
import path from 'node:path';
import type { Db } from '../db/client.js';
import { bigQuery, googleKeyPath } from '../lib/google.js';
import { cleanStopName, matchStation, trainNumberFromTripId, type ExistingStation } from '../import/gtfs-no.js';
import { addDays, todayIn } from '../lib/time.js';
import { OBSERVED_DIR, writeRaw } from './archive.js';
import { stationsByNsr } from './norway.js';
import { cancelLevel, fetchOf, recordFetch, saveRuns, type ObservedCall, type ObservedRun } from './store.js';

export const SOURCE = 'entur-bigquery';
const TABLE = '`ent-data-sharing-ext-prd.realtime_siri_et.realtime_siri_et_last_recorded`';
/**
 * Every version of every quay: older journeys call at quays since retired, which the latest-version table lacks
 * (12 March 2024: 540 of 1,470 trains had one of 16 such quays). Each quay's newest version is used.
 */
const QUAYS = '`ent-data-sharing-ext-prd.national_stop_registry.quays_all_versions`';
/** How far back Clack keeps Norway's record (owner, 2026-10-27: from 1 January 2021; the archive has 2020 too). */
export const HISTORY_START = '2021-01-01';
/** Days this recent are projected as they are fetched; older ones are kept raw and projected when first asked for. */
export const PROJECT_DAYS = 30;
/** Our monthly ceiling, well under the sandbox's 1 TiB. */
export const MONTHLY_BYTES = 800e9;
/** A day costing more than this is a sign the query or the table changed: stop and look. */
const MAX_DAY_BYTES = 5e9;

/** Rail only: trains report as vehicleMode 'rail'; buses under the same codespaces (Vy's) are left out. */
export const DAY_SQL = `SELECT * FROM ${TABLE} WHERE operatingDate = @date AND vehicleMode = 'rail'`;

type BqRow = Record<string, string | null>;

const usageFile = () => path.join(OBSERVED_DIR, SOURCE, 'usage.json');
function usage(): Record<string, number> {
  try {
    return JSON.parse(fs.readFileSync(usageFile(), 'utf8')) as Record<string, number>;
  } catch {
    return {};
  }
}
function addUsage(bytes: number, now: number) {
  const u = usage();
  const month = new Date(now).toISOString().slice(0, 7);
  u[month] = (u[month] ?? 0) + bytes;
  fs.mkdirSync(path.dirname(usageFile()), { recursive: true });
  fs.writeFileSync(usageFile(), JSON.stringify(u, null, 2));
}
export const bytesThisMonth = (now = Date.now()) => usage()[new Date(now).toISOString().slice(0, 7)] ?? 0;

const ts = (v: string | null | undefined) => (v === null || v === undefined || v === '' ? null : Number.isFinite(Number(v)) ? Math.round(Number(v) * 1000) : Date.parse(v));
const bool = (v: string | null | undefined) => v === 'true';

/** Quay → [platform, stop place], from the stop registry (refreshed weekly, kept as a raw file too). */
let quayCache: { at: number; map: Map<string, [string | null, string | null]> } | null = null;
async function quays(now: number): Promise<Map<string, [string | null, string | null]>> {
  if (quayCache && now - quayCache.at < 7 * 86400_000) return quayCache.map;
  const { rows, bytes } = await bigQuery(`SELECT id, publicCode, stopPlaceRef FROM ${QUAYS} QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY SAFE_CAST(version AS INT64) DESC) = 1`);
  addUsage(bytes, now);
  await writeRaw(SOURCE, todayIn('Europe/Oslo', now), 'quays', rows, { now });
  quayCache = { at: now, map: new Map(rows.map((r) => [r.id!, [r.publicCode || null, r.stopPlaceRef || null]])) };
  return quayCache.map;
}

/**
 * operatorRef values and the operator's codespace (the code its trips carry in the current feed). Seen 2021–2026
 * (one day a month, 2026-10-27): Vy as VY, vy, VYT, VYG, VYG:Operator:VY and VYG:Operator:VYT; Flytoget as FLY and
 * FLT:Operator:507; Go-Ahead as GAG and GOA:Operator:GOA. The same train numbers run under the later codes. Others
 * (SJN, SJ, TM, BN, NJM, VYG:Operator:FLB Flåmsbana, VYG:Operator:TAG Vy Tåg) are kept as given, without a brand
 * unless the current feed has trips under that code.
 */
const OPERATOR_CODESPACE: Record<string, string> = {
  VY: 'VYG',
  vy: 'VYG',
  VYT: 'VYG',
  'VYG:Operator:VY': 'VYG',
  'VYG:Operator:VYT': 'VYG',
  FLY: 'FLT',
  'FLT:Operator:507': 'FLT',
  GAG: 'GOA',
  'GOA:Operator:GOA': 'GOA',
  'VYG:Operator:FLB': 'FLB',
  'VYG:Operator:TAG': 'TAG',
};
const codespaceOf = (ref: string | null | undefined) => (ref ? (OPERATOR_CODESPACE[ref] ?? ref) : null);

/**
 * A journey's operator and train number. Two id styles (checked 2026-10-27): before each operator had its own stream
 * the id is just "<number>:<date>" ("471:2022-03-08", "471:2020-03-10") and the operator is in operatorRef (VY, SJN);
 * later it is the operator's codespace and journey ("VYG:ServiceJourney:61-LOD_617015-R"). Pure.
 */
export function journeyIdentity(r: Pick<BqRow, string>): { operator: string | null; number: string | null } {
  const id = r.serviceJourneyId ?? '';
  const old = /^(\d+):\d{4}-\d{2}-\d{2}$/.exec(id);
  if (old) return { operator: codespaceOf(r.operatorRef) || r.dataSource || null, number: old[1]! };
  // A third style from 2025: "VYG:DatedServiceJourney:61_OSL-BRG_25-06-01" (the number before the first "_"). Vy's
  // trains to Göteborg carry two, "389-115_OSL_389_HLD-GTB_…": the first, repeated after the station, is the train's.
  const dated = /:DatedServiceJourney:(\d+)[-_]/.exec(id);
  const operator = codespaceOf(r.operatorRef?.includes(':') ? r.operatorRef : null) ?? (id.split(':')[0] || codespaceOf(r.operatorRef) || r.dataSource || null);
  return { operator, number: dated ? dated[1]! : trainNumberFromTripId(id) };
}

const PLACES = '`ent-data-sharing-ext-prd.national_stop_registry.stop_places_all_versions`';
let placeCache: { at: number; rows: { id: string; name: string; lat: number; lon: number }[] } | null = null;

/**
 * Our station for each rail stop place in the registry, every version. A station knows one stop place by id
 * (stations.nsr_id), but a station can have several (Lillestrøm's platforms belong to NSR:StopPlace:451, the station
 * row has 60694), and older days use places since replaced. The rest are matched by name and position the way the
 * Norway import matches them (gtfs-no.ts matchStation: within 400 m, or 1.5 km with the same name). Weekly.
 */
export async function stationsByPlace(db: Db, now = Date.now()): Promise<Map<string, string>> {
  const out = stationsByNsr(db);
  if (!placeCache || now - placeCache.at > 7 * 86400_000) {
    const { rows, bytes } = await bigQuery(
      `SELECT id, name, location_latitude lat, location_longitude lon FROM ${PLACES} WHERE transportMode = 'RAIL' QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY SAFE_CAST(version AS INT64) DESC) = 1`,
    );
    addUsage(bytes, now);
    await writeRaw(SOURCE, todayIn('Europe/Oslo', now), 'stop-places', rows, { now });
    placeCache = { at: now, rows: rows.filter((r) => r.id && r.name && r.lat && r.lon).map((r) => ({ id: r.id!, name: r.name!, lat: Number(r.lat), lon: Number(r.lon) })) };
  }
  const existing: ExistingStation[] = (db.$client.prepare(`select id, name, lat, lon, country from stations`).all() as ExistingStation[]);
  // A rail place none of our stations is (closed or no longer served: Skoppum, Kjose, Kornsjø …; 56 of 566 on
  // 2026-10-27) becomes a historical-only station from the registry's own name and position, as the Swedish archive
  // does for its closed stations.
  const addStation = db.$client.prepare(
    `insert into stations (id, name, country, lat, lon, tz, trv_signature, gtfs_stop_ids, coord_source, historical_only, kind, needs_review, nsr_id)
     values (?, ?, 'NO', ?, ?, 'Europe/Oslo', null, ?, 'nsr', 1, 'rail_station', 0, ?) on conflict(id) do nothing`,
  );
  for (const p of placeCache.rows) {
    if (out.has(p.id)) continue;
    const hit = matchStation(p, existing);
    if (hit) out.set(p.id, hit.id);
    else {
      addStation.run(p.id, cleanStopName(p.name), p.lat, p.lon, JSON.stringify([p.id]), p.id);
      out.set(p.id, p.id);
    }
  }
  return out;
}

/** One day's rows as runs, one per dated journey, stops in sequence order. */
export function project(date: string, rows: BqRow[], quay: Map<string, [string | null, string | null]>, stationByNsr: Map<string, string>): ObservedRun[] {
  const byJourney = new Map<string, BqRow[]>();
  for (const r of rows) {
    const k = r.datedServiceJourneyId ?? r.serviceJourneyId ?? '';
    (byJourney.get(k) ?? byJourney.set(k, []).get(k)!).push(r);
  }
  const runs: ObservedRun[] = [];
  const COLS = new Set(['aimedArrivalTime', 'aimedDepartureTime', 'arrivalTime', 'departureTime', 'stopCancellation', 'stopPointRef', 'sequenceNr', 'operatingDate']);
  for (const [, list] of byJourney) {
    list.sort((a, b) => Number(a.sequenceNr) - Number(b.sequenceNr));
    const head = list[0]!;
    const { operator, number } = journeyIdentity(head);
    const line = head.lineRef?.split(':').at(-1);
    const n = list.length;
    const calls: ObservedCall[] = list.map((r, i) => {
      const [platform, stopPlace] = quay.get(r.stopPointRef ?? '') ?? [null, null];
      const est = bool(r.estimated);
      const [arr, dep] = [ts(r.arrivalTime), ts(r.departureTime)];
      const extra: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(r)) if (!COLS.has(k) && v !== null && v !== '' && !(k in head && head[k] === v && i > 0)) extra[k] = v;
      return {
        seq: i + 1,
        location: r.stopPointRef ?? '',
        stationId: (stopPlace && stationByNsr.get(stopPlace)) ?? null,
        schedArr: i === 0 ? null : ts(r.aimedArrivalTime),
        schedDep: i === n - 1 ? null : ts(r.aimedDepartureTime),
        estArr: i > 0 && est ? arr : null,
        estDep: i < n - 1 && est ? dep : null,
        actualArr: i > 0 && !est ? arr : null,
        actualDep: i < n - 1 && !est ? dep : null,
        platform,
        canceledArr: i > 0 && bool(r.stopCancellation),
        canceledDep: i < n - 1 && bool(r.stopCancellation),
        causes: [],
        extra,
      };
    });
    runs.push({
      country: 'NO',
      serviceDate: date,
      runId: `${operator ?? 'NO'}:${number ?? head.datedServiceJourneyId ?? head.serviceJourneyId}`,
      trainNumber: number,
      source: SOURCE,
      operator,
      // "SJN:Line:-": the older rows have no line.
      product: line && line !== '-' ? line : null,
      canceled: cancelLevel(calls, bool(head.journeyCancellation)),
      info: { dataSource: head.dataSource, dataSourceName: head.dataSourceName, lineRef: head.lineRef, operatorRef: head.operatorRef, directionRef: head.directionRef, serviceJourneyId: head.serviceJourneyId, datedServiceJourneyId: head.datedServiceJourneyId, originName: head.originName, destinationName: head.destinationName, extraJourney: bool(head.extraJourney) },
      passages: [],
      calls,
      final: true,
    });
  }
  return runs;
}

/** Fetch, archive and project one operating day. Throws past the monthly ceiling or on an oddly expensive day. */
export async function collectDay(db: Db, date: string, opts: { now?: number; log?: (m: string) => void; stationByNsr?: Map<string, string>; project?: boolean } = {}) {
  const now = opts.now ?? Date.now();
  const dry = await bigQuery(DAY_SQL, { dryRun: true, params: { date } });
  if (dry.bytes > MAX_DAY_BYTES) throw new Error(`BigQuery day ${date} would scan ${(dry.bytes / 1e9).toFixed(1)} GB; not run`);
  if (bytesThisMonth(now) + dry.bytes > MONTHLY_BYTES) throw new Error('BigQuery monthly ceiling reached; waiting for next month');
  const { rows, bytes } = await bigQuery(DAY_SQL, { params: { date } });
  addUsage(bytes, now);
  const file = await writeRaw(SOURCE, date, 'siri-et', rows, { now });
  const runs = opts.project === false ? [] : project(date, rows, await quays(now), opts.stationByNsr ?? (await stationsByPlace(db, now)));
  // Our own same-day record has platforms and messages this table lacks; it's kept where both exist.
  const written = saveRuns(db, runs, now, { keepSources: ['entur'] });
  recordFetch(db, { source: SOURCE, kind: 'siri-et', date, records: rows.length, runs: written, file, final: true }, now);
  opts.log?.(`observed NO (BigQuery) ${date}: ${rows.length} rows, ${runs.length} journeys, ${(bytes / 1e9).toFixed(2)} GB scanned`);
  return { rows: rows.length, runs: runs.length, bytes };
}

export const bigQueryEnabled = () => googleKeyPath() !== null;

/** Each morning: yesterday (Entur refreshes the table ~04:00 UTC). */
export async function runNightly(db: Db, opts: { now?: number; log?: (m: string) => void } = {}) {
  if (!bigQueryEnabled()) return;
  const date = addDays(todayIn('Europe/Oslo', opts.now ?? Date.now()), -1);
  if (fetchOf(db, SOURCE, 'siri-et', date)) return;
  await collectDay(db, date, opts);
}

/** One backfill step: the newest day not yet fetched, back to 2020. Null when done or when the month's budget is used. */
export async function backfillStep(db: Db, opts: { now?: number; log?: (m: string) => void } = {}): Promise<string | null> {
  if (!bigQueryEnabled()) return null;
  const now = opts.now ?? Date.now();
  if (bytesThisMonth(now) > MONTHLY_BYTES * 0.95) return null;
  const done = new Set((db.$client.prepare(`select date from observed_fetches where source = ? and kind = 'siri-et'`).all(SOURCE) as { date: string }[]).map((r) => r.date));
  for (let date = addDays(todayIn('Europe/Oslo', now), -2); date >= HISTORY_START; date = addDays(date, -1)) {
    if (done.has(date)) continue;
    await collectDay(db, date, { ...opts, project: date >= addDays(todayIn('Europe/Oslo', now), -PROJECT_DAYS) });
    return date;
  }
  return null;
}

/** Project one day already in the raw archive, replacing what's stored for it from this source. */
export async function projectDay(db: Db, date: string, ctx?: { quay: Awaited<ReturnType<typeof quays>>; stationByNsr: Map<string, string> }): Promise<number> {
  const { rawFiles, readRaw } = await import('./archive.js');
  const file = rawFiles(SOURCE, date, 'siri-et').at(-1);
  if (!file) return 0;
  const runs = project(date, readRaw<BqRow>(file), ctx?.quay ?? (await quays(Date.now())), ctx?.stationByNsr ?? (await stationsByPlace(db)));
  db.$client.transaction(() => {
    db.$client.prepare(`delete from observed_calls where country = 'NO' and service_date = ? and run_id in (select run_id from observed_runs where country = 'NO' and service_date = ? and source = ?)`).run(date, date, SOURCE);
    db.$client.prepare(`delete from observed_runs where country = 'NO' and service_date = ? and source = ?`).run(date, SOURCE);
  })();
  const written = saveRuns(db, runs, Date.now(), { keepSources: ['entur'] });
  db.$client.prepare(`update observed_fetches set runs = ? where source = ? and kind = 'siri-et' and date = ?`).run(written, SOURCE, date);
  return written;
}

/**
 * Fill a range of days fast (npm run import -- observed-backfill --country=NO): a week per query instead of a day
 * (a week of 2022 is ~120,000 rows, 0.6 GB scanned, ~20 s), several weeks at once, each day written to the raw archive.
 * Only days within PROJECT_DAYS are projected now; the rest when first asked for. Days already fetched are skipped.
 */
export async function backfillRange(db: Db, opts: { from: string; to?: string; parallel?: number; log?: (m: string) => void }) {
  const log = opts.log ?? console.log;
  const now = Date.now();
  const today = todayIn('Europe/Oslo', now);
  const to = opts.to ?? addDays(today, -2);
  const done = new Set((db.$client.prepare(`select date from observed_fetches where source = ? and kind = 'siri-et'`).all(SOURCE) as { date: string }[]).map((r) => r.date));
  const weeks: [string, string][] = [];
  for (let d = opts.from; d <= to; d = addDays(d, 7)) {
    const end = addDays(d, 6) < to ? addDays(d, 6) : to;
    let missing = false;
    for (let x = d; x <= end; x = addDays(x, 1)) if (!done.has(x)) missing = true;
    if (missing) weeks.push([d, end]);
  }
  const quay = await quays(now);
  const stationByNsr = await stationsByPlace(db, now);
  const projectFrom = addDays(today, -PROJECT_DAYS);
  const sql = `SELECT * FROM ${TABLE} WHERE operatingDate BETWEEN @from AND @to AND vehicleMode = 'rail'`;
  let next = 0;
  let rowsTotal = 0;
  const t0 = Date.now();
  const worker = async () => {
    for (let i = next++; i < weeks.length; i = next++) {
      const [from, end] = weeks[i]!;
      const dry = await bigQuery(sql, { dryRun: true, params: { from, to: end } });
      if (dry.bytes > MAX_DAY_BYTES * 7) throw new Error(`BigQuery week ${from} would scan ${(dry.bytes / 1e9).toFixed(1)} GB; stopped`);
      if (bytesThisMonth() + dry.bytes > MONTHLY_BYTES) throw new Error('BigQuery monthly ceiling reached; run again next month');
      const { rows, bytes } = await bigQuery(sql, { params: { from, to: end } });
      addUsage(bytes, Date.now());
      const byDay = new Map<string, BqRow[]>();
      for (const r of rows) {
        const d = String(r.operatingDate ?? '').slice(0, 10);
        (byDay.get(d) ?? byDay.set(d, []).get(d)!).push(r);
      }
      for (const [date, list] of byDay) {
        if (done.has(date)) continue;
        const file = await writeRaw(SOURCE, date, 'siri-et', list);
        const runs = date >= projectFrom ? project(date, list, quay, stationByNsr) : [];
        const written = saveRuns(db, runs, Date.now(), { keepSources: ['entur'] });
        recordFetch(db, { source: SOURCE, kind: 'siri-et', date, records: list.length, runs: written, file, final: true });
      }
      rowsTotal += rows.length;
      log(`NO backfill ${from}..${end}: ${rows.length} rows, ${(bytes / 1e9).toFixed(2)} GB (${i + 1}/${weeks.length} weeks, ${Math.round((Date.now() - t0) / 60_000)} min)`);
    }
  };
  await Promise.all(Array.from({ length: opts.parallel ?? 3 }, worker));
  log(`NO backfill done: ${weeks.length} weeks, ${rowsTotal} rows, ${(bytesThisMonth() / 1e9).toFixed(0)} GB used this month`);
}

/**
 * Rebuild the projection of every day already fetched, from the raw archive (after a change to `project`): the
 * stored runs of this source for the day are replaced. Nothing is fetched again.
 */
export async function reproject(db: Db, opts: { log?: (m: string) => void } = {}): Promise<number> {
  const { rawFiles, readRaw } = await import('./archive.js');
  // Only days already projected: the rest are raw only, and projected with the current reading when first asked for.
  const days = (
    db.$client.prepare(`select distinct service_date date from observed_runs where country = 'NO' and source = ? order by 1`).all(SOURCE) as { date: string }[]
  ).map((r) => r.date);
  const quay = await quays(Date.now());
  const stationByNsr = await stationsByPlace(db);
  for (const date of days) {
    const file = rawFiles(SOURCE, date, 'siri-et').at(-1);
    if (!file) continue;
    const runs = project(date, readRaw<BqRow>(file), quay, stationByNsr);
    db.$client.transaction(() => {
      db.$client.prepare(`delete from observed_calls where country = 'NO' and service_date = ? and run_id in (select run_id from observed_runs where country = 'NO' and service_date = ? and source = ?)`).run(date, date, SOURCE);
      db.$client.prepare(`delete from observed_runs where country = 'NO' and service_date = ? and source = ?`).run(date, SOURCE);
    })();
    saveRuns(db, runs, Date.now(), { keepSources: ['entur'] });
  }
  // Days already written as timetable trips (searched before) are written again from the new projection.
  const { writeDay } = await import('./timetable.js');
  const written = (db.$client.prepare(`select date from observed_fetches where source = 'clack' and kind = 'timetable-NO'`).all() as { date: string }[]).map((r) => r.date);
  for (const d of written) writeDay(db, 'NO', d);
  // Trips left with no dates by that (keys changed) go, unless a saved trip points at one.
  db.$client
    .prepare(`delete from timetable_trips where source = 'observed_no' and key not in (select trip_key from timetable_trip_dates) and key not in (select timetable_trip_key from legs where timetable_trip_key is not null)`)
    .run();
  opts.log?.(`reprojected ${days.length} Norwegian archive days; rewrote ${written.length} searched days`);
  return days.length;
}
