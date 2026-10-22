import { describe, expect, it } from 'vitest';
import { expectedStops, rtDate } from '../src/livemap/norway.js';
import { callsByPlace, callsToActuals, type NorwayCall } from '../src/entur/calls.js';
import { resetAt } from '../src/entur/client.js';
import { normalizeNorwayBoard, type JpBoardCall } from '../src/boards/norway.js';

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
      T('23:59'),
    );
    expect(m.get(1)).toMatchObject({ actualDep: T('23:04'), platform: '3' });
    expect(m.get(2)).toMatchObject({ actualArr: null, estimatedArr: T('06:25') });
    expect(m.has(3)).toBe(false);
  });

  it('treats an "actual" time still in the future as expected, not as reported', () => {
    // Flytoget's calls carry actual times for stops the train hasn't reached yet.
    const calls = [call({ aimedDep: T('07:00'), actualDep: T('07:00') }), call({ pos: 1, aimedArr: T('07:19'), actualArr: T('07:19'), realtime: false })];
    const m = callsToActuals(
      [
        { seq: 1, schedArr: null, schedDep: T('07:00') },
        { seq: 2, schedArr: T('07:19'), schedDep: null },
      ],
      calls,
      T('07:05'),
    );
    expect(m.get(1)).toMatchObject({ actualDep: T('07:00') });
    expect(m.get(2)).toMatchObject({ actualArr: null, estimatedArr: T('07:19') });
  });

  it('matches another feed\'s train by stop place and takes that country\'s published time', () => {
    // SJ 645 to Oslo: SJ's Swedish timetable says Oslo S 00:02, Norway's says 00:14; Entur has no live data for it.
    const calls = [
      call({ pos: 8, stopPlace: 'NSR:StopPlace:Kongsvinger', aimedArr: T('20:45'), aimedDep: T('20:45'), realtime: false }),
      call({ pos: 9, stopPlace: 'NSR:StopPlace:337', aimedArr: T('22:14'), realtime: false }),
    ];
    const m = callsByPlace(
      [
        { seq: 1, schedArr: null, schedDep: T('16:19'), nsrId: null },
        { seq: 9, schedArr: T('20:43'), schedDep: T('20:45'), nsrId: 'NSR:StopPlace:Kongsvinger' },
        { seq: 10, schedArr: T('22:02'), schedDep: null, nsrId: 'NSR:StopPlace:337' },
      ],
      calls,
      T('23:00'),
    );
    expect(m.get(10)).toMatchObject({ advertisedArr: T('22:14'), actualArr: null, source: null });
    expect(m.get(9)).toMatchObject({ advertisedArr: T('20:45') });
    expect(m.has(1)).toBe(false);
    // Hours away is not the same call.
    expect(callsByPlace([{ seq: 10, schedArr: T('18:02'), schedDep: null, nsrId: 'NSR:StopPlace:337' }], calls, T('23:00')).size).toBe(0);
  });

  it('waits for Entur\'s reset time after a quota hit', () => {
    const now = Date.parse('2026-10-22T01:00:00Z');
    expect(resetAt(new Headers({ 'rate-limit-expiry-time': 'Thu Oct 22 2026 01:01:30 GMT-0000 (GMT)' }), now)).toBe(now + 90_000);
    expect(resetAt(new Headers({ 'retry-after': '20' }), now)).toBe(now + 20_000);
    expect(resetAt(new Headers(), now)).toBe(now + 60_000);
  });
});

describe('Norwegian boards', () => {
  const jp = (p: Partial<JpBoardCall>): JpBoardCall => ({
    aimedArrivalTime: null,
    aimedDepartureTime: '2026-10-22T08:00:00+02:00',
    expectedArrivalTime: null,
    expectedDepartureTime: '2026-10-22T08:04:00+02:00',
    actualArrivalTime: null,
    actualDepartureTime: null,
    cancellation: false,
    quay: { publicCode: '3' },
    destinationDisplay: { frontText: 'Bergen', via: ['Voss'] },
    situations: [{ summary: [{ value: 'Forsinkelse', language: 'no' }, { value: 'Delay', language: 'en' }] }],
    serviceJourney: { id: 'VYG:ServiceJourney:61-LOD_1-R', privateCode: '61', quays: [{ name: 'Oslo S' }] },
    date: '2026-10-22',
    ...p,
  });

  it('turns Journey Planner calls into board rows linked to the timetable', () => {
    const memory = new Map();
    const tripCall = { tripKey: 'no:VYG:ServiceJourney:61-LOD_1-R:abc', serviceDate: '2026-10-22', seq: 1, trainNumber: '61', operatorId: 'vy', product: 'intercity' as const, category: 'intercity', arr: null, dep: Date.parse('2026-10-22T06:00:00Z') };
    const [row] = normalizeNorwayBoard([jp({})], { type: 'departures', now: 0, calls: [tripCall], memory });
    expect(row).toMatchObject({ trainNumber: '61', operatorId: 'vy', platform: '3', delayMin: 4, endpoints: ['Bergen'], via: ['Voss'], deviations: ['Delay'], trip: { seq: 1 } });
    // The track changes between polls.
    const [moved] = normalizeNorwayBoard([jp({ quay: { publicCode: '5' } })], { type: 'departures', now: 1, calls: [tripCall], memory });
    expect(moved!.platformChange).toEqual({ from: '3', at: 1 });
  });

  it('shows where an arriving train came from, and cancellations without a delay', () => {
    const [row] = normalizeNorwayBoard([jp({ aimedArrivalTime: '2026-10-22T08:00:00+02:00', cancellation: true, serviceJourney: { id: 'GOA:ServiceJourney:705-X', privateCode: '705', quays: [{ name: 'Stavanger stasjon' }] } })], { type: 'arrivals', now: 0, calls: [], memory: new Map() });
    expect(row).toMatchObject({ operatorId: 'go-ahead-norge', endpoints: ['Stavanger'], canceled: true, delayMin: null, trip: null });
  });
});
