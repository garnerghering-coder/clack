// Delay history (BUILDOUT O4): how a train usually runs at a station, read from the observed record
// (observed_runs / observed_calls, SPEC §5.6), which holds every passenger train in Sweden, Norway, Finland and
// Denmark since the recorder started. Nothing predicted: counts and quantiles of what happened on earlier days,
// said with the number of days they rest on. docs/DELAY_HISTORY.md has the method and a checked sample.
import type { Db } from '../db/client.js';
import { addDays } from '../lib/time.js';

export interface Punctuality {
  /** Days with an actual time (or a cancellation) for this train at this station in the window. */
  days: number;
  /** Days at least `LATE_HISTORY_MIN` late (cancellations count as late). */
  lateDays: number;
  /** Days under `LATE_HISTORY_MIN` late, early ones included. */
  onTimeDays: number;
  canceledDays: number;
  /** Quantiles of the delay in minutes over the days that ran (cancellations left out), never below 0. */
  medianMin: number;
  p80Min: number;
  /** The usual band: the first and third quartiles. */
  lowMin: number;
  highMin: number;
  /** The window read (service dates, both inclusive). */
  from: string;
  to: string;
}

/** Late, for the history: five minutes, as the risk card's pattern rule has used since 2026-10-22. */
export const LATE_HISTORY_MIN = 5;
/** Days looked back. */
export const HISTORY_DAYS = 28;

interface Row {
  d: string;
  sa: number | null;
  aa: number | null;
  sd: number | null;
  ad: number | null;
  ca: number;
  cd: number;
  rc: number;
}

/** One answer per train, station, event and day, for an hour: the record only grows by a day at a time. */
const cache = new Map<string, { at: number; value: Punctuality | null }>();
const CACHE_MS = 3600_000;

/** Nearest-rank quantile (the value at ceil(q·n)): the median of two days is the better one, p80 of nine the eighth. */
const quantile = (sorted: number[], q: number) => (sorted.length ? sorted[Math.max(0, Math.min(sorted.length - 1, Math.ceil(q * sorted.length) - 1))]! : 0);

/**
 * The train's record at the station over the `days` service dates before `before` (exclusive): arrivals by default
 * (`event: 'dep'` for departures, the boarding station). Null when the record has nothing for it.
 */
export function punctuality(
  db: Db,
  q: { trainNumber: string; stationId: string; before: string; days?: number; event?: 'arr' | 'dep'; now?: number },
): Punctuality | null {
  const days = q.days ?? HISTORY_DAYS;
  const event = q.event ?? 'arr';
  const key = `${q.trainNumber}|${q.stationId}|${q.before}|${days}|${event}`;
  const now = q.now ?? Date.now();
  const hit = cache.get(key);
  if (hit && now - hit.at < CACHE_MS) return hit.value;
  const from = addDays(q.before, -days);
  const to = addDays(q.before, -1);
  const rows = db.$client
    .prepare(
      `select r.service_date d, c.sched_arr sa, c.actual_arr aa, c.sched_dep sd, c.actual_dep ad, c.canceled_arr ca, c.canceled_dep cd, r.canceled rc
       from observed_runs r
       join observed_calls c on c.country = r.country and c.service_date = r.service_date and c.run_id = r.run_id
       where r.train_number = ? and c.station_id = ? and r.service_date >= ? and r.service_date <= ?
       order by r.service_date, c.seq`,
    )
    .all(q.trainNumber, q.stationId, from, to) as Row[];
  const value = summarise(rows, event, from, to);
  cache.set(key, { at: now, value });
  if (cache.size > 5000) cache.delete(cache.keys().next().value!);
  return value;
}

/** The figures from the day rows (the first call per day counts). Pure. */
export function summarise(rows: Row[], event: 'arr' | 'dep', from: string, to: string): Punctuality | null {
  const seen = new Set<string>();
  const delays: number[] = [];
  let canceled = 0;
  for (const r of rows) {
    if (seen.has(r.d)) continue;
    // Arrival at the station, or the departure when asked (or when there is no arrival: the train's first stop).
    const useDep = event === 'dep' || r.sa === null;
    const sched = useDep ? r.sd : r.sa;
    const actual = useDep ? r.ad : r.aa;
    const gone = r.rc === 1 || (useDep ? r.cd === 1 : r.ca === 1);
    if (gone) {
      seen.add(r.d);
      canceled += 1;
      continue;
    }
    if (sched === null || actual === null) continue;
    seen.add(r.d);
    delays.push(Math.max(0, Math.round((actual - sched) / 60_000)));
  }
  const n = delays.length + canceled;
  if (n === 0) return null;
  const s = [...delays].sort((a, b) => a - b);
  const late = delays.filter((x) => x >= LATE_HISTORY_MIN).length + canceled;
  return {
    days: n,
    lateDays: late,
    onTimeDays: n - late,
    canceledDays: canceled,
    medianMin: quantile(s, 0.5),
    p80Min: quantile(s, 0.8),
    lowMin: quantile(s, 0.25),
    highMin: quantile(s, 0.75),
    from,
    to,
  };
}

/** For tests. */
export function forgetPunctuality() {
  cache.clear();
}
