// Writing the observed record's projection (observed_runs, observed_calls). A run fetched again replaces its earlier
// version whole: a later fetch from the same source knows at least as much (Trafikverket fills actual times in for
// up to ~3 days), and a run marked final is never overwritten by a non-final one.
import type { Db } from '../db/client.js';

export type Country = 'SE' | 'NO' | 'FI' | 'DK';

export interface ObservedCause {
  src: string;
  code?: string;
  text?: string;
}

export interface ObservedCall {
  seq: number;
  location: string;
  stationId: string | null;
  schedArr: number | null;
  schedDep: number | null;
  estArr: number | null;
  estDep: number | null;
  actualArr: number | null;
  actualDep: number | null;
  platform: string | null;
  canceledArr: boolean;
  canceledDep: boolean;
  causes: ObservedCause[];
  extra: Record<string, unknown>;
}

/**
 * A timing point passed without a stop: where, arrival or departure, the planned time in epoch seconds, and how many
 * seconds after it the train actually passed (null: not reported). Compact because a long train has hundreds.
 */
export type Passage = [location: string, activity: 'A' | 'D', plannedSec: number, delaySec: number | null];

export const passage = (location: string, activity: 'A' | 'D', plannedMs: number, actualMs: number | null): Passage => [
  location,
  activity,
  Math.round(plannedMs / 1000),
  actualMs === null ? null : Math.round((actualMs - plannedMs) / 1000),
];

export interface ObservedRun {
  country: Country;
  serviceDate: string;
  runId: string;
  trainNumber: string | null;
  source: string;
  operator: string | null;
  product: string | null;
  /** 0 ran, 1 partly cancelled, 2 cancelled throughout. */
  canceled: 0 | 1 | 2;
  info: Record<string, unknown>;
  passages: Passage[];
  calls: ObservedCall[];
  final: boolean;
}

/** Run-level summary from the calls: first and last stop, their times, the final delay, how much was cancelled. */
export function summarize(calls: ObservedCall[]): {
  originLocation: string | null;
  destLocation: string | null;
  schedDep: number | null;
  schedArr: number | null;
  actualDep: number | null;
  actualArr: number | null;
  arrDelaySec: number | null;
} {
  const first = calls[0];
  const last = calls.at(-1);
  const schedArr = last?.schedArr ?? last?.schedDep ?? null;
  const actualArr = last?.actualArr ?? null;
  return {
    originLocation: first?.location ?? null,
    destLocation: last?.location ?? null,
    schedDep: first?.schedDep ?? first?.schedArr ?? null,
    schedArr,
    actualDep: first?.actualDep ?? null,
    actualArr,
    arrDelaySec: actualArr !== null && schedArr !== null ? Math.round((actualArr - schedArr) / 1000) : null,
  };
}

/** 2 when every call is cancelled both ways, 1 when some are, else 0. */
export function cancelLevel(calls: ObservedCall[], wholeTrain = false): 0 | 1 | 2 {
  if (wholeTrain) return 2;
  if (!calls.length) return 0;
  const flags = calls.flatMap((c, i) => [...(i > 0 ? [c.canceledArr] : []), ...(i < calls.length - 1 ? [c.canceledDep] : [])]);
  if (flags.length && flags.every(Boolean)) return 2;
  return flags.some(Boolean) ? 1 : 0;
}

/**
 * Save runs (one transaction). Returns how many were written. A final run already stored is kept over a non-final
 * one, and a run stored from one of `keepSources` is never replaced (Entur's archive fills gaps in our own same-day
 * record, which has more detail, rather than overwriting it).
 */
