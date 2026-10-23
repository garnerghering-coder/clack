// Where a tracked train is (DESIGN §9). Pure functions shared by the server's live tracker and the app, which uses
// them to keep the train moving on its own when the connection drops (docs/RELIABILITY_PLAN.md §4).
import { delayMinutes } from './delay';
import type { LatLon } from './polyline';

function haversineM(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const rad = Math.PI / 180;
  const a = Math.sin(((lat2 - lat1) * rad) / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(((lon2 - lon1) * rad) / 2) ** 2;
  return 2 * 6371008.8 * Math.asin(Math.sqrt(a));
}

/** A speed is shown only from a fix this fresh (fixes come every ~30 s). */
export const SPEED_FRESH_MS = 60_000;

/** A speed worth showing: from a fresh fix that passed the server's checks. */
export const shownSpeed = (f: GpsFix | null, now: number): number | null => (f && now - (f.speedAt ?? f.at) <= SPEED_FRESH_MS ? f.speedKmh : null);

/** `approaching`: the train is on its way to where you board and hasn't reached it yet (owner, 2026-10-23). */
export type LiveStatus = 'scheduled' | 'approaching' | 'boarding' | 'en_route' | 'at_stop' | 'arrived' | 'cancelled';

export interface LiveStop {
  stationId: string;
  name: string;
  lat: number;
  lon: number;
  schedArr: number | null;
  schedDep: number | null;
  actualArr: number | null;
  actualDep: number | null;
  estimatedArr: number | null;
  estimatedDep: number | null;
  platform: string | null;
  canceled: boolean;
}

export interface GpsFix {
  lat: number;
  lon: number;
  at: number;
  bearing: number | null;
  speedKmh: number | null;
  /** When the speed was read, if earlier than the fix (a fix that came without one keeps the last reading). */
  speedAt?: number;
}

export interface LiveView {
  status: LiveStatus;
  prevStopId: string | null;
  nextStopId: string | null;
  /** Expected time at the next stop. */
  eta: number | null;
  arrivalEta: number | null;
  arrivalDelayMin: number | null;
  progress: number | null;
  lat: number | null;
  lon: number | null;
  bearing: number | null;
  speedKmh: number | null;
  positionSource: 'gps' | 'estimated' | null;
  positionAt: number | null;
}

/** Boarding starts this long before departure (DESIGN §9.3). */
export const BOARDING_MS = 30 * 60_000;
/**
 * A train this far from your boarding stop, and no further along your ride than its start, hasn't reached you: it
 * isn't boarding yet, and a late estimate passing doesn't make it "departed".
 */
export const APPROACH_M = 2000;
/** Boarding starts a little before the train's expected arrival at your stop. */
export const REACHED_SLACK_MS = 2 * 60_000;
/** A GPS fix older than this isn't shown as live (Phase 0 §8). */
export const GPS_FRESH_MS = 2 * 60_000;
/**
 * After the GPS goes quiet (a tunnel, a gap in the feed), the train is carried on from its last fix at its last
 * speed for this long, never past the next stop; after that the timetable estimate takes over again.
 */
export const DEAD_RECKONING_MS = 5 * 60_000;

/**
 * Best-known times at each ridden stop: actual, else Trafikverket's estimate, else the timetable shifted by the
 * latest known delay (a train 5 min late at Hallsberg is probably 5 min late at Örebro too).
 */
export function expectedTimes(stops: LiveStop[]): { arr: number | null; dep: number | null }[] {
  let delay = 0;
  return stops.map((s) => {
    const arr = s.actualArr ?? s.estimatedArr ?? (s.schedArr === null ? null : s.schedArr + delay);
    if (s.schedArr !== null && (s.actualArr ?? s.estimatedArr) !== null) delay = Math.max(0, (s.actualArr ?? s.estimatedArr)! - s.schedArr);
    let dep = s.actualDep ?? s.estimatedDep ?? (s.schedDep === null ? null : s.schedDep + delay);
    // A train can't leave before it arrives.
    if (dep !== null && arr !== null && dep < arr) dep = arr;
    if (s.schedDep !== null && (s.actualDep ?? s.estimatedDep) !== null) delay = Math.max(0, (s.actualDep ?? s.estimatedDep)! - s.schedDep);
    return { arr, dep };
  });
}

/** Cumulative distance along the line at each point, metres. */
export function cumulative(line: LatLon[]): number[] {
  const out = [0];
  for (let i = 1; i < line.length; i++) out.push(out[i - 1]! + haversineM(line[i - 1]![0], line[i - 1]![1], line[i]![0], line[i]![1]));
  return out;
}

/** Distance along the line of the closest point to p, searching from `fromM` onwards (stops come in order). */
export function locate(line: LatLon[], cum: number[], p: { lat: number; lon: number }, fromM = 0): number {
  let best = Infinity;
  let at = fromM;
  const kx = Math.cos((p.lat * Math.PI) / 180);
  for (let i = 1; i < line.length; i++) {
    if (cum[i]! < fromM) continue;
    const [aLa, aLo] = line[i - 1]!;
    const [bLa, bLo] = line[i]!;
    const ax = (aLo - p.lon) * kx;
    const ay = aLa - p.lat;
    const dx = (bLo - aLo) * kx;
    const dy = bLa - aLa;
    const l2 = dx * dx + dy * dy;
    const t = l2 ? Math.max(0, Math.min(1, -(ax * dx + ay * dy) / l2)) : 0;
    const d = Math.hypot(ax + t * dx, ay + t * dy);
    if (d < best) {
      best = d;
      at = cum[i - 1]! + t * (cum[i]! - cum[i - 1]!);
    }
  }
  return Math.max(at, fromM);
}

/** Point and bearing at a distance along the line. */
export function pointAt(line: LatLon[], cum: number[], m: number): { lat: number; lon: number; bearing: number } {
  let i = 1;
  while (i < line.length - 1 && cum[i]! < m) i++;
  const a = line[i - 1]!;
  const b = line[i] ?? a;
  const span = cum[i]! - cum[i - 1]!;
  const t = span > 0 ? Math.min(1, Math.max(0, (m - cum[i - 1]!) / span)) : 0;
  const lat = a[0] + t * (b[0] - a[0]);
  const lon = a[1] + t * (b[1] - a[1]);
  const y = Math.sin(((b[1] - a[1]) * Math.PI) / 180) * Math.cos((b[0] * Math.PI) / 180);
  const x =
    Math.cos((a[0] * Math.PI) / 180) * Math.sin((b[0] * Math.PI) / 180) -
    Math.sin((a[0] * Math.PI) / 180) * Math.cos((b[0] * Math.PI) / 180) * Math.cos(((b[1] - a[1]) * Math.PI) / 180);
  return { lat, lon, bearing: ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360 };
}

/**
 * The live view of a leg from its ridden stops (board … alight), the route line and an optional GPS fix.
 * Without fresh GPS the position is estimated: constant speed between the last stop left and the next one.
 */
export function liveView(stops: LiveStop[], line: LatLon[], gps: GpsFix | null, now: number): LiveView {
  const times = expectedTimes(stops);
  const board = stops[0]!;
  const alight = stops.at(-1)!;
  const depAt = times[0]!.dep ?? times[0]!.arr ?? 0;
  const arrAt = times.at(-1)!.arr ?? times.at(-1)!.dep ?? 0;
  const arrivalDelayMin = delayMinutes(
    alight.schedArr ?? alight.schedDep,
    alight.actualArr ?? alight.estimatedArr ?? (alight.schedArr === null ? null : times.at(-1)!.arr),
  );
  const base: LiveView = {
    status: 'scheduled',
    prevStopId: null,
    nextStopId: board.stationId,
    eta: depAt || null,
    arrivalEta: arrAt || null,
    arrivalDelayMin,
    progress: 0,
    lat: null,
    lon: null,
    bearing: null,
    speedKmh: null,
    positionSource: null,
    positionAt: null,
  };
  if (board.canceled || alight.canceled) return { ...base, status: 'cancelled', progress: null };

  // Where the train is relative to the stop you board at. A train that started earlier is on its way to you until it
  // gets there: not boarding (however close the departure time), and not departed just because a late estimate passed.
  const cum = cumulative(line);
  const total = cum.at(-1) ?? 0;
  const gpsFresh = gps !== null && now - gps.at <= GPS_FRESH_MS;
  const upstream =
    gpsFresh && line.length > 1 && haversineM(gps!.lat, gps!.lon, board.lat, board.lon) > APPROACH_M && locate(line, cum, gps!) < 500;
  const arrBoard = times[0]!.arr;
  const reached = board.actualArr !== null || arrBoard === null || now >= arrBoard - REACHED_SLACK_MS;

  const departed = board.actualDep !== null || (now >= depAt && !upstream);
  const arrived = alight.actualArr !== null || (now >= arrAt && arrAt > 0);
  if (arrived)
    return {
      ...base,
      status: 'arrived',
      prevStopId: alight.stationId,
      nextStopId: null,
      eta: null,
      progress: 1,
      lat: alight.lat,
      lon: alight.lon,
      positionSource: null,
    };
  if (!departed) {
    const inWindow = now >= depAt - BOARDING_MS;
    const approaching = upstream || (inWindow && !reached);
    const out: LiveView = { ...base, status: approaching ? 'approaching' : inWindow ? 'boarding' : 'scheduled', eta: approaching ? (arrBoard ?? depAt) : base.eta };
    // On its way to you, and seen: show where it is.
    if (upstream)
      return { ...out, lat: gps!.lat, lon: gps!.lon, bearing: gps!.bearing, speedKmh: shownSpeed(gps!, now), positionSource: 'gps', positionAt: gps!.at };
    return out;
  }

  // Last stop the train has reached and the next one ahead.
  let prev = 0;
  for (let i = 0; i < stops.length; i++) {
    const t = times[i]!;
    const reached = stops[i]!.actualArr !== null || stops[i]!.actualDep !== null || (t.arr ?? t.dep ?? Infinity) <= now;
    if (reached) prev = i;
  }
  const next = Math.min(prev + 1, stops.length - 1);
  const prevT = times[prev]!;
  const leftPrev = stops[prev]!.actualDep !== null || (prevT.dep ?? prevT.arr ?? 0) <= now;
  const status: LiveStatus = leftPrev ? 'en_route' : 'at_stop';

  const stopM: number[] = [];
  for (const s of stops) stopM.push(line.length > 1 ? locate(line, cum, s, stopM.at(-1) ?? 0) : 0);

  let m: number;
  if (!leftPrev) m = stopM[prev]!;
  else {
    const from = prevT.dep ?? prevT.arr ?? now;
    const to = times[next]!.arr ?? times[next]!.dep ?? from;
    const f = to > from ? Math.min(1, Math.max(0, (now - from) / (to - from))) : 1;
    m = stopM[prev]! + f * (stopM[next]! - stopM[prev]!);
  }
  const out: LiveView = {
    ...base,
    status,
    prevStopId: stops[prev]!.stationId,
    nextStopId: status === 'at_stop' ? (stops[prev + 1]?.stationId ?? null) : stops[next]!.stationId,
    eta: status === 'at_stop' ? (times[prev + 1]?.arr ?? null) : (times[next]!.arr ?? times[next]!.dep),
  };
  const fresh = gps && now - gps.at <= GPS_FRESH_MS;
  if (fresh && line.length > 1) {
    const gm = locate(line, cum, gps);
    return {
      ...out,
      progress: total ? gm / total : null,
      lat: gps.lat,
      lon: gps.lon,
      bearing: gps.bearing,
      speedKmh: shownSpeed(gps, now),
      positionSource: 'gps',
      positionAt: gps.at,
    };
  }
  if (fresh)
    return { ...out, lat: gps.lat, lon: gps.lon, bearing: gps.bearing, speedKmh: shownSpeed(gps, now), positionSource: 'gps', positionAt: gps.at, progress: null };
  if (line.length < 2) return { ...out, progress: null };
  if (gps && status === 'en_route' && now - gps.at <= 30 * 60_000) {
    // Where the GPS last put it: an estimate never moves the train back behind that.
    const last = locate(line, cum, gps);
    const cap = stopM[next]!;
    const recent = now - gps.at <= DEAD_RECKONING_MS && gps.speedKmh !== null && gps.speedKmh > 0;
    m = Math.min(cap, Math.max(recent ? last + (gps.speedKmh! / 3.6) * ((now - gps.at) / 1000) : m, last));
  }
  const p = pointAt(line, cum, m);
  return { ...out, progress: total ? m / total : null, lat: p.lat, lon: p.lon, bearing: p.bearing, positionSource: 'estimated' };
}

