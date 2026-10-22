// The accuracy audit (docs/RELIABILITY_PLAN.md §1): after a trip has run, compare what Clack showed against the
// final record, and check that record against Trafikverket asked a second, independent way. Nothing here changes a
// trip; it only measures. Results go in leg_audits and a readable report in data/audit/.
import fs from 'node:fs';
import path from 'node:path';
import { and, asc, desc, eq, gt, isNull, lt, or } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legAudits, legStops, legs, liveQuality, shownValues, stations } from '../db/schema.js';
import { actualTime, trvQuery } from '../trafikverket/client.js';
import { TRV_HISTORY_MS } from '../legs/actuals.js';
import { REPO_ROOT } from '../env.js';

/** How far ahead of the event a shown time is judged: what you saw an hour, half an hour, 15 and 5 minutes before. */
export const HORIZONS_MIN = [60, 30, 15, 5] as const;

export interface PredictionStats {
  n: number;
  /** Shown time within 1 and within 3 minutes of what happened. */
  within1: number;
  within3: number;
  /** Mean absolute error, minutes. */
  meanAbsMin: number | null;
  /** Shown too early (train later than shown) vs too late, beyond a minute. */
  early: number;
  late: number;
}

export interface LegAudit {
  legId: string;
  train: string | null;
  route: string;
  date: string | null;
  /** Our stored actual times against Trafikverket asked by train number: the same rows, matched independently. */
  record: { checked: number; agree: number; disagree: number; missing: number; examples: string[] };
  /** What the trip showed before each departure and arrival against the actual time. */
  predictions: Record<string, PredictionStats>;
  platforms: { stops: number; changedAfterShown: number; wrong10MinBefore: number };
  position: { ticks: number; gpsShare: number | null; failedTicks: number; rejectedFixes: number } | null;
  /** Ridden stops by who reports them (trafikverket, entur, none). */
  sources: Record<string, number>;
  tracked: boolean;
}

const minute = 60_000;

function emptyStats(): PredictionStats {
  return { n: 0, within1: 0, within3: 0, meanAbsMin: null, early: 0, late: 0 };
}

function addError(s: PredictionStats, errMin: number) {
  const abs = Math.abs(errMin);
  s.meanAbsMin = ((s.meanAbsMin ?? 0) * s.n + abs) / (s.n + 1);
  s.n++;
  if (abs <= 1) s.within1++;
  if (abs <= 3) s.within3++;
  if (errMin < -1) s.early++;
  if (errMin > 1) s.late++;
}

/** The value shown at a moment: the last change at or before it. Pure. */
export function shownAt<T extends { shownAt: number; value: string | null }>(history: T[], at: number): string | null | undefined {
  let v: string | null | undefined;
  for (const h of history) {
    if (h.shownAt > at) break;
    v = h.value;
  }
  return v;
}

interface Row {
  AdvertisedTrainIdent: string;
  LocationSignature: string;
  ActivityType: 'Ankomst' | 'Avgang';
  AdvertisedTimeAtLocation: string;
  TimeAtLocation?: string;
}

/** Trafikverket's rows for these train numbers in a window, asked by number rather than by stop and minute. */
async function fetchByTrain(numbers: string[], from: number, to: number, fetchImpl?: typeof fetch): Promise<Row[]> {
  if (!numbers.length) return [];
  const r = await trvQuery<{ TrainAnnouncement?: Row[] }>(
    `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9"><FILTER><IN name="AdvertisedTrainIdent" value="${numbers.join(',')}"/>` +
      `<GT name="AdvertisedTimeAtLocation" value="${new Date(from).toISOString()}"/><LT name="AdvertisedTimeAtLocation" value="${new Date(to).toISOString()}"/></FILTER>` +
      ['AdvertisedTrainIdent', 'LocationSignature', 'ActivityType', 'AdvertisedTimeAtLocation', 'TimeAtLocation'].map((f) => `<INCLUDE>${f}</INCLUDE>`).join('') +
      `</QUERY>`,
    fetchImpl,
  );
  return r.TrainAnnouncement ?? [];
}

