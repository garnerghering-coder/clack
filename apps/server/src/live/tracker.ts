// Live tracking while the server runs (SPEC §5.5, DESIGN §9). Every 20 s, for each leg inside its tracking window,
// refresh times from Trafikverket, look up the train's GPS position, work out where it is, store live_state, record
// leg_events for anything that changed, and tell open clients over SSE.
//
// Polling, not Trafikverket's SSE stream: for the handful of trains one person tracks it's the same few requests,
// needs no reconnect/catch-up logic, and lags only ~7 s more (Phase 0 §9). One poll covers each leg once, so trains
// shared by several users later are still fetched once per tick.
import { EventEmitter } from 'node:events';
import { and, asc, desc, eq, gt, inArray, lt, ne } from 'drizzle-orm';
import { decodePolyline, type LatLon } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legEvents, legStops, legs, liveState, stations } from '../db/schema.js';
import { refreshLegActuals } from '../legs/actuals.js';
import { parseWgs84, trvQuery } from '../trafikverket/client.js';
import { gtfsRt, RT_DATASOURCES, type RtDatasource } from '../entur/client.js';
import { serviceJourneyFor } from '../entur/calls.js';
import { rtDate } from '../livemap/norway.js';
import { diffEvents, liveView, type GpsFix, type LegSummary, type LiveStop, type LiveView } from './progress.js';

export const POLL_MS = 20_000;
/** Track from an hour before departure until half an hour after arrival. */
const BEFORE_MS = 60 * 60_000;
const AFTER_MS = 30 * 60_000;

export interface LiveUpdate {
  legId: string;
  live: LiveView & { updatedAt: number };
  events: { type: string; ts: number; payload: Record<string, unknown> }[];
}

/** Open SSE connections listen here. */
export const liveBus = new EventEmitter();
liveBus.setMaxListeners(100);

interface TrvPosition {
  Train: { AdvertisedTrainNumber?: string; OperationalTrainNumber?: string };
  Position: { WGS84?: string };
  TimeStamp: string;
  Status?: { Active?: boolean };
  Bearing?: number;
  Speed?: number;
}

/** Newest active GPS fix per advertised train number. */
export async function fetchPositions(numbers: string[], now: number, fetchImpl?: typeof fetch): Promise<Map<string, GpsFix>> {
  const out = new Map<string, GpsFix>();
  if (!numbers.length) return out;
  const r = await trvQuery<{ TrainPosition?: TrvPosition[] }>(
    `<QUERY objecttype="TrainPosition" namespace="järnväg.trafikinfo" schemaversion="1.1"><FILTER>` +
      `<IN name="Train.AdvertisedTrainNumber" value="${numbers.join(',')}"/><GT name="TimeStamp" value="${new Date(now - 10 * 60_000).toISOString()}"/>` +
      `</FILTER></QUERY>`,
    fetchImpl,
  );
  for (const p of r.TrainPosition ?? []) {
    const n = p.Train.AdvertisedTrainNumber;
    const ll = parseWgs84(p.Position.WGS84);
    if (!n || !ll || p.Status?.Active === false) continue;
    const at = Date.parse(p.TimeStamp);
    if ((out.get(n)?.at ?? 0) >= at) continue;
    out.set(n, { lat: ll[0], lon: ll[1], at, bearing: p.Bearing ?? null, speedKmh: p.Speed ?? null });
  }
  return out;
}

/**
 * Newest fix per Entur service journey ("<trip id>|<date>"), for Norwegian trains. One vehicle-positions request
 * per operator involved; protobuf's 0 for a missing bearing is treated as none.
 */
export async function fetchNorwayPositions(tripIds: string[], now: number, fetchImpl?: typeof fetch): Promise<Map<string, GpsFix>> {
  const out = new Map<string, GpsFix>();
  const sources = [...new Set(tripIds.map((id) => id.split(':')[0]))].filter((c): c is RtDatasource => (RT_DATASOURCES as readonly string[]).includes(c!));
  for (const ds of sources) {
    const feed = await gtfsRt('vehicle-positions', ds, fetchImpl);
    for (const e of feed.entity) {
      const v = e.vehicle;
      const date = rtDate(v?.trip?.startDate);
      if (!v?.position || !v.trip?.tripId || !date) continue;
      const at = Number(v.timestamp ?? 0) * 1000;
      if (now - at > 10 * 60_000) continue;
      out.set(`${v.trip.tripId}|${date}`, { lat: v.position.latitude, lon: v.position.longitude, at, bearing: v.position.bearing || null, speedKmh: v.position.speed ? Math.round(v.position.speed * 3.6) : null });
    }
  }
  return out;
}

