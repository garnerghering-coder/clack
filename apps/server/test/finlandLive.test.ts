import Fastify from 'fastify';
import { afterEach, describe, expect, it } from 'vitest';
import { liveMapRoutes } from '../src/routes/livemap.js';
import { openDb } from '../src/db/client.js';
import { FinlandFeed, callsOf } from '../src/livemap/finland.js';
import { LiveMapIngest, isMine, type LiveTrain } from '../src/livemap/ingest.js';
import { isPassengerTrain, resetDigitrafficCaches, type DtTrain } from '../src/digitraffic/trains.js';
import { fakeDigitraffic, fixture, HAPARANDA, seedFinland, seedTrip, trainFixture } from './finlandFixtures.js';

// Real answers from rata.digitraffic.fi, 2026-10-24: IC 27 (Helsinki to Rovaniemi), commuter train 8192
// (Leppävaara to Helsinki), IC 407 (Oulu to Haaparanta pohjoinen, which is Haparanda), their GPS and compositions.
const Z = (iso: string) => Date.parse(iso);
const ic27 = trainFixture('ic-27');
const hl8192 = trainFixture('commuter-8192');
const ic407 = trainFixture('ic-407-haparanda');
const locations = fixture<unknown[]>('locations');

function setup(trains: DtTrain[], now: string, opts: { gps?: boolean } = {}) {
  resetDigitrafficCaches();
  const db = openDb(':memory:');
  seedFinland(db);
  for (const t of trains) if (isPassengerTrain(t)) seedTrip(db, t);
  const { fetchImpl, seen } = fakeDigitraffic({
    'train-locations/latest': () => (opts.gps === false ? [] : locations),
    'live-trains': trains,
    'live-trains?version=*': [],
    'compositions/*': [
      { trainNumber: 27, departureDate: '2026-10-24', journeySections: [{ locomotives: [{ locomotiveType: 'Sr3' }] }] },
      { trainNumber: 8192, departureDate: '2026-10-24', journeySections: [{ locomotives: [{ locomotiveType: 'Sm5' }] }] },
    ],
  });
  const feed = new FinlandFeed(db, { fetchImpl, now: () => Z(now), graph: () => null });
  return { db, feed, seen, fetchImpl };
}

