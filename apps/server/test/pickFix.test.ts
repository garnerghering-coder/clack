import { describe, expect, it } from 'vitest';
import type { LatLon } from '@clack/shared';
import { distanceToLineM, numbersNow, pickFix, type DatedFix } from '../src/live/tracker.js';

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

describe('which train number counts now', () => {
  // SL 2855 runs as 2858 for part of the trip; 2855 is another train elsewhere by then (2026-10-22).
  const at = (h: string) => Date.parse(`2026-10-22T${h}:00Z`);
  const stop = (id: string, lon: number, sched: string, num: string | null) => ({
    stationId: id, name: id, lat: 59, lon, schedArr: at(sched), schedDep: at(sched), actualArr: null, actualDep: null,
    estimatedArr: null, estimatedDep: null, platform: null, canceled: false, trvTrainNumber: num,
  });
  const stops = [stop('A', 17.0, '10:00', '2855'), stop('B', 17.2, '10:20', '2855'), stop('C', 17.4, '10:40', '2858'), stop('D', 17.6, '11:00', '2858')];
  const ln: LatLon[] = stops.map((s) => [s.lat, s.lon]);

  it('uses only the number reported at the stops either side of the train', () => {
    expect(numbersNow(stops, ln, at('10:50'), ['2855', '2858'])).toEqual(['2858']);
    expect(numbersNow(stops, ln, at('10:10'), ['2855', '2858'])).toEqual(['2855']);
    // Between the change stops, both.
    expect(numbersNow(stops, ln, at('10:30'), ['2855', '2858']).sort()).toEqual(['2855', '2858']);
  });

  it('falls back to every number without per-stop numbers', () => {
    const bare = stops.map((s) => ({ ...s, trvTrainNumber: null }));
    expect(numbersNow(bare, ln, at('10:50'), ['2855', '2858'])).toEqual(['2855', '2858']);
    expect(numbersNow(stops, ln, at('10:50'), ['441'])).toEqual(['441']);
  });
});
