// Journey risk (owner, 2026-10-22): warnings before trouble, from what can be observed, by fixed rules. No AI, and
// never a prediction dressed up: three kinds of evidence, each said for what it is.
// - Now, along your route: how trains have left the stations you'll pass in the last hour (Trafikverket's actual times).
// - Now, at your station: the same for departures from where you get on.
// - Past pattern for your train: how it left your station on earlier days, from what this computer has seen (boards
//   and these checks record it; Trafikverket keeps only about a day back). Silent until there's enough of it.
// Weak, stale or irrelevant evidence gives no warning (a trip more than 6 hours off gets no "right now" warning).
import { and, eq, gte, lt, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { delayObservations, legs, legStops, stations } from '../db/schema.js';
import { trvQuery } from '../trafikverket/client.js';
import { addDays, todayIn } from '../lib/time.js';

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

/** The pattern for one train at one station from earlier days' observations. Pure. */
export function patternWarning(obs: { delayMin: number | null; canceled: boolean }[], station: string): RiskWarning | null {
  const days = obs.length;
  const delays = obs.map((o) => (o.canceled ? 99 : (o.delayMin ?? 0)));
  const lateDays = delays.filter((x) => x >= 5).length;
  if (days < 4 || lateDays / days < 0.6 || median(delays) < 5) return null;
  return { kind: 'train_pattern', station, days, lateDays, medianMin: Math.min(median(delays), 98) };
}

/** Remember departures seen (one row per train, station and day; the latest report wins). Kept 30 days. */
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
  db.delete(delayObservations).where(lt(delayObservations.serviceDate, addDays(todayIn('Europe/Stockholm'), -30))).run();
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
      risk.warnings.push(...nowWarnings(deps.filter((d) => d.trainNumber !== leg.trainNumber), boardSig, board?.name ?? ''));
    } catch {
      risk.limits.push('no_live_data');
    }
  }
  if (boardSig && leg.trainNumber && dep - now <= 7 * 86400_000) {
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
