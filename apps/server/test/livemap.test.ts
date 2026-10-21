import { EventEmitter } from 'node:events';
import { afterEach, describe, expect, it } from 'vitest';
import Fastify from 'fastify';
import { openDb } from '../src/db/client.js';
import { trvLocations } from '../src/db/schema.js';
import { AnnouncementCache, summarizeTrain } from '../src/livemap/announcements.js';
import { LiveMapIngest, type LiveTrain } from '../src/livemap/ingest.js';
import { liveMapRoutes } from '../src/routes/livemap.js';

const T = (hhmm: string) => `2026-10-21T${hhmm}:00.000+02:00`;
const ms = (hhmm: string) => Date.parse(T(hhmm));
const ann = (sig: string, type: 'Ankomst' | 'Avgang', adv: string, extra: Record<string, unknown> = {}) => ({
  ActivityId: `${sig}-${type}`,
  ActivityType: type,
  AdvertisedTimeAtLocation: T(adv),
  AdvertisedTrainIdent: '270',
  LocationSignature: sig,
  FromLocation: [{ LocationName: 'Cst' }],
  ToLocation: [{ LocationName: 'Gä' }],
  ProductInformation: [{ Description: 'SJ InterCity' }],
  TypeOfTraffic: [{ Description: 'Tåg' }],
  ...extra,
});

