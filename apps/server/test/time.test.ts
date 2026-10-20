import { describe, expect, it } from 'vitest';
import { addDays, serviceTimeToUtc, todayIn, tzOffsetMs, zonedToUtc } from '../src/lib/time.js';
import { serviceDates } from '../src/import/gtfs-se3.js';

const iso = (ms: number) => new Date(ms).toISOString();

describe('time zones', () => {
  it('knows CET and CEST', () => {
    expect(tzOffsetMs(Date.parse('2026-07-01T12:00:00Z'), 'Europe/Stockholm')).toBe(2 * 3600_000);
    expect(tzOffsetMs(Date.parse('2026-12-01T12:00:00Z'), 'Europe/Stockholm')).toBe(3600_000);
    expect(iso(zonedToUtc(2026, 10, 20, 19, 20, 0, 'Europe/Stockholm'))).toBe('2026-10-20T17:20:00.000Z');
  });
  it('converts GTFS service times, including past midnight', () => {
    expect(iso(serviceTimeToUtc('2026-10-20', 19 * 3600 + 20 * 60, 'Europe/Stockholm'))).toBe('2026-10-20T17:20:00.000Z');
    // Öresundståg 51168 at "26:27" on service day 2026-10-19 is 02:27 local on the 20th.
    expect(iso(serviceTimeToUtc('2026-10-19', 26 * 3600 + 27 * 60, 'Europe/Stockholm'))).toBe('2026-10-20T00:27:00.000Z');
  });
  it('handles the DST change days (noon minus 12 h rule)', () => {
    // 2026-10-25: clocks go back at 03:00 CEST. 08:00 local is CET = 07:00 UTC.
    expect(iso(serviceTimeToUtc('2026-10-25', 8 * 3600, 'Europe/Stockholm'))).toBe('2026-10-25T07:00:00.000Z');
    // 2027-03-28: clocks go forward at 02:00 CET. 08:00 local is CEST = 06:00 UTC.
    expect(iso(serviceTimeToUtc('2027-03-28', 8 * 3600, 'Europe/Stockholm'))).toBe('2027-03-28T06:00:00.000Z');
  });
  it('dates helpers', () => {
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(todayIn('Europe/Stockholm', Date.parse('2026-10-20T22:30:00Z'))).toBe('2026-10-21');
  });
});

describe('serviceDates', () => {
  it('expands calendar weekdays and applies calendar_dates exceptions within the window', () => {
    const cal = [{ service_id: 'A', monday: '1', tuesday: '1', wednesday: '0', thursday: '0', friday: '0', saturday: '0', sunday: '0', start_date: '20261019', end_date: '20261103' }];
    const dates = serviceDates(cal, [{ service_id: 'A', date: '20261020', exception_type: '2' }, { service_id: 'B', date: '20261022', exception_type: '1' }], '20261019', '20261027');
    expect([...dates.get('A')!].sort()).toEqual(['20261019', '20261026', '20261027']);
    expect([...dates.get('B')!]).toEqual(['20261022']);
  });
});
