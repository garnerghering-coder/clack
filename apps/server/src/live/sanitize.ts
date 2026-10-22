// Between the raw feeds and what anyone sees (docs/RELIABILITY_PLAN.md §2). Trafikverket's and Entur's GPS is good,
// but about 1% of consecutive fixes jump somewhere a train can't get to in the time (checked 2026-10-22), and a
// speed can come with a fix that doesn't match how the train moved. Those are dropped here, never smoothed over:
// what passes is a real report, unchanged.
import { haversineM } from '../lib/geo.js';
import type { GpsFix } from './progress.js';

/** No passenger train in Sweden or Norway runs faster than ~210 km/h (X2000, SJ 3000, Flytoget); GPS noise needs room. */
export const MAX_IMPLIED_KMH = 300;
/** A reported speed above this is a broken reading. */
export const MAX_REPORTED_KMH = 250;
/** Moves shorter than this are GPS noise, whatever speed they imply over a few seconds. */
const NOISE_M = 500;
/** A speed is shown only from a fix this fresh (fixes come every ~30 s). */
export const SPEED_FRESH_MS = 60_000;
/** Where our trains run: Sweden, Norway, Denmark and the night trains' way south. */
const AREA = { minLat: 53, maxLat: 72, minLon: 4, maxLon: 32 };

export const inArea = (f: { lat: number; lon: number }) =>
  Number.isFinite(f.lat) && Number.isFinite(f.lon) && f.lat >= AREA.minLat && f.lat <= AREA.maxLat && f.lon >= AREA.minLon && f.lon <= AREA.maxLon;

/** Could a train have gone from a to b in the time between them? */
export function plausibleMove(a: GpsFix, b: GpsFix): boolean {
  const m = haversineM(a.lat, a.lon, b.lat, b.lon);
  if (m <= NOISE_M) return true;
  const s = Math.abs(b.at - a.at) / 1000;
  return s > 0 && (m / s) * 3.6 <= MAX_IMPLIED_KMH;
}

/** How far a fix can be off (fixes for SJ 441 on 2026-10-22, 8–15 s apart, implied 65–276 km/h at a steady 150). */
const FIX_ERROR_M = 250;

/**
 * The reported speed if it fits how the train moved since the previous fix; 0 when two fixes 15–120 s apart put it
 * in the same place and it reports nothing (Trafikverket leaves the speed out when slow); otherwise null.
 * The straight line between fixes cuts curves, averages over the gap and carries both fixes' error, hence the
 * margin (median difference 4 km/h, p90 24, on 653 pairs ~30 s apart).
 */
export function checkedSpeed(prev: GpsFix | null, f: GpsFix): number | null {
  const reported = f.speedKmh !== null && f.speedKmh >= 0 && f.speedKmh <= MAX_REPORTED_KMH ? f.speedKmh : null;
  const s = prev ? (f.at - prev.at) / 1000 : 0;
  if (!prev || s < 15 || s > 120) return reported;
  const moved = haversineM(prev.lat, prev.lon, f.lat, f.lon);
  if (reported === null) return moved < 30 ? 0 : null;
  const derived = (moved / s) * 3.6;
  const noise = ((2 * FIX_ERROR_M) / s) * 3.6;
  return Math.abs(reported - derived) <= Math.max(40, 0.4 * Math.max(reported, derived), noise) ? reported : null;
}

export interface FilterStats {
  accepted: number;
  rejected: number;
}

/**
 * GPS fixes per train, oldest first. A fix the train couldn't have reached from the last accepted one is dropped;
 * if the next fix agrees with the dropped one rather than the accepted one, the accepted one was the odd one out
 * (or the train really moved while the feed was quiet), so the train follows the new pair.
 */
export class FixFilter {
  private state = new Map<string, { last: GpsFix; doubt: GpsFix | null }>();
  readonly stats: FilterStats = { accepted: 0, rejected: 0 };

  /** Offer a fix; true if it's now the train's current one. Fixes no newer than the current one are ignored. */
  push(key: string, raw: GpsFix): boolean {
    if (!inArea(raw)) return this.reject();
    const st = this.state.get(key);
    if (st && raw.at <= st.last.at) return false;
    if (!st || plausibleMove(st.last, raw) || (st.doubt && raw.at > st.doubt.at && plausibleMove(st.doubt, raw))) {
      const prev = st && plausibleMove(st.last, raw) ? st.last : null;
      let f: GpsFix = { ...raw, speedKmh: checkedSpeed(prev, raw), speedAt: raw.at };
      // A fix that simply came without a speed (they do, between ones that have it) keeps the last reading, with
      // that reading's own time, so it still goes out of date on time. A speed that failed the check is not kept.
      if (raw.speedKmh === null && f.speedKmh === null && prev?.speedKmh != null && prev.speedAt != null && raw.at - prev.speedAt <= SPEED_FRESH_MS)
        f = { ...f, speedKmh: prev.speedKmh, speedAt: prev.speedAt };
      this.state.set(key, { last: f, doubt: null });
      this.stats.accepted++;
      return true;
    }
    st.doubt = raw;
    return this.reject();
  }

  current(key: string): GpsFix | null {
    return this.state.get(key)?.last ?? null;
  }

  forget(key: string) {
    this.state.delete(key);
  }

  /** Drop trains not heard from since `before`. */
  prune(before: number) {
    for (const [k, v] of this.state) if (v.last.at < before) this.state.delete(k);
  }

  get size() {
    return this.state.size;
  }

  private reject() {
    this.stats.rejected++;
    return false;
  }
}

/** A speed worth showing: from a fresh fix that passed the checks. */
export const shownSpeed = (f: GpsFix | null, now: number): number | null => (f && now - (f.speedAt ?? f.at) <= SPEED_FRESH_MS ? f.speedKmh : null);
