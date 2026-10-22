// Actual times from Trafikverket (SPEC §10, Phase 0 §2): match each ridden stop by
// (signature, activity, advertised minute), because train numbers change mid-journey and collide across operators.
import { and, eq, gt, lt, ne, sql } from 'drizzle-orm';
import { delayMinutes } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legStops, legs, stations, timetableTrips } from '../db/schema.js';
import { actualTime, trvQuery } from '../trafikverket/client.js';
import { parseComposition, typeFromComposition, type Composition } from './trainTypes.js';
import { productOf } from '../search/timetable.js';
import { onboardFromRow } from './onboard.js';
import { updateRides } from './recording.js';
import { enturStops } from '../entur/calls.js';
import type { OnboardFacts } from '@clack/shared';

/** Trafikverket keeps about 4 days of history (Phase 0 §1); after that a leg can't get actuals any more. */
export const TRV_HISTORY_MS = 4 * 86400_000;
/** Journey Planner keeps a Norwegian train's actual times for its operating day only. */
const ENTUR_HISTORY_MS = 30 * 3600_000;
/** Freeze a leg this long after it actually arrived. */
const SNAPSHOT_AFTER_MS = 30 * 60_000;

/**
 * Sanity rules between the feeds and the trip (docs/RELIABILITY_PLAN.md §2), applied to what a refresh found against
 * what's stored. Real reports pass unchanged; only these are held back:
 * - an actual time never goes back to "not yet" (a later answer that lacks it is a gap, not news);
 * - an "actual" time still in the future is an estimate at best;
 * - an estimate that jumps 15 min or more from the stored one waits for the next answer to say the same.
 */
export const JUMP_MS = 15 * 60_000;
const FUTURE_SLACK_MS = 2 * 60_000;
const held = new Map<string, { value: number; at: number }>();

export function resetHeldEstimates() {
  held.clear();
}

export function sanitizeStop(
  key: string,
  found: { actual: number | null; estimated: number | null },
  stored: { actual: number | null; estimated: number | null },
  now: number,
): { actual: number | null; estimated: number | null } {
  let actual = found.actual;
  let estimated = found.estimated;
  if (actual !== null && actual > now + FUTURE_SLACK_MS) {
    estimated ??= actual;
    actual = null;
  }
  if (actual === null && stored.actual !== null) return { actual: stored.actual, estimated: null };
  if (actual === null && estimated !== null && stored.estimated !== null && Math.abs(estimated - stored.estimated) >= JUMP_MS) {
    const h = held.get(key);
    if (h && Math.abs(h.value - estimated) <= 2 * 60_000 && now - h.at <= 10 * 60_000) held.delete(key);
    else {
      held.set(key, { value: estimated, at: now });
      estimated = stored.estimated;
    }
  } else held.delete(key);
  return { actual, estimated };
}

export interface AnnouncementRow {
  AdvertisedTrainIdent: string;
  LocationSignature: string;
  ActivityType: 'Ankomst' | 'Avgang';
  AdvertisedTimeAtLocation: string;
  TimeAtLocation?: string;
  EstimatedTimeAtLocation?: string;
  TrackAtLocation?: string;
  Canceled?: boolean;
  Deviation?: { Code?: string; Description: string }[];
  TypeOfTraffic?: { Description: string }[];
  TrainComposition?: (string | { Description?: string })[];
  Service?: { Code?: string; Description?: string }[];
}

export interface StopForMatch {
  seq: number;
  role: string;
  sig: string | null;
  schedArr: number | null;
  schedDep: number | null;
}

