// The cross-source consistency check (owner, 2026-11-07): where two feeds record the same train, do they agree? Each
// night the previous finished day is compared, pair by pair, and the differences written to `diagnostics` (kind
// `cross_source`) with a summary row per pair and day. Nothing here changes the record; it only measures, in the
// accuracy audit's words (audit.ts): agree (within a minute), disagree, missing (one side has a time, the other none).
//
//  - Öresund: Trafikverket's Swedish record against train-archive.eu's Danish one (Rejseplanen's feed). The two meet
//    on the trains Sweden's feed carries over the bridge, named in the Danish record by their Danish calls since
//    2026-11-07 (observed/dk-archive.ts, matchedBy 'se-stop-times'; a Danish train named by gtfs_dk may share its
//    number with an unrelated Swedish one, NT's 75 with a Pågatåg, so those are left out). Compared at the corridor
//    stations Hyllie, CPH Airport and København H; in practice only Hyllie, since Trafikverket announces no Danish
//    stop. Checked by hand on 2026-10-26: Öresundståg 1004 was 48 min late through Copenhagen in Rejseplanen's
//    record while Trafikverket had it on time from Malmö, a real difference the check exists to surface.
//  - Norway: our same-day Entur record against Entur's BigQuery archive. The archive never overwrites a live run
//    (store.ts keepSources), so its version is read again from the raw day file and compared in memory.
//
// Times are compared by minute, allowing one minute either way: Rejseplanen rounds to minutes, Trafikverket keeps
// seconds, and BigQuery's rows carry the last recorded value rather than the final one.
import type { Db } from '../db/client.js';
import { addDays, todayIn } from '../lib/time.js';
import { rawFiles, readRaw } from '../observed/archive.js';
import * as bq from '../observed/bigquery.js';
import { SOURCE as DK_SOURCE } from '../observed/dk-archive.js';
import { SOURCE as ENTUR_SOURCE } from '../observed/norway.js';
import { SOURCE as TRV_SOURCE } from '../observed/sweden.js';
import type { ObservedRun } from '../observed/store.js';

export const KIND = 'cross_source';
/** The pairs, named `<a>~<b>`; `a` is the side whose runs are walked. */
export const PAIRS = { oresund: `${TRV_SOURCE}~${DK_SOURCE}`, norway: `${ENTUR_SOURCE}~${bq.SOURCE}` } as const;
/** How many difference rows a pair writes for one day; the summary always carries the full counts. */
export const MAX_DIFFERENCES = 500;
/** The Öresund corridor's shared stations, as the stations table keys them (Sweden's feed ids): Hyllie, CPH Airport, København H. */
export const ORESUND_STATIONS = new Set(['740001586', '860000858', '860000626']);

export type Verdict = 'agree' | 'disagree' | 'missing';

export interface SourceCall {
  stationId: string | null;
  location: string;
  schedArr: number | null;
  schedDep: number | null;
  actualArr: number | null;
  actualDep: number | null;
  canceledArr: boolean;
  canceledDep: boolean;
}

export interface SourceRun {
  source: string;
  runId: string;
  trainNumber: string | null;
  /** 0 ran, 1 partly cancelled, 2 cancelled throughout (observed_runs.canceled). */
  canceled: number;
  /** How the Danish archive named the run (observed_runs.info.matchedBy); absent for other sources. */
  matchedBy?: string;
  calls: SourceCall[];
}

/** One thing the two sources say differently about a train on a day, as written to `diagnostics`. */
export interface Difference {
  train: string | null;
  date: string;
  /** Our station id, else the first source's location code. */
  station: string | null;
  field: 'arr' | 'dep' | 'canceled';
  verdict: 'disagree' | 'missing';
  /** The two values as HH:MM (UTC) for times, yes/no for cancellation, null where a side has none. */
  a: string | null;
  b: string | null;
  sources: [string, string];
}

