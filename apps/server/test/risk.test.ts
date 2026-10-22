import { describe, expect, it } from 'vitest';
import { nowWarnings, patternWarning, type Departure } from '../src/legs/risk.js';

const T = Date.parse('2026-10-22T12:00:00Z');
const dep = (n: number, sig: string, lateMin: number | null, canceled = false): Departure => ({
  trainNumber: String(n),
  signature: sig,
  advertised: T,
  actual: lateMin === null ? null : T + lateMin * 60_000,
  canceled,
});

describe('right-now warnings along the route', () => {
  it('stays quiet on a normal hour (the 57 departures seen on 2026-10-22: 2 late, median on time)', () => {
    const deps = [...Array.from({ length: 55 }, (_, i) => dep(i, 'Cst', i % 5)), dep(98, 'K', 12), dep(99, 'Hpbg', 15)];
    expect(nowWarnings(deps, 'Cst', 'Stockholm C')).toEqual([]);
  });

  it('warns when a real share of the trains along the route are late or cancelled', () => {
    const deps = [dep(1, 'Söc', 14), dep(2, 'Söc', 22), dep(3, 'K', 11), dep(4, 'K', 2), dep(5, 'Hpbg', 0), dep(6, 'Hpbg', 3), dep(7, 'Sk', 18), dep(8, 'Sk', 1), dep(9, 'Sk', null, true)];
    const [w] = nowWarnings(deps, 'Cst', 'Stockholm C');
    expect(w).toMatchObject({ kind: 'route_now', trains: 9, late: 4, canceled: 1 });
  });

  it('needs enough trains: two bad departures are not a pattern', () => {
    expect(nowWarnings([dep(1, 'K', 30), dep(2, 'K', 25)], 'K', 'Katrineholm C')).toEqual([]);
  });

  it('warns about your own station when most of its departures leave late', () => {
    const deps = [dep(1, 'Cst', 12), dep(2, 'Cst', 15), dep(3, 'Cst', 11), dep(4, 'Cst', 1), dep(5, 'U', 0)];
    expect(nowWarnings(deps, 'cst', 'Stockholm C')).toEqual([{ kind: 'station_now', station: 'Stockholm C', trains: 4, late: 3, medianMin: 12, windowMin: 60 }]);
  });
});

describe("a train's past pattern", () => {
  it('needs at least 4 days seen, mostly late', () => {
    expect(patternWarning([{ delayMin: 9, canceled: false }, { delayMin: 12, canceled: false }, { delayMin: 7, canceled: false }], 'Nässjö C')).toBeNull();
    const w = patternWarning(
      [6, 9, 0, 12, 7].map((d) => ({ delayMin: d, canceled: false })),
      'Nässjö C',
    );
    expect(w).toEqual({ kind: 'train_pattern', station: 'Nässjö C', days: 5, lateDays: 4, medianMin: 7 });
    expect(patternWarning([0, 1, 6, 2].map((d) => ({ delayMin: d, canceled: false })), 'Nässjö C')).toBeNull();
  });
});
