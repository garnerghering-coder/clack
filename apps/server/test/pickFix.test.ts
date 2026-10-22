import { describe, expect, it } from 'vitest';
import type { LatLon } from '@clack/shared';
import { distanceToLineM, pickFix, type DatedFix } from '../src/live/tracker.js';

// Malmö C → Lund C, ridden; the whole trip starts in Helsingør (via Copenhagen).
const line: LatLon[] = [
  [55.609, 13.0],
  [55.705, 13.187],
];
const route: LatLon[] = [[56.036, 12.612], [55.673, 12.565], [55.609, 13.0], [55.705, 13.187]];
const fix = (lat: number, lon: number, at: number, date: string | null = '2026-10-22'): DatedFix => ({ lat, lon, at, bearing: null, speedKmh: null, date });

describe('which GPS fix is your train', () => {
  it('measures the distance to a line', () => {
    expect(distanceToLineM({ lat: 55.609, lon: 13.0 }, line)).toBeLessThan(1);
    // ~0.01° of latitude off the line's start: about a kilometre.
    expect(distanceToLineM({ lat: 55.599, lon: 13.0 }, line)).toBeGreaterThan(900);
    expect(distanceToLineM({ lat: 55.599, lon: 13.0 }, line)).toBeLessThan(1300);
  });

  it('skips a same-numbered train elsewhere, even when its fix is newer', () => {
    const elsewhere = fix(59.33, 18.06, 2000); // Stockholm
    const ours = fix(55.65, 13.09, 1000);
    expect(pickFix([elsewhere, ours], { serviceDate: '2026-10-22', line, route })).toBe(ours);
  });

  it('accepts the train on its way to you, before it reaches your stop', () => {
    const nearCopenhagen = fix(55.68, 12.57, 1000);
    expect(pickFix([nearCopenhagen], { serviceDate: '2026-10-22', line, route })).toBe(nearCopenhagen);
  });

  it('skips yesterday\'s run of the same train', () => {
    expect(pickFix([fix(55.65, 13.09, 1000, '2026-10-21')], { serviceDate: '2026-10-22', line, route })).toBeNull();
  });
});