export async function auditLeg(db: Db, legId: string, opts: { fetchImpl?: typeof fetch } = {}): Promise<LegAudit | null> {
  const leg = db.select().from(legs).where(eq(legs.id, legId)).get();
  if (!leg) return null;
  const stops = db
    .select({
      seq: legStops.seq,
      role: legStops.role,
      name: stations.name,
      sig: stations.trvSignature,
      country: stations.country,
      schedArr: legStops.schedArr,
      schedDep: legStops.schedDep,
      actualArr: legStops.actualArr,
      actualDep: legStops.actualDep,
      platform: legStops.platform,
      reportSource: legStops.reportSource,
    })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, legId))
    .orderBy(asc(legStops.seq))
    .all()
    .filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
  const t = (d: Date | null) => d?.getTime() ?? null;

  // 1. The record, checked independently.
  const record: LegAudit['record'] = { checked: 0, agree: 0, disagree: 0, missing: 0, examples: [] };
  const swedish = stops.filter((s) => s.sig && !s.sig.includes('.') && s.country === 'SE');
  const first = t(stops[0]?.schedDep ?? null) ?? t(leg.schedDep);
  const last = t(stops.at(-1)?.schedArr ?? null) ?? t(leg.schedArr);
  if (swedish.length && first !== null && last !== null && leg.trvTrainNumbers.length) {
    const rows = await fetchByTrain(leg.trvTrainNumbers, first - 2 * 3600_000, last + 2 * 3600_000, opts.fetchImpl);
    for (const s of swedish)
      for (const [activity, sched, stored] of [
        ['Avgang', t(s.schedDep), t(s.actualDep)],
        ['Ankomst', t(s.schedArr), t(s.actualArr)],
      ] as const) {
        if (sched === null || (activity === 'Avgang' && s.role === 'alight') || (activity === 'Ankomst' && s.role === 'board')) continue;
        const row = rows.find(
          (r) => r.LocationSignature.toLowerCase() === s.sig!.toLowerCase() && r.ActivityType === activity && Math.floor(Date.parse(r.AdvertisedTimeAtLocation) / minute) === Math.floor(sched / minute),
        );
        const theirs = row ? actualTime(row.TimeAtLocation, row.AdvertisedTimeAtLocation) : null;
        if (theirs === null && stored === null) continue;
        record.checked++;
        if (theirs === null || stored === null) {
          record.missing++;
          if (record.examples.length < 5) record.examples.push(`${s.name} ${activity}: ours ${stored === null ? 'none' : new Date(stored).toISOString()}, Trafikverket ${theirs === null ? 'none' : new Date(theirs).toISOString()}`);
        } else if (Math.abs(theirs - stored) < minute) record.agree++;
        else {
          record.disagree++;
          if (record.examples.length < 5) record.examples.push(`${s.name} ${activity}: ours ${new Date(stored).toISOString()}, Trafikverket ${new Date(theirs).toISOString()}`);
        }
      }
  }

  // 2. What the trip showed, against what happened.
  const shown = db.select().from(shownValues).where(eq(shownValues.legId, legId)).orderBy(asc(shownValues.shownAt)).all();
  const history = (seq: number, field: string) => shown.filter((r) => r.seq === seq && r.field === field).map((r) => ({ shownAt: r.shownAt.getTime(), value: r.value }));
  const predictions: Record<string, PredictionStats> = Object.fromEntries(HORIZONS_MIN.map((h) => [`${h}min`, emptyStats()]));
  const platforms = { stops: 0, changedAfterShown: 0, wrong10MinBefore: 0 };
  for (const s of stops) {
    for (const [field, actual] of [
      ['dep', s.role === 'alight' ? null : t(s.actualDep)],
      ['arr', s.role === 'board' ? null : t(s.actualArr)],
    ] as const) {
      if (actual === null) continue;
      const h = history(s.seq, field);
      for (const mins of HORIZONS_MIN) {
        const v = shownAt(h, actual - mins * minute);
        if (v === undefined || v === null) continue;
        addError(predictions[`${mins}min`]!, (actual - Number(v)) / minute);
      }
    }
    const ph = history(s.seq, 'platform');
    if (s.platform && ph.length) {
      platforms.stops++;
      const values = [...new Set(ph.map((p) => p.value).filter(Boolean))];
      if (values.length > 1) platforms.changedAfterShown++;
      const when = (t(s.actualDep) ?? t(s.schedDep) ?? t(s.actualArr) ?? t(s.schedArr) ?? 0) - 10 * minute;
      const then = shownAt(ph, when);
      if (then && then !== s.platform) platforms.wrong10MinBefore++;
    }
  }

  // 3. How the position was shown.
  const q = db.select().from(liveQuality).where(eq(liveQuality.legId, legId)).get();
  const position = q
    ? { ticks: q.ticks, gpsShare: q.gpsTicks + q.estimatedTicks ? q.gpsTicks / (q.gpsTicks + q.estimatedTicks) : null, failedTicks: q.failedTicks, rejectedFixes: q.rejectedFixes }
    : null;

  const sources: Record<string, number> = {};
  for (const s of stops) sources[s.reportSource ?? 'none'] = (sources[s.reportSource ?? 'none'] ?? 0) + 1;

  return {
    legId,
    train: leg.trainNumber,
    route: `${stops[0]?.name ?? '?'} → ${stops.at(-1)?.name ?? '?'}`,
    date: leg.serviceDate,
    record,
    predictions,
    platforms,
    position,
    sources,
    tracked: shown.length > 0,
  };
}

