import { describe, expect, it } from 'vitest';
import { expectedStops, rtDate } from '../src/livemap/norway.js';
import { callsToActuals, type NorwayCall } from '../src/entur/calls.js';
import { resetAt } from '../src/entur/client.js';

const T = (hm: string) => Date.parse(`2026-10-22T${hm}:00Z`);

describe('Norway live data', () => {
  it('reads both GTFS-RT date formats', () => {
    expect(rtDate('20261022')).toBe('2026-10-22');
    expect(rtDate('2026-10-22')).toBe('2026-10-22');
    expect(rtDate(undefined)).toBeNull();
  });

  it('carries the last reported delay on to later stops', () => {
    const stops = [
      { seq: 1, arr: null, dep: T('10:00') },
      { seq: 2, arr: T('10:10'), dep: T('10:11') },
      { seq: 3, arr: T('10:30'), dep: null },
    ];
    const u = { canceled: false, delays: new Map([[2, { arr: 120, dep: 180 }]]), skipped: new Set([3]) };
    const e = expectedStops(stops, u);
    expect(e[0]).toEqual({ arr: null, dep: T('10:00'), skipped: false });
    expect(e[1]).toEqual({ arr: T('10:12'), dep: T('10:14'), skipped: false });
    expect(e[2]).toEqual({ arr: T('10:33'), dep: null, skipped: true });
    // No update at all: the timetable.
    expect(expectedStops(stops, undefined)[1]!.arr).toBe(T('10:10'));
  });

  const call = (p: Partial<NorwayCall>): NorwayCall => ({ pos: 0, stopPlace: 'NSR:StopPlace:1', aimedArr: null, aimedDep: null, expectedArr: null, expectedDep: null, actualArr: null, actualDep: null, platform: null, canceled: false, realtime: true, ...p });

  it('matches Journey Planner calls to stops by stop place and scheduled minute', () => {
    const calls = [
      call({ stopPlace: 'NSR:StopPlace:337', aimedDep: T('23:03'), actualDep: T('23:04'), platform: '3' }),
      call({ stopPlace: 'NSR:StopPlace:548', aimedArr: T('06:23'), expectedArr: T('06:25') }),
    ];
    const m = callsToActuals(
      [
        { seq: 1, schedArr: null, schedDep: T('23:03'), nsrId: 'NSR:StopPlace:337' },
        { seq: 2, schedArr: T('06:23'), schedDep: null, nsrId: 'NSR:StopPlace:548' },
        // Same minute, another place: not this train's call.
        { seq: 3, schedArr: T('06:23'), schedDep: null, nsrId: 'NSR:StopPlace:9' },
      ],
      calls,
    );
    expect(m.get(1)).toMatchObject({ actualDep: T('23:04'), platform: '3' });
    expect(m.get(2)).toMatchObject({ actualArr: null, estimatedArr: T('06:25') });
    expect(m.has(3)).toBe(false);
  });

  it('waits for Entur\'s reset time after a quota hit', () => {
    const now = Date.parse('2026-10-22T01:00:00Z');
    expect(resetAt(new Headers({ 'rate-limit-expiry-time': 'Thu Oct 22 2026 01:01:30 GMT-0000 (GMT)' }), now)).toBe(now + 90_000);
    expect(resetAt(new Headers({ 'retry-after': '20' }), now)).toBe(now + 20_000);
    expect(resetAt(new Headers(), now)).toBe(now + 60_000);
  });
});
