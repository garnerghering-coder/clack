import { eq } from 'drizzle-orm';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { buildApp } from '../src/app.js';
import { legs, stations } from '../src/db/schema.js';

// A platform the owner types where no source has one (owner, 2026-10-25): shown like any other, never over a source's.
const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const B = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';

describe('typed platforms', () => {
  let db: ReturnType<typeof openDb>;
  let app: ReturnType<typeof buildApp>;
  beforeEach(() => {
    db = openDb(':memory:');
    db.insert(stations)
      .values([
        { id: '740000140', name: 'Nässjö C', country: 'SE', lat: 57.652625, lon: 14.693759, tz: 'Europe/Stockholm', trvSignature: 'N' },
        { id: '740000004', name: 'Alvesta', country: 'SE', lat: 56.898911, lon: 14.55679, tz: 'Europe/Stockholm', trvSignature: 'Av' },
      ])
      .run();
    app = buildApp(db);
  });
  afterEach(() => app.close());

  const headers = (u: string) => ({ 'x-clack-user': u });
  const create = async () => {
    const res = await app.inject({
      method: 'POST', url: '/api/legs/manual', headers: headers(A),
      payload: { fromStationId: '740000140', toStationId: '740000004', date: '2015-07-01', dep: '10:00', arr: '11:00' },
    });
    expect(res.statusCode).toBe(201);
    return res.json();
  };
  const patch = (u: string, id: string, payload: object) => app.inject({ method: 'PATCH', url: `/api/legs/${id}`, headers: headers(u), payload });

  it('shows a typed platform where no source has one, and clears it with null', async () => {
    const leg = await create();
    expect(leg.depPlatform).toBeNull();
    expect(leg.depPlatformFromSource).toBe(false);
    const res = await patch(A, leg.id, { depPlatform: ' 4b ', arrPlatform: '2' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ depPlatform: '4b', arrPlatform: '2', depPlatformFromSource: false });
    const list = (await app.inject({ method: 'GET', url: '/api/legs', headers: headers(A) })).json();
    expect(list[0]).toMatchObject({ depPlatform: '4b', arrPlatform: '2' });
    expect((await patch(A, leg.id, { depPlatform: null })).json().depPlatform).toBeNull();
  });

  it("refuses one where a source has a platform, and someone else's trip", async () => {
    const leg = await create();
    db.update(legs).set({ depPlatform: '7' }).where(eq(legs.id, leg.id)).run();
    const res = await patch(A, leg.id, { depPlatform: '4' });
    expect(res.statusCode).toBe(409);
    const shown = (await app.inject({ method: 'GET', url: `/api/legs/${leg.id}`, headers: headers(A) })).json();
    expect(shown).toMatchObject({ depPlatform: '7', depPlatformFromSource: true });
    expect((await patch(B, leg.id, { arrPlatform: '1' })).statusCode).toBe(404);
    expect((await patch(A, leg.id, { arrPlatform: '1234567' })).statusCode).toBe(400);
  });

  it('a source platform that arrives later takes over from the typed one', async () => {
    const leg = await create();
    await patch(A, leg.id, { arrPlatform: '3' });
    db.update(legs).set({ arrPlatform: '5' }).where(eq(legs.id, leg.id)).run();
    const shown = (await app.inject({ method: 'GET', url: `/api/legs/${leg.id}`, headers: headers(A) })).json();
    expect(shown).toMatchObject({ arrPlatform: '5', arrPlatformFromSource: true });
  });
});