/** Legs ready for the audit: arrived at least an hour ago, recently enough that Trafikverket still has the day. */
export function auditableLegs(db: Db, now: number, limit = 50): string[] {
  return db
    .select({ id: legs.id })
    .from(legs)
    .leftJoin(legAudits, eq(legAudits.legId, legs.id))
    .where(and(isNull(legAudits.legId), lt(legs.schedArr, new Date(now - 3600_000)), gt(legs.schedArr, new Date(now - TRV_HISTORY_MS + 6 * 3600_000)), or(eq(legs.status, 'snapshotted'), eq(legs.status, 'completed'))))
    .orderBy(desc(legs.schedArr))
    .limit(limit)
    .all()
    .map((r) => r.id);
}

/** Totals over many legs' audits. Pure. */
export function summarize(audits: LegAudit[]) {
  const record = { checked: 0, agree: 0, disagree: 0, missing: 0 };
  const predictions: Record<string, PredictionStats> = Object.fromEntries(HORIZONS_MIN.map((h) => [`${h}min`, emptyStats()]));
  const platforms = { stops: 0, changedAfterShown: 0, wrong10MinBefore: 0 };
  const position = { ticks: 0, gpsTicks: 0, enRouteTicks: 0, failedTicks: 0, rejectedFixes: 0 };
  for (const a of audits) {
    for (const k of Object.keys(record) as (keyof typeof record)[]) record[k] += a.record[k];
    for (const [h, s] of Object.entries(a.predictions)) {
      const t = predictions[h]!;
      if (!s.n) continue;
      t.meanAbsMin = ((t.meanAbsMin ?? 0) * t.n + (s.meanAbsMin ?? 0) * s.n) / (t.n + s.n);
      t.n += s.n;
      t.within1 += s.within1;
      t.within3 += s.within3;
      t.early += s.early;
      t.late += s.late;
    }
    for (const k of Object.keys(platforms) as (keyof typeof platforms)[]) platforms[k] += a.platforms[k];
    if (a.position) {
      position.ticks += a.position.ticks;
      position.failedTicks += a.position.failedTicks;
      position.rejectedFixes += a.position.rejectedFixes;
    }
  }
  return { legs: audits.length, tracked: audits.filter((a) => a.tracked).length, record, predictions, platforms, position };
}

const pct = (a: number, b: number) => (b ? `${Math.round((100 * a) / b)}%` : '–');

