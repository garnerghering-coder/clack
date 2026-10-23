import { describe, expect, it } from 'vitest';
import type { GpsFix, LatLon } from '@clack/shared';
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

describe('a train still on its way to the stop you board at (owner, 2026-10-23: SJ 547 into Hässleholm)', () => {
  // You board at B (scheduled 10:10, leaving 10:12) and the train is running 20 min late into it.
  const board = (extra: Partial<LiveStop> = {}) => [stop('B', 14.1, '10:10', '10:12', { estimatedArr: T('10:30'), ...extra }), stop('C', 14.2, '10:22', null, { estimatedArr: T('10:42') })];
  const ridden: LatLon[] = [
    [57, 14.1],
    [57, 14.2],
  ];
  const fix = (lon: number, at: string): GpsFix => ({ lat: 57, lon, at: T(at), bearing: 90, speedKmh: 120 });

  it('is not boarding just because the departure is within 30 minutes: the train has not got there', () => {
    // 10:05 is 27 min before the late departure (10:32), but the train arrives at 10:30.
    const v = liveView(board(), ridden, null, T('10:05'));
    expect(v.status).toBe('approaching');
    expect(v.eta).toBe(T('10:30'));
  });

  it('is boarding once the train has arrived, or is about to', () => {
    expect(liveView(board(), ridden, null, T('10:29')).status).toBe('boarding');
    expect(liveView(board({ actualArr: T('10:28') }), ridden, null, T('10:29')).status).toBe('boarding');
  });

  it('shows where the train is while it is on its way, and does not call it departed when a late estimate passes', () => {
    // 26 km before the stop; the estimated departure (10:32) has passed in the schedule's eyes at 10:33.
    const v = liveView(board({ estimatedDep: T('10:32') }), ridden, fix(13.7, '10:32'), T('10:32'));
    expect(v.status).toBe('approaching');
    expect(v.positionSource).toBe('gps');
    expect(v.lon).toBeCloseTo(13.7, 3);
    expect(v.progress).toBe(0);
    expect(v.nextStopId).toBe('B');
  });

  it('is boarding when the train is at the stop, and departed once it is on the ride', () => {
    expect(liveView(board(), ridden, fix(14.1, '10:29'), T('10:29')).status).toBe('boarding');
    expect(liveView(board({ actualDep: T('10:31') }), ridden, fix(14.12, '10:34'), T('10:34')).status).toBe('en_route');
  });

  it('a train that starts at your stop boards 30 minutes before, as before', () => {
    const origin = [stop('B', 14.1, null, '10:12'), stop('C', 14.2, '10:22', null)];
    expect(liveView(origin, ridden, null, T('09:40')).status).toBe('scheduled');
    expect(liveView(origin, ridden, null, T('09:45')).status).toBe('boarding');
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

  it('ignores small wobbles, and reports a platform being announced for the first time (owner, 2026-10-23: alerts)', () => {
    expect(diffEvents(base, { ...base, arrivalDelayMin: 2 })).toEqual([]);
    expect(diffEvents({ ...base, depPlatform: null }, base)).toEqual([{ type: 'platform_set', payload: { which: 'departure', to: '3' } }]);
    expect(diffEvents(base, { ...base, depPlatform: null })).toEqual([]);
  });

  it('tells a cancellation from a short-turn', () => {
    expect(diffEvents(base, { ...base, canceled: true }).map((e) => e.type)).toEqual(['cancelled']);
    expect(diffEvents(base, { ...base, canceledStops: ['C'] }).map((e) => e.type)).toEqual(['short_turned']);
  });
});