export interface Comparison {
  agree: number;
  disagree: number;
  missing: number;
  differences: Difference[];
}

export interface PairSummary {
  pair: string;
  date: string;
  /** Runs seen in both sources, only in the first, only in the second. */
  runs: { both: number; onlyA: number; onlyB: number };
  agree: number;
  disagree: number;
  missing: number;
  /** Why nothing could be compared, when so. */
  note?: string;
}

const minute = (t: number | null) => (t === null ? null : Math.floor(t / 60_000));
const hhmm = (t: number | null) => (t === null ? null : new Date(t).toISOString().slice(11, 16));
const yesNo = (b: boolean) => (b ? 'yes' : 'no');

/** Both known and within a minute of each other. */
const near = (x: number | null, y: number | null) => x !== null && y !== null && Math.abs(minute(x)! - minute(y)!) <= 1;
/** The same scheduled event: the arrival or the departure planned at the same minute. */
const sameSchedule = (x: SourceCall, y: SourceCall) => near(x.schedArr, y.schedArr) || near(x.schedDep, y.schedDep);

/**
 * The call in `b` that is the same event as `a`'s: the same scheduled minute (the two sources read the same
 * timetable) and, where both know the station, the same station. Each call is used once.
 */
function alignCalls(a: SourceCall[], b: SourceCall[]): [SourceCall, SourceCall][] {
  const used = new Set<SourceCall>();
  const out: [SourceCall, SourceCall][] = [];
  for (const x of a) {
    const y = b.find((y) => !used.has(y) && sameSchedule(x, y) && (!x.stationId || !y.stationId || x.stationId === y.stationId));
    if (!y) continue;
    used.add(y);
    out.push([x, y]);
  }
  return out;
}

/**
 * Two sources' versions of one run, call by call. A time counts once per arrival or departure both could know; a
 * cancellation once per call where either says so, and once for the run as a whole. Pure.
 */
export function compareRuns(date: string, a: SourceRun, b: SourceRun, opts: { stations?: Set<string>; toleranceMin?: number } = {}): Comparison {
  const tol = opts.toleranceMin ?? 1;
  const c: Comparison = { agree: 0, disagree: 0, missing: 0, differences: [] };
  const sources: [string, string] = [a.source, b.source];
  const note = (d: Omit<Difference, 'date' | 'sources' | 'train'>) => {
    c[d.verdict]++;
    c.differences.push({ train: a.trainNumber ?? b.trainNumber, date, sources, ...d });
  };
  for (const [x, y] of alignCalls(a.calls, b.calls)) {
    const station = x.stationId ?? y.stationId ?? null;
    if (opts.stations && (!station || !opts.stations.has(station))) continue;
    for (const [field, ours, theirs] of [
      ['arr', x.actualArr, y.actualArr],
      ['dep', x.actualDep, y.actualDep],
    ] as const) {
      if (ours === null && theirs === null) continue;
      if (ours === null || theirs === null) note({ station: station ?? x.location, field, verdict: 'missing', a: hhmm(ours), b: hhmm(theirs) });
      else if (Math.abs(minute(ours)! - minute(theirs)!) <= tol) c.agree++;
      else note({ station: station ?? x.location, field, verdict: 'disagree', a: hhmm(ours), b: hhmm(theirs) });
    }
    const [xc, yc] = [x.canceledArr || x.canceledDep, y.canceledArr || y.canceledDep];
    if (xc || yc) {
      if (xc === yc) c.agree++;
      else note({ station: station ?? x.location, field: 'canceled', verdict: 'disagree', a: yesNo(xc), b: yesNo(yc) });
    }
  }
  const [ac, bc] = [a.canceled > 0, b.canceled > 0];
  if (ac === bc) c.agree++;
  else note({ station: null, field: 'canceled', verdict: 'disagree', a: yesNo(ac), b: yesNo(bc) });
  return c;
}

