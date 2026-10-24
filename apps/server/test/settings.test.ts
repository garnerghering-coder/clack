import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { openDb } from '../src/db/client.js';
import { buildApp } from '../src/app.js';

describe('settings API', () => {
  let app: ReturnType<typeof buildApp>;
  beforeEach(() => {
    app = buildApp(openDb(':memory:'));
  });
  afterEach(() => app.close());

  it('returns defaults for the seeded user', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/settings' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual(DEFAULT_SETTINGS);
  });

  it('saves a valid change and rejects an invalid one', async () => {
    const ok = await app.inject({ method: 'PATCH', url: '/api/settings', payload: { distanceUnit: 'mi' } });
    expect(ok.statusCode).toBe(200);
    expect(ok.json().distanceUnit).toBe('mi');
    const bad = await app.inject({ method: 'PATCH', url: '/api/settings', payload: { distanceUnit: 'furlongs' } });
    expect(bad.statusCode).toBe(400);
    const after = await app.inject({ method: 'GET', url: '/api/settings' });
    expect(after.json().distanceUnit).toBe('mi');
  });

  it('health check works', async () => {
    // The public answer is just ok; the inside needs the admin token (adminAuth.test.ts covers the refusals).
    expect((await app.inject({ method: 'GET', url: '/api/health' })).json()).toMatchObject({ ok: true });
    process.env.CLACK_ADMIN_TOKEN = 'test-admin-token';
    const res = await app.inject({ method: 'GET', url: '/api/health', headers: { 'x-clack-admin': 'test-admin-token' } });
    delete process.env.CLACK_ADMIN_TOKEN;
    expect(res.json()).toMatchObject({ ok: true, feeds: {}, gps: { accepted: 0, rejected: 0, recent: [] } });
  });
});