const ms = (d: Date | null) => d?.getTime() ?? null;

/** Legs to poll now: not frozen, and between an hour before departure and half an hour after arrival. */
export function trackedLegIds(db: Db, now: number): string[] {
  return db
    .select({ id: legs.id, schedArr: legs.schedArr, actualArr: legs.actualArr })
    .from(legs)
    .where(and(ne(legs.status, 'snapshotted'), lt(legs.schedDep, new Date(now + BEFORE_MS)), gt(legs.schedArr, new Date(now - AFTER_MS - 6 * 3600_000))))
    .all()
    .filter((l) => {
      // Late trains stay tracked until they've actually arrived (+30 min).
      const live = db.select({ arrivalEta: liveState.arrivalEta }).from(liveState).where(eq(liveState.legId, l.id)).get();
      const end = ms(l.actualArr) ?? ms(live?.arrivalEta ?? null) ?? ms(l.schedArr)!;
      return now <= end + AFTER_MS;
    })
    .map((l) => l.id);
}

function loadLeg(db: Db, legId: string) {
  const leg = db.select().from(legs).where(eq(legs.id, legId)).get();
  if (!leg) return null;
  const all = db
    .select({
      role: legStops.role,
      stationId: legStops.stationId,
      name: stations.name,
      lat: stations.lat,
      lon: stations.lon,
      schedArr: legStops.schedArr,
      schedDep: legStops.schedDep,
      actualArr: legStops.actualArr,
      actualDep: legStops.actualDep,
      estimatedArr: legStops.estimatedArr,
      estimatedDep: legStops.estimatedDep,
      platform: legStops.platform,
      canceled: legStops.canceled,
    })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, legId))
    .orderBy(asc(legStops.seq))
    .all();
  const ridden: LiveStop[] = all
    .filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight')
    .map((s) => ({
      ...s,
      schedArr: ms(s.schedArr),
      schedDep: ms(s.schedDep),
      actualArr: ms(s.actualArr),
      actualDep: ms(s.actualDep),
      estimatedArr: ms(s.estimatedArr),
      estimatedDep: ms(s.estimatedDep),
    }));
  const line: LatLon[] = leg.geometry ? decodePolyline(leg.geometry) : ridden.map((s) => [s.lat, s.lon]);
  return { leg, ridden, line };
}

function summary(loaded: NonNullable<ReturnType<typeof loadLeg>>): LegSummary {
  const { leg, ridden } = loaded;
  const alight = ridden.at(-1);
  const est = alight ? (alight.actualArr ?? alight.estimatedArr) : null;
  return {
    arrivalDelayMin: alight && alight.schedArr !== null && est !== null ? Math.round((est - alight.schedArr) / 60_000) : null,
    depPlatform: leg.depPlatform,
    arrPlatform: leg.arrPlatform,
    canceled: leg.canceled,
    canceledStops: ridden.filter((s) => s.canceled).map((s) => s.stationId),
    departedAt: ms(leg.actualDep),
    arrivedAt: ms(leg.actualArr),
  };
}

export interface TrackerOptions {
  fetchImpl?: typeof fetch;
  log?: (m: string) => void;
  now?: () => number;
}

