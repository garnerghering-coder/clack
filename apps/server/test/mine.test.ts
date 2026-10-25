import { describe, expect, it } from 'vitest';
import { ringStillOn } from '../src/livemap/mine.js';

const NOW = Date.parse('2026-10-25T12:00:00Z');
const at = (min: number) => new Date(NOW + min * 60_000);
const leg = (over: Partial<Parameters<typeof ringStillOn>[0]> = {}) => ({ actualArr: null, schedArr: at(30), arrDelayMin: 0, arrivalEta: null, ...over });

describe('the ring on your train', () => {
  it('stays while you are on the way or about to board', () => {
    expect(ringStillOn(leg(), NOW)).toBe(true);
    expect(ringStillOn(leg({ schedArr: at(-1) }), NOW)).toBe(true);
  });
  it('goes once the train has arrived where you get off', () => {
    expect(ringStillOn(leg({ actualArr: at(-3) }), NOW)).toBe(false);
  });
  it('goes shortly after the expected arrival when none was recorded', () => {
    expect(ringStillOn(leg({ schedArr: at(-5) }), NOW)).toBe(false);
  });
  it('follows a delay or the live estimate, not the timetable', () => {
    expect(ringStillOn(leg({ schedArr: at(-5), arrDelayMin: 10 }), NOW)).toBe(true);
    expect(ringStillOn(leg({ schedArr: at(-5), arrivalEta: at(4) }), NOW)).toBe(true);
    expect(ringStillOn(leg({ schedArr: at(40), arrivalEta: at(-6) }), NOW)).toBe(false);
  });
});
