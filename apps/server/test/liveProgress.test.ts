import { describe, expect, it } from 'vitest';
import type { LatLon } from '@clack/shared';
import { diffEvents, expectedTimes, liveView, type LegSummary, type LiveStop } from '../src/live/progress.js';

const T = (hhmm: string) => Date.parse(`2026-10-20T${hhmm}:00+02:00`);
const stop = (id: string, lon: number, arr: string | null, dep: string | null, extra: Partial<LiveStop> = {}): LiveStop => ({
  stationId: id,
  name: id,
  lat: 57,
  lon,
  schedArr: arr ? T(arr) : null,
  schedDep: dep ? T(dep) : null,
  actualArr: null,
  actualDep: null,
  estimatedArr: null,
  estimatedDep: null,
  platform: null,
  canceled: false,
  ...extra,
});
// A → B → C along the 57th parallel, 0.1° (~6 km) apart.
const line: LatLon[] = [
  [57, 14.0],
  [57, 14.1],
  [57, 14.2],
];
const stops = () => [stop('A', 14.0, null, '10:00'), stop('B', 14.1, '10:10', '10:12'), stop('C', 14.2, '10:22', null)];

describe('live view', () => {
  it('is scheduled, then boarding 30 min before departure', () => {
    expect(liveView(stops(), line, null, T('09:00')).status).toBe('scheduled');
    expect(liveView(stops(), line, null, T('09:45')).status).toBe('boarding');
  });

  it('estimates the position halfway between stops at the halfway time', () => {
    const s = stops();
    s[0]!.actualDep = T('10:00');
    const v = liveView(s, line, null, T('10:05'));
    expect(v.status).toBe('en_route');
    expect(v.positionSource).toBe('estimated');
    expect(v.lon).toBeCloseTo(14.05, 2);
    expect(v.nextStopId).toBe('B');
    expect(v.eta).toBe(T('10:10'));
    expect(v.progress).toBeCloseTo(0.25, 2);
  });

  it('waits at a stop during the dwell, and names the next one', () => {
    const s = stops();
    s[0]!.actualDep = T('10:00');
    s[1]!.actualArr = T('10:10');
    const v = liveView(s, line, null, T('10:11'));
    expect(v.status).toBe('at_stop');
    expect(v.prevStopId).toBe('B');
    expect(v.nextStopId).toBe('C');
    expect(v.lon).toBeCloseTo(14.1, 3);
  });

  it('prefers a fresh GPS fix and ignores a stale one', () => {
    const s = stops();
    s[0]!.actualDep = T('10:00');
    const gps = { lat: 57, lon: 14.03, at: T('10:04'), bearing: 90, speedKmh: 80 };
    const fresh = liveView(s, line, gps, T('10:05'));
    expect(fresh.positionSource).toBe('gps');
    expect(fresh.lon).toBe(14.03);
    expect(fresh.progress).toBeCloseTo(0.15, 2);
    expect(liveView(s, line, gps, T('10:09')).positionSource).toBe('estimated');
  });

  it('carries a known delay forward and reports the arrival delay', () => {
    const s = stops();
    s[0]!.actualDep = T('10:05');
    const times = expectedTimes(s);
    expect(times[1]!.arr).toBe(T('10:15'));
    expect(times[2]!.arr).toBe(T('10:27'));
    const v = liveView(s, line, null, T('10:06'));
    expect(v.arrivalDelayMin).toBe(5);
    expect(v.arrivalEta).toBe(T('10:27'));
  });

  it('is arrived once the arrival is known, and cancelled when the ride is cancelled', () => {
    const s = stops();
    s[2]!.actualArr = T('10:23');
    expect(liveView(s, line, null, T('10:24')).status).toBe('arrived');
    const c = stops();
    c[2]!.canceled = true;
    expect(liveView(c, line, null, T('10:05')).status).toBe('cancelled');
  });
});

describe('leg events', () => {
  const base: LegSummary = { arrivalDelayMin: 0, depPlatform: '3', arrPlatform: '1', canceled: false, canceledStops: [], departedAt: null, arrivedAt: null };

  it('reports departures, arrivals, platform changes and real delay changes', () => {
    expect(diffEvents(base, { ...base, departedAt: 1 }).map((e) => e.type)).toEqual(['departed']);
    expect(diffEvents(base, { ...base, arrPlatform: '4' })).toEqual([{ type: 'platform_changed', payload: { which: 'arrival', from: '1', to: '4' } }]);
    expect(diffEvents(base, { ...base, arrivalDelayMin: 8 }).map((e) => e.type)).toEqual(['delayed']);
    expect(diffEvents(base, { ...base, arrivedAt: 5, arrivalDelayMin: 2 }).map((e) => e.type)).toEqual(['arrived']);
  });

  it('ignores small wobbles and first platform assignments', () => {
    expect(diffEvents(base, { ...base, arrivalDelayMin: 2 })).toEqual([]);
    expect(diffEvents({ ...base, depPlatform: null }, base)).toEqual([]);
  });

  it('tells a cancellation from a short-turn', () => {
    expect(diffEvents(base, { ...base, canceled: true }).map((e) => e.type)).toEqual(['cancelled']);
    expect(diffEvents(base, { ...base, canceledStops: ['C'] }).map((e) => e.type)).toEqual(['short_turned']);
  });
});
