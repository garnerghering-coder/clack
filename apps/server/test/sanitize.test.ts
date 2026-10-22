import { beforeEach, describe, expect, it } from 'vitest';
import type { LatLon } from '@clack/shared';
import { checkedSpeed, FixFilter, plausibleMove, shownSpeed } from '../src/live/sanitize.js';
import { resetHeldEstimates, sanitizeStop } from '../src/legs/actuals.js';
import { liveView, type LiveStop } from '../src/live/progress.js';
import { feedFailed, feedHealth, feedOk, resetFeedHealth } from '../src/lib/health.js';

const T0 = Date.parse('2026-10-22T12:00:00Z');
// ~1.11 km per 0.01° of latitude.
const fix = (lat: number, s: number, speedKmh: number | null = null) => ({ lat, lon: 15, at: T0 + s * 1000, bearing: null, speedKmh });

describe('GPS jumps', () => {
  it('accepts moves a train can make and drops ones it cannot', () => {
    expect(plausibleMove(fix(59, 0), fix(59.01, 30))).toBe(true); // 1.1 km in 30 s: 133 km/h
    expect(plausibleMove(fix(59, 0), fix(59.1, 30))).toBe(false); // 11 km in 30 s: 1,330 km/h
    expect(plausibleMove(fix(59, 0), fix(59.004, 1))).toBe(true); // 450 m of noise between close fixes
  });

  it('keeps the train where it was when one fix jumps away, then follows it back', () => {
    const f = new FixFilter();
    expect(f.push('t', fix(59, 0))).toBe(true);
    expect(f.push('t', fix(59.01, 30))).toBe(true);
    expect(f.push('t', fix(60.5, 60))).toBe(false);
    expect(f.current('t')!.lat).toBe(59.01);
    expect(f.push('t', fix(59.02, 90))).toBe(true);
    expect(f.stats).toMatchObject({ accepted: 3, rejected: 1 });
    expect(f.stats.recent[0]).toMatchObject({ key: 't', reason: 'jump', seconds: 30 });
  });

  it('follows two fixes that agree with each other over a stale one (the train moved while the feed was quiet)', () => {
    const f = new FixFilter();
    f.push('t', fix(59, 0));
    expect(f.push('t', fix(59.5, 30))).toBe(false);
    expect(f.push('t', fix(59.51, 60))).toBe(true);
    expect(f.current('t')!.lat).toBe(59.51);
  });

  it('ignores fixes outside the area and repeats of the current one', () => {
    const f = new FixFilter();
    expect(f.push('t', { ...fix(59, 0), lat: 0, lon: 0 })).toBe(false);
    expect(f.push('t', fix(59, 0))).toBe(true);
    expect(f.push('t', fix(59, 0))).toBe(false);
  });
});

describe('speed', () => {
  it('keeps a reported speed that fits the movement, drops one that does not', () => {
    // 1.11 km in 30 s is 133 km/h.
    expect(checkedSpeed(fix(59, 0), fix(59.01, 30, 140))).toBe(140);
    expect(checkedSpeed(fix(59, 0), fix(59.01, 30, 40))).toBeNull();
    expect(checkedSpeed(fix(59, 0), fix(59.01, 30, 400))).toBeNull();
    expect(checkedSpeed(null, fix(59.01, 30, 160))).toBe(160);
  });

  it('reads standing still from two fixes in the same place', () => {
    expect(checkedSpeed(fix(59, 0), fix(59.0001, 30))).toBe(0);
    expect(checkedSpeed(fix(59, 0), fix(59.01, 30))).toBeNull();
  });

  it('is shown only from a fresh fix', () => {
    expect(shownSpeed(fix(59, 0, 150), T0 + 50_000)).toBe(150);
    expect(shownSpeed(fix(59, 0, 150), T0 + 70_000)).toBeNull();
  });
});

