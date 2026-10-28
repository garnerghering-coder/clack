// Norway's observed record, collected on the day (NORWAY_DATA_FINDINGS.md). Entur's Journey Planner has a train's
// actual times while it runs and for a while after (checked 2026-10-26 at 21:00: trains finished an hour earlier
// still had them to the second; that morning's had none), so each train is fetched about 15 minutes after its last
// scheduled arrival, and again once it is really in if it was running late. Entur's public BigQuery table
// (observed/bigquery.ts) is the safety net the next morning. Disruption messages (SIRI-SX) are polled and every new
// or changed one kept; Entur keeps no history of them.
import { createHash } from 'node:crypto';
import type { Db } from '../db/client.js';
import { jpQuery } from '../entur/client.js';
import { config } from '../env.js';
import { trainNumberFromTripId } from '../import/gtfs-no.js';
import { addDays, serviceTimeToUtc, todayIn } from '../lib/time.js';
import { writeRaw } from './archive.js';
import { cancelLevel, recordFetch, saveRuns, type ObservedCall, type ObservedCause, type ObservedRun } from './store.js';

const TZ = 'Europe/Oslo';
export const SOURCE = 'entur';
/** Fetch this long after the last scheduled (or expected) arrival. */
export const AFTER_ARRIVAL_MS = 15 * 60_000;
/** How long after arrival Journey Planner was seen to still have a train's actual times (at least ~1 h; not longer). */
const KEPT_MS = 2 * 3600_000;
/** A train still not in this long after its scheduled arrival is fetched as it is. */
const GIVE_UP_MS = 4 * 3600_000;

const QUERY = `query($id: String!, $date: Date!) { serviceJourney(id: $id) {
  id publicCode privateCode transportMode transportSubmode
  operator { id name } line { id publicCode name transportSubmode } journeyPattern { id }
  estimatedCalls(date: $date) {
    stopPositionInPattern aimedArrivalTime aimedDepartureTime expectedArrivalTime expectedDepartureTime
    actualArrivalTime actualDepartureTime cancellation realtime realtimeState predictionInaccurate
    forBoarding forAlighting requestStop occupancyStatus
    destinationDisplay { frontText via }
    quay { id publicCode name stopPlace { id name } }
    situations { id situationNumber reportType severity summary { value language } description { value language }
      advice { value language } validityPeriod { startTime endTime } }
  } } }`;

export interface JpJourney {
  id: string;
  privateCode?: string | null;
  publicCode?: string | null;
  transportMode?: string;
  transportSubmode?: string;
  operator?: { id: string; name?: string } | null;
  line?: { id: string; publicCode?: string | null; name?: string; transportSubmode?: string } | null;
  journeyPattern?: { id: string } | null;
  estimatedCalls: JpCall[];
}

export interface JpCall extends Record<string, unknown> {
  stopPositionInPattern: number;
  aimedArrivalTime: string | null;
  aimedDepartureTime: string | null;
  expectedArrivalTime: string | null;
  expectedDepartureTime: string | null;
  actualArrivalTime: string | null;
  actualDepartureTime: string | null;
  cancellation: boolean;
  realtime: boolean;
  realtimeState?: string;
  quay: { id: string; publicCode: string | null; name?: string; stopPlace: { id: string; name?: string } | null } | null;
  situations?: { situationNumber?: string; summary?: { value: string; language?: string }[] }[];
}

/** A Norwegian run's id: the operator's codespace and the train number (stable across sources, unlike journey ids). */
export function runIdOf(journeyId: string, number: string | null): string {
  return `${journeyId.split(':')[0]}:${number ?? journeyId}`;
}

const CALL_FIELDS = new Set(['aimedArrivalTime', 'aimedDepartureTime', 'expectedArrivalTime', 'expectedDepartureTime', 'actualArrivalTime', 'actualDepartureTime', 'cancellation']);
const ms = (s: string | null | undefined) => (s ? Date.parse(s) : null);

/**
 * One journey's calls as a run. An "actual" time later than the fetch isn't one (Flytoget sends them for stops ahead,
 * seen 2026-10-22): it's kept as the estimate. Situations become causes (Entur gives text, no codes).
 */
