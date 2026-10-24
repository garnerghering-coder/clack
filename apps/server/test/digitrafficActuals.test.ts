import { beforeEach, describe, expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { LOCAL_USER_ID, openDb } from '../src/db/client.js';
import { legStops, legs } from '../src/db/schema.js';
import { digitrafficStops, fetchTrain, resetDigitrafficCaches, vehicleOf, type DtComposition, type StopForDt } from '../src/digitraffic/trains.js';
import { refreshLegActuals } from '../src/legs/actuals.js';
import { createLeg, getLeg } from '../src/legs/legs.js';
import { typeFromVehicle } from '../src/legs/trainTypes.js';
import { fetchFinlandPositions, trackOnce } from '../src/live/tracker.js';
import { fakeDigitraffic, fixture, HAPARANDA, seedFinland, seedTrip, trainFixture } from './finlandFixtures.js';

const Z = (iso: string) => Date.parse(iso);
const ic27 = trainFixture('ic-27');
const ic24 = trainFixture('ic-24-causes');
const ic407 = trainFixture('ic-407-haparanda');
const ic142 = trainFixture('ic-142-short-turned');
const hdm750 = trainFixture('hdm-750-cancelled');

beforeEach(() => resetDigitrafficCaches());

const rowOf = (t: typeof ic27, code: string, type: 'ARRIVAL' | 'DEPARTURE') => t.timeTableRows.find((r) => r.stationShortCode === code && r.type === type)!;
const stop = (seq: number, role: string, fi: string, arr: string | null, dep: string | null): StopForDt => ({ seq, role, sig: null, schedArr: arr ? Z(arr) : null, schedDep: dep ? Z(dep) : null, fi });

describe('Digitraffic actuals for a leg', () => {
  it('takes actual times and platform from the matching call, and the platform you board at wins', () => {
    const m = digitrafficStops(
      [stop(1, 'board', 'HKI', null, '2026-10-24T11:20:00Z'), stop(2, 'through', 'PSL', '2026-10-24T11:25:00Z', '2026-10-24T11:26:00Z'), stop(3, 'alight', 'TPE', '2026-10-24T12:58:00Z', null)],
      ic27,
      Z('2026-10-24T19:00:00Z'),
    );
    expect(m.get(1)).toMatchObject({ actualDep: Z(ic27.timeTableRows[0]!.actualTime!), platform: '7', source: 'digitraffic', canceled: false, trvTrainNumber: null });
    expect(m.get(2)).toMatchObject({ platform: '3' });
    expect(m.get(2)!.actualArr).toBe(Z(rowOf(ic27, 'PSL', 'ARRIVAL').actualTime!));
    expect(m.get(3)!.actualArr).toBe(Z(rowOf(ic27, 'TPE', 'ARRIVAL').actualTime!));
    expect(m.get(3)!.platform).toBe('2');
  });

  it('calls an "actual" time that is still ahead an estimate, and keeps a live estimate as expected', () => {
    const first = ic27.timeTableRows[0]!;
    const future: typeof ic27 = { ...ic27, timeTableRows: [{ ...first, actualTime: '2026-10-24T11:24:00Z' }, { ...ic27.timeTableRows[1]!, actualTime: undefined, liveEstimateTime: '2026-10-24T11:27:00Z' }] };
    const m = digitrafficStops([stop(1, 'board', 'HKI', null, '2026-10-24T11:20:00Z'), stop(2, 'alight', 'PSL', '2026-10-24T11:25:00Z', null)], future, Z('2026-10-24T11:10:00Z'));
    expect(m.get(1)).toMatchObject({ actualDep: null, estimatedDep: Z('2026-10-24T11:24:00Z') });
    expect(m.get(2)).toMatchObject({ actualArr: null, estimatedArr: Z('2026-10-24T11:27:00Z') });
  });

  it('never counts a technical stop or a pass-through as a place you rode', () => {
    // IC 407 stops at Haapamäki-like technical points (HD, commercialStop false): a leg stop there gets nothing.
    const hd = ic407.timeTableRows.find((r) => r.stationShortCode === 'HD' && r.type === 'ARRIVAL')!;
    expect(hd.trainStopping).toBe(true);
    expect(hd.commercialStop).toBe(false);
    const m = digitrafficStops([stop(1, 'through', 'HD', hd.scheduledTime, null)], ic407, Z('2026-10-24T19:00:00Z'));
    expect(m.size).toBe(0);
    // Nor does a station Digitraffic doesn't serve (no short code).
    expect(digitrafficStops([stop(1, 'through', null as unknown as string, hd.scheduledTime, null)], ic407).size).toBe(0);
  });

  it('reports Haparanda from the Finnish train, with the delay in minutes', () => {
    const hpa = ic407.timeTableRows.find((r) => r.stationShortCode === 'HPA')!;
    const m = digitrafficStops([stop(1, 'board', 'TOR', null, '2026-10-24T18:22:00Z'), stop(2, 'alight', 'HPA', hpa.scheduledTime, null)], ic407, Z('2026-10-24T19:00:00Z'));
    expect(m.get(2)).toMatchObject({ actualArr: Z(hpa.actualTime!), platform: '1', source: 'digitraffic' });
    expect(Math.round((m.get(2)!.actualArr! - Z(hpa.scheduledTime)) / 60_000)).toBe(15);
  });

  it('marks cancelled calls, whole trains included, and keeps the codes of the causes', () => {
    const cancelled = digitrafficStops([stop(1, 'board', 'SL', null, '2026-10-22T17:56:00Z'), stop(2, 'alight', 'PAR', '2026-10-22T18:49:00Z', null)], hdm750);
    expect(hdm750.cancelled).toBe(true);
    expect(cancelled.get(1)!.canceled).toBe(true);
    expect(cancelled.get(2)!.canceled).toBe(true);
    // A train that is cancelled between two places and runs again (IC 142 on 2026-10-23): only those calls.
    const pm = ic142.timeTableRows.find((r) => r.stationShortCode === 'PM' && r.type === 'DEPARTURE')!;
    const part = digitrafficStops([stop(1, 'board', 'PM', null, pm.scheduledTime), stop(2, 'alight', 'TPE', rowOf(ic142, 'TPE', 'ARRIVAL').scheduledTime, null)], ic142);
    expect(ic142.cancelled).toBe(false);
    expect(part.get(1)!.canceled).toBe(true);
    expect(part.get(2)!.canceled).toBe(false);
    // Causes from a call that has them: its most specific code, as the app's own text lookup wants it.
    const withCause = ic24.timeTableRows.find((r) => r.causes?.length)!;
    const c = digitrafficStops([stop(1, 'alight', withCause.stationShortCode, withCause.scheduledTime, null)], ic24);
    expect(c.get(1)!.causes).toEqual([{ src: 'digitraffic', code: withCause.causes![0]!.thirdCategoryCode ?? withCause.causes![0]!.detailedCategoryCode ?? withCause.causes![0]!.categoryCode }]);
    expect(c.get(1)!.deviations).toEqual([]);
  });

  it('names the vehicle from a composition: a locomotive, or the unit itself for a multiple unit', () => {
    expect(vehicleOf(fixture<DtComposition>('composition-27'))).toBe('Sr3');
    expect(vehicleOf(fixture<DtComposition>('composition-8192'))).toBe('Sm5');
    expect(vehicleOf({ trainNumber: 1, departureDate: 'x', journeySections: [] })).toBeNull();
    // Rules decide the type; a unit nobody wrote a rule for decides nothing.
    expect(typeFromVehicle('vr-fi', 'intercity', 'Sr3')).toBe('fi_sr3_ic');
    expect(typeFromVehicle('vr-fi', 'commuter', 'Sm5')).toBe('fi_sm5');
    expect(typeFromVehicle('vr-fi', 'high_speed', 'Sm6')).toBeNull();
    expect(typeFromVehicle('vr-fi', 'commuter', null)).toBeNull();
  });

  it('fetches one train and asks again only after 30 seconds', async () => {
    const { fetchImpl, seen } = fakeDigitraffic({ 'trains/2026-10-24/27': [ic27] });
    expect((await fetchTrain('2026-10-24', '27', { fetchImpl, now: 0 }))?.trainNumber).toBe(27);
    await fetchTrain('2026-10-24', '27', { fetchImpl, now: 10_000 });
    expect(seen).toHaveLength(1);
    await fetchTrain('2026-10-24', '27', { fetchImpl, now: 40_000 });
    expect(seen).toHaveLength(2);
  });
});

describe('following your own Finnish train', () => {
  it('reads a train’s newest GPS fix from the list of every running train', async () => {
    const { fetchImpl } = fakeDigitraffic({ 'train-locations/latest': fixture('locations') });
    const m = await fetchFinlandPositions(['407|2026-10-24', '9999|2026-10-24'], Z('2026-10-24T18:46:00Z'), fetchImpl);
    expect([...m.keys()]).toEqual(['407|2026-10-24']);
    expect(m.get('407|2026-10-24')).toMatchObject({ lat: 65.82855, lon: 24.127751, at: Z('2026-10-24T18:45:10Z') });
    // Ten minutes old is too old.
    expect((await fetchFinlandPositions(['407|2026-10-24'], Z('2026-10-24T18:56:00Z'), fetchImpl)).size).toBe(0);
  });

  it('puts the leg on the map from Digitraffic, and asks Trafikverket nothing about a number it might share', async () => {
    const db = openDb(':memory:');
    seedFinland(db);
    const key = seedTrip(db, ic407);
    const id = createLeg(db, LOCAL_USER_ID, { tripKey: key, serviceDate: '2026-10-24', fromSeq: 4, toSeq: 5 }, Z('2026-10-24T10:00:00Z'));
    // Not yet at Haparanda: its arrival is only expected, for 18:50.
    const running = { ...ic407, timeTableRows: ic407.timeTableRows.map((r) => (r.stationShortCode === 'HPA' ? { ...r, actualTime: undefined, liveEstimateTime: '2026-10-24T18:50:00Z' } : r)) };
    const { fetchImpl, seen } = fakeDigitraffic({ 'trains/2026-10-24/407': [running], 'train-locations/latest': fixture('locations'), 'compositions/*': { trainNumber: 407, journeySections: [] } });
    const updates = await trackOnce(db, { now: () => Z('2026-10-24T18:45:30Z'), fetchImpl });
    expect(updates.map((u) => u.legId)).toEqual([id]);
    expect(updates[0]!.live).toMatchObject({ positionSource: 'gps', lat: 65.82855 });
    expect(seen).toContain('train-locations/latest');
  });
});

describe('refreshing a Finnish leg', () => {
  function setup(train: typeof ic27, from: number, to: number) {
    const db = openDb(':memory:');
    seedFinland(db);
    const key = seedTrip(db, train);
    const id = createLeg(db, LOCAL_USER_ID, { tripKey: key, serviceDate: train.departureDate, fromSeq: from, toSeq: to }, Z('2026-10-24T10:00:00Z'));
    return { db, id };
  }

  it('fills a Helsinki to Tampere leg from Digitraffic and nothing from Trafikverket', async () => {
    const { db, id } = setup(ic27, 1, 4);
    const { fetchImpl, seen } = fakeDigitraffic({ 'trains/2026-10-24/27': [ic27], 'compositions/2026-10-24/27': fixture('composition-27') });
    // A Trafikverket call would hit this fetch and fail as a 404: it must not happen.
    const quality = await refreshLegActuals(db, id, { now: Z('2026-10-24T14:00:00Z'), fetchImpl });
    expect(quality).toBe('full');
    const leg = getLeg(db, LOCAL_USER_ID, id)!;
    expect(leg.depPlatform).toBe('7');
    expect(leg.actualDep).toEqual(new Date(ic27.timeTableRows[0]!.actualTime!));
    expect(leg.arrDelayMin).toBe(3);
    expect(leg.countryCodes).toEqual(['FI']);
    expect(leg.trainType).toBe('fi_sr3_ic');
    expect(leg.trainTypeSource).toBe('composition');
    const stops = db.select().from(legStops).where(eq(legStops.legId, id)).all();
    // Every stop of the train (the ones before and after your ride too), and only Digitraffic's.
    expect(stops.length).toBeGreaterThan(4);
    expect(stops.every((s) => s.reportSource === 'digitraffic')).toBe(true);
    expect(seen.every((p) => p.startsWith('trains/') || p.startsWith('compositions/'))).toBe(true);
  });

  it('counts Tornio to Haparanda as ridden: the Finnish side and the Swedish stop, both from Digitraffic', async () => {
    const { db, id } = setup(ic407, 4, 5);
    const { fetchImpl } = fakeDigitraffic({ 'trains/2026-10-24/407': [ic407], 'compositions/*': { trainNumber: 407, departureDate: '2026-10-24', journeySections: [{ locomotives: [{ locomotiveType: 'Sr3' }] }] } });
    await refreshLegActuals(db, id, { now: Z('2026-10-24T19:30:00Z'), fetchImpl });
    const leg = getLeg(db, LOCAL_USER_ID, id)!;
    expect(leg.countryCodes.sort()).toEqual(['FI', 'SE']);
    expect(leg.dataQuality).toBe('full');
    expect(leg.depDelayMin).toBe(13);
    expect(leg.arrDelayMin).toBe(14);
    expect(leg.depPlatform).toBe('1');
    const stops = db.select().from(legStops).where(eq(legStops.legId, id)).all();
    expect(stops.find((s) => s.stationId === HAPARANDA)?.reportSource).toBe('digitraffic');
    // A day and a half later it is frozen, with the ride counted.
    expect(db.select().from(legs).where(eq(legs.id, id)).get()?.status).toBe('snapshotted');
    expect(leg.ride).toBe('auto');
  });

  it('keeps asking Digitraffic for a ride far in the past (it answers for years), where Trafikverket would be too late', async () => {
    const { db, id } = setup(ic27, 1, 4);
    const { fetchImpl } = fakeDigitraffic({ 'trains/2026-10-24/27': [ic27] });
    // Twenty days later: Trafikverket's 4 days are long gone; Digitraffic's history is not.
    await refreshLegActuals(db, id, { now: Z('2026-11-13T12:00:00Z'), fetchImpl });
    expect(getLeg(db, LOCAL_USER_ID, id)!.dataQuality).toBe('full');
  });
});
