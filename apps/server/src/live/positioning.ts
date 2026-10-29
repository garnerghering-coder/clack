// Where a train is, worked out the same way for every feed (docs/POSITIONING.md; docs/buildout/BUILDOUT.md §A).
// Pure functions only: the run profile, snapping a fix onto the track, dead reckoning and the blend back to the
// estimate, the standing rule, the approach rule after a missed arrival, and the choice between parallel tracks.
// The feeds (livemap/ingest.ts, norway.ts, finland.ts, denmark.ts) call these; nothing here reads the clock or the
// database, so every rule is tested on its own (test/positioning.test.ts).
import type { LatLon } from '@clack/shared';
import type { CountryCode } from '../lib/countries.js';

export type TrainState = 'running' | 'standing' | 'waiting';

const RAD = Math.PI / 180;
const KY = 110_574;
const kxAt = (lat: number) => 111_320 * Math.cos(lat * RAD);

// ---------- Run profile (§A.3) ----------

/**
 * Acceleration and braking used for estimates between stations, m/s². These are the plan's values (BUILDOUT §A.3),
 * in the range of modern electric multiple units in service (brochure figures are higher at low speed, lower near
 * line speed; the average to cruising speed is what matters here). Not yet checked against a Trafikverket or
 * Banverket running-time rule: Phase 3 (F4) compares them with the speeds the GPS feeds report and adjusts them.
 */
export const ACCEL_MPS2 = 0.5;
export const DECEL_MPS2 = 0.6;

export interface RunProfile {
  lengthM: number;
  durationS: number;
  /** Cruising speed, m/s. */
  vMax: number;
  tAcc: number;
  tCruise: number;
  tDec: number;
  accel: number;
  decel: number;
}

/**
 * The trapezoid (accelerate, cruise, brake) that covers `lengthM` in exactly `durationS`. From
 * T = v·k + L/v with k = 1/(2a) + 1/(2d) the cruising speed is the smaller root of k·v² − T·v + L = 0. When the
 * schedule is quicker than the accelerations allow (T² < 4kL, short hops with generous timings never hit this) both
 * are raised together until a triangle just fits, so the train still arrives on time.
 */
export function runProfile(lengthM: number, durationS: number, accel = ACCEL_MPS2, decel = DECEL_MPS2): RunProfile {
  const L = Math.max(0, lengthM);
  const T = Math.max(0, durationS);
  if (L <= 0 || T <= 0) return { lengthM: L, durationS: T, vMax: 0, tAcc: 0, tCruise: T, tDec: 0, accel, decel };
  let a = accel;
  let d = decel;
  let k = 1 / (2 * a) + 1 / (2 * d);
  if (T * T < 4 * k * L) {
    const s = (4 * k * L) / (T * T);
    a *= s;
    d *= s;
    k /= s;
  }
  const v = (T - Math.sqrt(Math.max(0, T * T - 4 * k * L))) / (2 * k);
  const tAcc = v / a;
  const tDec = v / d;
  return { lengthM: L, durationS: T, vMax: v, tAcc, tCruise: Math.max(0, T - tAcc - tDec), tDec, accel: a, decel: d };
}

/** Metres covered `tS` seconds after leaving, 0 … lengthM. */
export function distanceAt(p: RunProfile, tS: number): number {
  if (tS <= 0 || p.lengthM <= 0) return 0;
  if (tS >= p.durationS) return p.lengthM;
  if (tS <= p.tAcc) return 0.5 * p.accel * tS * tS;
  const dAcc = 0.5 * p.accel * p.tAcc * p.tAcc;
  if (tS <= p.tAcc + p.tCruise) return Math.min(p.lengthM, dAcc + p.vMax * (tS - p.tAcc));
  const td = tS - p.tAcc - p.tCruise;
  return Math.min(p.lengthM, dAcc + p.vMax * p.tCruise + p.vMax * td - 0.5 * p.decel * td * td);
}

/** Speed `tS` seconds after leaving, m/s. */
export function speedAt(p: RunProfile, tS: number): number {
  if (tS <= 0 || tS >= p.durationS || p.lengthM <= 0) return 0;
  if (tS <= p.tAcc) return p.accel * tS;
  if (tS <= p.tAcc + p.tCruise) return p.vMax;
  return Math.max(0, p.vMax - p.decel * (tS - p.tAcc - p.tCruise));
}