export function project(date: string, j: JpJourney, stationByNsr: Map<string, string>, fetchedAt: number): ObservedRun | null {
  const calls = j.estimatedCalls;
  if (!calls.length) return null;
  const number = j.privateCode ?? trainNumberFromTripId(j.id);
  const real = (t: number | null) => (t !== null && t <= fetchedAt ? t : null);
  const out: ObservedCall[] = calls.map((c, i) => {
    const [aa, ad] = [ms(c.actualArrivalTime), ms(c.actualDepartureTime)];
    const causes: ObservedCause[] = (c.situations ?? []).map((s) => ({
      src: 'entur',
      ...(s.situationNumber ? { code: s.situationNumber } : {}),
      ...(s.summary?.[0]?.value ? { text: (s.summary.find((x) => x.language === 'en') ?? s.summary[0]).value } : {}),
    }));
    const extra: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(c)) if (!CALL_FIELDS.has(k) && v !== null && !(Array.isArray(v) && !v.length)) extra[k] = v;
    const first = i === 0;
    const last = i === calls.length - 1;
    return {
      seq: i + 1,
      location: c.quay?.id ?? c.quay?.stopPlace?.id ?? '',
      stationId: (c.quay?.stopPlace?.id && stationByNsr.get(c.quay.stopPlace.id)) ?? null,
      schedArr: first ? null : ms(c.aimedArrivalTime),
      schedDep: last ? null : ms(c.aimedDepartureTime),
      estArr: first ? null : real(aa) === null ? (ms(c.expectedArrivalTime) ?? aa) : null,
      estDep: last ? null : real(ad) === null ? (ms(c.expectedDepartureTime) ?? ad) : null,
      actualArr: first ? null : real(aa),
      actualDep: last ? null : real(ad),
      platform: c.quay?.publicCode || null,
      canceledArr: !first && c.cancellation,
      canceledDep: !last && c.cancellation,
      causes,
      extra,
    };
  });
  const { estimatedCalls: _c, ...journey } = j;
  return {
    country: 'NO',
    serviceDate: date,
    runId: runIdOf(j.id, number),
    trainNumber: number,
    source: SOURCE,
    operator: j.id.split(':')[0] ?? null,
    product: j.line?.publicCode ?? null,
    canceled: cancelLevel(out, calls.every((c) => c.cancellation)),
    info: journey,
    passages: [],
    calls: out,
    final: false,
  };
}

/** Today's (and yesterday's late-running) Norwegian rail journeys from the timetable, with their last scheduled arrival. */
export function journeysDue(db: Db, date: string): { id: string; lastArr: number }[] {
  const rows = db.$client
    .prepare(
      `select t.trip_id id, max(coalesce(s.arr_sec, s.dep_sec)) last_sec from timetable_trips t
       join timetable_trip_dates d on d.trip_key = t.key join timetable_stop_times s on s.trip_key = t.key
       where t.source = 'gtfs_no' and d.service_date = ? group by t.trip_id`,
    )
    .all(date) as { id: string; last_sec: number }[];
  return rows.map((r) => ({ id: r.id, lastArr: serviceTimeToUtc(date, r.last_sec, TZ) }));
}

export function stationsByNsr(db: Db): Map<string, string> {
  const rows = db.$client.prepare(`select id, nsr_id from stations where nsr_id is not null`).all() as { id: string; nsr_id: string }[];
  return new Map(rows.map((r) => [r.nsr_id, r.id]));
}

/** Journeys fetched (or given up) per service date, so each is fetched when due and once more only if it ran late. */
const state = new Map<string, Map<string, { dueAt: number; tries: number; done: boolean }>>();

/**
 * One tick (every few minutes): fetch every journey that's due, archive the answers together, project them.
 * Returns how many journeys were fetched.
 */
