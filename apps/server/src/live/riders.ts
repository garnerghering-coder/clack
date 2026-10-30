// Riders' phones placing the train they are on (owner, 2026-10-30; docs/POSITIONING.md "Riders' reports").
// A phone with "Help place trains for everyone" on sends, every 15–30 s while the app is open or the trip's Live
// Activity runs, only: the live train's id, the stretch it is on (prevId → nextId, as the live trains name them), how
// far along our track for that stretch (0–1, snapped on the phone), its speed and the time. No coordinates, no user
// id (the request goes without X-Clack-User), and a session id that is random per trip. Nothing is written to disk:
// reports live here for REPORT_TTL_MS and are then gone.
//
// A report only ever replaces an *estimated* position (an operator's GPS stays first), and only when it is fresh and
// believable: two or more phones within AGREE_M of each other, or one phone on the stretch the feed itself has the
// train on (or the next one, when the feed is behind).
import { cumulative, pointAt, type LatLon } from '@clack/shared';
import type { LiveTrain } from '../livemap/ingest.js';

export interface RiderReport {
  train: string;
  prevId: string;
  nextId: string;
  /** 0 … 1 along our track from prevId to nextId. */
  progress: number;
  speedKmh: number | null;
  /** When the phone's fix was taken, ms. */
  at: number;
  /** Random per trip on the phone; tells phones apart, says nothing about who. */
  session: string;
}

export interface Stretch {
  points: LatLon[];
  cum: number[];
  lengthM: number;
}

/** How long a report counts. */
export const FRESH_MS = 90_000;
/** How long a report is kept at all (in memory). */
export const REPORT_TTL_MS = 3 * 60_000;
/** Two phones agree when, carried forward to the same moment, they are this close along the track. */
export const AGREE_M = 400;
/** No train in these countries runs faster (the fastest, X2000 and Pendolino, 200–220 km/h); a margin for GPS. */
export const MAX_SPEED_KMH = 260;
/** One report per phone per train this often at most; extra ones are dropped. */
export const MIN_INTERVAL_MS = 10_000;
/** Below this the train is taken as standing, which the feeds place better (at the platform). */
export const MOVING_KMH = 5;

const ID = /^[\w:.|@-]{1,96}$/;
const SESSION = /^[A-Za-z0-9-]{8,64}$/;

type Kept = RiderReport & { receivedAt: number };

export type Refusal = 'bad input' | 'stale' | 'unknown train' | 'unknown stretch' | 'too fast' | 'too often';

/** Checks one report's shape. Pure. */
export function validReport(r: unknown, now: number): r is RiderReport {
  if (!r || typeof r !== 'object') return false;
  const x = r as Record<string, unknown>;
  return (
    typeof x.train === 'string' && ID.test(x.train) &&
    typeof x.prevId === 'string' && ID.test(x.prevId) &&
    typeof x.nextId === 'string' && ID.test(x.nextId) && x.prevId !== x.nextId &&
    typeof x.progress === 'number' && Number.isFinite(x.progress) && x.progress >= 0 && x.progress <= 1 &&
    (x.speedKmh === null || (typeof x.speedKmh === 'number' && Number.isFinite(x.speedKmh) && x.speedKmh >= 0)) &&
    typeof x.at === 'number' && Number.isFinite(x.at) && x.at <= now + 10_000 &&
    typeof x.session === 'string' && SESSION.test(x.session)
  );
}

export class RiderFixes {
  private byTrain = new Map<string, Kept[]>();
  /** The track for a stretch, as the live map places trains on it; null when unknown. Set by the routes. */
  stretchOf: (prevId: string, nextId: string) => Stretch | null = () => null;
  /** Counters for the quality report: accepted, refused by reason, used. */
  readonly counts: Record<string, number> = {};

  private count(k: string) {
    this.counts[k] = (this.counts[k] ?? 0) + 1;
  }

  /** Takes a report, or says why not. The train must be on the map now. */
  add(r: unknown, train: LiveTrain | undefined, now: number): Refusal | null {
    const why = this.check(r, train, now);
    this.count(why ?? 'accepted');
    if (why) return why;
    const rep = r as RiderReport;
    const list = (this.byTrain.get(rep.train) ?? []).filter((k) => now - k.receivedAt <= REPORT_TTL_MS && k.session !== rep.session);
    list.push({ ...rep, receivedAt: now });
    // At most 50 phones per train.
    this.byTrain.set(rep.train, list.slice(-50));
    return null;
  }

