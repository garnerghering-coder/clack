import Fastify from 'fastify';
import { afterEach, describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { legs, stations, users } from '../src/db/schema.js';
import { liveRoutes } from '../src/routes/live.js';
import { liveMapRoutes } from '../src/routes/livemap.js';
import { isMine, type LiveMapIngest, type LiveTrain } from '../src/livemap/ingest.js';
import { liveBus, type LiveUpdate } from '../src/live/tracker.js';
import { DEFAULT_SETTINGS } from '@clack/shared';

// The server is shared by every phone: live updates and "your train" on the map must be each phone's own.
const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const B = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';

const train = (extra: Partial<LiveTrain> = {}): LiveTrain => ({
  id: '582|2026-10-21',
  number: '582',
  date: '2026-10-21',
  lat: 59.5,
  lon: 17.9,
  bearing: 0,
  speedKmh: 100,
  at: 1,
  estimated: false,
  operatorId: 'sj',
  productName: null,
  product: 'regional',
  trainType: null,
  origin: 'Stockholm C',
  destination: 'Uppsala C',
  next: null,
  nextEta: null,
  delayMin: 0,
  mine: false,
  ...extra,
});

/** A bare app whose requests say who they are, as app.ts's identity hook does. */
async function appFor(register: (app: ReturnType<typeof Fastify>) => Promise<unknown>) {
  const app = Fastify();
  app.decorateRequest('userId', '');
  app.addHook('onRequest', async (req) => {
    req.userId = (req.headers['x-clack-user'] as string | undefined) ?? (req.query as { u?: string }).u ?? 'local';
  });
  await register(app);
  return app;
}

describe('per-user live data', () => {
  let close: (() => Promise<unknown>) | null = null;
  afterEach(async () => close?.());

  it('tells a train apart as yours by number (Sweden) or by trip (Norway)', () => {
    const se = train();
    expect(isMine(se, new Set(['582|2026-10-21']))).toBe(true);
    expect(isMine(se, new Set(['582|2026-10-22']))).toBe(false);
    // Norway's feed names the trip: the same number on another trip isn't yours.
    const no = train({ id: 'no:x', number: '41', tripKey: 'NSB:41', date: '2026-10-21' });
    expect(isMine(no, new Set(['trip:NSB:41|2026-10-21']))).toBe(true);
    expect(isMine(no, new Set(['41|2026-10-21']))).toBe(false);
    expect(isMine({ ...no, crossBorder: true }, new Set(['41|2026-10-21']))).toBe(true);
  });

  it("marks a train as yours only for the phone that's on it", async () => {
    const fake = { trains: new Map([['582|2026-10-21', train()]]), acquire() {}, release() {}, upstreamAt: 0, mode: 'live' };
    const keys = (u: string) => new Set(u === A ? ['582|2026-10-21'] : []);
    const app = await appFor((a) => a.register(liveMapRoutes(openDb(':memory:'), fake as unknown as LiveMapIngest, keys), { prefix: '/api' }));
    close = () => app.close();
    const mine = async (u: string) => (await app.inject({ url: '/api/live/trains', headers: { 'x-clack-user': u } })).json().trains[0].mine;
    expect(await mine(A)).toBe(true);
    expect(await mine(B)).toBe(false);
    // /live/mine: only the asking phone's own trains.
    const own = async (u: string) => (await app.inject({ url: '/api/live/mine', headers: { 'x-clack-user': u } })).json().trains.map((t: { id: string }) => t.id);
    expect(await own(A)).toEqual(['582|2026-10-21']);
    expect(await own(B)).toEqual([]);
    // The shared train itself is untouched.
    expect(fake.trains.get('582|2026-10-21')!.mine).toBe(false);
  });

  it("sends each phone the live updates of its own trips only", async () => {
    const db = openDb(':memory:');
    db.insert(users).values([{ id: A, settings: DEFAULT_SETTINGS }, { id: B, settings: DEFAULT_SETTINGS }]).run();
    db.insert(stations)
      .values([
        { id: 'cst', name: 'Stockholm C', country: 'SE', lat: 59.33, lon: 18.06, tz: 'Europe/Stockholm', trvSignature: 'Cst' },
        { id: 'u', name: 'Uppsala C', country: 'SE', lat: 59.86, lon: 17.64, tz: 'Europe/Stockholm', trvSignature: 'U' },
      ])
      .run();
    const leg = (id: string, userId: string) => ({ id, userId, status: 'planned' as const, dataQuality: 'full', originStationId: 'cst', destStationId: 'u', createdAt: new Date() });
    db.insert(legs).values([leg('la', A), leg('lb', B)]).run();
    const app = await appFor((a) => a.register(liveRoutes(db), { prefix: '/api' }));
    const url = await app.listen({ port: 0, host: '127.0.0.1' });
    close = () => app.close();

    const ctrl = new AbortController();
    const res = await fetch(`${url}/api/live/stream?u=${B}`, { signal: ctrl.signal });
    const reader = res.body!.getReader();
    await reader.read(); // retry: line
    const update = (legId: string) => ({ legId, live: { updatedAt: 1, reportedAt: null }, events: [] }) as unknown as LiveUpdate;
    liveBus.emit('update', update('la'));
    liveBus.emit('update', update('lb'));
    let buf = '';
    while (!buf.includes('\n\n')) buf += new TextDecoder().decode((await reader.read()).value);
    expect(buf).toContain('"legId":"lb"');
    expect(buf).not.toContain('"legId":"la"');
    ctrl.abort();
  });
});
