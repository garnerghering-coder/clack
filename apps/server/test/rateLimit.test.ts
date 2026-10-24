import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import Fastify from 'fastify';
import { rateLimitPlugin } from '../src/plugins/rateLimit.js';
import { buildApp } from '../src/app.js';
import { openDb } from '../src/db/client.js';

const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const B = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';

// Small limits so the tests can go over them; the plugin reads them when it is registered.
const LIMITS = { CLACK_RATE_LIMIT: '5', CLACK_RATE_LIMIT_ANON: '3', CLACK_RATE_LIMIT_MAP: '8' };

describe('rate limiting', () => {
  let app: ReturnType<typeof Fastify>;
  const saved: Record<string, string | undefined> = {};
  beforeAll(() => {
    for (const k of Object.keys(LIMITS)) saved[k] = process.env[k];
    Object.assign(process.env, LIMITS);
  });
  afterAll(() => {
    for (const [k, v] of Object.entries(saved)) (v === undefined ? delete process.env[k] : (process.env[k] = v));
  });
  afterEach(async () => app?.close());

  const make = async () => {
    app = Fastify({ trustProxy: true });
    await app.register(rateLimitPlugin);
    for (const p of ['/api/things', '/api/live/stream', '/api/live/trains/stream', '/api/stations/x/board/stream', '/api/health', '/api/map/tile', '/api/operators/sj/logo']) app.get(p, async () => ({ ok: true }));
    await app.ready();
    return app;
  };
  const hit = (url: string, headers: Record<string, string> = {}) => app.inject({ url, headers });

  it('lets requests under the limit through and answers 429 in the server\'s error shape over it', async () => {
    await make();
    for (let i = 0; i < 5; i++) expect((await hit('/api/things', { 'x-clack-user': A })).statusCode).toBe(200);
    const over = await hit('/api/things', { 'x-clack-user': A });
    expect(over.statusCode).toBe(429);
    expect(over.headers['retry-after']).toBeDefined();
    const body = over.json();
    expect(body.statusCode).toBe(429);
    expect(body.error).toMatch(/too many requests, try again in \d+ seconds/);
  });

  it('counts each phone id on its own, and the ?u= form counts as the same id', async () => {
    await make();
    for (let i = 0; i < 5; i++) await hit('/api/things', { 'x-clack-user': A });
    expect((await hit('/api/things', { 'x-clack-user': A })).statusCode).toBe(429);
    expect((await hit(`/api/things?u=${A}`)).statusCode).toBe(429);
    expect((await hit('/api/things', { 'x-clack-user': B })).statusCode).toBe(200);
  });

  it('counts requests without a usable id per address, with a lower limit, and a made-up id does not buy a new bucket', async () => {
    await make();
    for (let i = 0; i < 3; i++) expect((await hit('/api/things', { 'x-forwarded-for': '203.0.113.7', 'x-clack-user': `junk-${i}` })).statusCode).toBe(200);
    expect((await hit('/api/things', { 'x-forwarded-for': '203.0.113.7' })).statusCode).toBe(429);
    expect((await hit('/api/things', { 'x-forwarded-for': '203.0.113.8' })).statusCode).toBe(200);
  });

  it('never limits the SSE streams or health', async () => {
    await make();
    for (const url of ['/api/live/stream', '/api/live/trains/stream?bbox=1,2,3,4', '/api/stations/x/board/stream?type=arrivals', '/api/health']) {
      for (let i = 0; i < 20; i++) expect((await hit(url, { 'x-clack-user': A })).statusCode).toBe(200);
    }
    // And they did not use up the budget of the ordinary routes.
    expect((await hit('/api/things', { 'x-clack-user': A })).statusCode).toBe(200);
  });

  it('gives map tiles and logos their own, larger bucket', async () => {
    await make();
    for (let i = 0; i < 8; i++) expect((await hit(i % 2 ? '/api/map/tile' : '/api/operators/sj/logo', { 'x-clack-user': A })).statusCode).toBe(200);
    expect((await hit('/api/map/tile', { 'x-clack-user': A })).statusCode).toBe(429);
    expect((await hit('/api/things', { 'x-clack-user': A })).statusCode).toBe(200);
  });

  it('is wired into the real app', async () => {
    const real = buildApp(openDb(':memory:'));
    try {
      for (let i = 0; i < 5; i++) expect((await real.inject({ url: '/api/settings', headers: { 'x-clack-user': A } })).statusCode).toBe(200);
      expect((await real.inject({ url: '/api/settings', headers: { 'x-clack-user': A } })).statusCode).toBe(429);
      expect((await real.inject({ url: '/api/settings', headers: { 'x-clack-user': B } })).statusCode).toBe(200);
    } finally {
      await real.close();
    }
  });
});