// ---------- The estimate between two stations, and what comes after a missed arrival (§A.3) ----------

/** A train that should have arrived is drawn this far short of the station until it is reported (or given up on). */
export const APPROACH_M = 50;
/** After this long past the expected arrival with nothing reported, the train is drawn standing at the platform. */
export const APPROACH_GRACE_MS = 90_000;

export interface Estimate {
  /** Metres along the prev → next track. */
  m: number;
  state: TrainState;
  /** From the run profile; null on the approach, where nothing says how fast it creeps. */
  speedKmh: number | null;
  /** 0 … 1 along the segment. */
  progress: number;
}

/**
 * Where a train without GPS is along a segment of `lengthM`, having left at `leftAt` and expected at `arriveAt`:
 * the run profile brings it to the approach (the last 50 m) at the expected arrival; past that with no arrival
 * reported it creeps the last 50 m over the grace period, then stands at the platform. Monotonic in time: no
 * estimate ever freezes short of the station or steps back.
 */
export function estimateAlong(lengthM: number, leftAt: number, arriveAt: number, now: number): Estimate {
  if (now <= leftAt || lengthM <= 0) return { m: 0, state: now <= leftAt ? 'standing' : 'running', speedKmh: 0, progress: 0 };
  const T = (arriveAt - leftAt) / 1000;
  const approach = lengthM > 2 * APPROACH_M ? APPROACH_M : 0;
  if (now < arriveAt && T > 0) {
    const p = runProfile(lengthM - approach, T);
    const t = (now - leftAt) / 1000;
    const m = distanceAt(p, t);
    return { m, state: 'running', speedKmh: speedAt(p, t) * 3.6, progress: m / lengthM };
  }
  const overdue = now - Math.max(arriveAt, leftAt);
  if (overdue < APPROACH_GRACE_MS) {
    const m = lengthM - approach + approach * (overdue / APPROACH_GRACE_MS);
    return { m, state: 'running', speedKmh: null, progress: m / lengthM };
  }
  return { m: lengthM, state: 'standing', speedKmh: 0, progress: 1 };
}

// ---------- Snapping a fix onto the track (§A.3) ----------

/** A fix further than this from the routed track is shown where it is (the route may be wrong, or the train elsewhere). */
export const SNAP_M = 60;

export interface Snapped {
  /** Metres along the line. */
  m: number;
  lat: number;
  lon: number;
  /** The track's direction here, towards the line's end (the next station), degrees. */
  bearing: number;
  /** How far the fix was from the track, metres. */
  offM: number;
}

/** The nearest point on the line within `maxM` of p, with the track's heading there; null when the fix is further off. */
export function snapToLine(line: LatLon[], cum: number[], p: { lat: number; lon: number }, maxM = SNAP_M): Snapped | null {
  if (line.length < 2) return null;
  const kx = kxAt(p.lat);
  let best: Snapped | null = null;
  for (let i = 1; i < line.length; i++) {
    const [aLa, aLo] = line[i - 1]!;
    const [bLa, bLo] = line[i]!;
    const ax = (aLo - p.lon) * kx;
    const ay = (aLa - p.lat) * KY;
    const dx = (bLo - aLo) * kx;
    const dy = (bLa - aLa) * KY;
    const l2 = dx * dx + dy * dy;
    const t = l2 ? Math.max(0, Math.min(1, -(ax * dx + ay * dy) / l2)) : 0;
    const d = Math.hypot(ax + t * dx, ay + t * dy);
    if (d > maxM || (best && d >= best.offM)) continue;
    best = { m: cum[i - 1]! + t * (cum[i]! - cum[i - 1]!), lat: aLa + t * (bLa - aLa), lon: aLo + t * (bLo - aLo), bearing: ((Math.atan2(dx, dy) / RAD) + 360) % 360, offM: d };
  }
  return best;
}

// ---------- Dead reckoning and the blend (§A.3), lag correction (§A.8) ----------

/** When GPS has gone stale, the dead-reckoned position gives way to the estimate over this long instead of jumping. */
export const BLEND_MS = 30_000;

