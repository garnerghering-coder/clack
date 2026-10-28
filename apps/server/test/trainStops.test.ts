import { describe, expect, it } from 'vitest';
import { mergeStops, trainStops } from '../src/livemap/trainStops.js';
import type { StopActuals } from '../src/legs/actuals.js';
import { openDb } from '../src/db/client.js';
import { resetDigitrafficCaches } from '../src/digitraffic/trains.js';
import { fakeDigitraffic, HAPARANDA, seedFinland, seedTrip, trainFixture } from './finlandFixtures.js';

const plan = [1, 2, 3, 4].map((seq) => ({ seq, stationId: `s${seq}`, name: `S${seq}`, arr: seq * 1000, dep: seq * 1000 + 60 }));
const act = (seq: number, a: Partial<StopActuals>): [number, StopActuals] => [
  seq,
  { seq, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled: false, deviations: [], trvTrainNumber: null, composition: null, onboard: null, ...a },
];

describe('a live train’s stop list', () => {
  it('marks stops passed up to the last report, filling gaps before it', () => {
    const r = mergeStops(plan, new Map([act(1, { actualDep: 1070 }), act(3, { actualArr: 3010, actualDep: 3080, platform: '2' }), act(4, { estimatedArr: 4120 })]));
    expect(r.map((s) => s.passed)).toEqual([true, true, true, false]);
    expect(r[2]!.platform).toBe('2');
    expect(r[3]!.estimatedArr).toBe(4120);
  });
  it('counts the last stop as passed once the train has arrived there', () => {
    expect(mergeStops(plan, new Map([act(4, { actualArr: 4000 })])).every((s) => s.passed)).toBe(true);
    expect(mergeStops(plan, new Map()).some((s) => s.passed)).toBe(false);
  });
  it("keeps each stop's delay causes (SJ 547, 27 Oct: Trafikverket's 'Olycka' never reached the app)", () => {
    const r = mergeStops(plan, new Map([act(2, { causes: [{ src: 'trv', code: 'FHA015', text: 'Olycka' }] }), act(3, { deviations: ['Spårändrat'] })]));
    expect(r[1]!.causes).toEqual([{ src: 'trv', code: 'FHA015', text: 'Olycka' }]);
    expect(r[2]!.causes).toEqual([{ src: 'trv', text: 'Spårändrat' }]);
    expect(r[0]!.causes).toEqual([]);
  });
});

describe('a Finnish train’s stop list', () => {
  it('lays Digitraffic’s times over the timetable and says who reports each stop', async () => {
    resetDigitrafficCaches();
    const db = openDb(':memory:');
    seedFinland(db);
    const ic27 = trainFixture('ic-27');
    const key = seedTrip(db, ic27);
    const { fetchImpl, seen } = fakeDigitraffic({ 'trains/2026-10-24/27': [ic27] });
    // Trafikverket is never asked: its host isn't in the table, so a call to it would be a 404 in `seen`.
    const stops = (await trainStops(db, { key, serviceDate: '2026-10-24' }, '27', { now: Date.parse('2026-10-24T13:30:00Z'), fetchImpl }))!;
    expect(seen).toEqual(['trains/2026-10-24/27']);
    expect(stops.map((s) => s.name).slice(0, 4)).toEqual(['Helsinki', 'Pasila', 'Tikkurila', 'Tampere']);
    expect(stops.every((s) => s.source === 'digitraffic')).toBe(true);
    expect(stops[0]).toMatchObject({ platform: '7', passed: true });
    expect(stops[3]).toMatchObject({ name: 'Tampere', platform: '2', passed: true });
    // Everything the train hasn't reached by 13:30 is still ahead.
    expect(stops.at(-1)!.passed).toBe(false);
  });

  it('names Haparanda as Digitraffic’s, even though Trafikverket has a signature for it', async () => {
    resetDigitrafficCaches();
    const db = openDb(':memory:');
    seedFinland(db);
    const ic407 = trainFixture('ic-407-haparanda');
    const key = seedTrip(db, ic407);
    const { fetchImpl } = fakeDigitraffic({ 'trains/2026-10-24/407': [ic407] });
    const stops = (await trainStops(db, { key, serviceDate: '2026-10-24' }, '407', { now: Date.parse('2026-10-24T19:00:00Z'), fetchImpl }))!;
    expect(stops.at(-1)).toMatchObject({ stationId: HAPARANDA, source: 'digitraffic', passed: true });
  });
});