/** One tick: refresh every tracked leg. Exported for tests and for "refresh now". */
export async function trackOnce(db: Db, opts: TrackerOptions = {}): Promise<LiveUpdate[]> {
  const now = (opts.now ?? Date.now)();
  const ids = trackedLegIds(db, now);
  if (!ids.length) return [];
  const before = new Map<string, LegSummary>();
  for (const id of ids) {
    const l = loadLeg(db, id);
    if (l) before.set(id, summary(l));
    try {
      await refreshLegActuals(db, id, { now, fetchImpl: opts.fetchImpl });
    } catch (e) {
      opts.log?.(`live: times for leg ${id} failed: ${(e as Error).message}`);
    }
  }
  const loaded = ids.map((id) => loadLeg(db, id)).filter((l): l is NonNullable<typeof l> => l !== null);
  const numbers = [...new Set(loaded.flatMap((l) => (l.leg.trvTrainNumbers.length ? l.leg.trvTrainNumbers : l.leg.trainNumber ? [l.leg.trainNumber] : [])))];
  let fixes = new Map<string, GpsFix>();
  try {
    fixes = await fetchPositions(numbers, now, opts.fetchImpl);
  } catch (e) {
    opts.log?.(`live: positions failed: ${(e as Error).message}`);
  }

  // Norwegian trains (and the Norwegian part of cross-border ones): Entur's GPS, by service journey.
  const journeyOf = new Map<string, string>();
  for (const l of loaded) {
    const id = l.leg.serviceDate ? serviceJourneyFor(db, l.leg.timetableTripKey, l.leg.trainNumber, l.leg.serviceDate) : null;
    if (id) journeyOf.set(l.leg.id, `${id}|${l.leg.serviceDate}`);
  }
  let noFixes = new Map<string, GpsFix>();
  if (journeyOf.size)
    try {
      noFixes = await fetchNorwayPositions([...journeyOf.values()].map((k) => k.split('|')[0]!), now, opts.fetchImpl);
    } catch (e) {
      opts.log?.(`live: Norway positions failed: ${(e as Error).message}`);
    }

  const updates: LiveUpdate[] = [];
  for (const l of loaded) {
    if (!l.ridden.length) continue;
    const nums = l.leg.trvTrainNumbers.length ? l.leg.trvTrainNumbers : l.leg.trainNumber ? [l.leg.trainNumber] : [];
    // With a number change mid-journey (or two countries' feeds), use whichever fix is newest.
    const jk = journeyOf.get(l.leg.id);
    const gps =
      [...nums.map((n) => fixes.get(n)), jk ? noFixes.get(jk) : undefined]
        .filter((f): f is GpsFix => !!f)
        .sort((a, b) => b.at - a.at)[0] ?? null;
    const view = liveView(l.ridden, l.line, gps, now);
    const row = {
      legId: l.leg.id,
      updatedAt: new Date(now),
      status: view.status,
      lat: view.lat,
      lon: view.lon,
      bearing: view.bearing,
      speedKmh: view.speedKmh,
      positionSource: view.positionSource,
      positionAt: view.positionAt === null ? null : new Date(view.positionAt),
      progress: view.progress,
      prevStopId: view.prevStopId,
      nextStopId: view.nextStopId,
      eta: view.eta === null ? null : new Date(view.eta),
      arrivalEta: view.arrivalEta === null ? null : new Date(view.arrivalEta),
      arrivalDelayMin: view.arrivalDelayMin,
    };
    const events = diffEvents(before.get(l.leg.id) ?? summary(l), summary(l));
    db.transaction((tx) => {
      tx.insert(liveState).values(row).onConflictDoUpdate({ target: liveState.legId, set: row }).run();
      for (const e of events)
        tx.insert(legEvents)
          .values({ legId: l.leg.id, ts: new Date(now), type: e.type, payload: e.payload })
          .run();
    });
    const u: LiveUpdate = { legId: l.leg.id, live: { ...view, updatedAt: now }, events: events.map((e) => ({ ...e, ts: now })) };
    updates.push(u);
    liveBus.emit('update', u);
  }
  return updates;
}

/** Runs trackOnce every POLL_MS; ticks don't overlap. */
export function startLiveTracker(db: Db, opts: TrackerOptions = {}) {
  let busy = false;
  let lastCount = -1;
  const tick = async () => {
    if (busy) return;
    busy = true;
    try {
      const u = await trackOnce(db, opts);
      if (u.length !== lastCount) {
        if (u.length) opts.log?.(`live: tracking ${u.length} trip(s)`);
        else if (lastCount > 0) opts.log?.('live: nothing to track right now');
        lastCount = u.length;
      }
    } catch (e) {
      opts.log?.(`live: ${(e as Error).message}`);
    } finally {
      busy = false;
    }
  };
  void tick();
  const timer = setInterval(tick, POLL_MS);
  return () => clearInterval(timer);
}

export function liveFor(db: Db, legId: string) {
  const live = db.select().from(liveState).where(eq(liveState.legId, legId)).get() ?? null;
  const events = db.select().from(legEvents).where(eq(legEvents.legId, legId)).orderBy(desc(legEvents.ts), desc(legEvents.id)).limit(50).all();
  return { live, events };
}

export function liveForMany(db: Db, legIds: string[]) {
  if (!legIds.length) return new Map<string, typeof liveState.$inferSelect>();
  return new Map(
    db
      .select()
      .from(liveState)
      .where(inArray(liveState.legId, legIds))
      .all()
      .map((r) => [r.legId, r]),
  );
}