/** A readable report of the last week's audits. Pure. */
export function reportMarkdown(audits: LegAudit[], now: number): string {
  const s = summarize(audits);
  const lines = [
    `# Accuracy audit`,
    '',
    `Generated ${new Date(now).toISOString()} from ${s.legs} trips that ran in the last days (${s.tracked} followed live).`,
    '',
    '## Our record against Trafikverket',
    '',
    `Each stored actual time, checked against Trafikverket asked by train number (independently of how the trip matched its rows).`,
    '',
    `| Checked | Agree | Disagree | Missing on one side |`,
    `|---|---|---|---|`,
    `| ${s.record.checked} | ${s.record.agree} (${pct(s.record.agree, s.record.checked)}) | ${s.record.disagree} | ${s.record.missing} |`,
    '',
    '## What the trip showed before each departure and arrival',
    '',
    `| Before the event | Times | Within 1 min | Within 3 min | Mean error | Train later than shown | Earlier |`,
    `|---|---|---|---|---|---|---|`,
    ...Object.entries(s.predictions).map(
      ([h, p]) => `| ${h.replace('min', ' min')} | ${p.n} | ${pct(p.within1, p.n)} | ${pct(p.within3, p.n)} | ${p.meanAbsMin === null ? '–' : `${p.meanAbsMin.toFixed(1)} min`} | ${p.late} | ${p.early} |`,
    ),
    '',
    '## Tracks',
    '',
    `${s.platforms.stops} stops with a track shown; it changed after we first showed it at ${s.platforms.changedAfterShown}, and was wrong 10 minutes before the train at ${s.platforms.wrong10MinBefore}.`,
    '',
    '## Position',
    '',
    `${s.position.ticks} live updates; Trafikverket/Entur didn't answer on ${s.position.failedTicks} (${pct(s.position.failedTicks, s.position.ticks)}); ${s.position.rejectedFixes} GPS fixes dropped as impossible jumps.`,
    '',
    '## Trips',
    '',
    `| Train | Route | Date | Record | 15 min before: within 1 min | GPS share |`,
    `|---|---|---|---|---|---|`,
    ...audits.map((a) => {
      const p = a.predictions['15min']!;
      return `| ${a.train ?? '–'} | ${a.route} | ${a.date ?? '–'} | ${a.record.agree}/${a.record.checked}${a.record.disagree || a.record.missing ? ' ⚠' : ''} | ${p.n ? `${p.within1}/${p.n}` : '–'} | ${a.position?.gpsShare == null ? '–' : pct(a.position.gpsShare, 1)} |`;
    }),
  ];
  const problems = audits.flatMap((a) => a.record.examples.map((e) => `- ${a.train ?? ''} ${a.date ?? ''}: ${e}`));
  if (problems.length) lines.push('', '## Record differences to look at', '', ...problems);
  return lines.join('\n') + '\n';
}

export const AUDIT_DIR = path.join(REPO_ROOT, 'data', 'audit');

/** Audit what's ready, then rewrite the report from the last 7 days of audits. */
export async function runAudit(db: Db, opts: { log?: (m: string) => void; now?: number; fetchImpl?: typeof fetch; dir?: string } = {}) {
  const now = opts.now ?? Date.now();
  let done = 0;
  for (const id of auditableLegs(db, now)) {
    try {
      const a = await auditLeg(db, id, opts);
      if (!a) continue;
      db.insert(legAudits).values({ legId: id, auditedAt: new Date(now), result: a as unknown as Record<string, unknown> }).onConflictDoNothing().run();
      done++;
    } catch (e) {
      opts.log?.(`audit of leg ${id} failed: ${(e as Error).message}`);
    }
  }
  const recent = db
    .select()
    .from(legAudits)
    .where(gt(legAudits.auditedAt, new Date(now - 7 * 86400_000)))
    .all()
    .map((r) => r.result as unknown as LegAudit);
  const dir = opts.dir ?? AUDIT_DIR;
  if (recent.length) {
    fs.mkdirSync(dir, { recursive: true });
    const md = reportMarkdown(recent, now);
    fs.writeFileSync(path.join(dir, 'latest.md'), md);
    fs.writeFileSync(path.join(dir, `${new Date(now).toISOString().slice(0, 10)}.md`), md);
  }
  if (done) opts.log?.(`accuracy audit: ${done} trip(s) audited`);
  return { audited: done, summary: summarize(recent) };
}
