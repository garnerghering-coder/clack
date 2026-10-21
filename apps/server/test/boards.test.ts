import { afterEach, describe, expect, it } from 'vitest';
import { brandMatcher, normalizeBoard, type PlatformMemory, type TrvBoardRow } from '../src/boards/board.js';
import { loadBrands } from '../src/dataFiles.js';
import { openDb } from '../src/db/client.js';
import { stations } from '../src/db/schema.js';
import { BoardHub } from '../src/boards/hub.js';
import type { StationCall } from '../src/search/timetable.js';

const T = (hhmm: string) => `2026-10-21T${hhmm}:00.000+02:00`;
const ms = (hhmm: string) => Date.parse(T(hhmm));
const row = (p: Partial<TrvBoardRow> & { ActivityId: string }): TrvBoardRow => ({
  ActivityType: 'Avgang',
  AdvertisedTimeAtLocation: T('11:33'),
  AdvertisedTrainIdent: '270',
  ToLocation: [{ LocationName: 'Gä' }],
  ViaToLocation: [
    { LocationName: 'U', Order: 1 },
    { LocationName: 'Arnc', Order: 0 },
    { LocationName: 'Tip', Order: 2 },
    { LocationName: 'Sk', Order: 3 },
  ],
  ProductInformation: [{ Description: 'SJ InterCity' }],
  TypeOfTraffic: [{ Description: 'Tåg' }],
  TrackAtLocation: '17b',
  ...p,
});
const names: Record<string, string> = { Gä: 'Gävle C', U: 'Uppsala C', Arnc: 'Arlanda C', Tip: 'Tierp', Sk: 'Skutskär' };
const matchBrand = brandMatcher(loadBrands());
const ctx = (memory: PlatformMemory = new Map(), calls: StationCall[] = [], now = ms('11:00')) => ({
  type: 'departures' as const,
  now,
  names: (s: string) => names[s] ?? s,
  matchBrand,
  calls,
  memory,
});

describe('board rows', () => {
  it("recognises the brands in Trafikverket's product names", () => {
    const want: Record<string, string> = {
      'SJ Snabbtåg': 'sj',
      'SJ InterCity': 'sj',
      'SL Pendeltåg': 'sl',
      Pågatågen: 'pagatag',
      Östgötapendel: 'ostgotapendeln',
      Mälartåg: 'malartag',
      Krösatågen: 'krosatag',
      Västtågen: 'vasttagen',
      Norrtåg: 'norrtag',
      Öresundståg: 'oresundstag',
      'X-Tåget': 'x-taget',
      TiB: 'tib',
      'Vy Snabbtåg': 'vy',
      Tågab: 'tagab',
      Snälltåget: 'snalltaget',
      'VR Snabbtåg': 'vr',
      'Arlanda Express': 'arlanda-express',
    };
    for (const [text, id] of Object.entries(want)) expect(matchBrand(text), text).toBe(id);
  });

  it('shows destination, via in order, brand and train type', () => {
    const [r] = normalizeBoard([row({ ActivityId: 'a' })], ctx());
    expect(r!.endpoints).toEqual(['Gävle C']);
    expect(r!.via).toEqual(['Arlanda C', 'Uppsala C', 'Tierp']);
    expect(r!.operatorId).toBe('sj');
    expect(r!.product).toBe('intercity');
    expect(r!.trainType).toBe('rc6_coaches');
  });

  it('works out the delay from the estimate, and marks cancelled trains without a delay', () => {
    const [late, cancelled] = normalizeBoard(
      [row({ ActivityId: 'a', EstimatedTimeAtLocation: T('11:41') }), row({ ActivityId: 'b', AdvertisedTimeAtLocation: T('11:50'), Canceled: true })],
      ctx(),
    );
    expect(late!.delayMin).toBe(8);
    expect(late!.done).toBe(false);
    expect(cancelled!.canceled).toBe(true);
    expect(cancelled!.delayMin).toBeNull();
    expect(cancelled!.done).toBe(false);
  });

  it('leaves out replacement buses and taxis', () => {
    const rows = normalizeBoard([row({ ActivityId: 'a' }), row({ ActivityId: 'b', TypeOfTraffic: [{ Description: 'Buss' }] }), row({ ActivityId: 'c', TypeOfTraffic: [{ Description: 'Taxi' }] })], ctx());
    expect(rows.map((r) => r.id)).toEqual(['a']);
  });

  it('notices a platform change between polls and keeps showing it', () => {
    const memory: PlatformMemory = new Map();
    expect(normalizeBoard([row({ ActivityId: 'a', TrackAtLocation: '12' })], ctx(memory))[0]!.platformChange).toBeNull();
    const changed = normalizeBoard([row({ ActivityId: 'a', TrackAtLocation: '14' })], ctx(memory, [], ms('11:05')))[0]!;
    expect(changed.platform).toBe('14');
    expect(changed.platformChange).toEqual({ from: '12', at: ms('11:05') });
    expect(normalizeBoard([row({ ActivityId: 'a', TrackAtLocation: '14' })], ctx(memory, [], ms('11:06')))[0]!.platformChange?.from).toBe('12');
  });

  it("trusts Trafikverket's 'Spårändrat' when it hasn't seen the old platform", () => {
    const r = normalizeBoard([row({ ActivityId: 'a', Deviation: [{ Description: 'Spårändrat' }, { Description: 'Dubbeltåg' }] })], ctx())[0]!;
    expect(r.platformChange).toEqual({ from: null, at: null });
    expect(r.deviations).toEqual(['Dubbeltåg']);
  });

  it('links a row to its timetable trip by minute and train number', () => {
    const calls: StationCall[] = [
      { tripKey: 'other', serviceDate: '2026-10-21', seq: 3, trainNumber: '8740', operatorId: 'malartag', product: 'regional', category: 'regional', arr: null, dep: ms('11:33') },
      { tripKey: 'k270', serviceDate: '2026-10-21', seq: 1, trainNumber: '270', operatorId: 'sj', product: 'intercity', category: 'intercity', arr: null, dep: ms('11:33') },
    ];
    expect(normalizeBoard([row({ ActivityId: 'a' })], ctx(new Map(), calls))[0]!.trip).toEqual({ key: 'k270', serviceDate: '2026-10-21', seq: 1 });
    expect(normalizeBoard([row({ ActivityId: 'a', AdvertisedTrainIdent: '999' })], ctx(new Map(), calls))[0]!.trip).toBeNull();
  });
});

