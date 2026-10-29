// Journey risk (owner, 2026-10-22): warnings before trouble, from what can be observed, by fixed rules. No AI, and
// never a prediction dressed up: three kinds of evidence, each said for what it is.
// - Now, along your route: how trains have left the stations you'll pass in the last hour (Trafikverket's actual times).
// - Now, at your station: the same for departures from where you get on.
// - Ahead of you: the trains that left your station the same way in the last hour, and how late they are now (a
//   queue on the line reaches yours too). The count of trains and their delays, nothing guessed about yours.
// - Past pattern for your train: how it left your station on earlier days, from what this computer has seen (boards
//   and these checks record it; Trafikverket keeps only about a day back). Silent until there's enough of it.
// Weak, stale or irrelevant evidence gives no warning (a trip more than 6 hours off gets no "right now" warning).
import { and, eq, gte, lt, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { delayObservations, legs, legStops, stations } from '../db/schema.js';
import { trvQuery } from '../trafikverket/client.js';
import { addDays, todayIn } from '../lib/time.js';
import { punctuality } from '../stats/punctuality.js';

export interface Departure {
  trainNumber: string;
  signature: string;
  advertised: number;
  actual: number | null;
  canceled: boolean;
}

export type RiskWarning =
  | { kind: 'route_now'; trains: number; late: number; canceled: number; medianMin: number; windowMin: number }
  | { kind: 'station_now'; station: string; trains: number; late: number; medianMin: number; windowMin: number }
  | { kind: 'ahead'; station: string; toward: string; trains: number; late: number; delays: number[]; windowMin: number }
  | { kind: 'train_pattern'; station: string; days: number; lateDays: number; medianMin: number };

export const LATE_MIN = 10;
const WINDOW_MIN = 60;
const NOW_HORIZON_MS = 6 * 3600_000;
const PATTERN_DAYS = 14;

const median = (xs: number[]) => {
  if (!xs.length) return 0;
  const s = [...xs].sort((a, b) => a - b);
  return s.length % 2 ? s[(s.length - 1) / 2]! : Math.round((s[s.length / 2 - 1]! + s[s.length / 2]!) / 2);
};
const delayOf = (d: Departure) => (d.actual === null ? null : Math.max(0, Math.round((d.actual - d.advertised) / 60_000)));

/** "Right now" warnings from the last hour's departures. Pure. */
export function nowWarnings(deps: Departure[], boardSig: string | null, boardName: string): RiskWarning[] {
  const out: RiskWarning[] = [];
  const ran = deps.filter((d) => d.actual !== null);
  const canceled = deps.filter((d) => d.canceled).length;
  const delays = ran.map((d) => delayOf(d)!);
  const late = delays.filter((x) => x >= LATE_MIN).length;
  const trains = ran.length + canceled;
  // Enough trains, and a real share of them late or cancelled: not one bad train.
  if (trains >= 8 && (late / trains >= 0.35 || median(delays) >= 7 || canceled / trains >= 0.15))
    out.push({ kind: 'route_now', trains, late, canceled, medianMin: median(delays), windowMin: WINDOW_MIN });
  if (boardSig) {
    const here = ran.filter((d) => d.signature.toLowerCase() === boardSig.toLowerCase()).map((d) => delayOf(d)!);
    const hereLate = here.filter((x) => x >= LATE_MIN).length;
    if (here.length >= 4 && hereLate / here.length >= 0.5 && !out.length)
      out.push({ kind: 'station_now', station: boardName, trains: here.length, late: hereLate, medianMin: median(here), windowMin: WINDOW_MIN });
  }
  return out;
}

/**
 * The trains that left your station before yours, the same way, with their latest delay: a warning when at least two
 * of them, and at least half, are running 10+ min late. Pure.
 */
export function aheadWarning(ahead: { delayMin: number }[], station: string, toward: string): RiskWarning | null {
  const late = ahead.filter((a) => a.delayMin >= LATE_MIN);
  if (late.length < 2 || late.length / ahead.length < 0.5) return null;
  return { kind: 'ahead', station, toward, trains: ahead.length, late: late.length, delays: late.map((a) => a.delayMin).sort((a, b) => a - b), windowMin: WINDOW_MIN };
}

interface TrvCall extends TrvDep {
  EstimatedTimeAtLocation?: string;
  ActivityType?: string;
}

/**
 * Of the trains that left `boardSig` in the last hour, the ones that also call at `nextSig` afterwards (so: your way),
 * each with its latest delay: at `nextSig` if reported or expected there, else as it left your station.
 */
export async function trainsAhead(deps: Departure[], boardSig: string, nextSig: string, now: number, fetchImpl?: typeof fetch): Promise<{ trainNumber: string; delayMin: number }[]> {
  const left = deps.filter((d) => d.signature.toLowerCase() === boardSig.toLowerCase() && d.actual !== null);
  if (!left.length) return [];
  const r = await trvQuery<{ TrainAnnouncement?: TrvCall[] }>(
    `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9"><FILTER><EQ name="Advertised" value="true"/><EQ name="LocationSignature" value="${nextSig}"/>` +
      `<IN name="AdvertisedTrainIdent" value="${[...new Set(left.map((d) => d.trainNumber))].join(',')}"/>` +
      `<GTE name="AdvertisedTimeAtLocation" value="${new Date(now - WINDOW_MIN * 60_000).toISOString()}"/><LTE name="AdvertisedTimeAtLocation" value="${new Date(now + 3 * 3600_000).toISOString()}"/></FILTER>` +
      ['AdvertisedTrainIdent', 'ActivityType', 'AdvertisedTimeAtLocation', 'TimeAtLocation', 'EstimatedTimeAtLocation'].map((f) => `<INCLUDE>${f}</INCLUDE>`).join('') +
      `</QUERY>`,
    fetchImpl,
  );
  const out: { trainNumber: string; delayMin: number }[] = [];
  for (const d of left) {
    const there = (r.TrainAnnouncement ?? []).filter((a) => a.AdvertisedTrainIdent === d.trainNumber && Date.parse(a.AdvertisedTimeAtLocation) > d.advertised);
    if (!there.length) continue;
    const arr = there.find((a) => a.ActivityType === 'Ankomst') ?? there[0]!;
    const latest = arr.TimeAtLocation ?? arr.EstimatedTimeAtLocation;
    const delay = latest ? Math.round((Date.parse(latest) - Date.parse(arr.AdvertisedTimeAtLocation)) / 60_000) : delayOf(d)!;
    out.push({ trainNumber: d.trainNumber, delayMin: Math.max(0, delay) });
  }
  return out;
}

/** The pattern for one train at one station from earlier days' observations. Pure. */
/** The same rule on the observed record's figures: most days late and a median of 5 min or more. Pure. */
export function patternFromHistory(h: { days: number; lateDays: number; medianMin: number }, station: string): RiskWarning | null {
  if (h.days < 4 || h.lateDays / h.days < 0.6 || h.medianMin < 5) return null;
  return { kind: 'train_pattern', station, days: h.days, lateDays: h.lateDays, medianMin: Math.min(h.medianMin, 98) };
}

export function patternWarning(obs: { delayMin: number | null; canceled: boolean }[], station: string): RiskWarning | null {
  const days = obs.length;
  const delays = obs.map((o) => (o.canceled ? 99 : (o.delayMin ?? 0)));
  const lateDays = delays.filter((x) => x >= 5).length;
  if (days < 4 || lateDays / days < 0.6 || median(delays) < 5) return null;
  return { kind: 'train_pattern', station, days, lateDays, medianMin: Math.min(median(delays), 98) };
}

/**
 * Remember departures seen (one row per train, station and day; the latest report wins). Kept: the data is the product
 * (patterns only read the last PATTERN_DAYS).
 */
export function recordObservations(db: Db, deps: (Departure & { serviceDate: string })[]) {
  const done = deps.filter((d) => d.actual !== null || d.canceled);
  if (!done.length) return;
  const upsert = db.$client.prepare(
    `insert into delay_observations (train_number, signature, service_date, advertised, delay_min, canceled) values (?, ?, ?, ?, ?, ?)
     on conflict(train_number, signature, service_date) do update set delay_min = excluded.delay_min, canceled = excluded.canceled`,
  );
  db.transaction(() => {
    for (const d of done) upsert.run(d.trainNumber, d.signature, d.serviceDate, d.advertised, delayOf(d), d.canceled ? 1 : 0);
  });
}

interface TrvDep {
  AdvertisedTrainIdent: string;
  LocationSignature: string;
  AdvertisedTimeAtLocation: string;
  TimeAtLocation?: string;
  Canceled?: boolean;
}

/** Departures in the last hour at these stations (Trafikverket). */
export async function recentDepartures(sigs: string[], now: number, fetchImpl?: typeof fetch): Promise<Departure[]> {
  if (!sigs.length) return [];
  const from = new Date(now - WINDOW_MIN * 60_000).toISOString();
  const to = new Date(now).toISOString();
  const r = await trvQuery<{ TrainAnnouncement?: TrvDep[] }>(
    `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9"><FILTER><EQ name="Advertised" value="true"/><EQ name="ActivityType" value="Avgang"/>` +
      `<IN name="LocationSignature" value="${sigs.join(',')}"/><GTE name="AdvertisedTimeAtLocation" value="${from}"/><LTE name="AdvertisedTimeAtLocation" value="${to}"/>` +
      `<NE name="TypeOfTraffic.Description" value="Buss"/></FILTER>` +
      `<INCLUDE>AdvertisedTrainIdent</INCLUDE><INCLUDE>LocationSignature</INCLUDE><INCLUDE>AdvertisedTimeAtLocation</INCLUDE><INCLUDE>TimeAtLocation</INCLUDE><INCLUDE>Canceled</INCLUDE></QUERY>`,
    fetchImpl,
  );
  return (r.TrainAnnouncement ?? []).map((a) => ({
    trainNumber: a.AdvertisedTrainIdent,
    signature: a.LocationSignature,
    advertised: Date.parse(a.AdvertisedTimeAtLocation),
    actual: a.TimeAtLocation ? Date.parse(a.TimeAtLocation) : null,
    canceled: Boolean(a.Canceled),
  }));
}

export interface LegRisk {
  checkedAt: number;
  /** Why there may be no warnings: the trip is too far off for "right now" to matter, or the data isn't there. */
  limits: ('too_far' | 'abroad' | 'no_live_data' | 'no_history')[];
  warnings: RiskWarning[];
}

const cache = new Map<string, { at: number; risk: LegRisk }>();

export async function legRisk(db: Db, userId: string, legId: string, opts: { now?: number; fetchImpl?: typeof fetch } = {}): Promise<LegRisk | null> {
  const now = opts.now ?? Date.now();
  const hit = cache.get(legId);
  if (hit && now - hit.at < 2 * 60_000) return hit.risk;
  const leg = db.select().from(legs).where(and(eq(legs.id, legId), eq(legs.userId, userId))).get();
  if (!leg) return null;
  const dep = leg.schedDep?.getTime() ?? 0;
  const risk: LegRisk = { checkedAt: now, limits: [], warnings: [] };
  if ((leg.schedArr?.getTime() ?? 0) < now || leg.canceled) return risk;
  const stops = db
    .select({ seq: legStops.seq, role: legStops.role, sig: stations.trvSignature, name: stations.name })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, legId))
    .orderBy(legStops.seq)
    .all()
    .filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
  const swedish = stops.filter((s) => s.sig && !s.sig.includes('.'));
  if (!swedish.length) risk.limits.push('abroad');
  const board = stops.find((s) => s.role === 'board');
  const boardSig = board?.sig && !board.sig.includes('.') ? board.sig : null;
  if (dep - now > NOW_HORIZON_MS) risk.limits.push('too_far');
  else if (swedish.length) {
    // At most 15 stations, spread along the route, the boarding station always in.
    const step = Math.max(1, Math.ceil(swedish.length / 15));
    const sigs = [...new Set([boardSig, ...swedish.filter((_, i) => i % step === 0).map((s) => s.sig!)].filter((s): s is string => !!s))];
    try {
      const deps = await recentDepartures(sigs, now, opts.fetchImpl);
      recordObservations(db, deps.map((d) => ({ ...d, serviceDate: todayIn('Europe/Stockholm', d.advertised) })));
      // Your own train's earlier stops aren't "other trains": its own delay is shown on the trip already.
      const others = deps.filter((d) => d.trainNumber !== leg.trainNumber);
      const now_ = nowWarnings(others, boardSig, board?.name ?? '');
      // The trains ahead of yours, the same way: only shortly before you leave, when it can still matter.
      const next = stops.find((s) => s.seq > (board?.seq ?? Infinity) && s.sig && !s.sig.includes('.'));
      let ahead: RiskWarning | null = null;
      if (boardSig && next && dep - now <= 2 * 3600_000 && dep > now)
        try {
          ahead = aheadWarning(await trainsAhead(others, boardSig, next.sig!, now, opts.fetchImpl), board?.name ?? '', next.name);
        } catch {
          // The rest of the check stands.
        }
      // Said once: the trains your way say more than all of your station's departures.
      risk.warnings.push(...(ahead ? [...now_.filter((w) => w.kind !== 'station_now'), ahead] : now_));
    } catch {
      risk.limits.push('no_live_data');
    }
  }
  // The past pattern: the observed record first (every country, departures from where you get on, 28 days;
  // BUILDOUT O4), else what boards and these checks have recorded in Sweden.
  let patternDone = false;
  if (leg.trainNumber && dep - now <= 7 * 86400_000) {
    const history = punctuality(db, { trainNumber: leg.trainNumber, stationId: leg.originStationId, before: leg.serviceDate ?? todayIn('Europe/Stockholm', now), event: 'dep' });
    if (history && history.days >= 4) {
      patternDone = true;
      const p = patternFromHistory(history, board?.name ?? '');
      if (p) risk.warnings.push(p);
    }
  }
  if (!patternDone && boardSig && leg.trainNumber && dep - now <= 7 * 86400_000) {
    const today = todayIn('Europe/Stockholm', now);
    const obs = db
      .select({ delayMin: delayObservations.delayMin, canceled: delayObservations.canceled })
      .from(delayObservations)
      .where(
        and(
          eq(delayObservations.trainNumber, leg.trainNumber),
          sql`lower(${delayObservations.signature}) = ${boardSig.toLowerCase()}`,
          gte(delayObservations.serviceDate, addDays(today, -PATTERN_DAYS)),
          lt(delayObservations.serviceDate, today),
        ),
      )
      .all();
    const p = patternWarning(obs, board?.name ?? '');
    if (p) risk.warnings.push(p);
    else if (obs.length < 4) risk.limits.push('no_history');
  }
  cache.set(legId, { at: now, risk });
  if (cache.size > 200) cache.delete(cache.keys().next().value!);
  return risk;
}
