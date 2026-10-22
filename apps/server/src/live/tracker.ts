// Live tracking while the server runs (SPEC §5.5, DESIGN §9). Every 20 s, for each leg inside its tracking window,
// refresh times from Trafikverket, look up the train's GPS position, work out where it is, store live_state, record
// leg_events for anything that changed, and tell open clients over SSE.
//
// Polling, not Trafikverket's SSE stream: for the handful of trains one person tracks it's the same few requests,
// needs no reconnect/catch-up logic, and lags only ~7 s more (Phase 0 §9). One poll covers each leg once, so trains
// shared by several users later are still fetched once per tick.
import { EventEmitter } from 'node:events';
import { and, asc, desc, eq, gt, inArray, lt, ne, sql } from 'drizzle-orm';
import { decodePolyline, type LatLon } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legEvents, legStops, legs, liveQuality, liveState, shownValues, stations } from '../db/schema.js';
import { refreshLegActuals } from '../legs/actuals.js';
import { parseWgs84, trvQuery } from '../trafikverket/client.js';
import { gtfsRt, RT_DATASOURCES, type RtDatasource } from '../entur/client.js';
import { enturJourneyFor } from '../entur/calls.js';
import { rtDate } from '../livemap/norway.js';
import { diffEvents, expectedTimes, liveView, type GpsFix, type LegSummary, type LiveStop, type LiveView } from './progress.js';
import { FixFilter } from './sanitize.js';

export const POLL_MS = 20_000;
/** Track from an hour before departure until half an hour after arrival. */
const BEFORE_MS = 60 * 60_000;
const AFTER_MS = 30 * 60_000;

export interface LiveUpdate {
  legId: string;
  live: LiveView & { updatedAt: number; reportedAt: number | null };
  events: { type: string; ts: number; payload: Record<string, unknown> }[];
}

/** Every tracked leg's GPS goes through here (one train per leg), so a jump never reaches the map or the trip. */
export const trackerFixes = new FixFilter();

/** Open SSE connections listen here. */
export const liveBus = new EventEmitter();
liveBus.setMaxListeners(100);

interface TrvPosition {
  Train: { AdvertisedTrainNumber?: string; OperationalTrainNumber?: string; JourneyPlanDepartureDate?: string };
  Position: { WGS84?: string };
  TimeStamp: string;
  Status?: { Active?: boolean };
  Bearing?: number;
  Speed?: number;
}

export type DatedFix = GpsFix & { date: string | null };

/**
 * Active GPS fixes of the last 10 minutes per advertised train number, newest first. Several trains can share a
 * number (Öresundståg 1378 and Pågatåg 1378), so the caller picks the one that fits the trip (pickFix).
 */
export async function fetchPositions(numbers: string[], now: number, fetchImpl?: typeof fetch): Promise<Map<string, DatedFix[]>> {
  const out = new Map<string, DatedFix[]>();
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
    const list = out.get(n) ?? out.set(n, []).get(n)!;
    list.push({ lat: ll[0], lon: ll[1], at: Date.parse(p.TimeStamp), bearing: p.Bearing ?? null, speedKmh: p.Speed ?? null, date: p.Train.JourneyPlanDepartureDate?.slice(0, 10) ?? null });
  }
  for (const list of out.values()) list.sort((a, b) => b.at - a.at);
  return out;
}

/** Shortest distance from a point to a polyline, in metres (flat-earth per segment; fine at these scales). */
export function distanceToLineM(p: { lat: number; lon: number }, line: LatLon[]): number {
  if (!line.length) return Infinity;
  const kx = 111_320 * Math.cos((p.lat * Math.PI) / 180);
  const ky = 110_540;
  let best = Infinity;
  for (let i = 0; i < line.length; i++) {
    const a = line[i]!;
    const b = line[Math.min(i + 1, line.length - 1)]!;
    const [ax, ay, bx, by] = [(a[1] - p.lon) * kx, (a[0] - p.lat) * ky, (b[1] - p.lon) * kx, (b[0] - p.lat) * ky];
    const dx = bx - ax;
    const dy = by - ay;
    const len = dx * dx + dy * dy;
    const t = len ? Math.max(0, Math.min(1, -(ax * dx + ay * dy) / len)) : 0;
    best = Math.min(best, Math.hypot(ax + t * dx, ay + t * dy));
  }
  return best;
}

/** On the ridden track (3 km), or near the train's whole route on its way to you (15 km, straight lines between stops). */
export const ON_ROUTE_M = 3_000;
export const NEAR_ROUTE_M = 15_000;

/**
 * Which GPS fix is this trip's train: the newest one for its number that runs on its date (when the feed says) and
 * is on or near its route. A same-numbered train elsewhere in the country is never taken for yours. Pure.
 */
