// Finland's observed record, from Digitraffic (FINLAND_DATA_FINDINGS.md). Unlike Trafikverket and Entur, Digitraffic
// keeps its history (full days back to 2016-01, checked 2026-10-26), so Finland's past can be filled in too. Each night:
// every train of yesterday (/trains/{date}: all trains, freight included, with every timetable row, actual time,
// track and cause) and every composition (/compositions/{date}: locomotives and wagons with type, length, pet,
// catering and accessibility flags, top speed), refetched once more the next night (then final). A slow backfill
// walks back to 2016 keeping the raw days; the projection is built for passenger trains.
//
// Measured 2026-10-26: a day is ~1,330 trains (~1,000 passenger), 17.8 MB as JSON, 0.76 MB gzipped; compositions
// 0.8 MB / 26 KB.
import type { Db } from '../db/client.js';
import { fetchJson } from '../digitraffic/client.js';
import { isPassengerTrain, type DtRow, type DtTrain } from '../digitraffic/trains.js';
import { addDays, todayIn } from '../lib/time.js';
import { COUNTRIES } from '../lib/countries.js';
import { writeRaw } from './archive.js';
import { cancelLevel, fetchOf, passage, recordFetch, saveRuns, type ObservedCall, type ObservedCause, type ObservedRun, type Passage } from './store.js';

const TZ = COUNTRIES.FI.tz;
export const SOURCE = 'digitraffic';
/** Digitraffic settles a day's data within about a day; the second night's fetch is final. */
export const FINAL_AFTER_DAYS = 2;
/** The oldest day Digitraffic was seen to have in full (2015-06-01 came back empty; 2016-01-15 full). */
export const HISTORY_START = '2016-01-01';

type Row = DtRow & Record<string, unknown>;
type Train = Omit<DtTrain, 'timeTableRows'> & Record<string, unknown> & { timeTableRows: Row[] };
type Composition = Record<string, unknown> & { trainNumber: number; departureDate: string; journeySections?: unknown[] };

/**
 * Row fields with a column of their own, and ones that repeat a station fact (its UIC code and country) or follow from
 * the times (differenceInMinutes): those are left to the raw archive, which keeps every field.
 */
const CALL_FIELDS = new Set(['type', 'stationShortCode', 'scheduledTime', 'actualTime', 'liveEstimateTime', 'commercialTrack', 'cancelled', 'trainStopping', 'commercialStop', 'stationUICCode', 'countryCode', 'differenceInMinutes']);

const ms = (s: unknown) => (typeof s === 'string' ? Date.parse(s) : null);

function causesOf(rows: (Row | undefined)[]): ObservedCause[] {
  const out: ObservedCause[] = [];
  const seen = new Set<string>();
  for (const r of rows)
    for (const c of (r?.causes ?? []) as Record<string, string | undefined>[]) {
      const code = c.thirdCategoryCode ?? c.detailedCategoryCode ?? c.categoryCode;
      if (!code || seen.has(code)) continue;
      seen.add(code);
      out.push({ src: 'dt', code });
    }
  return out;
}

const rest = (r?: Row) => {
  if (!r) return undefined;
  const o: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(r)) if (!CALL_FIELDS.has(k) && !(k === 'causes' && Array.isArray(v) && !v.length)) o[k] = v;
  return o;
};

/**
 * One day's trains as runs (passenger trains only; the rest stay in the raw archive). Stops are rows where the train
 * stops for passengers, arrival and departure merged per station; every other row is a passage. The train's own
 * fields and its composition go in `info`.
 */