export interface StopActuals {
  seq: number;
  actualArr: number | null;
  actualDep: number | null;
  estimatedArr: number | null;
  estimatedDep: number | null;
  platform: string | null;
  canceled: boolean;
  deviations: string[];
  trvTrainNumber: string | null;
  /** Planned coach order on the departure row ("Vagnsordning 1-3-4-5-6-7"). */
  composition: Composition | null;
  /** On-board facts from the departure row (catering, day-of notices). */
  onboard: OnboardFacts | null;
  /** Who reports this stop live: Trafikverket, Entur, or nobody (a timetable-only match). */
  source?: 'trafikverket' | 'entur' | null;
  /** The time the stop's own country publishes for it, when it differs from our timetable (Norway's for SJ at Oslo S). */
  advertisedArr?: number | null;
  advertisedDep?: number | null;
}

const minuteKey = (sig: string, activity: string, ms: number) => `${sig.toLowerCase()}|${activity}|${Math.floor(ms / 60000)}`;

/** Events we look up: departures where you can board, arrivals where you can alight, for the stops you rode. */
export function eventsFor(stops: StopForMatch[]): { seq: number; sig: string; activity: 'Ankomst' | 'Avgang'; at: number }[] {
  const out: { seq: number; sig: string; activity: 'Ankomst' | 'Avgang'; at: number }[] = [];
  for (const s of stops) {
    // Only Swedish stops: Trafikverket has no announcements at foreign stations (Phase 0).
    if (!s.sig || s.sig.includes('.')) continue;
    if ((s.role === 'through' || s.role === 'alight') && s.schedArr !== null) out.push({ seq: s.seq, sig: s.sig, activity: 'Ankomst', at: s.schedArr });
    if ((s.role === 'board' || s.role === 'through') && s.schedDep !== null) out.push({ seq: s.seq, sig: s.sig, activity: 'Avgang', at: s.schedDep });
  }
  return out;
}

/** Pick the Trafikverket rows that belong to this leg and turn them into per-stop actuals. Pure, for tests. */
export function matchAnnouncements(stops: StopForMatch[], rows: AnnouncementRow[], trainNumber: string | null): Map<number, StopActuals> {
  const events = eventsFor(stops);
  const byKey = new Map<string, AnnouncementRow[]>();
  for (const r of rows) {
    const k = minuteKey(r.LocationSignature, r.ActivityType, Date.parse(r.AdvertisedTimeAtLocation));
    (byKey.get(k) ?? byKey.set(k, []).get(k)!).push(r);
  }
  // Count the stops (not events) each Trafikverket train matches; accept trains at >= 2 stops (or our own number).
  // A train meeting ours at a station has its arrival and departure in the same minutes as ours: that's one stop
  // (found 2026-10-22: northbound SL 2858 taken for southbound 2855 at Vega, and its GPS then used as ours).
  const hitStops = new Map<string, Set<number>>();
  for (const e of events)
    for (const r of byKey.get(minuteKey(e.sig, e.activity, e.at)) ?? []) (hitStops.get(r.AdvertisedTrainIdent) ?? hitStops.set(r.AdvertisedTrainIdent, new Set()).get(r.AdvertisedTrainIdent)!).add(e.seq);
  const hits = new Map([...hitStops].map(([n, seqs]) => [n, seqs.size]));
  const stripped = trainNumber && trainNumber.length === 5 ? String(Number(trainNumber.slice(1))) : null;
  const own = (n: string) => n === trainNumber || n === stripped;
  const need = Math.min(2, new Set(events.map((e) => e.seq)).size);
  const accepted = new Set([...hits].filter(([n, c]) => c >= need || own(n)).map(([n]) => n));
  // Where several accepted trains share a stop's minute, ours first, then the one matching the most stops.
  const rank = (r: AnnouncementRow) => (own(r.AdvertisedTrainIdent) ? Infinity : (hits.get(r.AdvertisedTrainIdent) ?? 0));

  const out = new Map<number, StopActuals>();
  for (const e of events) {
    const row = (byKey.get(minuteKey(e.sig, e.activity, e.at)) ?? []).filter((r) => accepted.has(r.AdvertisedTrainIdent)).sort((a, b) => rank(b) - rank(a))[0];
    if (!row) continue;
    const a =
      out.get(e.seq) ??
      out.set(e.seq, { seq: e.seq, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled: false, deviations: [], trvTrainNumber: null, composition: null, onboard: null, source: 'trafikverket' }).get(e.seq)!;
    const actual = actualTime(row.TimeAtLocation, row.AdvertisedTimeAtLocation);
    const estimated = row.EstimatedTimeAtLocation ? Date.parse(row.EstimatedTimeAtLocation) : null;
    if (e.activity === 'Ankomst') {
      a.actualArr = actual;
      a.estimatedArr = estimated;
    } else {
      a.actualDep = actual;
      a.estimatedDep = estimated;
    }
    // Departure platform wins (it's the one you board at); otherwise the arrival platform.
    if (row.TrackAtLocation && row.TrackAtLocation !== 'x' && (e.activity === 'Avgang' || !a.platform)) a.platform = row.TrackAtLocation;
    a.canceled ||= Boolean(row.Canceled);
    for (const d of row.Deviation ?? []) if (!a.deviations.includes(d.Description)) a.deviations.push(d.Description);
    a.trvTrainNumber ??= row.AdvertisedTrainIdent;
    if (e.activity === 'Avgang') {
      a.composition ??= parseComposition(row.TrainComposition);
      a.onboard ??= onboardFromRow(row);
    }
  }
  return out;
}

