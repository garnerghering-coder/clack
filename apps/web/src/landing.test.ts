import { describe, expect, it } from 'vitest';
import { isActive, isImminent, resolveLanding } from './landing';

const now = Date.parse('2026-10-21T12:00:00Z');
const at = (min: number) => new Date(now + min * 60_000).toISOString();
const leg = (depMin: number, arrMin: number, extra: Record<string, unknown> = {}) =>
  ({ schedDep: at(depMin), schedArr: at(arrMin), actualDep: null, actualArr: null, depDelayMin: null, canceled: false, live: null, ...extra }) as Parameters<typeof isActive>[0];

describe('where the app opens', () => {
  it('opens on Trips while a train is running', () => {
    expect(resolveLanding({ legs: [leg(-30, 30)], now, lastTab: 'passport' })).toBe('trips');
  });
  it('opens on Trips for a departure inside the attention window, not one further out', () => {
    expect(resolveLanding({ legs: [leg(90, 200)], now, lastTab: 'explore' })).toBe('trips');
    expect(resolveLanding({ legs: [leg(5 * 60, 6 * 60)], now, lastTab: 'passport' })).toBe('passport');
    expect(resolveLanding({ legs: [leg(5 * 60, 6 * 60)], now, lastTab: null, windowMs: 6 * 3600_000 })).toBe('trips');
  });
  it('restores the last tab, and a new user starts on Explore', () => {
    expect(resolveLanding({ legs: [], now, lastTab: 'passport' })).toBe('passport');
    expect(resolveLanding({ legs: [], now, lastTab: null })).toBe('explore');
    expect(resolveLanding({ legs: [leg(-600, -500)], now, lastTab: null })).toBe('explore');
  });
  it('keeps a late train active past its timetabled arrival, and stops once it has arrived', () => {
    expect(isActive(leg(-60, -5, { live: { status: 'en_route' } }), now)).toBe(true);
    expect(isActive(leg(-60, -5, { live: { status: 'scheduled', arrivalEta: at(15) } }), now)).toBe(true);
    expect(isActive(leg(-60, -5, { actualArr: at(-3) }), now)).toBe(false);
    expect(isActive(leg(-60, -30), now)).toBe(false);
  });
  it('handles delays, cancellations and missing times', () => {
    // Timetabled 10 min ago, 20 min late: still ahead.
    expect(isImminent(leg(-10, 60, { depDelayMin: 20 }), now)).toBe(true);
    expect(isActive(leg(-10, 60, { canceled: true }), now)).toBe(false);
    expect(isImminent(leg(30, 90, { canceled: true }), now)).toBe(true);
    expect(isImminent({ ...leg(0, 0), schedDep: null, schedArr: null }, now)).toBe(false);
  });
  it('works for an overnight train (times are instants, not local clock times)', () => {
    // 23:15 → 00:30: imminent at 22:30, active at 00:10 the next day.
    const overnight = leg(11 * 60 + 15, 12 * 60 + 30);
    expect(resolveLanding({ legs: [overnight], now: Date.parse('2026-10-21T22:30:00Z'), lastTab: 'explore' })).toBe('trips');
    expect(isActive(overnight, Date.parse('2026-10-22T00:10:00Z'))).toBe(true);
    expect(isActive(overnight, Date.parse('2026-10-22T01:00:00Z'))).toBe(false);
  });
});
