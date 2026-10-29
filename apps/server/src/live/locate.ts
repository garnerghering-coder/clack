// Where a train is between two stops, the same for every feed (BUILDOUT §A.2–A.3, A.8): the one place the GPS,
// dead-reckoning, run-profile, approach and standing rules meet. Sweden (livemap/ingest.ts), Norway (norway.ts),
// Finland (finland.ts) and Denmark (denmark.ts) each work out their prev/next stops and times their own way, then
// call locateOnSegment with the routed track between them.
import { cumulative, pointAt } from '@clack/shared';
import type { Segment } from '../geo/trackSegments.js';
import type { CountryCode } from '../lib/countries.js';
import { haversineM } from '../lib/geo.js';
import type { Placement } from './placement.js';
import { advanceM, blendM, estimateAlong, snapToLine, standingByGps, TIMESTAMP_OFFSET_S, type TrainState } from './positioning.js';
import { DEAD_RECKONING_MS } from './progress.js';
import type { LiveQuality, Source } from './quality.js';

export interface SegStop {
  /** Our station id, or "trv:<signature>" for a Swedish location without one. */
  id: string;
  name: string | null;
  lat: number;
  lon: number;
  /** The platform or track the feed gives here, when it does. */
  track: string | null;
}

export interface SegGps {
  lat: number;
  lon: number;
  at: number;
  bearing: number | null;
  /** The checked speed while fresh (SPEED_FRESH_MS), else null. */
  speedKmh: number | null;
  /** The last checked speed however old, for dead reckoning. */
  lastSpeedKmh: number | null;
  fresh: boolean;
  ageMs: number;
}

export interface Located {
  lat: number;
  lon: number;
  bearing: number | null;
  speedKmh: number | null;
  at: number;
  estimated: boolean;
  state: TrainState;
  prevId: string | null;
  nextId: string | null;
  atStation: string | null;
  platform: string | null;
  progress: number | null;
  fixAt?: number;
}

export interface LocateInput {
  prev: SegStop;
  next: SegStop;
  /** When it left prev and when it is expected at next; null when the feed doesn't say. */
  left: number | null;
  arriving: number | null;
  /** The feed says it has arrived at prev and not left. */
  standingAtPrev: boolean;
  gps: SegGps | null;
  now: number;
  country: CountryCode | null;
  source: Source;
}

export interface LocateEnv {
  seg: Segment & { cum?: number[] };
  placement: Placement;
  quality?: LiveQuality;
}

/** A fix older than this says nothing about where the train is now; the estimate stands alone. */
export const STALE_GPS_MAX_MS = 30 * 60_000;

/**
 * - A fresh fix: standing at a platform when slow next to a station (or the feed says arrived), else snapped onto
 *   the track, pointed along it and carried forward by the delivery lag, never past the next stop. A fix off the
 *   track (> 60 m) is shown where it is.
 * - A stale fix (2–30 min): dead-reckoned along the track at its last speed for 5 min, then blended into the
 *   estimate over 30 s.
 * - No fix: the run profile from `left` to `arriving`, the approach once overdue, then standing at next's platform.
 * Null when there is neither a fresh fix nor the times to estimate from.
 */
export function locateOnSegment(env: LocateEnv, input: LocateInput): Located | null {
  const { prev, next, gps, now, country, source } = input;
  const points = env.seg.points;
  const cum = env.seg.cum ?? cumulative(points);
  const L = cum.at(-1) ?? 0;

  const standingAt = (s: SegStop, prevId: string | null, nextId: string | null, state: TrainState, estimated: boolean): Located => {
    const placed = env.placement.standing(s.id.startsWith('trv:') ? null : s.id, s.lat, s.lon, s.track);
    // With a fix and no mapped platform, the fix beats the station's point.
    const at = gps?.fresh && placed.how !== 'platform' ? gps : placed;
    return { lat: at.lat, lon: at.lon, bearing: null, speedKmh: estimated ? null : 0, at: now, estimated, state, prevId, nextId, atStation: s.name, platform: placed.how === 'platform' ? s.track : null, progress: null, ...(gps?.fresh ? { fixAt: gps.at } : {}) };
  };
  const running = (m: number, speedKmh: number | null, estimated: boolean, at: number, fixAt?: number): Located => {
    const pt = pointAt(points, cum, Math.min(L, Math.max(0, m)));
    const side = env.placement.onSide(country, pt.lat, pt.lon, pt.bearing, gps?.fresh ? gps : null);
    if (side.agree !== null && country) env.quality?.recordSide(country, side.agree);
    return { lat: side.lat, lon: side.lon, bearing: Math.round(pt.bearing), speedKmh, at, estimated, state: 'running', prevId: prev.id, nextId: next.id, atStation: null, platform: null, progress: L > 0 ? Math.min(1, Math.max(0, m / L)) : null, ...(fixAt !== undefined ? { fixAt } : {}) };
  };

  if (prev.id === next.id || input.standingAtPrev) return standingAt(prev, prev.id, next.id, 'standing', !gps?.fresh);
  if (input.left !== null && now < input.left && !gps?.fresh) return standingAt(prev, prev.id, next.id, 'standing', true);

  if (gps?.fresh) {
    const nearPrev = haversineM(gps.lat, gps.lon, prev.lat, prev.lon);
    const nearNext = haversineM(gps.lat, gps.lon, next.lat, next.lon);
    if (standingByGps(gps.speedKmh, Math.min(nearPrev, nearNext))) {
      const atNext = nearNext < nearPrev;
      return standingAt(atNext ? next : prev, prev.id, next.id, atNext || input.left === null || now >= input.left ? 'standing' : 'standing', false);
    }
    const snapped = points.length > 1 ? snapToLine(points, cum, gps) : null;
    if (!snapped) return { lat: gps.lat, lon: gps.lon, bearing: gps.bearing, speedKmh: gps.speedKmh, at: gps.at, estimated: false, state: 'running', prevId: prev.id, nextId: next.id, atStation: null, platform: null, progress: null };
    // Carried forward from the fix's own time by the delivery lag (plus the measured offset, 0 until F4), never past the next stop.
    const m = advanceM(snapped.m, gps.speedKmh, now - gps.at + TIMESTAMP_OFFSET_S[source] * 1000, L);
    return running(m, gps.speedKmh, false, now, gps.at);
  }

  if (input.left === null || input.arriving === null) return null;
  const est = estimateAlong(L, input.left, input.arriving, now);
  if (gps && gps.ageMs <= STALE_GPS_MAX_MS && est.state === 'running' && points.length > 1) {
    const last = snapToLine(points, cum, gps, 200);
    if (last) {
      const dr = advanceM(last.m, gps.lastSpeedKmh, Math.min(gps.ageMs, DEAD_RECKONING_MS), L);
      const m = gps.ageMs <= DEAD_RECKONING_MS ? dr : blendM(dr, est.m, gps.ageMs - DEAD_RECKONING_MS);
      // Never behind where the GPS last put it.
      return running(Math.max(m, last.m), null, true, now);
    }
  }
  if (est.state === 'standing' && est.progress >= 1) return standingAt(next, prev.id, next.id, 'standing', true);
  return running(est.m, est.speedKmh === null ? null : Math.round(est.speedKmh), true, now);
}
