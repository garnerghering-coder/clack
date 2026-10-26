// Older Norwegian and Finnish days, searchable from the observed record. Neither country publishes past timetables,
// but the record holds every train that ran: Norway from Entur's archive back to 2020, Finland from Digitraffic back
// to 2016. When a day before the current feed is asked for, its recorded trains are written into the timetable tables
// (planned times only; what actually happened stays in the record and reaches a saved trip through observed/lookup),
// so search, the confirm step and saving work as for any day. Only days someone asks for are written, and a train
// that runs the same way on many days is stored once (keys are a fingerprint, like the Swedish archive's).
//
// Unlike a timetable, this has only the trains that ran and reported: one cancelled outright or run without real-time
// reporting may be missing. Lines aren't in Norway's older archive rows, so those trains get the default category.
import crypto from 'node:crypto';
import type { Db } from '../db/client.js';
import { FI_AGENCY_BRANDS, finnishProduct } from '../import/gtfs-fi.js';
import { norwegianCategory } from '../import/gtfs-no.js';
import { COUNTRIES } from '../lib/countries.js';
import { serviceTimeToUtc } from '../lib/time.js';
import * as bq from './bigquery.js';
import * as fi from './finland.js';
import { fetchOf, recordFetch } from './store.js';

export type RecordCountry = 'NO' | 'FI';
const SOURCE: Record<RecordCountry, string> = { NO: 'observed_no', FI: 'observed_fi' };

/** The first day of the country's current timetable feed: the record is only needed before it. */
export function firstFeedDay(db: Db, country: RecordCountry): string {
  const r = db.$client
    .prepare(`select min(d.service_date) d from timetable_trip_dates d join timetable_trips t on t.key = d.trip_key where t.source = ?`)
    .get(COUNTRIES[country].timetableSource) as { d: string | null };
  return r.d ?? '9999-12-31';
}

/** The first day the record can give, for the "goes back to" message. */
export function recordFrom(db: Db, country: RecordCountry): string {
  if (country === 'FI') return fi.HISTORY_START;
  return bq.bigQueryEnabled() ? bq.HISTORY_START : firstFeedDay(db, 'NO');
}

interface RunRow {
  run_id: string;
  train_number: string | null;
  operator: string | null;
  product: string | null;
  info: string;
}
interface CallRow {
  run_id: string;
  seq: number;
  station_id: string | null;
  sched_arr: number | null;
  sched_dep: number | null;
}

/**
 * Write one recorded day into the timetable tables. Returns how many trains it holds; trains with a stop that isn't
 * one of our stations (or not a passenger type) are left out, as the imports do. Idempotent.
 */