/** Runs of one source on one day from the projection, with their calls. */
export function storedRuns(db: Db, country: string, source: string, date: string): SourceRun[] {
  const runs = db.$client
    .prepare(`select run_id, train_number, canceled, json_extract(info, '$.matchedBy') matched_by from observed_runs where country = ? and source = ? and service_date = ?`)
    .all(country, source, date) as { run_id: string; train_number: string | null; canceled: number; matched_by: string | null }[];
  const calls = db.$client
    .prepare(
      `select c.run_id, c.station_id, c.location, c.sched_arr, c.sched_dep, c.actual_arr, c.actual_dep, c.canceled_arr, c.canceled_dep
       from observed_calls c join observed_runs r on r.country = c.country and r.service_date = c.service_date and r.run_id = c.run_id
       where c.country = ? and r.source = ? and c.service_date = ? order by c.run_id, c.seq`,
    )
    .all(country, source, date) as { run_id: string; station_id: string | null; location: string; sched_arr: number | null; sched_dep: number | null; actual_arr: number | null; actual_dep: number | null; canceled_arr: number; canceled_dep: number }[];
  const byRun = new Map<string, SourceCall[]>();
  for (const c of calls)
    (byRun.get(c.run_id) ?? byRun.set(c.run_id, []).get(c.run_id)!).push({
      stationId: c.station_id,
      location: c.location,
      schedArr: c.sched_arr,
      schedDep: c.sched_dep,
      actualArr: c.actual_arr,
      actualDep: c.actual_dep,
      canceledArr: Boolean(c.canceled_arr),
      canceledDep: Boolean(c.canceled_dep),
    });
  return runs.map((r) => ({ source, runId: r.run_id, trainNumber: r.train_number, canceled: r.canceled, ...(r.matched_by ? { matchedBy: r.matched_by } : {}), calls: byRun.get(r.run_id) ?? [] }));
}

const asSource = (r: ObservedRun): SourceRun => ({
  source: r.source,
  runId: r.runId,
  trainNumber: r.trainNumber,
  canceled: r.canceled,
  calls: r.calls.map((c) => ({ stationId: c.stationId, location: c.location, schedArr: c.schedArr, schedDep: c.schedDep, actualArr: c.actualArr, actualDep: c.actualDep, canceledArr: c.canceledArr, canceledDep: c.canceledDep })),
});

/** The BigQuery archive's own version of a Norwegian day, from its raw file (no stations: calls align by minute). Null without the file. */
export function bigQueryDay(date: string, root?: string): SourceRun[] | null {
  const file = rawFiles(bq.SOURCE, date, 'siri-et', root).at(-1);
  if (!file) return null;
  return bq.project(date, readRaw<Record<string, string | null>>(file), new Map(), new Map()).map(asSource);
}

/** Walk `a`'s runs, find each in `b` by `key`, compare, and sum up. Pure. */
export function comparePair(pair: string, date: string, a: SourceRun[], b: SourceRun[], key: (r: SourceRun) => string | null, opts: { stations?: Set<string> } = {}): { summary: PairSummary; differences: Difference[] } {
  const byKey = new Map<string, SourceRun>();
  for (const r of b) {
    const k = key(r);
    if (k && !byKey.has(k)) byKey.set(k, r);
  }
  const summary: PairSummary = { pair, date, runs: { both: 0, onlyA: 0, onlyB: 0 }, agree: 0, disagree: 0, missing: 0 };
  const differences: Difference[] = [];
  const seen = new Set<SourceRun>();
  for (const x of a) {
    const k = key(x);
    const y = k ? byKey.get(k) : undefined;
    if (!y) {
      if (k) summary.runs.onlyA++;
      continue;
    }
    seen.add(y);
    summary.runs.both++;
    const c = compareRuns(date, x, y, opts);
    summary.agree += c.agree;
    summary.disagree += c.disagree;
    summary.missing += c.missing;
    differences.push(...c.differences);
  }
  summary.runs.onlyB = [...byKey.values()].filter((r) => !seen.has(r)).length;
  return { summary, differences };
}