/** Carry a position `dtMs` on at `speedKmh`, never backwards and never past `capM` (a station where the train stops). */
export function advanceM(m: number, speedKmh: number | null, dtMs: number, capM: number): number {
  if (speedKmh === null || speedKmh <= 0 || dtMs <= 0) return Math.min(m, capM);
  return Math.min(capM, m + (speedKmh / 3.6) * (dtMs / 1000));
}

/** Between two positions along the track, `elapsedMs` into a blend of `overMs`. */
export function blendM(fromM: number, toM: number, elapsedMs: number, overMs = BLEND_MS): number {
  const f = overMs > 0 ? Math.min(1, Math.max(0, elapsedMs / overMs)) : 1;
  return fromM + (toM - fromM) * f;
}

/**
 * How far ahead of its own timestamp a fix is drawn, per source: the delivery lag (now − fix time) plus this
 * offset, which is how early or late the fix's timestamp itself is. All 0 until the passage comparison in
 * live/quality.ts has run long enough to say (Phase 3, F4): see docs/POSITIONING.md.
 */
export const TIMESTAMP_OFFSET_S: Record<'trafikverket' | 'entur' | 'digitraffic' | 'rejseplanen', number> = { trafikverket: 0, entur: 0, digitraffic: 0, rejseplanen: 0 };

// ---------- Standing (§A.2) ----------

/** Below this speed and this close to a station, a GPS-tracked train is standing there. */
export const STANDING_KMH = 3;
export const STANDING_NEAR_M = 400;

export const standingByGps = (speedKmh: number | null, nearStationM: number | null): boolean =>
  speedKmh !== null && speedKmh < STANDING_KMH && nearStationM !== null && nearStationM <= STANDING_NEAR_M;

// ---------- Parallel tracks (§A.5) ----------

export type Side = 'left' | 'right';

/**
 * Which track a train runs on where two lie side by side.
 * - Sweden: left. "Sweden, which had LHT till 1967, did not switch the direction of its trains, but the line from
 *   the north of Malmö, which leads to the border with Denmark and further south uses RHT." (Wikipedia, "Left- and
 *   right-hand traffic", rail section, read 2026-10-28.)
 * - Norway and Denmark: right. "Norge og Danmark har høyrekjøring og må bytte side nær grensen til Sverige."
 *   (Norwegian Wikipedia, "Høyre- og venstrekjøring", Jernbane section, read 2026-10-28.) The plan (§A.5) had both
 *   on the left; the sources say otherwise, so the sources win.
 * - Finland: right. "In Finland, several lines of Helsinki commuter rail, like the line to Helsinki Airport uses
 *   LHT, while the metro and the rest of lines uses RHT." (Wikipedia, as above.)
 * Where the sources name an exception without saying exactly where it starts, the choice is turned off there
 * (SIDE_EXCEPTIONS) and the nearest track is used. The quality counters record how often the raw fix agrees with
 * the chosen track per country, so a wrong rule shows up and can be turned off (quality.ts, docs/POSITIONING.md).
 */
export const RUNNING_SIDE: Record<CountryCode, Side> = { SE: 'left', NO: 'right', DK: 'right', FI: 'right' };

export const SIDE_EXCEPTIONS: { country: CountryCode; name: string; box: { minLat: number; maxLat: number; minLon: number; maxLon: number } }[] = [
  { country: 'SE', name: 'Öresund link, Malmö C to the bridge: right-hand running to match Denmark', box: { minLat: 55.5, maxLat: 55.66, minLon: 12.8, maxLon: 13.05 } },
  { country: 'FI', name: 'Helsinki commuter area: some lines run on the left; which ones is not verified', box: { minLat: 60.1, maxLat: 60.45, minLon: 24.45, maxLon: 25.25 } },
];

/** The running side at a place, or null where no rule applies. */
export function runningSide(country: CountryCode | null, lat: number, lon: number): Side | null {
  if (!country) return null;
  for (const x of SIDE_EXCEPTIONS) if (x.country === country && lat >= x.box.minLat && lat <= x.box.maxLat && lon >= x.box.minLon && lon <= x.box.maxLon) return null;
  return RUNNING_SIDE[country];
}

/** Two running tracks this close are a double track; one is chosen by side. */
export const PARALLEL_M = 12;

/**
 * Among track points near a position (nearest first is not required), the one on the running side of the direction
 * of travel: the nearest when there is no parallel track within PARALLEL_M of it, no heading, or no rule.
 * Positive lateral offset is to the right of travel: r·(cos θ, −sin θ) with θ the heading from north.
 */
