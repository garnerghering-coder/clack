import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { tokenMatches } from '../src/plugins/adminAuth.js';
import { openDb } from '../src/db/client.js';

const TOKEN = 'correct-horse-battery-staple-0123456789';
const PROTECTED = ['/api/import/status', '/api/audit', '/api/live/status'];

describe('admin token', () => {
  let app: ReturnType<typeof buildApp>;
  const saved = process.env.CLACK_ADMIN_TOKEN;
  beforeAll(() => {
    app = buildApp(openDb(':memory:'));
  });
  afterAll(async () => {
    await app.close();
    saved === undefined ? delete process.env.CLACK_ADMIN_TOKEN : (process.env.CLACK_ADMIN_TOKEN = saved);
  });
  beforeEach(() => {
    process.env.CLACK_ADMIN_TOKEN = TOKEN;
  });
  const get = (url: string, token?: string) => app.inject({ url, headers: token === undefined ? {} : { 'x-clack-admin': token } });

  it('compares in constant time and refuses an empty or missing token', () => {
    expect(tokenMatches(TOKEN, TOKEN)).toBe(true);
    expect(tokenMatches(TOKEN + 'x', TOKEN)).toBe(false);
    expect(tokenMatches('', '')).toBe(false);
    expect(tokenMatches(undefined, TOKEN)).toBe(false);
    expect(tokenMatches(TOKEN, undefined)).toBe(false);
    expect(tokenMatches([TOKEN], TOKEN)).toBe(false);
  });

  it('answers the protected routes only with the right token', async () => {
    for (const url of PROTECTED) {
      expect((await get(url, TOKEN)).statusCode, url).toBe(200);
      expect((await get(url)).statusCode, `${url} without`).toBe(404);
      expect((await get(url, 'wrong')).statusCode, `${url} wrong`).toBe(404);
      expect((await get(`${url}?x=1`)).statusCode, `${url} with a query`).toBe(404);
    }
  });

  it('answers 404 for the protected routes when no token is set on the server, even for an empty header', async () => {
    delete process.env.CLACK_ADMIN_TOKEN;
    for (const url of PROTECTED) {
      expect((await get(url)).statusCode).toBe(404);
      expect((await get(url, '')).statusCode).toBe(404);
      expect((await get(url, 'anything')).statusCode).toBe(404);
    }
  });

  it('keeps /api/health public, with the details only for the token', async () => {
    const open = (await get('/api/health')).json();
    expect(open.ok).toBe(true);
    expect(open).not.toHaveProperty('memoryMb');
    expect(open).not.toHaveProperty('feeds');
    expect(open).not.toHaveProperty('gps');
    expect(open).not.toHaveProperty('uptimeS');
    expect((await get('/api/health', 'wrong')).json()).not.toHaveProperty('feeds');
    const inside = (await get('/api/health', TOKEN)).json();
    expect(inside).toMatchObject({ ok: true });
    expect(inside).toHaveProperty('memoryMb');
    expect(inside).toHaveProperty('feeds');
    delete process.env.CLACK_ADMIN_TOKEN;
    expect((await get('/api/health')).json()).not.toHaveProperty('memoryMb');
  });

  it('leaves the other routes alone', async () => {
    expect((await get('/api/settings')).statusCode).toBe(200);
  });
});
