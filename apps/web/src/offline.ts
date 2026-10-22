// Working without a connection (docs/RELIABILITY_PLAN.md §4): trains go through tunnels and dead zones. Your trips,
// their stops and track are kept on the phone as they load, so the trip page still opens and the train keeps moving
// on its own (from its last report, clearly marked as an estimate) until the connection comes back.
import { useEffect, useState } from 'react';
import { liveView, type GpsFix, type LiveStop } from '@clack/shared';
import { decodePolyline, type LatLon } from '@clack/shared';
import { ms, type LegDetail, type LiveState } from './api';

const PREFIX = 'clack.offline:';
const INDEX = 'clack.offline.index';
const MAX_ENTRIES = 60;

/** What's worth keeping: your trips and what the trip page needs to draw them. Live data never is. */
const KEEP = [/^\/legs$/, /^\/legs\/[^/]+$/, /^\/journeys\/[^/]+$/, /^\/operators$/, /^\/train-types$/, /^\/settings$/, /^\/amenities$/, /^\/stations\/[^/?]+$/, /^\/stations\/[^/]+\/map$/];

export const keepOffline = (path: string) => KEEP.some((r) => r.test(path));

export function remember(path: string, body: unknown) {
  try {
    localStorage.setItem(PREFIX + path, JSON.stringify(body));
    const index = (JSON.parse(localStorage.getItem(INDEX) ?? '[]') as string[]).filter((p) => p !== path);
    index.push(path);
    // Oldest out first; if the phone is out of space, drop more.
    while (index.length > MAX_ENTRIES) localStorage.removeItem(PREFIX + index.shift()!);
    localStorage.setItem(INDEX, JSON.stringify(index));
  } catch {
    // Private mode or full: nothing kept, nothing else lost.
  }
}

export function recall<T>(path: string): T | undefined {
  try {
    const v = localStorage.getItem(PREFIX + path);
    return v === null ? undefined : (JSON.parse(v) as T);
  } catch {
    return undefined;
  }
}

// ---------- Connection state ----------

let offline = typeof navigator !== 'undefined' && navigator.onLine === false;
const listeners = new Set<(v: boolean) => void>();

export function setOffline(v: boolean) {
  if (v === offline) return;
  offline = v;
  for (const l of listeners) l(v);
}

if (typeof window !== 'undefined') {
  window.addEventListener('offline', () => setOffline(true));
  window.addEventListener('online', () => setOffline(false));
}

/** True while the app can't reach the server. */
export function useOffline() {
  const [v, setV] = useState(offline);
  useEffect(() => {
    listeners.add(setV);
    setV(offline);
    return () => void listeners.delete(setV);
  }, []);
  return v;
}

// ---------- The train, on its own ----------

/** The server sends a live update every 20 s; after this long without one, the phone works it out itself. */
export const LOCAL_AFTER_MS = 60_000;

/**
 * Where the train is now from what the phone already has: the trip's stops and times, its track, and the last live
 * report (its GPS fix and speed). The same rules as the server: on from the last fix at its last speed for a few
 * minutes, never past the next stop, then by the timetable and the last known delays.
 */
export function localLive(leg: LegDetail, live: LiveState, now: number): LiveState {
  const ridden = leg.stops.filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
  const stops: LiveStop[] = ridden.map((s) => ({
    stationId: s.stationId,
    name: s.name,
    lat: s.lat,
    lon: s.lon,
    schedArr: ms(s.schedArr),
    schedDep: ms(s.schedDep),
    actualArr: ms(s.actualArr),
    actualDep: ms(s.actualDep),
    estimatedArr: ms(s.estimatedArr),
    estimatedDep: ms(s.estimatedDep),
    platform: s.platform,
    canceled: s.canceled,
  }));
  if (!stops.length) return live;
  const line: LatLon[] = leg.geometry ? decodePolyline(leg.geometry) : stops.map((s) => [s.lat, s.lon]);
  const at = ms(live.positionAt);
  const gps: GpsFix | null =
    live.positionSource === 'gps' && live.lat !== null && live.lon !== null && at !== null ? { lat: live.lat, lon: live.lon, at, bearing: live.bearing, speedKmh: live.speedKmh } : null;
  const v = liveView(stops, line, gps, now);
  return { ...live, ...v, updatedAt: live.updatedAt, reportedAt: live.reportedAt, localEstimate: true };
}