export function pickTrack<T extends { point: LatLon; d: number }>(cands: T[], headingDeg: number | null, side: Side | null): T | null {
  if (!cands.length) return null;
  const nearest = cands.reduce((a, b) => (b.d < a.d ? b : a));
  if (headingDeg === null || side === null) return nearest;
  const kx = kxAt(nearest.point[0]);
  const near = (c: T) => Math.hypot((c.point[1] - nearest.point[1]) * kx, (c.point[0] - nearest.point[0]) * KY);
  const group = cands.filter((c) => c === nearest || near(c) <= PARALLEL_M);
  if (group.length < 2) return nearest;
  const th = headingDeg * RAD;
  const right = (c: T) => (c.point[1] - nearest.point[1]) * kx * Math.cos(th) - (c.point[0] - nearest.point[0]) * KY * Math.sin(th);
  return group.reduce((a, b) => ((side === 'right' ? right(b) > right(a) : right(b) < right(a)) ? b : a));
}

// ---------- The time a track of fixes passed a point (§A.8, the timestamp offset) ----------

/**
 * When a run of fixes crossed a circle of `radiusM` around `point`: `in` is the first crossing inward (an arrival),
 * `out` the last crossing outward (a departure), interpolated between the two fixes either side of the crossing;
 * null when the run never crosses that way, or the two fixes are more than `maxGapMs` apart. Pure.
 */
export function crossingTime(fixes: { lat: number; lon: number; at: number }[], point: { lat: number; lon: number }, dir: 'in' | 'out', radiusM = 150, maxGapMs = 90_000): number | null {
  if (fixes.length < 2) return null;
  const kx = kxAt(point.lat);
  const dist = (f: { lat: number; lon: number }) => Math.hypot((f.lon - point.lon) * kx, (f.lat - point.lat) * KY);
  const idx = dir === 'in' ? [...Array(fixes.length - 1).keys()].map((i) => i + 1) : [...Array(fixes.length - 1).keys()].map((i) => fixes.length - 1 - i);
  for (const i of idx) {
    const a = fixes[i - 1]!;
    const b = fixes[i]!;
    const da = dist(a);
    const db = dist(b);
    const crosses = dir === 'in' ? da > radiusM && db <= radiusM : da <= radiusM && db > radiusM;
    if (!crosses) continue;
    if (b.at - a.at > maxGapMs) return null;
    const t = (da - radiusM) / (da - db);
    return a.at + t * (b.at - a.at);
  }
  return null;
}

/**
 * When a run of fixes passed closest to `station`, by interpolating between the two fixes that bracket the closest
 * approach; null when the approach isn't bracketed (the nearest point is the first or last fix), the fixes around it
 * are more than `maxGapMs` apart, or the track stays further than `maxOffM` away. Pure.
 */
export function passageTime(fixes: { lat: number; lon: number; at: number }[], station: { lat: number; lon: number }, maxOffM = 150, maxGapMs = 90_000): number | null {
  if (fixes.length < 2) return null;
  const kx = kxAt(station.lat);
  let best: { d: number; i: number; t: number } | null = null;
  for (let i = 1; i < fixes.length; i++) {
    const a = fixes[i - 1]!;
    const b = fixes[i]!;
    const ax = (a.lon - station.lon) * kx;
    const ay = (a.lat - station.lat) * KY;
    const dx = (b.lon - a.lon) * kx;
    const dy = (b.lat - a.lat) * KY;
    const l2 = dx * dx + dy * dy;
    const t = l2 ? Math.max(0, Math.min(1, -(ax * dx + ay * dy) / l2)) : 0;
    const d = Math.hypot(ax + t * dx, ay + t * dy);
    if (!best || d < best.d) best = { d, i, t };
  }
  if (!best || best.d > maxOffM) return null;
  const a = fixes[best.i - 1]!;
  const b = fixes[best.i]!;
  if (b.at - a.at > maxGapMs) return null;
  // Closest at the very start or end of the run: the train may still be approaching, or have passed before the run began.
  if ((best.i === 1 && best.t === 0) || (best.i === fixes.length - 1 && best.t === 1)) return null;
  return a.at + best.t * (b.at - a.at);
}
