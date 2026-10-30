import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { openDb } from '../src/db/client.js';

// With user ids required everywhere else, a rider's report still goes without one (live/riders.ts).
describe('POST /api/live/report', () => {
  let app: Awaited<ReturnType<typeof import('../src/app.js')['buildApp']>>;
  beforeAll(async () => {
    vi.stubEnv('CLACK_REQUIRE_USER', '1');
    const { buildApp } = await import('../src/app.js');
    app = buildApp(openDb(':memory:'));
  });
  afterAll(async () => {
    await app.close();
    vi.unstubAllEnvs();
  });

  it('is open without a user id, and refuses a train not on the map', async () => {
    const res = await app.inject({ method: 'POST', url: '/api/live/report', payload: { train: 'nope|2026-10-30', prevId: 'A', nextId: 'B', progress: 0.5, speedKmh: 80, at: Date.now(), session: 'abcdefgh-1' } });
    expect(res.statusCode).toBe(422);
    expect(res.json()).toEqual({ error: 'unknown train' });
    // Other routes still need the id.
    expect((await app.inject({ url: '/api/live/trains' })).statusCode).toBe(401);
  });
});
