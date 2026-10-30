import { describe, expect, it } from 'vitest';
import { MIN_SAMPLES, RunCurves } from '../src/live/runCurves.js';

describe('learned run curves', () => {
  it('says nothing until a stretch has enough samples in every part of its run', () => {
    const c = new RunCurves();
    for (let i = 0; i < MIN_SAMPLES; i++) c.record('A>B', 0.05 + (i % 5) * 0.1, 0.3); // only the first half of the run
    expect(c.progressAt('A>B', 0.5)).toBeNull();
    expect(c.progressAt('X>Y', 0.5)).toBeNull();
  });

  it('learns a slow start and a quick finish, never going backwards, and survives a save', () => {
    const c = new RunCurves();
    // Trains that crawl out (a long slow section) then run: share of track = share of time squared.
    for (let i = 0; i < 200; i++) {
      const t = (i + 0.5) / 200;
      c.record('A>B', t, t * t);
    }
    const mid = c.progressAt('A>B', 0.5)!;
    expect(mid).toBeGreaterThan(0.2);
    expect(mid).toBeLessThan(0.32);
    expect(c.progressAt('A>B', 0.95)!).toBeGreaterThan(c.progressAt('A>B', 0.9)!);
    // Outside 0–1 is ignored.
    c.record('A>B', 1.4, 0.5);
    const back = RunCurves.from(JSON.parse(JSON.stringify(c.toJSON())));
    expect(back.progressAt('A>B', 0.5)).toBeCloseTo(mid, 6);
    expect(back.summary()).toMatchObject({ stretches: 1, ready: 1, samples: 200 });
  });
});
