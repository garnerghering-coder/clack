import Fastify from 'fastify';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { BoardHub } from '../src/boards/hub.js';
import { boardRoutes } from '../src/routes/boards.js';
import { normalizeFinlandBoard, type FinlandBoardContext } from '../src/boards/finland.js';
import { openDb } from '../src/db/client.js';
import { resetDigitrafficCaches } from '../src/digitraffic/trains.js';
import { fakeDigitraffic, fixture, HAPARANDA, seedFinland, seedTrip, trainFixture } from './finlandFixtures.js';

const Z = (iso: string) => Date.parse(iso);
const ic27 = trainFixture('ic-27');
const hl8192 = trainFixture('commuter-8192');
const ic407 = trainFixture('ic-407-haparanda');
const ic24 = trainFixture('ic-24-causes');
const hdm750 = trainFixture('hdm-750-cancelled');
const names: Record<string, string> = { HKI: 'Helsinki', TPE: 'Tampere', ROI: 'Rovaniemi', PSL: 'Pasila', OL: 'Oulu', HPA: 'Haparanda', TOR: 'Tornio', LPV: 'Leppävaara', SL: 'Savonlinna', PAR: 'Parikkala' };

const ctx = (extra: Partial<FinlandBoardContext> = {}): FinlandBoardContext => ({
  type: 'departures',
  now: Z('2026-10-24T11:00:00Z'),
  code: 'HKI',
  from: Z('2026-10-24T10:00:00Z'),
  to: Z('2026-10-24T23:00:00Z'),
  names: (c) => names[c] ?? c,
  calls: [],
  memory: new Map(),
  ...extra,
});

beforeEach(() => resetDigitrafficCaches());

describe('Finnish boards', () => {
  it('turns Digitraffic calls into departure rows: platform, delay, destination, operator and train type', () => {
    const [row] = normalizeFinlandBoard([ic27], ctx({ vehicleOf: () => 'Sr3' }));
    expect(row).toMatchObject({
      trainNumber: '27',
      advertised: Z('2026-10-24T11:20:00Z'),
      platform: '7',
      endpoints: ['Rovaniemi'],
      operatorId: 'vr-fi',
      product: 'intercity',
      trainType: 'fi_sr3_ic',
      canceled: false,
      done: true,
      delayMin: 0,
    });
    // Departed at 11:20:53: actual, so no estimate left over.
    expect(row!.actual).toBe(Z(ic27.timeTableRows[0]!.actualTime!));
    expect(row!.estimated).toBeNull();
  });

  it('lists arrivals with the train\'s origin, and a train never lists its own start as an arrival', () => {
    const arrivals = normalizeFinlandBoard([ic27], ctx({ type: 'arrivals', code: 'TPE', from: Z('2026-10-24T12:00:00Z') }));
    expect(arrivals).toHaveLength(1);
    expect(arrivals[0]).toMatchObject({ endpoints: ['Helsinki'], platform: '2', delayMin: 3 });
    expect(normalizeFinlandBoard([ic27], ctx({ type: 'arrivals' }))).toEqual([]);
  });

  it('keeps only commercial stops and the window, and leaves freight and shunting out', () => {
    // Pass-through and technical stops are not departures anyone can take.
    expect(normalizeFinlandBoard([ic407], ctx({ code: 'HD' }))).toEqual([]);
    expect(normalizeFinlandBoard([hl8192], ctx({ code: 'KHK' }))).toEqual([]);
    expect(normalizeFinlandBoard([ic27], ctx({ from: Z('2026-10-24T11:30:00Z') }))).toEqual([]);
    expect(normalizeFinlandBoard(fixture('non-passenger'), ctx({ code: fixture<{ timeTableRows: { stationShortCode: string }[] }[]>('non-passenger')[0]!.timeTableRows[0]!.stationShortCode }))).toEqual([]);
  });

  it('shows a cancelled train as cancelled, without a delay', () => {
    const [row] = normalizeFinlandBoard([hdm750], ctx({ code: 'SL', now: Z('2026-10-22T16:00:00Z'), from: Z('2026-10-22T15:00:00Z'), to: Z('2026-10-23T00:00:00Z') }));
    expect(row).toMatchObject({ trainNumber: '750', canceled: true, delayMin: null, endpoints: ['Parikkala'], product: 'regional' });
  });

  it('keeps the codes of causes, for the app to word in its language', () => {
    const withCause = ic24.timeTableRows.find((r) => r.causes?.length && r.type === 'DEPARTURE') ?? ic24.timeTableRows.find((r) => r.causes?.length)!;
    const type = withCause.type === 'DEPARTURE' ? 'departures' : 'arrivals';
    const rows = normalizeFinlandBoard([ic24], ctx({ type, code: withCause.stationShortCode, from: Z('2026-10-24T00:00:00Z'), to: Z('2026-10-25T00:00:00Z') }));
    const row = rows.find((r) => r.advertised === Z(withCause.scheduledTime))!;
    expect(row.causes).toHaveLength(withCause.causes!.length);
    expect(row.causes[0]).toMatchObject({ src: 'digitraffic' });
    expect(row.causes[0]!.code).toMatch(/^[A-Z]\d*/);
  });

  it('notices a platform change between two polls', () => {
    const memory = new Map();
    normalizeFinlandBoard([ic27], ctx({ memory }));
    const moved = { ...ic27, timeTableRows: ic27.timeTableRows.map((r, i) => (i === 0 ? { ...r, commercialTrack: '9' } : r)) };
    const [row] = normalizeFinlandBoard([moved], ctx({ memory, now: Z('2026-10-24T11:10:00Z') }));
    expect(row).toMatchObject({ platform: '9', platformChange: { from: '7', at: Z('2026-10-24T11:10:00Z') } });
  });

  it('links a row to the timetable trip of the same train, day and minute', () => {
    const call = { tripKey: 'fi:27_20261024:abc', serviceDate: '2026-10-24', seq: 1, trainNumber: '27', operatorId: 'vr-fi', product: 'intercity' as const, category: 'intercity', arr: null, dep: Z('2026-10-24T11:20:00Z') };
    expect(normalizeFinlandBoard([ic27], ctx({ calls: [call] }))[0]!.trip).toEqual({ key: 'fi:27_20261024:abc', serviceDate: '2026-10-24', seq: 1 });
    expect(normalizeFinlandBoard([ic27], ctx({ calls: [{ ...call, trainNumber: '28' }] }))[0]!.trip).toBeNull();
  });
});