describe('Finland on the live map', () => {
  it('knows passenger trains from freight, shunting and the rest', () => {
    for (const t of fixture<DtTrain[]>('non-passenger')) expect(isPassengerTrain(t)).toBe(false);
    for (const t of [ic27, hl8192, ic407]) expect(isPassengerTrain(t)).toBe(true);
  });

  it('keeps only commercial calls at stations we know, with the delay so far carried to the ones after', () => {
    const known = new Set(['HKI', 'PSL', 'TPE', 'LPV', 'MÄK', 'PJM', 'VMO', 'HPL', 'ILA']);
    const calls = callsOf(hl8192, (c) => known.has(c));
    // Käpylä-style pass-through points (KHK) are not calls.
    expect(calls.map((c) => c.code)).toEqual(['LPV', 'MÄK', 'PJM', 'VMO', 'HPL', 'ILA', 'PSL', 'HKI']);
    expect(calls[0]).toMatchObject({ arr: null, dep: Z('2026-10-24T16:46:00Z') });
    expect(calls.at(-1)).toMatchObject({ arr: Z('2026-10-24T17:03:00Z'), dep: null, expArr: Z(hl8192.timeTableRows.at(-1)!.actualTime!) });
    // No estimate at the first stop of IC 27's fixture beyond the actuals: remove them and the last delay carries on.
    const open: DtTrain = { ...ic27, timeTableRows: ic27.timeTableRows.map((r, i) => (i < 6 ? r : { ...r, actualTime: undefined, liveEstimateTime: undefined })) };
    const c = callsOf(open, () => true);
    const sixth = ic27.timeTableRows[5]!;
    const delay = Z(sixth.actualTime ?? sixth.liveEstimateTime!) - Z(sixth.scheduledTime);
    const later = c.find((x) => x.code === ic27.timeTableRows[12]!.stationShortCode)!;
    expect(later.expArr! - later.arr!).toBe(delay);
  });

  it('picks up Finnish stations imported after the server (and the feed) started', () => {
    // The server starts this feed before the first Finnish import has finished; an index cached from then dropped every train.
    resetDigitrafficCaches();
    const db = openDb(':memory:');
    let t = Z('2026-10-24T18:00:00Z');
    const { fetchImpl } = fakeDigitraffic({});
    const feed = new FinlandFeed(db, { fetchImpl, now: () => t, graph: () => null });
    const station = (code: string) => (feed as unknown as { station: (c: string) => unknown }).station(code);
    expect(station('HKI')).toBeUndefined();
    seedFinland(db);
    t += 10_000; // still inside the 30 s retry pause
    expect(station('HKI')).toBeUndefined();
    t += 25_000;
    expect(station('HKI')).toMatchObject({ id: expect.any(String) });
  });

  it('draws a train from its GPS, with the delay from its calls and the unit type from its composition', async () => {
    const { feed } = setup([ic27, hl8192, ic407], '2026-10-24T18:50:30Z');
    await feed.poll();
    const t = feed.trains().find((x) => x.number === '27')!;
    expect(t).toMatchObject({ estimated: false, product: 'intercity', operatorId: 'vr-fi', trainType: 'IC', vehicle: 'Sr3', origin: 'Helsinki', destination: 'Rovaniemi' });
    expect(t.lat).toBeCloseTo(65.794751, 5);
    expect(t.lon).toBeCloseTo(24.540295, 5);
    expect(t.speedKmh).toBe(51);
    expect(t.delayMin).not.toBeNull();
    expect(t.tripKey).toBe('fi:27_20261024:test');
    expect(feed.upstreamAt).toBe(Z('2026-10-24T18:50:30Z'));
  });

  it('places a train without GPS from its calls, hollow, between the stations it left and reaches', async () => {
    // 16:55:30 UTC: commuter 8192 left Ilmala (16:55) and reaches Pasila at 16:57.
    const { feed } = setup([hl8192], '2026-10-24T16:56:10Z', { gps: false });
    await feed.poll();
    const [t] = feed.trains();
    expect(t).toMatchObject({ number: '8192', estimated: true, product: 'commuter', next: 'Pasila', destination: 'Helsinki', origin: 'Leppävaara', vehicle: 'Sm5' });
    const ila = { lat: 60.2, lon: 24.9 };
    expect(t!.lat).toBeGreaterThan(ila.lat);
    expect(t!.lat).toBeLessThan(60.22);
    // Not yet departed (two minutes before) it waits at its first station; long after arriving it is gone.
    const before = setup([hl8192], '2026-10-24T16:44:30Z', { gps: false });
    await before.feed.poll();
    expect(before.feed.trains()[0]).toMatchObject({ estimated: true, next: 'Leppävaara' });
    const after = setup([hl8192], '2026-10-24T17:30:00Z', { gps: false });
    await after.feed.poll();
    expect(after.feed.trains()).toEqual([]);
  });

  it('leaves freight and shunting off the map, even when they have GPS', async () => {
    const cargo = fixture<DtTrain[]>('non-passenger');
    const { feed } = setup([...cargo, hl8192], '2026-10-24T16:56:10Z');
    // A GPS fix for the freight train: nobody asked for it.
    feed.ingestLocations([{ trainNumber: cargo[0]!.trainNumber, departureDate: cargo[0]!.departureDate, timestamp: '2026-10-24T16:56:00Z', location: { type: 'Point', coordinates: [24.9, 60.2] }, speed: 60 }]);
    await feed.poll();
    expect(feed.trains().map((t) => t.number)).toEqual(['8192']);
  });

  it('treats Haparanda as a stop of the Finnish train, whatever country the station is in', async () => {
    const { feed, db } = setup([ic407], '2026-10-24T18:40:00Z', { gps: false });
    await feed.poll();
    const [t] = feed.trains();
    expect(t).toMatchObject({ number: '407', crossBorder: true, destination: 'Haparanda', next: 'Haparanda', delayMin: 15 });
    // Between Tornio and Haparanda, in the Tornio-Haparanda direction.
    expect(t!.lon).toBeGreaterThan(24.1);
    expect(db.$client.prepare('select id from stations where fi_id = ?').get('HPA')).toEqual({ id: HAPARANDA });
    // Standing at Haparanda once it has arrived (18:44 expected), until it leaves the map five minutes later.
    const arrived = setup([ic407], '2026-10-24T18:46:00Z', { gps: false });
    await arrived.feed.poll();
    expect(arrived.feed.trains()[0]).toMatchObject({ next: null, estimated: true });
    expect(arrived.feed.trains()[0]!.lat).toBeCloseTo(65.828, 2);
  });

  it('reads only what changed after the first full load, and starts over every half hour', async () => {
    let clock = Z('2026-10-24T16:56:10Z');
    const db = openDb(':memory:');
    seedFinland(db);
    seedTrip(db, hl8192);
    const full = [{ ...hl8192, version: 100 }];
    const { fetchImpl, seen } = fakeDigitraffic({ 'train-locations/latest': [], 'live-trains': full, 'live-trains?version=*': [{ ...hl8192, version: 105, cancelled: true }], 'compositions/*': [] });
    const feed = new FinlandFeed(db, { fetchImpl, now: () => clock, graph: () => null });
    await feed.pollTrains();
    clock += 31_000;
    await feed.pollTrains();
    expect(seen.filter((p) => p.startsWith('live-trains'))).toEqual(['live-trains', 'live-trains?version=100']);
    // The delta said it is cancelled: off the map.
    expect(feed.trains()).toEqual([]);
    clock += 31 * 60_000;
    await feed.pollTrains();
    expect(seen.filter((p) => p.startsWith('live-trains')).at(-1)).toBe('live-trains');
  });

  it('ignores a location that is not GPS and one older than the newest', async () => {
    const { feed } = setup([hl8192], '2026-10-24T16:56:10Z');
    await feed.pollTrains();
    const loc = (at: string, lon: number, extra: object = {}) => ({ trainNumber: 8192, departureDate: '2026-10-24', timestamp: at, location: { type: 'Point', coordinates: [lon, 60.2] }, speed: 40, ...extra });
    feed.ingestLocations([loc('2026-10-24T16:56:00Z', 24.9), loc('2026-10-24T16:55:00Z', 24.0), loc('2026-10-24T16:56:05Z', 25.0, { isGpsLocation: false })]);
    expect(feed.trains()[0]!.lon).toBeCloseTo(24.9, 5);
  });
});