describe('actual and expected times', () => {
  beforeEach(() => resetHeldEstimates());
  const now = T0;

  it('never lets an actual time go back to "not yet"', () => {
    expect(sanitizeStop('k', { actual: null, estimated: null }, { actual: now - 60_000, estimated: null }, now)).toEqual({ actual: now - 60_000, estimated: null });
  });

  it('treats an actual time in the future as an estimate', () => {
    expect(sanitizeStop('k', { actual: now + 10 * 60_000, estimated: null }, { actual: null, estimated: null }, now)).toEqual({ actual: null, estimated: now + 10 * 60_000 });
  });

  it('holds a 15-minute jump in an estimate until the next answer says the same', () => {
    const stored = { actual: null, estimated: now + 20 * 60_000 };
    const jump = { actual: null, estimated: now };
    expect(sanitizeStop('k', jump, stored, now).estimated).toBe(stored.estimated);
    expect(sanitizeStop('k', jump, stored, now + 20_000).estimated).toBe(now);
    // A one-off that isn't repeated never shows.
    expect(sanitizeStop('j', jump, stored, now).estimated).toBe(stored.estimated);
    expect(sanitizeStop('j', { actual: null, estimated: now + 21 * 60_000 }, stored, now + 20_000).estimated).toBe(now + 21 * 60_000);
  });
});

describe('position after the GPS goes quiet', () => {
  const T = (hhmm: string) => Date.parse(`2026-10-20T${hhmm}:00+02:00`);
  const line: LatLon[] = [
    [57, 14.0],
    [57, 14.2],
  ];
  const stop = (id: string, lon: number, arr: string | null, dep: string | null): LiveStop => ({
    stationId: id,
    name: id,
    lat: 57,
    lon,
    schedArr: arr ? T(arr) : null,
    schedDep: dep ? T(dep) : null,
    actualArr: null,
    actualDep: id === 'A' ? T('10:00') : null,
    estimatedArr: null,
    estimatedDep: null,
    platform: null,
    canceled: false,
  });
  const stops = [stop('A', 14.0, null, '10:00'), stop('B', 14.2, '10:20', null)];

  it('carries the train on from its last fix at its last speed, never past the next stop', () => {
    // Last fix at 14.10 (about 6 km in) at 10:05, doing 120 km/h; 3 minutes later it's about 6 km further.
    const gps = { lat: 57, lon: 14.1, at: T('10:05'), bearing: 90, speedKmh: 120 };
    const v = liveView(stops, line, gps, T('10:05') + 3 * 60_000);
    expect(v.positionSource).toBe('estimated');
    expect(v.lon!).toBeGreaterThan(14.19);
    expect(v.speedKmh).toBeNull();
    const later = liveView(stops, line, gps, T('10:05') + 4.5 * 60_000);
    expect(later.lon!).toBeLessThanOrEqual(14.2);
  });

  it('never puts the estimate behind where the GPS last saw it', () => {
    // A slow timetable estimate would say 14.05 at 10:05; the train was last seen further on, with no speed.
    const gps = { lat: 57, lon: 14.15, at: T('10:04'), bearing: 90, speedKmh: null };
    expect(liveView(stops, line, gps, T('10:05')).lon!).toBeGreaterThan(14.14);
  });
});

describe('feed health', () => {
  beforeEach(() => resetFeedHealth());
  it('is ok after an answer, degraded after a failure, down after three', () => {
    feedOk('trafikverket', T0);
    expect(feedHealth(T0).trafikverket!.status).toBe('ok');
    feedFailed('trafikverket', new Error('500'), T0 + 1000);
    expect(feedHealth(T0 + 1000).trafikverket!.status).toBe('degraded');
    feedFailed('trafikverket', new Error('500'), T0 + 2000);
    feedFailed('trafikverket', new Error('500'), T0 + 3000);
    expect(feedHealth(T0 + 3000).trafikverket!.status).toBe('down');
    feedOk('trafikverket', T0 + 4000);
    expect(feedHealth(T0 + 4000).trafikverket!.status).toBe('ok');
  });
});

describe('a fix without a speed', () => {
  it('keeps the last checked reading until that reading is a minute old', () => {
    const f = new FixFilter();
    f.push('t', fix(59, 0, 150));
    f.push('t', fix(59.004, 10));
    expect(shownSpeed(f.current('t'), T0 + 30_000)).toBe(150);
    expect(shownSpeed(f.current('t'), T0 + 61_000)).toBeNull();
  });

  it("doesn't keep a reading that failed the check", () => {
    const f = new FixFilter();
    f.push('t', fix(59, 0, 150));
    f.push('t', fix(59.002, 30, 150)); // 220 m in 30 s is ~27 km/h: 150 doesn't fit
    expect(f.current('t')!.speedKmh).toBeNull();
    f.push('t', fix(59.003, 40));
    expect(f.current('t')!.speedKmh).toBeNull();
  });
});
