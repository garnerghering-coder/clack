import { describe, expect, it } from 'vitest';
import { mergeStops } from '../src/livemap/trainStops.js';
import type { StopActuals } from '../src/legs/actuals.js';

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
});