export function pickFix(fixes: DatedFix[], trip: { serviceDate: string | null; line: LatLon[]; route: LatLon[] }): GpsFix | null {
  return tripFixes(fixes, trip)[0] ?? null;
}

/** All of the fixes that can be this trip's train, newest first. Pure. */
export function tripFixes(fixes: DatedFix[], trip: { serviceDate: string | null; line: LatLon[]; route: LatLon[] }): DatedFix[] {
  return fixes.filter(
    (f) => !(f.date && trip.serviceDate && f.date !== trip.serviceDate) && (distanceToLineM(f, trip.line) <= ON_ROUTE_M || distanceToLineM(f, trip.route) <= NEAR_ROUTE_M),
  );
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
export function trackedLegIds(db: Db, now: number, userId?: string): string[] {
  return db
    .select({ id: legs.id, schedArr: legs.schedArr, actualArr: legs.actualArr })
    .from(legs)
    .where(
      and(
        ne(legs.status, 'snapshotted'),
        lt(legs.schedDep, new Date(now + BEFORE_MS)),
        gt(legs.schedArr, new Date(now - AFTER_MS - 6 * 3600_000)),
        userId ? eq(legs.userId, userId) : undefined,
      ),
    )
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
      seq: legStops.seq,
      role: legStops.role,
      stationId: legStops.stationId,
      name: stations.name,
      lat: stations.lat,
      lon: stations.lon,
      nsrId: stations.nsrId,
      country: stations.country,
      schedArr: legStops.schedArr,
      schedDep: legStops.schedDep,
      actualArr: legStops.actualArr,
      actualDep: legStops.actualDep,
      estimatedArr: legStops.estimatedArr,
      estimatedDep: legStops.estimatedDep,
      platform: legStops.platform,
      canceled: legStops.canceled,
      trvTrainNumber: legStops.trvTrainNumber,
    })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, legId))
    .orderBy(asc(legStops.seq))
    .all();
  const ridden: (LiveStop & { seq: number })[] = all
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
  // The whole trip, stop to stop, including before you board: where the train may be on its way to you.
  const route: LatLon[] = all.map((s) => [s.lat, s.lon]);
  const forEntur = all.map((s) => ({ nsrId: s.nsrId, country: s.country, schedArr: ms(s.schedArr), schedDep: ms(s.schedDep) }));
  return { leg, ridden, line, route, forEntur };
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
  const answered = new Set<string>();
  for (const id of ids) {
    const l = loadLeg(db, id);
    if (l) before.set(id, summary(l));
    try {
      await refreshLegActuals(db, id, { now, fetchImpl: opts.fetchImpl });
      answered.add(id);
    } catch (e) {
      opts.log?.(`live: times for leg ${id} failed: ${(e as Error).message}`);
    }
  }
  const loaded = ids.map((id) => loadLeg(db, id)).filter((l): l is NonNullable<typeof l> => l !== null);
  const numbers = [...new Set(loaded.flatMap((l) => (l.leg.trvTrainNumbers.length ? l.leg.trvTrainNumbers : l.leg.trainNumber ? [l.leg.trainNumber] : [])))];
  let fixes = new Map<string, DatedFix[]>();
  try {
    fixes = await fetchPositions(numbers, now, opts.fetchImpl);
  } catch (e) {
    opts.log?.(`live: positions failed: ${(e as Error).message}`);
  }

  // Norwegian trains (and the Norwegian part of cross-border ones): Entur's GPS, by service journey.
  const journeyOf = new Map<string, string>();
  for (const l of loaded) {
    try {
      const j = l.leg.serviceDate
        ? await enturJourneyFor(db, { tripKey: l.leg.timetableTripKey, trainNumber: l.leg.trainNumber, serviceDate: l.leg.serviceDate, stops: l.forEntur }, { now, fetchImpl: opts.fetchImpl })
        : null;
      if (j) journeyOf.set(l.leg.id, `${j.id}|${j.date}`);
    } catch (e) {
      opts.log?.(`live: Entur lookup failed: ${(e as Error).message}`);
    }
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
    const nums = numbersNow(l.ridden, l.line, now, l.leg.trvTrainNumbers.length ? l.leg.trvTrainNumbers : l.leg.trainNumber ? [l.leg.trainNumber] : []);
    // With a number change mid-journey (or two countries' feeds), use whichever fix is newest.
    const jk = journeyOf.get(l.leg.id);
    const candidates = [...nums.flatMap((n) => tripFixes(fixes.get(n) ?? [], { serviceDate: l.leg.serviceDate, line: l.line, route: l.route })), ...(jk && noFixes.get(jk) ? [noFixes.get(jk)!] : [])].sort(
      (a, b) => a.at - b.at,
    );
    // Oldest first through the filter: a fix the train couldn't have reached is dropped, not shown.
    const rejectedBefore = trackerFixes.stats.rejected;
    for (const f of candidates) trackerFixes.push(l.leg.id, { lat: f.lat, lon: f.lon, at: f.at, bearing: f.bearing, speedKmh: f.speedKmh });
    const rejected = trackerFixes.stats.rejected - rejectedBefore;
    const gps = trackerFixes.current(l.leg.id);
    const view = liveView(l.ridden, l.line, gps, now);
    const prevRow = db.select({ reportedAt: liveState.reportedAt }).from(liveState).where(eq(liveState.legId, l.leg.id)).get();
    const reportedAt = answered.has(l.leg.id) ? now : (prevRow?.reportedAt?.getTime() ?? null);
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
      reportedAt: reportedAt === null ? null : new Date(reportedAt),
    };
    const events = diffEvents(before.get(l.leg.id) ?? summary(l), summary(l));
    db.transaction((tx) => {
      tx.insert(liveState).values(row).onConflictDoUpdate({ target: liveState.legId, set: row }).run();
      for (const e of events)
        tx.insert(legEvents)
          .values({ legId: l.leg.id, ts: new Date(now), type: e.type, payload: e.payload })
          .run();
      recordShown(tx as unknown as Db, l.leg.id, l.ridden, now);
      const enRoute = view.status === 'en_route' || view.status === 'at_stop';
      const q = {
        ticks: 1,
        gpsTicks: enRoute && view.positionSource === 'gps' ? 1 : 0,
        estimatedTicks: enRoute && view.positionSource === 'estimated' ? 1 : 0,
        failedTicks: answered.has(l.leg.id) ? 0 : 1,
        rejectedFixes: rejected,
      };
      tx.insert(liveQuality)
        .values({ legId: l.leg.id, ...q, firstAt: new Date(now), lastAt: new Date(now) })
        .onConflictDoUpdate({
          target: liveQuality.legId,
          set: {
            ticks: sql`${liveQuality.ticks} + ${q.ticks}`,
            gpsTicks: sql`${liveQuality.gpsTicks} + ${q.gpsTicks}`,
            estimatedTicks: sql`${liveQuality.estimatedTicks} + ${q.estimatedTicks}`,
            failedTicks: sql`${liveQuality.failedTicks} + ${q.failedTicks}`,
            rejectedFixes: sql`${liveQuality.rejectedFixes} + ${q.rejectedFixes}`,
            lastAt: new Date(now),
          },
        })
        .run();
    });
    const u: LiveUpdate = { legId: l.leg.id, live: { ...view, updatedAt: now, reportedAt }, events: events.map((e) => ({ ...e, ts: now })) };
    updates.push(u);
    liveBus.emit('update', u);
  }
  trackerFixes.prune(now - 60 * 60_000);
  return updates;
}

