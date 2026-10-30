import { describe, expect, it } from 'vitest';
import { RiderFixes, stretchFrom, validReport, type RiderReport } from '../src/live/riders.js';
import type { LiveTrain } from '../src/livemap/ingest.js';

const NOW = 1_800_000_000_000;
// A 10 km stretch due north from 57.0, 14.0.
const north = stretchFrom(Array.from({ length: 11 }, (_, i): [number, number] => [57 + (i * 1000) / 111_195, 14]));
const train = (over: Partial<LiveTrain> = {}): LiveTrain => ({
  id: 'dk:634761@8600708.1201|2026-10-30', number: '1127', date: '2026-10-30', lat: 57, lon: 14, bearing: null, speedKmh: null, at: NOW, estimated: true,
  operatorId: 'dsb', productName: null, product: 'regional', trainType: null, origin: null, destination: null, next: null, nextEta: null, delayMin: null,
  mine: false, state: 'running', prevId: 'A', nextId: 'B', progress: 0.2, ...over,
});
const report = (over: Partial<RiderReport> = {}): RiderReport => ({ train: train().id, prevId: 'A', nextId: 'B', progress: 0.5, speedKmh: 90, at: NOW - 10_000, session: 'aaaaaaaa-1', ...over });
const fixes = () => {
  const r = new RiderFixes();
  r.stretchOf = (a, b) => (a === 'A' && b === 'B') || (a === 'B' && b === 'C') ? north : null;
  return r;
};

describe("riders' reports", () => {
  it('refuses what is malformed, old, too fast, too frequent, or for a train or stretch not on the map', () => {
    const r = fixes();
    expect(validReport({ ...report(), progress: 1.5 }, NOW)).toBe(false);
    expect(validReport({ ...report(), lat: 57 }, NOW)).toBe(true); // extra fields are ignored, never kept
    expect(r.add({ ...report(), session: 'x' }, train(), NOW)).toBe('bad input');
    expect(r.add(report({ at: NOW - 120_000 }), train(), NOW)).toBe('stale');
    expect(r.add(report(), undefined, NOW)).toBe('unknown train');
    expect(r.add(report({ speedKmh: 400 }), train(), NOW)).toBe('too fast');
    expect(r.add(report({ prevId: 'X' }), train(), NOW)).toBe('unknown stretch');
    expect(r.add(report(), train(), NOW)).toBeNull();
    expect(r.add(report(), train(), NOW + 5_000)).toBe('too often');
  });

  it("one phone on the feed's own stretch places an estimated train, carried forward at its speed", () => {
    const r = fixes();
    r.add(report(), train(), NOW);
    const t = r.adjust(train(), NOW);
    // 5 000 m at the fix, plus 10 s at 90 km/h = 250 m.
    expect(t.progress).toBeCloseTo(0.525, 3);
    expect(t.estimated).toBe(false);
    expect(t.riders).toBe(1);
    expect(t.fixAt).toBe(NOW - 10_000);
    expect(t.lat).toBeCloseTo(57 + 5250 / 111_195, 4);
    // A second phone agreeing makes it two, on the train the riders already placed.
    r.add(report({ progress: 0.51, session: 'bbbbbbbb-2' }), t, NOW);
    expect(r.adjust(t, NOW).riders).toBe(2);
  });

  it("never replaces an operator's GPS, nor a train standing", () => {
    const r = fixes();
    r.add(report(), train(), NOW);
    const gps = train({ estimated: false });
    expect(r.adjust(gps, NOW)).toBe(gps);
    const s = fixes();
    s.add(report({ speedKmh: 0 }), train(), NOW);
    const t = train();
    expect(s.adjust(t, NOW)).toBe(t);
  });

  it('a phone on another stretch counts only when a second phone agrees with it', () => {
    const r = fixes();
    // The feed has the train on A → B; one phone says it is on B → C (one stretch on is allowed) …
    r.add(report({ prevId: 'B', nextId: 'C', progress: 0.1 }), train(), NOW);
    expect(r.adjust(train(), NOW).prevId).toBe('B');
    // … but a phone two stretches away (C → D) alone is not believed.
    const s = new RiderFixes();
    s.stretchOf = () => north;
    s.add(report({ prevId: 'C', nextId: 'D' }), train(), NOW);
    expect(s.adjust(train(), NOW).estimated).toBe(true);
    // Two phones within 400 m of each other on C → D are.
    s.add(report({ prevId: 'C', nextId: 'D', progress: 0.52, session: 'bbbbbbbb-2' }), train(), NOW);
    const t = s.adjust(train(), NOW);
    expect([t.prevId, t.nextId, t.riders]).toEqual(['C', 'D', 2]);
  });

  it('forgets every report after a few minutes', () => {
    const r = fixes();
    r.add(report(), train(), NOW);
    r.prune(NOW + 4 * 60_000);
    expect(r.trains()).toEqual([]);
  });
});
