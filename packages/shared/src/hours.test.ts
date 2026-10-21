import { describe, expect, it } from 'vitest';
import { isOpenAt, openState, parseHours, swedishHolidays } from './hours';

// Stockholm wall-clock to epoch ms (October 2026 is CEST, +02:00; late November is CET, +01:00).
const at = (s: string) => Date.parse(s);

describe('opening hours', () => {
  it('reads common station-shop syntax, and refuses what it cannot evaluate', () => {
    expect(parseHours('24/7')).toEqual({ rules: [], always: true });
    expect(parseHours('Mo-Fr 06:00-22:00; Sa,Su 08:00-20:00')!.rules).toHaveLength(2);
    expect(parseHours('Mo-Fr 06:00-22:00 "except in summer"')).toBeNull();
    // ", " before a weekday starts a new rule; between times it doesn't.
    const h = parseHours('Su-Th 09:00-03:00, Fr,Sa 09:00-05:00')!;
    expect(h.rules).toHaveLength(2);
    expect(isOpenAt(h, at('2026-10-24T04:30:00+02:00'))).toBe(true); // Saturday 04:30, from Friday night
    expect(parseHours('Mo-Fr 06:00-10:00, 12:00-14:00')!.rules).toHaveLength(1);
    expect(parseHours('sunrise-sunset')).toBeNull();
    expect(parseHours('')).toBeNull();
  });

  it('shows the Mo-Su 06-22 kiosk closed at 23:30 on a Sunday (ADDITIONS_01 C2 acceptance)', () => {
    // Sunday 2026-10-25, 23:30 CET.
    expect(openState('Mo-Su 06:00-22:00', at('2026-10-25T23:30:00+01:00')).state).toBe('closed');
    expect(openState('Mo-Su 06:00-22:00', at('2026-10-25T12:00:00+01:00')).state).toBe('open');
  });

  it('handles spans past midnight', () => {
    const h = parseHours('Mo-Su 18:00-02:00')!;
    expect(isOpenAt(h, at('2026-10-21T23:00:00+02:00'))).toBe(true);
    expect(isOpenAt(h, at('2026-10-22T01:30:00+02:00'))).toBe(true);
    expect(isOpenAt(h, at('2026-10-22T02:30:00+02:00'))).toBe(false);
  });

  it('knows Swedish public holidays, PH rules and days marked off', () => {
    const y = swedishHolidays(2026);
    for (const d of ['2026-01-01', '2026-04-03', '2026-04-05', '2026-04-06', '2026-05-14', '2026-06-06', '2026-06-19', '2026-06-20', '2026-10-31', '2026-12-24', '2026-12-25'])
      expect(y.has(d), d).toBe(true);
    expect(y.has('2026-10-21')).toBe(false);
    // Christmas Day 2026 is a Friday: the PH rule wins over Mo-Fr.
    expect(openState('Mo-Fr 06:00-22:00; PH off', at('2026-12-25T12:00:00+01:00')).state).toBe('closed');
    expect(openState('Mo-Fr 06:00-22:00; PH 10:00-16:00', at('2026-12-25T12:00:00+01:00')).state).toBe('open');
    expect(openState('Mo-Fr 06:00-22:00; Su off', at('2026-10-25T12:00:00+01:00')).state).toBe('closed');
  });

  it('says when something closes soon, and over a layover window', () => {
    const s = openState('Mo-Su 06:00-22:00', at('2026-10-21T21:45:00+02:00'));
    expect(s.state).toBe('closing_soon');
    expect(s.closesAt).toBe(at('2026-10-21T22:00:00+02:00'));
    // Layover 21:30–22:15: open at first, closes during it.
    const w = openState('Mo-Su 06:00-22:00', at('2026-10-21T21:30:00+02:00'), at('2026-10-21T22:15:00+02:00'));
    expect(w).toEqual({ state: 'closing_soon', closesAt: at('2026-10-21T22:00:00+02:00') });
    expect(openState('Mo-Su 06:00-22:00', at('2026-10-21T22:30:00+02:00'), at('2026-10-21T23:00:00+02:00')).state).toBe('closed');
    expect(openState(null, at('2026-10-21T12:00:00+02:00')).state).toBe('unknown');
  });
});