/**
 * The train numbers the train carries where it is now. A trip that changes number on the way has more than one,
 * and the other number can be another train elsewhere at the time, so only the numbers Trafikverket reported at
 * the stops either side of the train count. Without per-stop numbers yet, all of them.
 */
export function numbersNow(ridden: (LiveStop & { trvTrainNumber?: string | null })[], line: LatLon[], now: number, all: string[]): string[] {
  if (all.length < 2) return all;
  const v = liveView(ridden, line, null, now);
  const near = ridden.filter((s) => s.stationId === v.prevStopId || s.stationId === v.nextStopId || (!v.prevStopId && s === ridden[0]));
  const nums = [...new Set(near.map((s) => s.trvTrainNumber).filter((n): n is string => !!n))];
  return nums.length ? nums : all;
}

/** Last value recorded per leg|seq|field, so only changes are written. Loaded from the database on first sight. */
const lastShown = new Map<string, string | null>();

/** What the trip shows for each ridden stop (expected times, track), written whenever it changes (the audit's input). */
export function recordShown(db: Db, legId: string, ridden: (LiveStop & { seq: number })[], now: number) {
  if (!ridden.length) return;
  if (!lastShown.has(`${legId}|loaded`)) {
    lastShown.set(`${legId}|loaded`, '1');
    const rows = db.select().from(shownValues).where(eq(shownValues.legId, legId)).orderBy(asc(shownValues.shownAt)).all();
    for (const r of rows) lastShown.set(`${legId}|${r.seq}|${r.field}`, r.value);
  }
  const times = expectedTimes(ridden);
  ridden.forEach((s, i) => {
    for (const [field, v] of [
      ['arr', times[i]!.arr],
      ['dep', times[i]!.dep],
      ['platform', s.platform],
    ] as const) {
      const value = v === null ? null : String(v);
      const k = `${legId}|${s.seq}|${field}`;
      if (lastShown.has(k) && lastShown.get(k) === value) continue;
      lastShown.set(k, value);
      db.insert(shownValues).values({ legId, seq: s.seq, field, value, shownAt: new Date(now) }).onConflictDoNothing().run();
    }
  });
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
