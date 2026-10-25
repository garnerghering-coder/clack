import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { buildApp } from '../src/app.js';
import { usageCounts } from '../src/db/schema.js';

// Anonymous daily counts (owner, 2026-10-25): nothing about who, only what, and only well-formed names.
describe('usage', () => {
  let db: ReturnType<typeof openDb>;
  let app: ReturnType<typeof buildApp>;
  const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
  beforeEach(() => {
    db = openDb(':memory:');
    app = buildApp(db);
    process.env.CLACK_ADMIN_TOKEN = 'secret';
  });
  afterEach(() => app.close());

  const post = (url: string, payload: object) => app.inject({ method: 'POST', url, headers: { 'x-clack-user': A }, payload });

  it('adds up counts per day, kind and name, and keeps no user id', async () => {
    await post('/api/usage', { events: [{ kind: 'feature', name: 'trips.add', count: 2 }, { kind: 'route', name: '740000001>740000005' }] });
    const res = await post('/api/usage', { events: [{ kind: 'feature', name: 'trips.add', count: 3 }] });
    expect(res.statusCode).toBe(202);
    const rows = db.select().from(usageCounts).all();
    expect(rows.find((r) => r.name === 'trips.add')?.count).toBe(5);
    expect(rows.find((r) => r.kind === 'route')?.count).toBe(1);
    expect(JSON.stringify(rows)).not.toContain(A);
  });

  it('drops unknown kinds and anything that looks like free text', async () => {
    const res = await post('/api/usage', {
      events: [{ kind: 'secret', name: 'x' }, { kind: 'feature', name: 'my email is a@b.se' }, { kind: 'error', name: 'board.load' }],
    });
    expect(res.json()).toEqual({ kept: 1 });
  });

  it('keeps crash summaries, and shows the summary only with the admin token', async () => {
    await post('/api/diagnostics', { build: '22', reports: [{ kind: 'crash', signature: 'Clack TripDetailScreen.load', count: 1 }] });
    await post('/api/usage', { events: [{ kind: 'feature', name: 'share' }] });
    expect((await app.inject({ url: '/api/usage/summary', headers: { 'x-clack-user': A } })).statusCode).toBe(404);
    const summary = (await app.inject({ url: '/api/usage/summary', headers: { 'x-clack-user': A, 'x-clack-admin': 'secret' } })).json();
    expect(summary.features[0]).toMatchObject({ name: 'share', count: 1 });
    expect(summary.crashes[0]).toMatchObject({ build: '22', kind: 'crash', count: 1 });
  });
});