const FIELDS = ['AdvertisedTrainIdent', 'LocationSignature', 'ActivityType', 'AdvertisedTimeAtLocation', 'TimeAtLocation', 'EstimatedTimeAtLocation', 'TrackAtLocation', 'Canceled', 'Deviation', 'TypeOfTraffic', 'TrainComposition', 'Service'];

export async function fetchAnnouncements(events: ReturnType<typeof eventsFor>, fetchImpl?: typeof fetch): Promise<AnnouncementRow[]> {
  const rows: AnnouncementRow[] = [];
  // One query per ~40 events keeps the request small.
  for (let i = 0; i < events.length; i += 40) {
    const or = events
      .slice(i, i + 40)
      .map(
        (e) =>
          `<AND><EQ name="LocationSignature" value="${e.sig}"/><EQ name="ActivityType" value="${e.activity}"/>` +
          `<GTE name="AdvertisedTimeAtLocation" value="${new Date(e.at).toISOString()}"/>` +
          `<LT name="AdvertisedTimeAtLocation" value="${new Date(e.at + 60_000).toISOString()}"/></AND>`,
      )
      .join('');
    const r = await trvQuery<{ TrainAnnouncement?: AnnouncementRow[] }>(
      `<QUERY objecttype="TrainAnnouncement" schemaversion="1.9"><FILTER><EQ name="Advertised" value="true"/><OR>${or}</OR></FILTER>${FIELDS.map((f) => `<INCLUDE>${f}</INCLUDE>`).join('')}</QUERY>`,
      fetchImpl,
    );
    rows.push(...(r.TrainAnnouncement ?? []));
  }
  return rows;
}

