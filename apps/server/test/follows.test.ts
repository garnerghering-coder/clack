import { describe, expect, it } from 'vitest';
import Fastify from 'fastify';
import { LOCAL_USER_ID, openDb } from '../src/db/client.js';
import { legs } from '../src/db/schema.js';
import type { LiveMapIngest } from '../src/livemap/ingest.js';
import { liveMapRoutes } from '../src/routes/livemap.js';

async function setup() {
  const db = openDb(':memory:');
  const app = Fastify();
  app.decorateRequest('userId', '');
  app.addHook('onRequest', async (req) => {
    (req as unknown as { userId: string }).userId = LOCAL_USER_ID;
  });
  const ingest = { trains: new Map([['x', { id: 'x', number: '2042', date: '2099-01-01', lat: 59, lon: 18 }]]) };
  await app.register(liveMapRoutes(db, ingest as unknown as LiveMapIngest), { prefix: '/api' });
  return { db, app };
}

describe('following a train', () => {
  it('is idempotent, shows the train when it is on the map, and never creates a trip', async () => {
    const { db, app } = await setup();
    const body = { trainNumber: '2042', serviceDate: '2099-01-01', operatorId: 'vy', label: 'Göteborg C → Stockholm C' };
    expect((await app.inject({ method: 'PUT', url: '/api/follows', payload: body })).statusCode).toBe(200);
    await app.inject({ method: 'PUT', url: '/api/follows', payload: body });
    const list = (await app.inject({ url: '/api/follows' })).json();
    expect(list).toHaveLength(1);
    expect(list[0].train.id).toBe('x');
    expect(db.select().from(legs).all()).toHaveLength(0);
    await app.inject({ method: 'DELETE', url: '/api/follows/2042/2099-01-01' });
    expect((await app.inject({ url: '/api/follows' })).json()).toHaveLength(0);
  });
  it('rejects bad input and drops follows from before yesterday', async () => {
    const { app } = await setup();
    expect((await app.inject({ method: 'PUT', url: '/api/follows', payload: { trainNumber: 'abc', serviceDate: '2099-01-01' } })).statusCode).toBe(400);
    await app.inject({ method: 'PUT', url: '/api/follows', payload: { trainNumber: '1', serviceDate: '2020-01-01' } });
    expect((await app.inject({ url: '/api/follows' })).json()).toHaveLength(0);
  });
});
