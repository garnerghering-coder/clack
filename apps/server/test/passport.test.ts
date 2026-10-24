import { describe, expect, it } from 'vitest';
import { co2, co2FactorsFor, computeMilestones, computePassport, loadPassportLegs, type PassportLeg, type PassportStop } from '../src/stats/passport.js';
import { LOCAL_USER_ID, openDb } from '../src/db/client.js';
import { refreshLegActuals } from '../src/legs/actuals.js';
import { createLeg } from '../src/legs/legs.js';
import { fakeDigitraffic, seedFinland, seedTrip, trainFixture } from './finlandFixtures.js';

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

describe('Finland in the passport', () => {
  // Tornio (FI) to Haparanda (SE) on IC 407, 2026-10-24: a border crossing in a single leg.
  const tornio = leg({ id: '407', operatorId: 'vr-fi', product: 'intercity', trainType: 'fi_sr3_ic', distanceM: 2_000, stops: [st('fi:TOR', 'FI', 'board'), st('740000372', 'SE', 'alight')], tz: 'Europe/Helsinki' });
  const opts = { includeCommuter: true, comparison: 'flight' } as const;

  it('counts Tornio to Haparanda as two countries and one border crossing', () => {
    const p = computePassport([tornio], opts);
    expect(p.totals.borderCrossings).toBe(1);
    expect(p.totals.countries).toBe(2);
    expect(p.countries.map((c) => c.code).sort()).toEqual(['FI', 'SE']);
    expect(computeMilestones([tornio]).achieved.map((m) => `${m.family}:${m.target}`)).toContain('borderCrossings:1');
  });

  it("decides the day, month and year in the boarding station's zone", () => {
    // 00:30 on 1 April in Helsinki is 23:30 on 31 March in Stockholm.
    const late = leg({ id: 'fi-late', dep: Date.parse('2026-03-31T21:30:00Z'), arr: Date.parse('2026-03-31T22:30:00Z'), schedDep: Date.parse('2026-03-31T21:30:00Z'), tz: 'Europe/Helsinki' });
    const stockholm = { ...late, id: 'se-late', tz: undefined };
    const two = (l: PassportLeg) => computePassport([l, { ...l, id: `${l.id}2` }], opts);
    expect(two(late).flavor.busiestMonth?.month).toBe('2026-04');
    expect(two(stockholm).flavor.busiestMonth?.month).toBe('2026-03');
    // New Year in Helsinki comes an hour before Stockholm's.
    const ny = leg({ id: 'ny', dep: Date.parse('2026-12-31T22:30:00Z'), arr: Date.parse('2026-12-31T23:30:00Z'), schedDep: Date.parse('2026-12-31T22:30:00Z'), tz: 'Europe/Helsinki' });
    expect(computePassport([ny], opts).years).toEqual([2027]);
    expect(computePassport([{ ...ny, tz: undefined }], opts).years).toEqual([2026]);
  });

  it("uses Sweden's CO2 factors for Norway and Finland, until they have figures of their own", () => {
    expect(co2FactorsFor('FI')).toBe(co2FactorsFor('SE'));
    expect(co2FactorsFor('NO')).toBe(co2FactorsFor('SE'));
    expect(co2FactorsFor(undefined)).toBe(co2FactorsFor('SE'));
    expect(computePassport([tornio], opts).co2.trainKg).toBeCloseTo(co2(2, 'flight').trainKg, 8);
  });

  it('reads a ridden Finnish leg from the database with the Helsinki zone', async () => {
    const db = openDb(':memory:');
    seedFinland(db);
    const ic407 = trainFixture('ic-407-haparanda');
    const key = seedTrip(db, ic407);
    const id = createLeg(db, LOCAL_USER_ID, { tripKey: key, serviceDate: '2026-10-24', fromSeq: 4, toSeq: 5 }, Date.parse('2026-10-24T10:00:00Z'));
    const { fetchImpl } = fakeDigitraffic({ 'trains/2026-10-24/407': [ic407] });
    await refreshLegActuals(db, id, { now: Date.parse('2026-10-24T20:30:00Z'), fetchImpl });
    const [l] = loadPassportLegs(db, LOCAL_USER_ID, Date.parse('2026-10-25T10:00:00Z'));
    expect(l).toMatchObject({ id, tz: 'Europe/Helsinki', operatorId: 'vr-fi', product: 'intercity', trainNumber: '407' });
    expect(l!.stops.map((x) => x.country)).toEqual(['FI', 'SE']);
    expect(computePassport([l!], opts).totals.borderCrossings).toBe(1);
  });
});