export async function tick(db: Db, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void; max?: number } = {}): Promise<number> {
  const now = opts.now ?? Date.now();
  const today = todayIn(TZ, now);
  const stationByNsr = stationsByNsr(db);
  let fetched = 0;
  for (const date of [addDays(today, -1), today]) {
    let jobs = state.get(date);
    if (!jobs) {
      jobs = new Map();
      // Journeys already in the record (a restart) aren't fetched again.
      const have = new Set((db.$client.prepare(`select run_id from observed_runs where country = 'NO' and service_date = ? and source = ?`).all(date, SOURCE) as { run_id: string }[]).map((r) => r.run_id));
      // Nor are ones that finished too long ago for Journey Planner to still have them (after a restart).
      for (const j of journeysDue(db, date))
        if (!have.has(runIdOf(j.id, trainNumberFromTripId(j.id))) && j.lastArr + KEPT_MS > now) jobs.set(j.id, { dueAt: j.lastArr + AFTER_ARRIVAL_MS, tries: 0, done: false });
      state.set(date, jobs);
    }
    const raw: unknown[] = [];
    const runs: ObservedRun[] = [];
    for (const [id, job] of jobs) {
      if (job.done || job.dueAt > now) continue;
      if (opts.max !== undefined && fetched >= opts.max) break;
      let j: JpJourney | null = null;
      try {
        j = (await jpQuery<{ serviceJourney: JpJourney | null }>(QUERY, { id, date }, opts.fetchImpl)).serviceJourney;
      } catch (e) {
        opts.log?.(`observed NO ${id} ${date}: ${(e as Error).message}`);
        job.dueAt = now + 5 * 60_000;
        if (++job.tries >= 5) job.done = true;
        continue;
      }
      fetched++;
      raw.push({ id, date, fetchedAt: now, serviceJourney: j });
      const lastCall = j?.estimatedCalls.at(-1);
      const lastExpected = ms(lastCall?.expectedArrivalTime) ?? 0;
      const stillRunning = Boolean(lastCall?.realtime) && !lastCall?.actualArrivalTime && lastExpected + AFTER_ARRIVAL_MS > now && now - (job.dueAt - AFTER_ARRIVAL_MS) < GIVE_UP_MS;
      // Late and not in yet: keep this answer, and come back after its expected arrival.
      if (stillRunning) job.dueAt = lastExpected + AFTER_ARRIVAL_MS;
      else job.done = true;
      const run = j ? project(date, j, stationByNsr, now) : null;
      if (run) runs.push(run);
    }
    if (raw.length) {
      const file = await writeRaw(SOURCE, date, 'calls', raw, { now });
      saveRuns(db, runs, now);
      const total = (db.$client.prepare(`select count(*) n from observed_runs where country = 'NO' and service_date = ? and source = ?`).get(date, SOURCE) as { n: number }).n;
      recordFetch(db, { source: SOURCE, kind: 'calls', date, records: raw.length, runs: total, file }, now);
    }
  }
  for (const d of state.keys()) if (d < addDays(today, -1)) state.delete(d);
  if (fetched) opts.log?.(`observed NO: fetched ${fetched} journeys`);
  return fetched;
}

/** For tests. */
export const resetNorwayState = () => state.clear();

// ---------- Disruption messages (SIRI-SX) ----------

const SX_URL = 'https://api.entur.io/realtime/v1/rest/sx';
const seenSituations = new Set<string>();

/**
 * Poll every current situation (~480, 0.7 MB, all modes) and keep those new or changed since the last poll, as Entur
 * sent them. Changed means a different JSON body, so each version of a situation is kept once.
 */
export async function pollSituations(db: Db, opts: { now?: number; fetchImpl?: typeof fetch; log?: (m: string) => void } = {}): Promise<number> {
  const now = opts.now ?? Date.now();
  const res = await (opts.fetchImpl ?? fetch)(SX_URL, { headers: { 'ET-Client-Name': config.enturClientName, Accept: 'application/json' }, signal: AbortSignal.timeout(60_000) });
  if (!res.ok) throw new Error(`Entur SX ${res.status}`);
  const body = (await res.json()) as { Siri?: { ServiceDelivery?: { SituationExchangeDelivery?: { Situations?: { PtSituationElement?: unknown[] } }[] } } };
  const all = body.Siri?.ServiceDelivery?.SituationExchangeDelivery?.[0]?.Situations?.PtSituationElement ?? [];
  const fresh = all.filter((s) => {
    const h = createHash('sha1').update(JSON.stringify(s)).digest('hex');
    if (seenSituations.has(h)) return false;
    seenSituations.add(h);
    return true;
  });
  if (seenSituations.size > 50_000) seenSituations.clear();
  if (!fresh.length) return 0;
  const date = todayIn(TZ, now);
  const file = await writeRaw(SOURCE, date, 'situations', fresh, { now });
  const prev = (db.$client.prepare(`select records from observed_fetches where source = ? and kind = 'situations' and date = ?`).get(SOURCE, date) as { records: number } | undefined)?.records ?? 0;
  recordFetch(db, { source: SOURCE, kind: 'situations', date, records: prev + fresh.length, file }, now);
  return fresh.length;
}