export function writeDay(db: Db, country: RecordCountry, date: string): number {
  const sqlite = db.$client;
  const tz = COUNTRIES[country].tz;
  const runs = sqlite.prepare(`select run_id, train_number, operator, product, info from observed_runs where country = ? and service_date = ?`).all(country, date) as RunRow[];
  const calls = sqlite.prepare(`select run_id, seq, station_id, sched_arr, sched_dep from observed_calls where country = ? and service_date = ? order by run_id, seq`).all(country, date) as CallRow[];
  const byRun = new Map<string, CallRow[]>();
  for (const c of calls) (byRun.get(c.run_id) ?? byRun.set(c.run_id, []).get(c.run_id)!).push(c);
  const names = new Map((sqlite.prepare(`select id, name from stations`).all() as { id: string; name: string }[]).map((s) => [s.id, s.name]));
  // Norway's brands by codespace, as the current feed has them (VYG → Vy …); Finland's by the agency code.
  const brandOfCodespace = new Map<string, string | null>();
  const noBrand = (cs: string | null) => {
    if (!cs) return null;
    if (!brandOfCodespace.has(cs))
      brandOfCodespace.set(cs, (sqlite.prepare(`select operator_id from timetable_trips where source = 'gtfs_no' and trip_id like ? and operator_id is not null limit 1`).get(`${cs}:%`) as { operator_id: string } | undefined)?.operator_id ?? null);
    return brandOfCodespace.get(cs)!;
  };
  const day0 = serviceTimeToUtc(date, 0, tz);
  const sec = (ms: number | null) => (ms === null ? null : Math.round((ms - day0) / 1000));

  const trips: { key: string; number: string | null; operatorId: string | null; gtfsOperator: string | null; routeName: string | null; routeType: string; category: string; line: string | null; headsign: string | null; stops: [string, number | null, number | null][] }[] = [];
  let skipped = 0;
  for (const r of runs) {
    const list = byRun.get(r.run_id) ?? [];
    // Every stop must be one of our stations, as in the timetable imports; otherwise the train is left out.
    if (list.length < 2 || list.some((c) => !c.station_id)) {
      skipped++;
      continue;
    }
    const info = JSON.parse(r.info) as Record<string, unknown>;
    const stops = list.map((c): [string, number | null, number | null] => [c.station_id!, sec(c.sched_arr), sec(c.sched_dep)]);
    let category: string;
    let routeType = '2';
    let operatorId: string | null;
    if (country === 'FI') {
      const kind = finnishProduct(String(info.trainType ?? ''));
      if (!kind.product) {
        skipped++;
        continue;
      }
      category = kind.product;
      routeType = info.trainCategory === 'Commuter' ? '109' : '102';
      operatorId = FI_AGENCY_BRANDS[String(info.operatorUICCode ?? '')] ?? null;
    } else {
      category = norwegianCategory(r.product ?? '', stops[0]![2] ?? stops[0]![1], stops.at(-1)![1] ?? stops.at(-1)![2]);
      operatorId = noBrand(r.operator);
    }
    const first = names.get(stops[0]![0]) ?? '';
    const last = names.get(stops.at(-1)![0]) ?? '';
    const routeName = [r.product, `${first} - ${last}`].filter(Boolean).join(' ');
    const line = country === 'FI' ? (String(info.commuterLineID ?? '') || String(info.trainType ?? '') || null) : r.product;
    const hash = crypto.createHash('sha1').update(JSON.stringify([r.train_number, operatorId, r.operator, category, routeType, line, stops])).digest('hex').slice(0, 14);
    trips.push({ key: `${COUNTRIES[country].keyPrefix}:obs:${hash}`, number: r.train_number, operatorId, gtfsOperator: r.operator, routeName, routeType, category, line, headsign: last || null, stops });
  }

  db.transaction(() => {
    // The day again (more trains recorded since): its old dates go, the trains stay for trips saved against them.
    sqlite.prepare(`delete from timetable_trip_dates where service_date = ? and trip_key in (select key from timetable_trips where source = ?)`).run(date, SOURCE[country]);
    const insertTrip = sqlite.prepare(
      `insert or ignore into timetable_trips (key, source, trip_id, train_number, operator_id, gtfs_operator, route_name, route_type, category, tz, feed_version, line, headsign)
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    );
    const insertStop = sqlite.prepare(`insert or ignore into timetable_stop_times (trip_key, seq, station_id, arr_sec, dep_sec) values (?, ?, ?, ?, ?)`);
    const insertDate = sqlite.prepare(`insert or ignore into timetable_trip_dates (trip_key, service_date) values (?, ?)`);
    for (const t of trips) {
      insertTrip.run(t.key, SOURCE[country], t.key, t.number, t.operatorId, t.gtfsOperator, t.routeName, t.routeType, t.category, tz, `record:${date}`, t.line, t.headsign);
      t.stops.forEach((s, i) => insertStop.run(t.key, i + 1, s[0], s[1], s[2]));
      insertDate.run(t.key, date);
    }
  });
  recordFetch(db, { source: 'clack', kind: `timetable-${country}`, date, records: runs.length, runs: trips.length, file: '', final: true });
  return trips.length;
}

export type DayState = 'ready' | 'loading' | 'failed' | 'unavailable';
const inflight = new Map<string, Promise<unknown>>();
const failures = new Map<string, number>();

/**
 * Make sure an older Norwegian or Finnish day is searchable. Returns at once: 'ready' (written now, or the current
 * feed covers it), 'loading' (being fetched: ask again shortly), 'failed' (retried after a minute), 'unavailable'
 * (before the record starts, or Norway without BigQuery).
 */
export function ensureRecordedDay(db: Db, country: RecordCountry, date: string, opts: { log?: (m: string) => void; now?: number } = {}): DayState {
  const now = opts.now ?? Date.now();
  if (date >= firstFeedDay(db, country)) return 'ready';
  if (date < recordFrom(db, country)) return 'unavailable';
  const k = `${country}|${date}`;
  if (inflight.has(k)) return 'loading';
  if (now - (failures.get(k) ?? 0) < 60_000) return 'failed';
  const written = fetchOf(db, 'clack', `timetable-${country}`, date);
  const runs = (db.$client.prepare(`select count(*) n from observed_runs where country = ? and service_date = ?`).get(country, date) as { n: number }).n;
  // Already written with what the record holds now.
  if (written && written.records === runs && runs > 0) return 'ready';
  const have = country === 'FI' ? fetchOf(db, fi.SOURCE, 'trains', date) : fetchOf(db, bq.SOURCE, 'siri-et', date);
  if (have && runs > 0) {
    writeDay(db, country, date);
    return 'ready';
  }
  if (country === 'NO' && !bq.bigQueryEnabled()) return 'unavailable';
  // Fetched before but kept raw only (Finland's deep backfill), or not fetched yet: get it, then write it.
  const run = (country === 'FI' ? (have ? fi.projectFromRaw(db, date) : fi.collectDay(db, date, { log: opts.log })) : bq.collectDay(db, date, { log: opts.log })).then(() => writeDay(db, country, date));
  inflight.set(k, run);
  run.then(
    () => failures.delete(k),
    (e) => {
      failures.set(k, Date.now());
      opts.log?.(`record ${country} ${date} failed: ${(e as Error).message}`);
    },
  ).finally(() => inflight.delete(k));
  return 'loading';
}
