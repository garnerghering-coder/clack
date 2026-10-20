import { describe, expect, it } from 'vitest';
import { delayBand, delayMinutes, isOnTime } from './delay';

const t = (hhmm: string) => Date.parse(`2026-10-20T${hhmm}:00+02:00`);

describe('delays', () => {
  it('computes whole minutes, early as negative', () => {
    expect(delayMinutes(t('18:25'), t('19:04'))).toBe(39);
    expect(delayMinutes(t('19:20'), t('19:20'))).toBe(0);
    expect(delayMinutes(t('10:23'), t('10:20'))).toBe(-3);
    expect(delayMinutes(t('23:58'), Date.parse('2026-10-21T00:03:00+02:00'))).toBe(5);
    expect(delayMinutes(null, t('10:00'))).toBeNull();
  });
  it('bands match DESIGN §2.1', () => {
    expect(delayBand(-2)).toBe('on_time');
    expect(delayBand(0)).toBe('on_time');
    expect(delayBand(1)).toBe('slight');
    expect(delayBand(15)).toBe('slight');
    expect(delayBand(16)).toBe('late');
    expect(delayBand(30)).toBe('late');
    expect(delayBand(31)).toBe('very_late');
    expect(delayBand(5, true)).toBe('cancelled');
    expect(delayBand(null)).toBe('unknown');
  });
  it('on time means at most 5 minutes late', () => {
    expect(isOnTime(5)).toBe(true);
    expect(isOnTime(6)).toBe(false);
    expect(isOnTime(null)).toBe(false);
  });
});