/** Replace the day's rows for a pair in `diagnostics`: the summary and up to MAX_DIFFERENCES differences. */
export function writeResults(db: Db, summary: PairSummary, differences: Difference[]) {
  const sqlite = db.$client;
  const insert = sqlite.prepare(
    `insert into diagnostics (day, build, kind, signature, count) values (?, ?, ?, ?, ?)
     on conflict (day, build, kind, signature) do update set count = count + excluded.count`,
  );
  sqlite.transaction(() => {
    sqlite.prepare(`delete from diagnostics where day = ? and build = ? and kind = ?`).run(summary.date, summary.pair, KIND);
    const { pair: _p, date: _d, ...rest } = summary;
    insert.run(summary.date, summary.pair, KIND, `summary ${JSON.stringify(rest)}`, 1);
    for (const d of differences.slice(0, MAX_DIFFERENCES)) {
      const { date: _dd, ...body } = d;
      insert.run(summary.date, summary.pair, KIND, JSON.stringify(body), 1);
    }
  })();
}

/**
 * The day the nightly job checks: two days back. The archives for a day arrive the next morning (Denmark 05:00,
 * BigQuery 07:30 Oslo) and Sweden's night fetch runs at 04:10, all after this job's 03:30, so yesterday is not in yet.
 */
export const dayToCheck = (now = Date.now()) => addDays(todayIn('Europe/Stockholm', now), -2);

/** Run every pair for one day and write the results. Returns the summaries (also printed by `npm run import -- cross-source`). */
export async function runCrossSource(db: Db, opts: { date?: string; now?: number; log?: (m: string) => void; observedRoot?: string } = {}): Promise<PairSummary[]> {
  const date = opts.date ?? dayToCheck(opts.now);
  const log = opts.log ?? (() => {});
  const out: PairSummary[] = [];
  const byNumber = (r: SourceRun) => r.trainNumber;

  // Öresund: the Danish runs named from Sweden's feed, against Trafikverket's run of the same number and day.
  // Only the Swedish runs the Danish record names from Sweden's feed are walked: `onlyB` is then the cross-border runs
  // Trafikverket lacks.
  const dk = storedRuns(db, 'DK', DK_SOURCE, date).filter((r) => r.trainNumber !== null && r.matchedBy === 'se-stop-times');
  const dkNumbers = new Set(dk.map((r) => r.trainNumber));
  const se = storedRuns(db, 'SE', TRV_SOURCE, date);
  const oresund = comparePair(PAIRS.oresund, date, se.filter((r) => dkNumbers.has(r.trainNumber)), dk, byNumber, { stations: ORESUND_STATIONS });
  if (!dk.length) oresund.summary.note = "no Danish runs named from Sweden's feed for the day";
  else if (!se.length) oresund.summary.note = 'no Swedish runs for the day';
  writeResults(db, oresund.summary, oresund.differences);
  out.push(oresund.summary);

  // Norway: our live Entur runs against the archive's version from the raw day file.
  const live = storedRuns(db, 'NO', ENTUR_SOURCE, date);
  const archive = bigQueryDay(date, opts.observedRoot);
  const norway = comparePair(PAIRS.norway, date, live, archive ?? [], (r) => r.runId);
  if (!archive) norway.summary.note = 'no BigQuery archive file for the day';
  else if (!live.length) norway.summary.note = 'no same-day Entur runs for the day';
  writeResults(db, norway.summary, norway.differences);
  out.push(norway.summary);

  for (const s of out) log(`cross-source ${s.date} ${s.pair}: ${s.runs.both} runs in both, agree ${s.agree}, disagree ${s.disagree}, missing ${s.missing}${s.note ? ` (${s.note})` : ''}`);
  return out;
}