describe('what the announcements say about a running train', () => {
  it('finds the last stop passed, the next one and the delay', () => {
    const rows = [
      ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:02') }),
      ann('U', 'Ankomst', '11:40', { TimeAtLocation: T('11:44') }),
      ann('U', 'Avgang', '11:42', { TimeAtLocation: T('11:46') }),
      ann('Tip', 'Ankomst', '12:10', { EstimatedTimeAtLocation: T('12:16') }),
      ann('Gä', 'Ankomst', '12:40'),
    ];
    const s = summarizeTrain(rows, ms('11:50'))!;
    expect(s).toMatchObject({ number: '270', date: '2026-10-21', originSig: 'Cst', destinationSig: 'Gä', lastSig: 'U', nextSig: 'Tip', delayMin: 6, canceled: false, isTrain: true });
    expect(s.nextEta).toBe(ms('12:16'));
  });

  it('carries the last delay forward when there is no estimate', () => {
    const s = summarizeTrain([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:04') }), ann('U', 'Ankomst', '11:40')], ms('11:10'))!;
    expect(s.delayMin).toBe(4);
    expect(s.nextEta).toBe(ms('11:44'));
  });

  it('marks a train cancelled when everything ahead is', () => {
    const s = summarizeTrain([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40', { Canceled: true }), ann('Gä', 'Ankomst', '12:40', { Canceled: true })], ms('11:10'))!;
    expect(s.canceled).toBe(true);
  });

  it('knows a replacement bus is not a train', () => {
    expect(summarizeTrain([ann('Cst', 'Avgang', '11:00', { TypeOfTraffic: [{ Description: 'Buss' }] })], ms('11:10'))!.isTrain).toBe(false);
  });
});

describe('loading the announcements', () => {
  it('uses the slices that arrive, retries the rest, and only then calls the window complete', async () => {
    process.env.TRAFIKVERKET_API_KEY ||= 'test';
    let failFirst = 2;
    const fetchImpl = (async (_url: string, init: { body: string }) => {
      const from = Date.parse(init.body.match(/GTE name="AdvertisedTimeAtLocation" value="([^"]+)"/)![1]!);
      // The first slice (10:00–10:30) fails twice, then works.
      const first = from < ms('10:20');
      if (first && failFirst-- > 0) return new Response('{ "RESPONSE":{"RESULT":[{ "ERROR":{"MESSAGE":"Internal error"}}]}}', { status: 500 });
      const rows = first ? [ann('U', 'Ankomst', '10:10', { AdvertisedTrainIdent: '99' })] : from >= ms('11:00') && from < ms('11:20') ? [ann('Cst', 'Avgang', '11:10')] : [];
      return new Response(JSON.stringify({ RESPONSE: { RESULT: [{ TrainAnnouncement: rows, INFO: { LASTCHANGEID: String(from) } }] } }));
    }) as unknown as typeof fetch;
    let now = ms('11:00');
    const cache = new AnnouncementCache({ fetchImpl, now: () => now });
    await cache.refresh();
    expect(cache.info('270', '2026-10-21')).not.toBeNull();
    expect(cache.info('99', '2026-10-21')).toBeNull();
    expect(cache.complete).toBe(false);
    now += 30_000;
    await cache.refresh();
    expect(cache.info('99', '2026-10-21')).not.toBeNull();
    expect(cache.complete).toBe(true);
  });
});

const pos = (n: string, lat: number, lon: number, at: string) => ({
  Train: { AdvertisedTrainNumber: n, JourneyPlanDepartureDate: '2026-10-21T00:00:00.000+02:00' },
  Position: { WGS84: `POINT (${lon} ${lat})` },
  TimeStamp: T(at),
  Bearing: 10,
  Speed: 120,
});

describe('live map ingest', () => {
  let ingest: LiveMapIngest | null = null;
  afterEach(() => ingest?.stop());

  it('keeps the newest position per train and drops stale ones', () => {
    ingest = new LiveMapIngest(openDb(':memory:'), { now: () => ms('11:05') });
    ingest.ingest([pos('270', 59.9, 17.6, '11:00'), pos('270', 59.0, 17.0, '10:59')]);
    expect(ingest.trains.get('270|2026-10-21')).toMatchObject({ lat: 59.9, lon: 17.6, bearing: 10, speedKmh: 120 });
    (ingest as unknown as { opts: { now: () => number } }).opts.now = () => ms('11:20');
    (ingest as unknown as { prune(): void }).prune();
    expect(ingest.trains.size).toBe(0);
  });

  it('opens one upstream connection however many people watch', async () => {
    process.env.TRAFIKVERKET_API_KEY ||= 'test';
    let positionQueries = 0;
    const fetchImpl = (async (_url: string, init: { body: string }) => {
      if (init.body.includes('TrainPosition')) positionQueries++;
      const result = init.body.includes('TrainPosition') ? { TrainPosition: [pos('270', 59.9, 17.6, '11:00')] } : { TrainAnnouncement: [] };
      return new Response(JSON.stringify({ RESPONSE: { RESULT: [result] } }));
    }) as unknown as typeof fetch;
    ingest = new LiveMapIngest(openDb(':memory:'), { fetchImpl, now: () => ms('11:01') });
    ingest.acquire();
    ingest.acquire();
    ingest.acquire();
    await new Promise((r) => setTimeout(r, 50));
    expect(ingest.viewers).toBe(3);
    expect(positionQueries).toBe(1);
    expect(ingest.upstreamOpens).toBe(1);
    expect(ingest.trains.size).toBe(1);
  });
});

describe('estimated positions (trains without GPS)', () => {
  let ingest: LiveMapIngest | null = null;
  afterEach(() => ingest?.stop());

  const setup = async (rows: ReturnType<typeof ann>[], now: string) => {
    process.env.TRAFIKVERKET_API_KEY ||= 'test';
    const db = openDb(':memory:');
    for (const [s, lat, lon] of [
      ['Cst', 59.33, 18.06],
      ['U', 59.86, 17.65],
      ['Gä', 60.67, 17.15],
    ] as const)
      db.insert(trvLocations).values({ signature: s, name: s, country: 'SE', lat, lon, advertised: true }).run();
    const fetchImpl = (async () => new Response(JSON.stringify({ RESPONSE: { RESULT: [{ TrainAnnouncement: rows }] } }))) as unknown as typeof fetch;
    ingest = new LiveMapIngest(db, { fetchImpl, now: () => ms(now), graph: () => null });
    await (ingest as unknown as { ann: { refresh(): Promise<void> } }).ann.refresh();
    ingest.estimateAll();
    return ingest.trains.get('270|2026-10-21');
  };

  it('puts a train between its last and next stop, by time, drawn hollow', async () => {
    const t = await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40', { EstimatedTimeAtLocation: T('11:40') })], '11:20');
    expect(t).toMatchObject({ estimated: true, next: 'U' });
    // Halfway in time is halfway along the (here straight) line.
    expect(t!.lat).toBeCloseTo((59.33 + 59.86) / 2, 2);
  });

  it('stops short of the next station when the train is running late', async () => {
    const t = await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40')], '11:58');
    expect(t!.lat).toBeLessThan(59.86 - 0.01);
  });

  it('keeps a train that is standing at a station there', async () => {
    const t = await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40', { TimeAtLocation: T('11:41') }), ann('U', 'Avgang', '11:43'), ann('Gä', 'Ankomst', '12:40')], '11:42');
    expect(t).toMatchObject({ lat: 59.86, lon: 17.65, estimated: true });
  });

  it("leaves out trains that haven't left yet, and ones that arrived a while ago", async () => {
    expect(await setup([ann('Cst', 'Avgang', '11:00'), ann('U', 'Ankomst', '11:40')], '10:55')).toBeUndefined();
    expect(await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40', { TimeAtLocation: T('11:40') })], '11:50')).toBeUndefined();
  });

  it('lets a fresh GPS fix take over', async () => {
    await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40')], '11:20');
    ingest!.ingest([pos('270', 59.5, 17.9, '11:20')]);
    ingest!.estimateAll();
    expect(ingest!.trains.get('270|2026-10-21')).toMatchObject({ lat: 59.5, lon: 17.9, estimated: false });
  });
});

/** Just enough of the ingest for the route: trains, deltas, viewer counting. */
class FakeIngest extends EventEmitter {
  trains = new Map<string, LiveTrain>();
  mode = 'stream';
  upstreamAt = 1;
  viewers = 0;
  acquire() {
    this.viewers++;
  }
  release() {
    this.viewers--;
  }
}
const train = (id: string, lat: number, lon: number, extra: Partial<LiveTrain> = {}): LiveTrain => ({
  id,
  number: id,
  date: '2026-10-21',
  lat,
  lon,
  bearing: 0,
  speedKmh: 100,
  at: 1,
  estimated: false,
  operatorId: 'sj',
  productName: 'SJ Regional',
  product: 'regional',
  trainType: null,
  origin: 'A',
  destination: 'B',
  next: null,
  nextEta: null,
  delayMin: 0,
  mine: false,
  ...extra,
});

describe('live map stream', () => {
  let close: (() => Promise<unknown>) | null = null;
  afterEach(async () => close?.());

  it("sends only the trains in view, short position updates, and tells you when one leaves", async () => {
    const fake = new FakeIngest();
    fake.trains.set('gbg', train('gbg', 57.7, 12.0));
    fake.trains.set('sth', train('sth', 59.3, 18.1));
    const app = Fastify();
    await app.register(liveMapRoutes(openDb(':memory:'), fake as unknown as LiveMapIngest), { prefix: '/api' });
    const url = await app.listen({ port: 0, host: '127.0.0.1' });
    close = () => app.close();

    const ctrl = new AbortController();
    const res = await fetch(`${url}/api/live/trains/stream?bbox=11,57,13,58`, { signal: ctrl.signal });
    const reader = res.body!.getReader();
    const dec = new TextDecoder();
    let buf = '';
    const next = async (event: string) => {
      for (;;) {
        const m = buf.match(new RegExp(`event: ${event}\\ndata: (.*)\\n\\n`));
        if (m) {
          buf = buf.slice(buf.indexOf(m[0]) + m[0].length);
          return JSON.parse(m[1]!);
        }
        buf += dec.decode((await reader.read()).value);
      }
    };
    const snap = await next('snapshot');
    expect(snap.trains.map((t: LiveTrain) => t.id)).toEqual(['gbg']);
    expect(snap.total).toBe(2);
    expect(fake.viewers).toBe(1);

    // Göteborg train moves (position only), Stockholm train is out of view either way.
    fake.emit('delta', { changed: [train('gbg', 57.71, 12.01), train('sth', 59.31, 18.1)], removed: [], total: 2, upstreamAt: 2 });
    const d1 = await next('delta');
    expect(d1.changed).toEqual([]);
    expect(d1.moved).toEqual([['gbg', 57.71, 12.01, 0, 100, 1, false]]);

    // Its delay changes: the whole train is sent again.
    fake.emit('delta', { changed: [train('gbg', 57.71, 12.01, { delayMin: 7 })], removed: [], total: 2, upstreamAt: 3 });
    expect((await next('delta')).changed[0]).toMatchObject({ id: 'gbg', delayMin: 7 });

    // It drives out of view.
    fake.emit('delta', { changed: [train('gbg', 58.9, 12.5, { delayMin: 7 })], removed: [], total: 2, upstreamAt: 4 });
    expect((await next('delta')).removed).toEqual(['gbg']);

    ctrl.abort();
    await new Promise((r) => setTimeout(r, 50));
    expect(fake.viewers).toBe(0);
  });
});