/** Fetch and store actual times for one leg; returns the new data quality. Never touches snapshotted legs. */
export async function refreshLegActuals(db: Db, legId: string, opts: { now?: number; fetchImpl?: typeof fetch } = {}): Promise<string | null> {
  const now = opts.now ?? Date.now();
  const leg = db.select().from(legs).where(eq(legs.id, legId)).get();
  if (!leg || leg.status === 'snapshotted') return leg?.dataQuality ?? null;
  // A trip added by hand has no timetable to match reports against: it only moves from planned to completed.
  if (leg.dataQuality === 'manual') {
    const done = leg.schedArr !== null && now > leg.schedArr.getTime();
    if (done && leg.status === 'planned') db.update(legs).set({ status: 'completed' }).where(eq(legs.id, legId)).run();
    updateRides(db, { legId, now });
    return 'manual';
  }
  const stops = db
    .select({
      seq: legStops.seq,
      role: legStops.role,
      stationId: legStops.stationId,
      sig: stations.trvSignature,
      nsrId: stations.nsrId,
      country: stations.country,
      schedArr: legStops.schedArr,
      schedDep: legStops.schedDep,
      storedActualArr: legStops.actualArr,
      storedActualDep: legStops.actualDep,
      storedEstimatedArr: legStops.estimatedArr,
      storedEstimatedDep: legStops.estimatedDep,
    })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, legId))
    .orderBy(legStops.seq)
    .all()
    .map((s) => ({ ...s, schedArr: s.schedArr?.getTime() ?? null, schedDep: s.schedDep?.getTime() ?? null }));
  const storedOf = new Map(stops.map((s) => [s.seq, s]));

  const arr = leg.schedArr?.getTime() ?? 0;
  const tooOld = arr && now - arr > TRV_HISTORY_MS;
  const events = eventsFor(stops);
  let matched = new Map<number, StopActuals>();
  if (!tooOld && events.length) matched = matchAnnouncements(stops, await fetchAnnouncements(events, opts.fetchImpl), leg.trainNumber);
  // Norwegian stops: Entur, for what Trafikverket doesn't cover, and Norway's own published times for them.
  let entur = new Map<number, StopActuals>();
  if (arr && now - arr < ENTUR_HISTORY_MS && leg.serviceDate) {
    try {
      entur = await enturStops(db, { tripKey: leg.timetableTripKey, trainNumber: leg.trainNumber, serviceDate: leg.serviceDate, stops }, opts);
    } catch {
      // Entur down or over quota: Trafikverket's part still stands, and the next refresh tries again.
    }
  }
  for (const [seq, e] of entur) {
    const have = matched.get(seq);
    if (!have) matched.set(seq, e);
    else {
      have.actualArr ??= e.actualArr;
      have.actualDep ??= e.actualDep;
      have.platform ??= e.platform;
      have.canceled ||= e.canceled;
    }
  }
  for (const m of matched.values()) {
    const st = storedOf.get(m.seq);
    const ms = (d: Date | null | undefined) => d?.getTime() ?? null;
    const arr = sanitizeStop(`${legId}|${m.seq}|arr`, { actual: m.actualArr, estimated: m.estimatedArr }, { actual: ms(st?.storedActualArr), estimated: ms(st?.storedEstimatedArr) }, now);
    const dep = sanitizeStop(`${legId}|${m.seq}|dep`, { actual: m.actualDep, estimated: m.estimatedDep }, { actual: ms(st?.storedActualDep), estimated: ms(st?.storedEstimatedDep) }, now);
    Object.assign(m, { actualArr: arr.actual, estimatedArr: arr.estimated, actualDep: dep.actual, estimatedDep: dep.estimated });
  }

  // Who can report each stop: Trafikverket in Sweden, Entur where it has live data, otherwise nobody (Denmark,
  // Germany, and SJ's or Snälltåget's trains in Norway): those stops stay on the timetable and say so.
  const sourceOf = (s: (typeof stops)[number]): 'trafikverket' | 'entur' | null =>
    s.sig && !s.sig.includes('.') && s.country === 'SE' ? 'trafikverket' : (entur.get(s.seq)?.source ?? null);
  // Norway's published time for a Norwegian stop of another country's train (SJ 645: Oslo S 00:14, not SJ's 00:02).
  const adjusted = new Map<number, { arr: number | null; dep: number | null }>();
  for (const s of stops) {
    const e = entur.get(s.seq);
    if (s.country !== 'NO' || !e || (e.advertisedArr === undefined && e.advertisedDep === undefined)) continue;
    const arrT = s.schedArr === null ? null : (e.advertisedArr ?? s.schedArr);
    const depT = s.schedDep === null ? null : (e.advertisedDep ?? s.schedDep);
    if (arrT !== s.schedArr || depT !== s.schedDep) adjusted.set(s.seq, { arr: arrT, dep: depT });
  }
  for (const [seq, t] of adjusted) Object.assign(stops.find((s) => s.seq === seq)!, { schedArr: t.arr, schedDep: t.dep });

  const ridden = stops.filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
  const board = stops.find((s) => s.role === 'board');
  const alight = stops.find((s) => s.role === 'alight');
  const b = board ? matched.get(board.seq) : undefined;
  const a = alight ? matched.get(alight.seq) : undefined;
  const actualDep = b?.actualDep ?? null;
  const actualArr = a?.actualArr ?? null;
  // Beyond live data: the stop nearest the unreported end that was reported, as evidence the train ran there.
  const reported = (s: (typeof stops)[number]) => {
    const m = matched.get(s.seq);
    return m ? (m.actualDep ?? m.actualArr) : null;
  };
  const borderEvidence: NonNullable<typeof leg.borderEvidence> = {};
  if (board && !sourceOf(board)) {
    const first = ridden.find((s) => s !== board && sourceOf(s) && reported(s) !== null);
    if (first) borderEvidence.board = { stationId: first.stationId, at: reported(first)! };
  }
  if (alight && !sourceOf(alight)) {
    const last = [...ridden].reverse().find((s) => s !== alight && sourceOf(s) && reported(s) !== null);
    if (last) borderEvidence.alight = { stationId: last.stationId, at: reported(last)! };
  }
  // Stops beyond live data after the last report: expected times from the delay there, never as actual times.
  const lastReported = [...stops].reverse().find((s) => sourceOf(s) && reported(s) !== null);
  if (lastReported) {
    const m = matched.get(lastReported.seq)!;
    const delay = m.actualDep !== null && lastReported.schedDep !== null ? m.actualDep - lastReported.schedDep : m.actualArr !== null && lastReported.schedArr !== null ? m.actualArr - lastReported.schedArr : null;
    if (delay !== null)
      for (const s of stops.filter((x) => x.seq > lastReported.seq && !sourceOf(x) && !matched.get(x.seq)?.actualArr && !matched.get(x.seq)?.actualDep)) {
        const e =
          matched.get(s.seq) ??
          matched.set(s.seq, { seq: s.seq, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled: false, deviations: [], trvTrainNumber: null, composition: null, onboard: null, source: null }).get(s.seq)!;
        e.estimatedArr = s.schedArr === null ? null : s.schedArr + Math.max(0, delay);
        e.estimatedDep = s.schedDep === null ? null : s.schedDep + Math.max(0, delay);
      }
  }
  const dataQuality = actualDep !== null && actualArr !== null ? 'full' : actualDep !== null || actualArr !== null ? 'partial' : 'scheduled_only';
  const schedArrNow = alight?.schedArr ?? alight?.schedDep ?? arr;
  const arrived = actualArr !== null ? actualArr : schedArrNow;
  const snapshot = (actualArr !== null && now - actualArr > SNAPSHOT_AFTER_MS) || Boolean(tooOld);
  const status = snapshot ? 'snapshotted' : schedArrNow && now > arrived ? 'completed' : 'planned';

  // The coach order where you boarded can pin down the train type (SJ: X2000 or SJ 3000). Never over the owner's choice.
  const trip = leg.timetableTripKey ? db.select({ routeType: timetableTrips.routeType }).from(timetableTrips).where(eq(timetableTrips.key, leg.timetableTripKey)).get() : undefined;
  const composedType =
    leg.trainTypeSource === 'user' ? null : typeFromComposition(leg.operatorId, productOf(trip?.routeType ?? '', leg.category ?? ''), b?.composition ?? null);

  db.transaction((tx) => {
    for (const m of matched.values()) {
      tx.update(legStops)
        .set({
          actualArr: m.actualArr === null ? null : new Date(m.actualArr),
          actualDep: m.actualDep === null ? null : new Date(m.actualDep),
          // Estimates only matter until the real time is known.
          estimatedArr: m.actualArr === null && m.estimatedArr !== null ? new Date(m.estimatedArr) : null,
          estimatedDep: m.actualDep === null && m.estimatedDep !== null ? new Date(m.estimatedDep) : null,
          platform: m.platform,
          canceled: m.canceled,
          deviations: m.deviations,
          trvTrainNumber: m.trvTrainNumber,
        })
        .where(and(eq(legStops.legId, legId), eq(legStops.seq, m.seq)))
        .run();
    }
    for (const s of stops) {
      const t = adjusted.get(s.seq);
      tx.update(legStops)
        .set({ reportSource: sourceOf(s), ...(t ? { schedArr: t.arr === null ? null : new Date(t.arr), schedDep: t.dep === null ? null : new Date(t.dep) } : {}) })
        .where(and(eq(legStops.legId, legId), eq(legStops.seq, s.seq)))
        .run();
    }
    tx.update(legs)
      .set({
        status,
        dataQuality,
        actualDep: actualDep === null ? null : new Date(actualDep),
        actualArr: actualArr === null ? null : new Date(actualArr),
        depDelayMin: delayMinutes(board?.schedDep, actualDep),
        arrDelayMin: delayMinutes(alight?.schedArr, actualArr),
        depPlatform: b?.platform ?? null,
        arrPlatform: a?.platform ?? null,
        canceled: Boolean(b?.canceled || a?.canceled),
        trvTrainNumbers: [...new Set([...matched.values()].map((m) => m.trvTrainNumber).filter((n): n is string => !!n))],
        borderEvidence: borderEvidence.board || borderEvidence.alight ? borderEvidence : null,
        // Norway's published times for the stops you got on or off at, when they differ from our timetable.
        ...(board && adjusted.has(board.seq) && board.schedDep !== null ? { schedDep: new Date(board.schedDep) } : {}),
        ...(alight && adjusted.has(alight.seq) && alight.schedArr !== null ? { schedArr: new Date(alight.schedArr) } : {}),
        ...(composedType ? { trainType: composedType, trainTypeSource: 'composition' } : {}),
        ...(b?.onboard ? { onboard: b.onboard } : {}),
      })
      .where(eq(legs.id, legId))
      .run();
  });
  updateRides(db, { legId, now });
  return dataQuality;
}

