import { afterEach, describe, expect, it, vi } from 'vitest';
import { buildApp } from '../src/app.js';
import { openDb } from '../src/db/client.js';

// Each phone is its own user (no sign-in): its random id keeps its trips and settings apart from everyone else's.
describe('per-device identity', () => {
  let app: ReturnType<typeof buildApp>;
  afterEach(async () => app?.close());
  const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
  const B = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';

  it('keeps settings apart per id, and falls back to the local user without one', async () => {
    app = buildApp(openDb(':memory:'));
    await app.inject({ method: 'PATCH', url: '/api/settings', headers: { 'x-clack-user': A }, payload: { displayName: 'Garner' } });
    const a = (await app.inject({ url: '/api/settings', headers: { 'x-clack-user': A } })).json();
    const b = (await app.inject({ url: `/api/settings?u=${B}` })).json();
    const local = (await app.inject({ url: '/api/settings' })).json();
    expect(a.displayName).toBe('Garner');
    expect(b.displayName).not.toBe('Garner');
    expect(local.displayName).not.toBe('Garner');
    // Not a UUID: treated as no id at all.
    expect((await app.inject({ url: '/api/settings', headers: { 'x-clack-user': 'local' } })).json().displayName).toBe(local.displayName);
  });

  it('deletes everything of one user and nothing of anyone else', async () => {
    app = buildApp(openDb(':memory:'));
    await app.inject({ method: 'PATCH', url: '/api/settings', headers: { 'x-clack-user': A }, payload: { displayName: 'A' } });
    await app.inject({ method: 'PATCH', url: '/api/settings', headers: { 'x-clack-user': B }, payload: { displayName: 'B' } });
    expect((await app.inject({ method: 'DELETE', url: '/api/me', headers: { 'x-clack-user': A } })).statusCode).toBe(204);
    expect((await app.inject({ url: '/api/settings', headers: { 'x-clack-user': A } })).json().displayName).not.toBe('A');
    expect((await app.inject({ url: '/api/settings', headers: { 'x-clack-user': B } })).json().displayName).toBe('B');
  });

  it('refuses requests without a phone id when the server is shared (CLACK_REQUIRE_USER)', async () => {
    process.env.CLACK_REQUIRE_USER = '1';
    vi.resetModules();
    const { buildApp: build } = await import('../src/app.js');
    app = build(openDb(':memory:'));
    delete process.env.CLACK_REQUIRE_USER;
    expect((await app.inject({ url: '/api/settings' })).statusCode).toBe(401);
    expect((await app.inject({ url: '/api/settings', headers: { 'x-clack-user': 'local' } })).statusCode).toBe(401);
    expect((await app.inject({ url: '/api/settings', headers: { 'x-clack-user': A } })).statusCode).toBe(200);
    expect((await app.inject({ url: `/api/legs?u=${A}` })).statusCode).toBe(200);
    // Shared files that hold nobody's data stay open.
    expect((await app.inject({ url: '/api/health' })).statusCode).toBe(200);
    expect((await app.inject({ url: '/api/map/status' })).statusCode).toBe(200);
  });

  it('lets the iOS app call it (CORS for capacitor://localhost only)', async () => {
    app = buildApp(openDb(':memory:'));
    const pre = await app.inject({ method: 'OPTIONS', url: '/api/settings', headers: { origin: 'capacitor://localhost', 'access-control-request-method': 'PATCH' } });
    expect(pre.statusCode).toBe(204);
    expect(pre.headers['access-control-allow-origin']).toBe('capacitor://localhost');
    const other = await app.inject({ url: '/api/settings', headers: { origin: 'https://evil.example' } });
    expect(other.headers['access-control-allow-origin']).toBeUndefined();
  });
});