describe('shared board polling', () => {
  let hub: BoardHub | null = null;
  afterEach(() => hub?.close());

  it('serves two viewers of the same board with one upstream query', async () => {
    const db = openDb(':memory:');
    db.insert(stations).values({ id: 's1', name: 'Stockholm C', country: 'SE', lat: 59.33, lon: 18.06, tz: 'Europe/Stockholm', trvSignature: 'Cst' }).run();
    let calls = 0;
    const fetchImpl = (async () => {
      calls++;
      return new Response(JSON.stringify({ RESPONSE: { RESULT: [{ TrainAnnouncement: [row({ ActivityId: 'a' })] }] } }));
    }) as unknown as typeof fetch;
    process.env.TRAFIKVERKET_API_KEY ||= 'test';
    hub = new BoardHub(db, { fetchImpl, pollMs: 60_000 });
    const a = hub.subscribe('s1', 'departures', () => {});
    const b = hub.subscribe('s1', 'departures', () => {});
    const [b1, b2] = await Promise.all([hub.current('s1', 'departures'), hub.current('s1', 'departures')]);
    expect(b1.rows).toHaveLength(1);
    expect(b2).toBe(b1);
    expect(calls).toBe(1);
    expect(hub.viewers('s1', 'departures')).toBe(2);
    a();
    b();
    expect(hub.viewers('s1', 'departures')).toBe(0);
  });
});

describe("Trafikverket's mislabelled actual times (2026-10-21)", () => {
  it('reads a UTC clock time labelled +02:00 as UTC, and leaves correct times alone', async () => {
    const { actualTime } = await import('../src/trafikverket/client.js');
    const adv = '2026-10-21T12:00:00.000+02:00';
    expect(new Date(actualTime('2026-10-21T10:00:39.000+02:00', adv)!).toISOString()).toBe('2026-10-21T10:00:39.000Z');
    expect(new Date(actualTime('2026-10-21T12:03:00.000+02:00', adv)!).toISOString()).toBe('2026-10-21T10:03:00.000Z');
    // A genuinely very late train stays as reported.
    expect(new Date(actualTime('2026-10-21T15:00:00.000+02:00', adv)!).toISOString()).toBe('2026-10-21T13:00:00.000Z');
    // Shifted twice (seen on SL 2731 at Solna: advertised 11:14, reported 07:16+02:00).
    expect(new Date(actualTime('2026-10-21T07:16:00.000+02:00', '2026-10-21T11:14:00.000+02:00')!).toISOString()).toBe('2026-10-21T09:16:00.000Z');
    expect(actualTime(undefined, adv)).toBeNull();
  });
});