export function saveRuns(db: Db, runs: ObservedRun[], now = Date.now(), opts: { keepSources?: string[] } = {}): number {
  const sqlite = db.$client;
  const isFinal = sqlite.prepare(`select final, source from observed_runs where country = ? and service_date = ? and run_id = ?`);
  const upsertRun = sqlite.prepare(`
    insert into observed_runs (country, service_date, run_id, train_number, source, operator, product, canceled,
      origin_location, dest_location, sched_dep, sched_arr, actual_dep, actual_arr, arr_delay_sec, info, passages, fetched_at, final)
    values (@country, @serviceDate, @runId, @trainNumber, @source, @operator, @product, @canceled,
      @originLocation, @destLocation, @schedDep, @schedArr, @actualDep, @actualArr, @arrDelaySec, @info, @passages, @fetchedAt, @final)
    on conflict (country, service_date, run_id) do update set
      train_number = excluded.train_number, source = excluded.source, operator = excluded.operator, product = excluded.product,
      canceled = excluded.canceled, origin_location = excluded.origin_location, dest_location = excluded.dest_location,
      sched_dep = excluded.sched_dep, sched_arr = excluded.sched_arr, actual_dep = excluded.actual_dep, actual_arr = excluded.actual_arr,
      arr_delay_sec = excluded.arr_delay_sec, info = excluded.info, passages = excluded.passages, fetched_at = excluded.fetched_at,
      final = excluded.final`);
  const clearCalls = sqlite.prepare(`delete from observed_calls where country = ? and service_date = ? and run_id = ?`);
  const insertCall = sqlite.prepare(`
    insert into observed_calls (country, service_date, run_id, seq, location, station_id, sched_arr, sched_dep, est_arr, est_dep,
      actual_arr, actual_dep, platform, canceled_arr, canceled_dep, causes, extra)
    values (@country, @serviceDate, @runId, @seq, @location, @stationId, @schedArr, @schedDep, @estArr, @estDep,
      @actualArr, @actualDep, @platform, @canceledArr, @canceledDep, @causes, @extra)`);
  let written = 0;
  sqlite.transaction(() => {
    for (const r of runs) {
      const stored = isFinal.get(r.country, r.serviceDate, r.runId) as { final: number; source: string } | undefined;
      if (stored?.final && !r.final) continue;
      if (stored && stored.source !== r.source && opts.keepSources?.includes(stored.source)) continue;
      upsertRun.run({
        country: r.country,
        serviceDate: r.serviceDate,
        runId: r.runId,
        trainNumber: r.trainNumber,
        source: r.source,
        operator: r.operator,
        product: r.product,
        canceled: r.canceled,
        ...summarize(r.calls),
        info: JSON.stringify(r.info),
        passages: JSON.stringify(r.passages),
        fetchedAt: now,
        final: r.final ? 1 : 0,
      });
      clearCalls.run(r.country, r.serviceDate, r.runId);
      for (const c of r.calls)
        insertCall.run({
          country: r.country,
          serviceDate: r.serviceDate,
          runId: r.runId,
          ...c,
          canceledArr: c.canceledArr ? 1 : 0,
          canceledDep: c.canceledDep ? 1 : 0,
          causes: JSON.stringify(c.causes),
          extra: JSON.stringify(c.extra),
        });
      written++;
    }
  })();
  return written;
}

/** Note a fetch in observed_fetches (the latest per source, kind and day wins). */
export function recordFetch(
  db: Db,
  f: { source: string; kind: string; date: string; records: number; runs?: number; file: string; final?: boolean },
  now = Date.now(),
) {
  db.$client
    .prepare(
      `insert into observed_fetches (source, kind, date, fetched_at, records, runs, file, final) values (?, ?, ?, ?, ?, ?, ?, ?)
       on conflict (source, kind, date) do update set fetched_at = excluded.fetched_at, records = excluded.records,
         runs = excluded.runs, file = excluded.file, final = excluded.final`,
    )
    .run(f.source, f.kind, f.date, now, f.records, f.runs ?? 0, f.file, f.final ? 1 : 0);
}

/** The stored fetch for a source, kind and day, if any. */
export function fetchOf(db: Db, source: string, kind: string, date: string): { fetchedAt: number; final: boolean; records: number } | null {
  const r = db.$client.prepare(`select fetched_at, final, records from observed_fetches where source = ? and kind = ? and date = ?`).get(source, kind, date) as
    | { fetched_at: number; final: number; records: number }
    | undefined;
  return r ? { fetchedAt: r.fetched_at, final: Boolean(r.final), records: r.records } : null;
}
