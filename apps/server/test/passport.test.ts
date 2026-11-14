import { describe, expect, it } from 'vitest';
import { ARCTIC_CIRCLE_LAT, COUNTRY_LENGTH_KM, EUROPE_KM, MILESTONES, MILESTONE_TIERS, co2, co2FactorsFor, computeMilestones, homeCountryOf, computePassport, loadPassportLegs, type PassportLeg, type PassportStop } from '../src/stats/passport.js';
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
    // The bar agrees with the number (polish pass 1): +3 is on time in both.
    expect(p.delays.bands).toEqual({ on_time: 1, slight: 0, late: 0, very_late: 0 });
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

  it("uses each country's own published train figure, with Sweden's car and flight comparisons", () => {
    expect(co2FactorsFor('FI').train.g_per_pkm).toBe(1.1);
    expect(co2FactorsFor('NO').train.g_per_pkm).toBe(7);
    expect(co2FactorsFor('DK').train.g_per_pkm).toBe(42);
    expect(co2FactorsFor('DK', 'commuter').train.g_per_pkm).toBe(11);
    expect(co2FactorsFor('DK').comparisons).toEqual(co2FactorsFor('SE').comparisons);
    expect(co2FactorsFor(undefined).train.g_per_pkm).toBe(co2FactorsFor('SE').train.g_per_pkm);
    expect(computePassport([tornio], opts).co2.trainKg).toBeCloseTo(co2(2, 'flight', co2FactorsFor(tornio.stops[0]!.country)).trainKg, 8);
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

describe('milestones: levels and new families', () => {
  const keys = (legs: PassportLeg[], home?: 'SE' | 'NO' | 'FI') => computeMilestones(legs, home).achieved.map((m) => `${m.family}:${m.target}`);
  const hour = 3_600_000;
  const at = (i: number, p: Partial<PassportLeg> = {}) => leg({ id: `l${i}`, dep: 1_000_000 + i * 10 * hour, arr: 1_000_000 + i * 10 * hour + hour, schedDep: 1_000_000 + i * 10 * hour, ...p });

  // Polish pass 1's families.
  const day = 24 * hour;
  const stAt = (id: string, country: string, role: string, lat: number): PassportStop => ({ stationId: id, name: id, country, lat, lon: 15, role });
  // 2026-01-05 is a Monday; 05:30 in Stockholm (UTC+1 in winter) is 04:30Z.
  const monday = Date.UTC(2026, 0, 5, 4, 30);

  it('early bird, weekender and a streak of days', () => {
    const north = (i: number) => [stAt('A', 'SE', 'board', 59), stAt('B', 'SE', 'alight', 59.5)];
    const legs = Array.from({ length: 7 }, (_, i) => leg({ id: `d${i}`, dep: monday + i * day, arr: monday + i * day + hour, schedDep: monday + i * day, stops: north(i) }));
    const k = keys(legs);
    expect(k).toEqual(expect.arrayContaining(['earlyBird:1', 'earlyBird:5', 'streak:3', 'streak:7']));
    // Saturday and Sunday of that week: two weekend trips, short of the first level (5).
    expect(k).not.toContain('weekender:5');
  });

  it('every month and four seasons of one year, and the capitals', () => {
    const caps = ['740000001', '760000100', '860000626', 'fi:HKI'];
    const legs = Array.from({ length: 12 }, (_, m) => leg({
      id: `m${m}`, dep: Date.UTC(2026, m, 10, 10), arr: Date.UTC(2026, m, 10, 12), schedDep: Date.UTC(2026, m, 10, 10),
      stops: [stAt(caps[m % 4]!, 'SE', 'board', 59), stAt('X', 'SE', 'alight', 59)],
    }));
    expect(keys(legs)).toEqual(expect.arrayContaining(['everyMonth:12', 'fourSeasons:4', 'capitals:4']));
  });

  it('the far north counts from 59°N, the far south below 55.5°N, and Öresund crossings', () => {
    const kiruna = leg({ id: 'k', stops: [stAt('S', 'SE', 'board', 59.3), stAt('K', 'SE', 'alight', 67.86)] });
    expect(keys([kiruna])).toContain('farNorth:8');
    expect(keys([kiruna])).not.toContain('farNorth:9');
    const ore = leg({ id: 'o', stops: [stAt('M', 'SE', 'board', 55.6), stAt('C', 'DK', 'alight', 55.67)] });
    expect(keys([ore])).toContain('oresund:1');
    expect(keys([ore])).not.toContain('farSouth:1');
    const ystad = leg({ id: 'y', stops: [stAt('M', 'SE', 'board', 55.6), stAt('Y', 'SE', 'alight', 55.43)] });
    expect(keys([ystad])).toContain('farSouth:1');
  });

  it('a run of on-time trips breaks on a late one; an hour late counts once as patient', () => {
    const timed = (i: number, delay: number) => at(i, { dataQuality: 'full', arrDelayMin: delay, stops: [stAt('A', 'SE', 'board', 59), stAt('B', 'SE', 'alight', 59)] });
    const legs = [...Array.from({ length: 9 }, (_, i) => timed(i, 2)), timed(9, 61), ...Array.from({ length: 10 }, (_, i) => timed(10 + i, 0))];
    const k = keys(legs);
    expect(k).toContain('onTimeRun:10');
    expect(k).toContain('patient:1');
  });

  it('every level has a tier, bronze to platinum', () => {
    for (const [family, levels] of Object.entries(MILESTONES)) {
      expect(MILESTONE_TIERS[family as keyof typeof MILESTONES].length).toBe(levels.length);
    }
  });

  it('border crossings and night trains have four levels', () => {
    const cross = (i: number) => at(i, { product: 'night', stops: [st('A', 'SE', 'board'), st('B', 'NO', 'alight')] });
    const five = keys(Array.from({ length: 5 }, (_, i) => cross(i)));
    expect(five).toEqual(expect.arrayContaining(['borderCrossings:1', 'borderCrossings:5', 'nightTrains:1', 'nightTrains:5']));
    expect(five).not.toContain('borderCrossings:10');
  });

  it('longest train is a maximum, not a sum', () => {
    expect(keys([at(0, { distanceM: 200_000 }), at(1, { distanceM: 200_000 })])).not.toContain('longestTrainKm:300');
    expect(keys([at(0, { distanceM: 200_000 }), at(1, { distanceM: 520_000 })])).toEqual(expect.arrayContaining(['longestTrainKm:300', 'longestTrainKm:500']));
  });

  it('hours on board add up the time on the train', () => {
    expect(keys(Array.from({ length: 10 }, (_, i) => at(i)))).toContain('hoursOnBoard:10');
    expect(keys(Array.from({ length: 9 }, (_, i) => at(i)))).not.toContain('hoursOnBoard:10');
  });

  it('train types count only known, distinct types', () => {
    const five = ['a', 'b', 'c', 'd', 'e'].map((t, i) => at(i, { trainType: t }));
    expect(keys(five)).toContain('trainTypes:5');
    expect(keys([...five.slice(0, 4), at(9, { trainType: null }), at(10, { trainType: null }), at(11, { trainType: 'a' })])).not.toContain('trainTypes:5');
  });

  it('every kind of train needs all five, and heritage is not one of them', () => {
    const kinds = ['high_speed', 'intercity', 'night', 'regional', 'commuter'];
    expect(keys(kinds.slice(0, 4).map((p, i) => at(i, { product: p })).concat(at(9, { product: 'heritage' })))).not.toContain('kindsOfTrain:5');
    expect(keys(kinds.map((p, i) => at(i, { product: p })))).toContain('kindsOfTrain:5');
  });

  it('crossing the Arctic Circle: consecutive stops on either side of it (Boden → Narvik)', () => {
    const north = (id: string, lat: number, role: string) => ({ ...st(id, 'SE', role), lat });
    const boden = at(0, { stops: [north('Boden', 65.83, 'board'), north('Gällivare', 67.14, 'through'), north('Narvik', 68.43, 'alight')] });
    expect(keys([boden])).toContain('arcticCircle:1');
    expect(keys([at(1, { stops: [north('A', 65.0, 'board'), north('B', 66.0, 'alight')] })])).not.toContain('arcticCircle:1');
    expect(ARCTIC_CIRCLE_LAT).toBeCloseTo(66.5642, 3);
  });

  it('the length of your home country depends on which country that is', () => {
    const ride = (km: number) => [at(0, { distanceM: km * 1000 })];
    expect(keys(ride(1_600), 'SE')).toContain('homeLength:1');
    expect(keys(ride(1_600), 'NO')).not.toContain('homeLength:1');
    expect(keys(ride(1_700), 'NO')).toContain('homeLength:1');
    expect(keys(ride(1_160), 'FI')).toContain('homeLength:1');
    expect(keys(ride(1_150), 'FI')).not.toContain('homeLength:1');
    expect(COUNTRY_LENGTH_KM).toEqual({ SE: 1_572, NO: 1_699, FI: 1_157, DK: 368 });
  });

  it('the length of Europe is a great-circle figure of about 4,360 km', () => {
    expect(EUROPE_KM).toBeGreaterThan(4_300);
    expect(EUROPE_KM).toBeLessThan(4_400);
    expect(keys([at(0, { distanceM: (EUROPE_KM + 1) * 1000 })])).toContain('europeLength:1');
    expect(keys([at(0, { distanceM: (EUROPE_KM - 1) * 1000 })])).not.toContain('europeLength:1');
  });

  it('puts the home country in the passport and the flavor lines', () => {
    const p = computePassport([at(0, { distanceM: 1_699_000 })], { includeCommuter: true, comparison: 'flight', home: 'NO' });
    expect(p.home).toBe('NO');
    expect(p.flavor.homeLengths).toBeCloseTo(1, 5);
    expect(p.flavor.europeLengths).toBeCloseTo(1_699 / EUROPE_KM, 5);
    expect(p.flavor.swedenLengths).toBeCloseTo(1_699 / 1_572, 5);
  });

  it('home country: the setting, else the first trip, else Sweden', () => {
    const first = at(0, { stops: [st('H', 'FI', 'board'), st('T', 'FI', 'alight')] });
    const later = at(5, { stops: [st('A', 'SE', 'board'), st('B', 'SE', 'alight')] });
    expect(homeCountryOf('NO', [first])).toBe('NO');
    expect(homeCountryOf(undefined, [later, first])).toBe('FI');
    expect(homeCountryOf(undefined, [])).toBe('SE');
    expect(homeCountryOf('DK', [])).toBe('DK');
    expect(homeCountryOf('DE', [])).toBe('SE');
  });
});
