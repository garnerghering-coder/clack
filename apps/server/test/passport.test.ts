import { describe, expect, it } from 'vitest';
import { co2, computePassport, type PassportLeg, type PassportStop } from '../src/stats/passport.js';

const T = (date: string, hhmm: string) => Date.parse(`${date}T${hhmm}:00+02:00`);
const st = (stationId: string, country: string, role: string): PassportStop => ({ stationId, name: stationId, country, lat: 0, lon: 0, role });
const leg = (p: Partial<PassportLeg> & { id: string }): PassportLeg => ({
  journeyId: null,
  dep: T('2026-10-20', '10:00'),
  arr: T('2026-10-20', '11:00'),
  schedDep: T('2026-10-20', '10:00'),
  distanceM: 100_000,
  operatorId: 'sj',
  product: 'regional',
  category: 'regional',
  trainType: 'x40',
  trainNumber: '1',
  dataQuality: 'full',
  arrDelayMin: 0,
  canceled: false,
  geometry: null,
  stops: [st('A', 'SE', 'board'), st('B', 'SE', 'alight')],
  ...p,
});

// The owner's 20 Oct: Kolding (DK) → Nässjö 533 km +39, then Nässjö → Jönköping 43 km +3, one journey.
const day = [
  leg({ id: '306', journeyId: 'j1', operatorId: 'snalltaget', product: 'intercity', trainType: 'loco_coaches', distanceM: 533_000, dep: T('2026-10-20', '13:01'), arr: T('2026-10-20', '19:04'), arrDelayMin: 39, dataQuality: 'partial', stops: [st('Kd', 'DK', 'board'), st('Od', 'DK', 'through'), st('M', 'SE', 'through'), st('N', 'SE', 'alight')] }),
  leg({ id: '7256', journeyId: 'j1', operatorId: 'vasttagen', trainType: 'regina', distanceM: 43_000, dep: T('2026-10-20', '19:20'), arr: T('2026-10-20', '19:54'), arrDelayMin: 3, stops: [st('N', 'SE', 'board'), st('Jö', 'SE', 'alight')] }),
];

describe('passport', () => {
  const p = computePassport(day, { includeCommuter: true, comparison: 'flight' });

  it('adds up distance, time, trains, journeys and stations', () => {
    expect(p.totals.distanceM).toBe(576_000);
    expect(p.totals.trains).toBe(2);
    expect(p.totals.journeys).toBe(1);
    expect(p.totals.minutes).toBe(363 + 34);
    // Kolding, Nässjö, Jönköping: got on or off there. Passing through Odense and Malmö doesn't count.
    expect(p.totals.stations).toBe(3);
    expect(p.totals.countries).toBe(2);
    expect(p.totals.borderCrossings).toBe(1);
  });

  it('counts delays only from trains with full actual times', () => {
    expect(p.delays.basedOn).toBe(1);
    expect(p.delays.onTimePct).toBe(100); // +3 is within the 5-minute on-time threshold
    expect(p.delays.bands).toEqual({ on_time: 0, slight: 1, late: 0, very_late: 0 });
  });

  it('ranks operators and train types', () => {
    expect(p.operators.map((o) => o.key)).toEqual(['snalltaget', 'vasttagen']);
    expect(p.trainTypes.find((t) => t.key === 'regina')?.distanceM).toBe(43_000);
    expect(p.records.longestDistance?.legId).toBe('306');
  });

  it('filters by year and leaves commuter trains out when asked', () => {
    const more = [...day, leg({ id: 'sl', category: 'commuter', product: 'commuter', operatorId: 'sl', schedDep: T('2025-05-01', '08:00') })];
    expect(computePassport(more, { includeCommuter: false, comparison: 'flight' }).totals.trains).toBe(2);
    expect(computePassport(more, { year: 2025, includeCommuter: true, comparison: 'flight' }).totals.trains).toBe(1);
    expect(computePassport(more, { includeCommuter: true, comparison: 'flight' }).years).toEqual([2026, 2025]);
  });

  it("doesn't count a cancelled train as ridden", () => {
    const p2 = computePassport([...day, leg({ id: 'x', canceled: true })], { includeCommuter: true, comparison: 'flight' });
    expect(p2.totals.trains).toBe(2);
    expect(p2.totals.cancellations).toBe(1);
  });
});

describe('CO₂ (SPEC §15)', () => {
  it('saves (comparison − train) × km', () => {
    const r = co2(1000, 'flight');
    expect(r.trainKg).toBeCloseTo(0.27, 5);
    expect(r.comparisonKg).toBeCloseTo(170, 5);
    expect(r.savedKg).toBeCloseTo(169.73, 5);
    expect(co2(100, 'car_1').savedKg).toBeCloseTo(18.973, 3);
  });
});
