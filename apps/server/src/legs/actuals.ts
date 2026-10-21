// Actual times from Trafikverket (SPEC §10, Phase 0 §2): match each ridden stop by
// (signature, activity, advertised minute), because train numbers change mid-journey and collide across operators.
import { and, eq, gt, lt, ne, sql } from 'drizzle-orm';
import { delayMinutes } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legStops, legs, stations, timetableTrips } from '../db/schema.js';
import { actualTime, trvQuery } from '../trafikverket/client.js';
import { parseComposition, typeFromComposition, type Composition } from './trainTypes.js';
import { productOf } from '../search/timetable.js';

/** Trafikverket keeps about 4 days of history (Phase 0 §1); after that a leg can't get actuals any more. */
export const TRV_HISTORY_MS = 4 * 86400_000;
/** Freeze a leg this long after it actually arrived. */
const SNAPSHOT_AFTER_MS = 30 * 60_000;

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
  // Count matched events per Trafikverket train; accept trains with >= 2 (or our own number).
  const hits = new Map<string, number>();
  for (const e of events) for (const r of byKey.get(minuteKey(e.sig, e.activity, e.at)) ?? []) hits.set(r.AdvertisedTrainIdent, (hits.get(r.AdvertisedTrainIdent) ?? 0) + 1);
  const stripped = trainNumber && trainNumber.length === 5 ? String(Number(trainNumber.slice(1))) : null;
  const need = Math.min(2, events.length);
  const accepted = new Set([...hits].filter(([n, c]) => c >= need || n === trainNumber || n === stripped).map(([n]) => n));

  const out = new Map<number, StopActuals>();
  for (const e of events) {
    const row = (byKey.get(minuteKey(e.sig, e.activity, e.at)) ?? []).find((r) => accepted.has(r.AdvertisedTrainIdent));
    if (!row) continue;
    const a =
      out.get(e.seq) ??
      out.set(e.seq, { seq: e.seq, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled: false, deviations: [], trvTrainNumber: null, composition: null }).get(e.seq)!;
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
    if (e.activity === 'Avgang') a.composition ??= parseComposition(row.TrainComposition);
  }
  return out;
}

const FIELDS = ['AdvertisedTrainIdent', 'LocationSignature', 'ActivityType', 'AdvertisedTimeAtLocation', 'TimeAtLocation', 'EstimatedTimeAtLocation', 'TrackAtLocation', 'Canceled', 'Deviation', 'TypeOfTraffic', 'TrainComposition'];

async function fetchAnnouncements(events: ReturnType<typeof eventsFor>, fetchImpl?: typeof fetch): Promise<AnnouncementRow[]> {
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
  const stops = db
    .select({ seq: legStops.seq, role: legStops.role, sig: stations.trvSignature, schedArr: legStops.schedArr, schedDep: legStops.schedDep })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, legId))
    .all()
    .map((s) => ({ ...s, schedArr: s.schedArr?.getTime() ?? null, schedDep: s.schedDep?.getTime() ?? null }));

  const arr = leg.schedArr?.getTime() ?? 0;
  const tooOld = arr && now - arr > TRV_HISTORY_MS;
  const events = eventsFor(stops);
  let matched = new Map<number, StopActuals>();
  if (!tooOld && events.length) matched = matchAnnouncements(stops, await fetchAnnouncements(events, opts.fetchImpl), leg.trainNumber);

  const board = stops.find((s) => s.role === 'board');
  const alight = stops.find((s) => s.role === 'alight');
  const b = board ? matched.get(board.seq) : undefined;
  const a = alight ? matched.get(alight.seq) : undefined;
  const actualDep = b?.actualDep ?? null;
  const actualArr = a?.actualArr ?? null;
  const dataQuality = actualDep !== null && actualArr !== null ? 'full' : actualDep !== null || actualArr !== null ? 'partial' : 'scheduled_only';
  const arrived = actualArr !== null ? actualArr : arr;
  const snapshot = (actualArr !== null && now - actualArr > SNAPSHOT_AFTER_MS) || Boolean(tooOld);
  const status = snapshot ? 'snapshotted' : arr && now > arrived ? 'completed' : 'planned';

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
        ...(composedType ? { trainType: composedType, trainTypeSource: 'composition' } : {}),
      })
      .where(eq(legs.id, legId))
      .run();
  });
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
  if (due.length || expired) log(`actual times: refreshed ${ok}/${due.length} legs${expired ? `, ${expired} expired as scheduled-only` : ''}`);
  void sql;
}