export function project(date: string, trains: Train[], compositions: Composition[], stationByCode: Map<string, string>, final: boolean): ObservedRun[] {
  const comp = new Map(compositions.map((c) => [String(c.trainNumber), c]));
  const runs: ObservedRun[] = [];
  for (const t of trains) {
    if (t.departureDate !== date || !isPassengerTrain(t)) continue;
    const pairs: { arr?: Row; dep?: Row }[] = [];
    const passages: Passage[] = [];
    for (const r of t.timeTableRows) {
      if (!(r.trainStopping && r.commercialStop)) {
        passages.push(passage(r.stationShortCode, r.type === 'ARRIVAL' ? 'A' : 'D', Date.parse(r.scheduledTime), ms(r.actualTime)));
        continue;
      }
      const cur = pairs.at(-1);
      if (r.type === 'DEPARTURE' && cur && !cur.dep && cur.arr?.stationShortCode === r.stationShortCode) cur.dep = r;
      else pairs.push(r.type === 'ARRIVAL' ? { arr: r } : { dep: r });
    }
    const calls: ObservedCall[] = pairs.map((p, i) => {
      const any = (p.arr ?? p.dep)!;
      const extra: Record<string, unknown> = {};
      const ea = rest(p.arr);
      const ed = rest(p.dep);
      if (ea && Object.keys(ea).length) extra.a = ea;
      if (ed && Object.keys(ed).length) extra.d = ed;
      return {
        seq: i + 1,
        location: any.stationShortCode,
        stationId: stationByCode.get(any.stationShortCode) ?? null,
        schedArr: p.arr ? ms(p.arr.scheduledTime) : null,
        schedDep: p.dep ? ms(p.dep.scheduledTime) : null,
        estArr: p.arr ? ms(p.arr.liveEstimateTime) : null,
        estDep: p.dep ? ms(p.dep.liveEstimateTime) : null,
        actualArr: p.arr ? ms(p.arr.actualTime) : null,
        actualDep: p.dep ? ms(p.dep.actualTime) : null,
        platform: p.dep?.commercialTrack || p.arr?.commercialTrack || null,
        canceledArr: Boolean(p.arr?.cancelled),
        canceledDep: Boolean(p.dep?.cancelled),
        causes: causesOf([p.arr, p.dep]),
        extra,
      };
    });
    if (!calls.length) continue;
    const { timeTableRows: _rows, ...trainFields } = t;
    const c = comp.get(String(t.trainNumber));
    const info: Record<string, unknown> = { ...trainFields };
    if (c) info.composition = { version: c.version, journeySections: c.journeySections };
    runs.push({
      country: 'FI',
      serviceDate: date,
      runId: String(t.trainNumber),
      trainNumber: String(t.trainNumber),
      source: SOURCE,
      operator: t.operatorShortCode ?? null,
      product: [t.trainType, t.commuterLineID].filter(Boolean).join(' ') || null,
      canceled: cancelLevel(calls, Boolean(t.cancelled)),
      info,
      passages,
      calls,
      final,
    });
  }
  return runs;
}

export function stationsByFiCode(db: Db): Map<string, string> {
  const rows = db.$client.prepare(`select id, fi_id from stations where fi_id is not null`).all() as { id: string; fi_id: string }[];
  return new Map(rows.map((r) => [r.fi_id, r.id]));
}

/** Fetch and archive one day; project it unless `projectRuns` is false (the deep backfill keeps raw days only). */
export async function collectDay(db: Db, date: string, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void; projectRuns?: boolean } = {}) {
  const now = opts.now ?? Date.now();
  const final = date <= addDays(todayIn(TZ, now), -FINAL_AFTER_DAYS);
  const trains = await fetchJson<Train[]>(`trains/${date}`, { fetchImpl: opts.fetchImpl });
  // An empty day means Digitraffic doesn't have it (yet), not that no train ran: don't call it done.
  if (!Array.isArray(trains) || !trains.length) {
    opts.log?.(`observed FI ${date}: Digitraffic has nothing for this day`);
    return { records: 0, runs: 0 };
  }
  const compositions = await fetchJson<Composition[]>(`compositions/${date}`, { fetchImpl: opts.fetchImpl });
  const tFile = writeRaw(SOURCE, date, 'trains', trains, { now });
  const cFile = writeRaw(SOURCE, date, 'compositions', compositions, { now });
  const runs = opts.projectRuns === false ? [] : project(date, trains, compositions, stationsByFiCode(db), final);
  const written = saveRuns(db, runs, now);
  recordFetch(db, { source: SOURCE, kind: 'trains', date, records: trains.length, runs: written, file: tFile, final }, now);
  recordFetch(db, { source: SOURCE, kind: 'compositions', date, records: compositions.length, file: cFile, final }, now);
  opts.log?.(`observed FI ${date}: ${trains.length} trains, ${runs.length} passenger runs${final ? ' (final)' : ''}`);
  return { records: trains.length, runs: runs.length };
}

/** The nightly round: yesterday and any recent day not final yet. */
export async function runFinland(db: Db, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void } = {}) {
  const today = todayIn(TZ, opts.now ?? Date.now());
  for (let back = FINAL_AFTER_DAYS + 1; back >= 1; back--) {
    const date = addDays(today, -back);
    if (fetchOf(db, SOURCE, 'trains', date)?.final) continue;
    await collectDay(db, date, opts).catch((e) => opts.log?.(`observed FI ${date} failed: ${(e as Error).message}`));
  }
}

/** Days within this many of today get projected during the backfill; older ones are kept raw (projectable later). */
export const BACKFILL_PROJECT_DAYS = 730;

/**
 * One step of the backfill: the newest day before today that has no final fetch, back to HISTORY_START. Returns the
 * day done, or null when the backfill is complete. Two requests per step; the scheduler paces it.
 */
export async function backfillStep(db: Db, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void } = {}): Promise<string | null> {
  const now = opts.now ?? Date.now();
  const today = todayIn(TZ, now);
  const done = new Set(
    (db.$client.prepare(`select date from observed_fetches where source = ? and kind = 'trains' and final = 1`).all(SOURCE) as { date: string }[]).map((r) => r.date),
  );
  for (let date = addDays(today, -(FINAL_AFTER_DAYS + 1)); date >= HISTORY_START; date = addDays(date, -1)) {
    if (done.has(date)) continue;
    await collectDay(db, date, { ...opts, projectRuns: date >= addDays(today, -BACKFILL_PROJECT_DAYS) });
    return date;
  }
  return null;
}