describe('the board hub for Finland', () => {
  let hub: BoardHub | null = null;
  afterEach(() => hub?.close());

  function setup() {
    const db = openDb(':memory:');
    seedFinland(db);
    seedTrip(db, ic27);
    seedTrip(db, ic407);
    const { fetchImpl, seen } = fakeDigitraffic({
      'live-trains/station/HKI?*': [ic27],
      'live-trains/station/TOR?*': [ic407],
      'compositions/2026-10-24': [{ trainNumber: 27, departureDate: '2026-10-24', journeySections: [{ locomotives: [{ locomotiveType: 'Sr2' }] }] }],
    });
    hub = new BoardHub(db, { fetchImpl, now: () => Z('2026-10-24T11:00:00Z') });
    return { db, hub, seen };
  }

  it('serves Finnish stations from Digitraffic, and Haparanda from Trafikverket as before', () => {
    const { hub } = setup();
    expect(hub.sourceOf('fi:HKI')).toEqual({ kind: 'digitraffic', id: 'HKI' });
    expect(hub.sourceOf(HAPARANDA)).toEqual({ kind: 'trv', id: 'Hp' });
    expect(hub.sourceOf('nowhere')).toBeNull();
  });

  it('loads the live board for Helsinki with the unit type, once per 30 seconds however many ask', async () => {
    const { hub, seen } = setup();
    const board = await hub.load('fi:HKI', 'departures', Z('2026-10-24T10:00:00Z'), Z('2026-10-24T23:00:00Z'));
    expect(board).toMatchObject({ stationId: 'fi:HKI', signature: 'HKI', type: 'departures' });
    expect(board.rows).toHaveLength(1);
    expect(board.rows[0]).toMatchObject({ trainNumber: '27', platform: '7', trainType: 'fi_sr2_ic', endpoints: ['Rovaniemi'], trip: { seq: 1 } });
    await hub.load('fi:HKI', 'arrivals', Z('2026-10-24T10:00:00Z'), Z('2026-10-24T23:00:00Z'));
    expect(seen.filter((p) => p.startsWith('live-trains/station/HKI'))).toHaveLength(1);
  });

  it('is reachable over the API: the station page says it has a board, and the board comes back', async () => {
    const { db, hub } = setup();
    const app = Fastify();
    app.decorateRequest('userId', '');
    app.addHook('onRequest', async (req) => {
      req.userId = 'local';
    });
    await app.register(boardRoutes(db, hub));
    try {
      const info = (await app.inject('/stations/fi:HKI')).json();
      expect(info).toMatchObject({ id: 'fi:HKI', name: 'Helsinki', country: 'FI', tz: 'Europe/Helsinki', hasBoard: true });
      const from = Z('2026-10-24T10:00:00Z');
      const board = (await app.inject(`/stations/fi:HKI/board?type=departures&from=${from}&to=${from + 6 * 3600_000}`)).json();
      expect(board.rows[0]).toMatchObject({ trainNumber: '27', platform: '7' });
      // A station nobody serves has no board.
      expect((await app.inject('/stations/nowhere/board')).statusCode).toBe(404);
    } finally {
      await app.close();
    }
  });

  it('names a Finnish train\'s destination in Haparanda by its station name, from the short code', async () => {
    const { hub } = setup();
    const board = await hub.load('fi:TOR', 'departures', Z('2026-10-24T17:00:00Z'), Z('2026-10-24T23:00:00Z'));
    expect(board.rows.map((r) => r.endpoints)).toEqual([['Haparanda']]);
  });
});
