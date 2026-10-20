// Where a tracked train is and what changed (DESIGN §9). Pure functions, so they're easy to test.
import { delayMinutes, type LatLon } from '@clack/shared';
import { haversineM } from '../lib/geo.js';

export type LiveStatus = 'scheduled' | 'boarding' | 'en_route' | 'at_stop' | 'arrived' | 'cancelled';

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
/** A GPS fix older than this isn't shown as live (Phase 0 §8). */
export const GPS_FRESH_MS = 2 * 60_000;

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
  const x = Math.cos((a[0] * Math.PI) / 180) * Math.sin((b[0] * Math.PI) / 180) - Math.sin((a[0] * Math.PI) / 180) * Math.cos((b[0] * Math.PI) / 180) * Math.cos(((b[1] - a[1]) * Math.PI) / 180);
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
  const arrivalDelayMin = delayMinutes(alight.schedArr ?? alight.schedDep, alight.actualArr ?? alight.estimatedArr ?? (alight.schedArr === null ? null : times.at(-1)!.arr));
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

  const departed = board.actualDep !== null || now >= depAt;
  const arrived = alight.actualArr !== null || (now >= arrAt && arrAt > 0);
  if (arrived) return { ...base, status: 'arrived', prevStopId: alight.stationId, nextStopId: null, eta: null, progress: 1, lat: alight.lat, lon: alight.lon, positionSource: null };
  if (!departed) return { ...base, status: now >= depAt - BOARDING_MS ? 'boarding' : 'scheduled' };

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

  const cum = cumulative(line);
  const total = cum.at(-1) ?? 0;
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
    return { ...out, progress: total ? gm / total : null, lat: gps.lat, lon: gps.lon, bearing: gps.bearing, speedKmh: gps.speedKmh, positionSource: 'gps', positionAt: gps.at };
  }
  if (fresh) return { ...out, lat: gps.lat, lon: gps.lon, bearing: gps.bearing, speedKmh: gps.speedKmh, positionSource: 'gps', positionAt: gps.at, progress: null };
  if (line.length < 2) return { ...out, progress: null };
  const p = pointAt(line, cum, m);
  return { ...out, progress: total ? m / total : null, lat: p.lat, lon: p.lon, bearing: p.bearing, positionSource: 'estimated' };
}

export interface LegSummary {
  arrivalDelayMin: number | null;
  depPlatform: string | null;
  arrPlatform: string | null;
  canceled: boolean;
  /** Stations on the ridden part that are cancelled (a short-turn when the train still runs part of the way). */
  canceledStops: string[];
  departedAt: number | null;
  arrivedAt: number | null;
}

export interface LegEvent {
  type: 'delayed' | 'platform_changed' | 'cancelled' | 'short_turned' | 'departed' | 'arrived';
  payload: Record<string, unknown>;
}

/** Events between two snapshots of a leg (DESIGN §9.3). Small delay wobbles (< 3 min) aren't worth an event. */
export function diffEvents(before: LegSummary, after: LegSummary): LegEvent[] {
  const out: LegEvent[] = [];
  if (!before.canceled && after.canceled) out.push({ type: 'cancelled', payload: {} });
  const newCanceled = after.canceledStops.filter((s) => !before.canceledStops.includes(s));
  if (!after.canceled && newCanceled.length) out.push({ type: 'short_turned', payload: { stationIds: newCanceled } });
  if (before.departedAt === null && after.departedAt !== null) out.push({ type: 'departed', payload: { at: after.departedAt } });
  if (before.arrivedAt === null && after.arrivedAt !== null) out.push({ type: 'arrived', payload: { at: after.arrivedAt, delayMin: after.arrivalDelayMin } });
  const d0 = before.arrivalDelayMin ?? 0;
  const d1 = after.arrivalDelayMin ?? 0;
  if (after.arrivedAt === null && after.arrivalDelayMin !== null && Math.abs(d1 - d0) >= 3) out.push({ type: 'delayed', payload: { delayMin: d1, previousDelayMin: before.arrivalDelayMin } });
  for (const [key, which] of [
    ['depPlatform', 'departure'],
    ['arrPlatform', 'arrival'],
  ] as const)
    if (before[key] && after[key] && before[key] !== after[key]) out.push({ type: 'platform_changed', payload: { which, from: before[key], to: after[key] } });
  return out;
}
