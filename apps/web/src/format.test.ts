import { describe, expect, it } from 'vitest';
import { dayOffset, fmtDay, fmtDelay, fmtDistance, fmtDuration, fmtTime } from './format';

const ms = Date.parse('2026-10-20T17:04:00Z');
describe('formatting', () => {
  it('shows times in the station time zone, 24h or 12h', () => {
    expect(fmtTime(ms, 'Europe/Stockholm', '24h')).toBe('19:04');
    expect(fmtTime(ms, 'Europe/Stockholm', '12h')).toBe('7:04 pm');
    expect(fmtTime(null, 'Europe/Stockholm', '24h')).toBe('--:--');
  });
  it('formats days, durations, distances and delays', () => {
    expect(fmtDay(ms, 'Europe/Stockholm', ms)).toBe('Tue 20 Oct');
    expect(fmtDay(ms, 'Europe/Stockholm', Date.parse('2027-03-01T00:00:00Z'))).toBe('Tue 20 Oct 2026');
    expect(fmtDuration(168)).toBe('2h 48m');
    expect(fmtDuration(45)).toBe('45m');
    expect(fmtDistance(455_300, 'km')).toBe('455 km');
    expect(fmtDistance(455_300, 'mi')).toBe('283 mi');
    expect(fmtDelay(39)).toBe('+39');
    expect(fmtDelay(-2)).toBe('−2');
    expect(fmtDelay(null)).toBe('—');
  });
  it('detects arrivals on the next day', () => {
    expect(dayOffset(Date.parse('2026-10-20T20:00:00Z'), 'Europe/Stockholm', Date.parse('2026-10-20T23:30:00Z'), 'Europe/Stockholm')).toBe(1);
    expect(dayOffset(ms, 'Europe/Stockholm', ms + 3600_000, 'Europe/Stockholm')).toBe(0);
  });
});
