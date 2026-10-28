import { describe, expect, it } from 'vitest';
import { comfortOf, countryOfStops, crossBorderMin, minChangeMin } from '@clack/shared';

describe('the change rule', () => {
  it('takes the larger of the station tier and the cross-border minimum, never the sum', () => {
    expect(minChangeMin('default', 'SE', 'SE')).toBe(7);
    expect(minChangeMin('mid', 'SE', 'SE')).toBe(10);
    expect(minChangeMin('hub', 'DK', 'SE')).toBe(15); // København H, Öresundståg to DSB: 15, not 25
    expect(minChangeMin('default', 'DK', 'SE')).toBe(10);
    expect(minChangeMin('default', 'NO', 'SE')).toBe(15);
    expect(minChangeMin('mid', 'FI', 'SE')).toBe(15);
    expect(crossBorderMin(null, 'SE')).toBe(0);
  });
  it('rates comfort against the minimum: at a 7-min station tight 7–10, normal 11–14, relaxed 15+', () => {
    expect([6, 7, 10, 11, 14, 15].map((g) => comfortOf(g, 7))).toEqual(['risky', 'tight', 'tight', 'normal', 'normal', 'relaxed']);
    expect([14, 15, 22, 23, 30, 31].map((g) => comfortOf(g, 15))).toEqual(['risky', 'tight', 'tight', 'normal', 'normal', 'relaxed']);
  });
  it("names a train's country by where most of its stops are", () => {
    expect(countryOfStops(['SE', 'SE', 'SE', 'DK', 'DK'])).toBe('SE');
    expect(countryOfStops([null, undefined])).toBeNull();
  });
});