describe('three feeds on one map', () => {
  let ingest: LiveMapIngest | null = null;
  afterEach(() => ingest?.stop());

  it('draws Finland beside Sweden and Norway, with ids that never collide, and stops drawing a train that is gone', async () => {
    const db = openDb(':memory:');
    seedFinland(db);
    seedTrip(db, hl8192);
    let delta: DtTrain[] = [];
    resetDigitrafficCaches();
    const { fetchImpl } = fakeDigitraffic({
      'train-locations/latest': [],
      'live-trains': [hl8192],
      'live-trains?version=*': () => delta,
      'compositions/*': [{ trainNumber: 8192, departureDate: '2026-10-24', journeySections: [{ locomotives: [{ locomotiveType: 'Sm5' }] }] }],
    });
    ingest = new LiveMapIngest(db, { fetchImpl, now: () => Z('2026-10-24T16:56:10Z'), graph: () => null, finland: true });
    // A Swedish train with the same number on the same day.
    ingest.trains.set('8192|2026-10-24', { id: '8192|2026-10-24', number: '8192', date: '2026-10-24', lat: 59.3, lon: 18.0, bearing: 0, speedKmh: 90, at: 1, estimated: false, operatorId: 'sj', productName: null, product: 'regional', trainType: null, origin: 'A', destination: 'B', next: null, nextEta: null, delayMin: 0, mine: false });
    const feed = (ingest as unknown as { fi: FinlandFeed }).fi;
    await feed.poll();
    ingest.applyFinland();
    expect([...ingest.trains.keys()].sort()).toEqual(['8192|2026-10-24', 'fi:8192|2026-10-24']);
    expect(ingest.trains.get('fi:8192|2026-10-24')).toMatchObject({ product: 'commuter', trainType: 'fi_sm5', tripKey: 'fi:8192_20261024:test', operatorId: 'vr-fi' });
    expect(ingest.finlandAt).toBe(Z('2026-10-24T16:56:10Z'));
    // Swedish and Norwegian trains are untouched when Finland's train leaves.
    delta = [{ ...hl8192, cancelled: true }];
    (feed as unknown as { trainsAt: number }).trainsAt = 0;
    await feed.pollTrains();
    ingest.applyFinland();
    expect([...ingest.trains.keys()]).toEqual(['8192|2026-10-24']);
  });

  it('serves a Finnish train over the API: its trip, its stops from Digitraffic, and the status of the feed', async () => {
    const db = openDb(':memory:');
    seedFinland(db);
    seedTrip(db, ic27);
    resetDigitrafficCaches();
    const { fetchImpl } = fakeDigitraffic({
      'train-locations/latest': locations,
      'live-trains': [ic27],
      'compositions/*': [{ trainNumber: 27, departureDate: '2026-10-24', journeySections: [{ locomotives: [{ locomotiveType: 'Sr3' }] }] }],
      'trains/2026-10-24/27': [ic27],
    });
    ingest = new LiveMapIngest(db, { fetchImpl, now: () => Z('2026-10-24T18:50:30Z'), graph: () => null, finland: true });
    const feed = (ingest as unknown as { fi: FinlandFeed }).fi;
    await feed.poll();
    ingest.applyFinland();
    const app = Fastify();
    app.decorateRequest('userId', '');
    app.addHook('onRequest', async (req) => {
      req.userId = 'local';
    });
    await app.register(liveMapRoutes(db, ingest));
    try {
      const one = (await app.inject('/live/trains/fi:27%7C2026-10-24')).json();
      expect(one.train).toMatchObject({ id: 'fi:27|2026-10-24', trainType: 'fi_sr3_ic', mine: false });
      expect(one.trip).toMatchObject({ key: 'fi:27_20261024:test', serviceDate: '2026-10-24' });
      const stops = (await app.inject('/live/trains/fi:27%7C2026-10-24/stops')).json().stops;
      expect(stops[0]).toMatchObject({ name: 'Helsinki', platform: '7', source: 'digitraffic', passed: true });
      // By number and day, the way a board row or a follow opens it.
      const byNumber = (await app.inject('/trains/27/2026-10-24')).json();
      expect(byNumber).toMatchObject({ number: '27', operatorId: 'vr-fi', trip: { key: 'fi:27_20261024:test' } });
      expect(byNumber.live).toMatchObject({ id: 'fi:27|2026-10-24' });
      const status = (await app.inject('/live/status')).json();
      expect(status.finlandAt).toBe(Z('2026-10-24T18:50:30Z'));
      expect(status.trains).toBe(1);
    } finally {
      await app.close();
    }
  });

  it('marks a Finnish train as yours by its trip, or by its number when the timetable lacks the trip', () => {
    const t = (extra: Partial<LiveTrain>): LiveTrain => ({
      id: 'fi:8192|2026-10-24', number: '8192', date: '2026-10-24', lat: 0, lon: 0, bearing: null, speedKmh: null, at: 1, estimated: false, operatorId: 'vr-fi', productName: null, product: 'commuter', trainType: null,
      origin: null, destination: null, next: null, nextEta: null, delayMin: null, mine: false, ...extra,
    });
    expect(isMine(t({ tripKey: 'fi:8192_20261024:abc' }), new Set(['trip:fi:8192_20261024:abc|2026-10-24']))).toBe(true);
    expect(isMine(t({ tripKey: null }), new Set(['fi:8192|2026-10-24']))).toBe(true);
    // A Swedish train 8192 of the same day is not it, nor is another day.
    expect(isMine(t({ tripKey: null }), new Set(['8192|2026-10-24']))).toBe(false);
    expect(isMine(t({ tripKey: null }), new Set(['fi:8192|2026-10-23']))).toBe(false);
    // Sweden's and Norway's rules are as before.
    expect(isMine({ ...t({}), id: '8192|2026-10-24', tripKey: undefined }, new Set(['8192|2026-10-24']))).toBe(true);
    expect(isMine({ ...t({ tripKey: 'no:x:1' }), id: 'no:8192|2026-10-24' }, new Set(['trip:no:x:1|2026-10-24']))).toBe(true);
  });
});