  private check(r: unknown, train: LiveTrain | undefined, now: number): Refusal | null {
    if (!validReport(r, now)) return 'bad input';
    if (now - r.at > FRESH_MS) return 'stale';
    if (!train) return 'unknown train';
    if (r.speedKmh !== null && r.speedKmh > MAX_SPEED_KMH) return 'too fast';
    if (!this.stretchOf(r.prevId, r.nextId)) return 'unknown stretch';
    const last = this.byTrain.get(r.train)?.find((k) => k.session === r.session);
    if (last && now - last.receivedAt < MIN_INTERVAL_MS) return 'too often';
    return null;
  }

  /** Drops what is too old to count. */
  prune(now: number) {
    for (const [k, list] of this.byTrain) {
      const kept = list.filter((x) => now - x.receivedAt <= REPORT_TTL_MS);
      if (kept.length) this.byTrain.set(k, kept);
      else this.byTrain.delete(k);
    }
  }

  /** The trains that have reports now. */
  trains(): string[] {
    return [...this.byTrain.keys()];
  }

  /**
   * The train as the riders place it, or the train unchanged: only an estimated, moving train with a believable
   * report (see the file's head). Carried forward from the reports' time at their speed, never past the next stop.
   */
  adjust(t: LiveTrain, now: number): LiveTrain {
    // Estimated, or already placed by riders (a newer report moves it on); never an operator's GPS.
    if (!t.estimated && !t.riders) return t;
    const fresh = (this.byTrain.get(t.id) ?? []).filter((r) => now - r.at <= FRESH_MS && r.speedKmh !== null && r.speedKmh >= MOVING_KMH);
    if (!fresh.length) return t;
    const fix = pickFix(t, fresh, now, (a, b) => this.stretchOf(a, b));
    if (!fix) return t;
    this.count('used');
    const p = pointAt(fix.stretch.points, fix.stretch.cum, fix.m);
    return {
      ...t,
      lat: p.lat,
      lon: p.lon,
      bearing: Math.round(p.bearing),
      speedKmh: Math.round(fix.speedKmh),
      at: now,
      estimated: false,
      riders: fix.phones,
      state: 'running',
      prevId: fix.prevId,
      nextId: fix.nextId,
      atStation: null,
      platform: null,
      progress: fix.stretch.lengthM > 0 ? fix.m / fix.stretch.lengthM : null,
      fixAt: fix.at,
    };
  }
}

/** Where the believable reports put the train now, metres along their stretch. Pure given the stretches. */
export function pickFix(t: Pick<LiveTrain, 'prevId' | 'nextId'>, reports: RiderReport[], now: number, stretchOf: (a: string, b: string) => Stretch | null) {
  const bySeg = new Map<string, RiderReport[]>();
  for (const r of reports) {
    const k = `${r.prevId}>${r.nextId}`;
    bySeg.set(k, [...(bySeg.get(k) ?? []), r]);
  }
  let best: { prevId: string; nextId: string; stretch: Stretch; m: number; speedKmh: number; at: number; phones: number } | null = null;
  for (const group of bySeg.values()) {
    const { prevId, nextId } = group[0]!;
    const stretch = stretchOf(prevId, nextId);
    if (!stretch) continue;
    const L = stretch.lengthM;
    const now_m = group.map((r) => ({ r, m: Math.min(L, r.progress * L + ((r.speedKmh ?? 0) / 3.6) * Math.max(0, now - r.at) / 1000) })).sort((a, b) => a.m - b.m);
    // The largest set of phones within AGREE_M of each other (a window over the sorted places).
    let lo = 0, top = { from: 0, to: 0 };
    for (let hi = 0; hi < now_m.length; hi++) {
      while (now_m[hi]!.m - now_m[lo]!.m > AGREE_M) lo++;
      if (hi - lo > top.to - top.from) top = { from: lo, to: hi };
    }
    const agreeing = now_m.slice(top.from, top.to + 1);
    const onFeedStretch = (prevId === t.prevId && nextId === t.nextId) || prevId === t.nextId;
    if (agreeing.length < 2 && !onFeedStretch) continue;
    const mid = agreeing[Math.floor(agreeing.length / 2)]!;
    const candidate = { prevId, nextId, stretch, m: mid.m, speedKmh: mid.r.speedKmh ?? 0, at: Math.max(...agreeing.map((a) => a.r.at)), phones: agreeing.length };
    if (!best || candidate.phones > best.phones) best = candidate;
  }
  return best;
}

/** A stretch from a polyline. Pure. */
export function stretchFrom(points: LatLon[]): Stretch {
  const cum = cumulative(points);
  return { points, cum, lengthM: cum.at(-1) ?? 0 };
}