/**
 * Legs that can still get (better) actuals: not snapshotted, departing within the next day, and arrived less than
 * ~4 days ago. Run by the scheduler, on server start and right after a leg is added.
 */
export async function refreshDueLegs(db: Db, log: (m: string) => void = () => {}, now = Date.now()) {
  const due = db
    .select({ id: legs.id })
    .from(legs)
    .where(and(ne(legs.status, 'snapshotted'), lt(legs.schedDep, new Date(now + 86400_000)), gt(legs.schedArr, new Date(now - TRV_HISTORY_MS - 86400_000))))
    .all();
  // Older legs that were never caught in time: freeze them as scheduled-only (the data is gone from Trafikverket).
  const expired = db
    .update(legs)
    .set({ status: 'snapshotted' })
    .where(and(ne(legs.status, 'snapshotted'), lt(legs.schedArr, new Date(now - TRV_HISTORY_MS))))
    .run().changes;
  let ok = 0;
  for (const { id } of due) {
    try {
      await refreshLegActuals(db, id, { now });
      ok++;
    } catch (e) {
      log(`actuals for leg ${id} failed: ${(e as Error).message}`);
    }
  }
  // Trips that finished without clear reports move to "Did you take this train?" once the wait is over.
  const asked = updateRides(db, { now });
  if (asked) log(`trip records: ${asked} updated`);
  if (due.length || expired) log(`actual times: refreshed ${ok}/${due.length} legs${expired ? `, ${expired} expired as scheduled-only` : ''}`);
  void sql;
}
