import Fastify from 'fastify';
import { describe, expect, it } from 'vitest';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { openDb } from '../src/db/client.js';
import { journeys, legs, sharedJourneys, stations, users } from '../src/db/schema.js';
import { shareRoutes, sharePageRoutes } from '../src/routes/share.js';
import { changesOf, createShare, follow, following, publicJourney, revokeShare, SHARE_AFTER_ARRIVAL_MS, unfollow } from '../src/share/shared.js';

const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const B = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';
const MIN = 60_000;
const NOW = Date.parse('2026-10-25T12:00:00Z');

/** Two trains in one journey, Stockholm C → Hässleholm → Malmö C, with private things on them. */
function setup() {
  const db = openDb(':memory:');
  db.insert(users).values([{ id: A, settings: DEFAULT_SETTINGS }, { id: B, settings: DEFAULT_SETTINGS }]).run();
  db.insert(stations)
    .values([
      { id: 'cst', name: 'Stockholm C', country: 'SE', lat: 59.33, lon: 18.06, tz: 'Europe/Stockholm' },
      { id: 'hsl', name: 'Hässleholm C', country: 'SE', lat: 56.15, lon: 13.76, tz: 'Europe/Stockholm' },
      { id: 'mc', name: 'Malmö C', country: 'SE', lat: 55.61, lon: 13.0, tz: 'Europe/Stockholm' },
    ])
    .run();
  db.insert(journeys).values({ id: 'j1', userId: A }).run();
  const leg = (id: string, from: string, to: string, dep: number, arr: number, extra: Record<string, unknown> = {}) => ({
    id, userId: A, status: 'planned' as const, dataQuality: 'full', originStationId: from, destStationId: to,
    schedDep: new Date(dep), schedArr: new Date(arr), journeyId: 'j1', trainNumber: '547', coach: '4', seat: '23', notes: 'secret note', createdAt: new Date(NOW), ...extra,
  });
  db.insert(legs)
    .values([
      leg('l1', 'cst', 'hsl', NOW - 60 * MIN, NOW + 30 * MIN),
      leg('l2', 'hsl', 'mc', NOW + 45 * MIN, NOW + 90 * MIN, { trainNumber: '1387' }),
      leg('other', 'cst', 'mc', NOW, NOW + 60 * MIN, { userId: B, journeyId: null }),
    ])
    .run();
  return db;
}

describe('sharing a journey', () => {
  it('makes one token for the journey, the same again, and only for your own legs', () => {
    const db = setup();
    const a = createShare(db, A, { legId: 'l1' }, NOW)!;
    expect(a.legIds.sort()).toEqual(['l1', 'l2']);
    expect(createShare(db, A, { journeyId: 'j1' }, NOW)!.token).toBe(a.token);
    expect(a.token).toMatch(/^[A-Za-z0-9_-]{22}$/);
    expect(createShare(db, A, { legId: 'other' }, NOW)).toBeNull();
    expect(createShare(db, B, { legId: 'l1' }, NOW)).toBeNull();
    expect(createShare(db, A, {}, NOW)).toBeNull();
  });

  it('expires a day after the last arrival and stops when revoked', () => {
    const db = setup();
    const { token, expiresAt } = createShare(db, A, { legId: 'l1' }, NOW)!;
    expect(expiresAt.getTime()).toBe(NOW + 90 * MIN + SHARE_AFTER_ARRIVAL_MS);
    expect(publicJourney(db, token, NOW)).not.toBeNull();
    expect(publicJourney(db, token, expiresAt.getTime() + 1)).toBeNull();
    expect(revokeShare(db, B, token, NOW)).toBe(false);
    expect(revokeShare(db, A, token, NOW)).toBe(true);
    expect(publicJourney(db, token, NOW)).toBeNull();
    // A new share after revoking is a new token.
    expect(createShare(db, A, { legId: 'l1' }, NOW)!.token).not.toBe(token);
  });

  it('gives followers a cut-down copy with nothing private in it', () => {
    const db = setup();
    const { token } = createShare(db, A, { legId: 'l1' }, NOW)!;
    const copy = publicJourney(db, token, NOW)!;
    const text = JSON.stringify(copy);
    for (const secret of [A, 'secret note', '"seat"', '"coach"', 'j1', '"l1"', '"l2"', 'userId']) expect(text).not.toContain(secret);
    expect(Object.keys(copy).sort()).toEqual(['changes', 'expiresAt', 'legs', 'summary', 'token']);
    expect(Object.keys(copy.legs[0]!).sort()).toEqual([
      'arrPlatform', 'arrDelayMin', 'arrived', 'canceled', 'depDelayMin', 'depPlatform', 'departed', 'expArr', 'expDep', 'from', 'geometry', 'live',
      'operator', 'schedArr', 'schedDep', 'serviceDate', 'stops', 'to', 'trainNumber',
    ].sort());
    expect(copy.legs.map((l) => l.trainNumber)).toEqual(['547', '1387']);
    expect(copy.summary).toMatchObject({ phase: 'underway', legIndex: 0, from: 'Stockholm C', to: 'Malmö C' });
  });

  it('says where the journey is, and whether the change will be made', () => {
    const db = setup();
    const { token } = createShare(db, A, { legId: 'l1' }, NOW)!;
    expect(publicJourney(db, token, NOW - 2 * 60 * MIN)!.summary.phase).toBe('upcoming');
    expect(publicJourney(db, token, NOW + 35 * MIN)!.summary.phase).toBe('atChange');
    expect(publicJourney(db, token, NOW + 60 * MIN)!.summary.phase).toBe('underway');
    expect(publicJourney(db, token, NOW + 2 * 60 * MIN)!.summary.phase).toBe('arrived');
    const [change] = publicJourney(db, token, NOW)!.changes;
    expect(change).toMatchObject({ station: 'Hässleholm C', sameStation: true, spareMin: 15, status: 'ok' });
    const at = (arr: number, dep: number) => ({ expArr: arr, expDep: dep, arrPlatform: '1', depPlatform: '2', canceled: false, to: { name: 'X' }, from: { name: 'X' } });
    const two = (a: number, b: number) => changesOf([at(0, 0), at(0, 0)].map((l, i) => ({ ...l, expArr: i === 0 ? a : 0, expDep: i === 1 ? b : 0 })) as never)[0]!;
    expect(two(0, 6 * MIN).status).toBe('tight');
    expect(two(0, -3 * MIN).status).toBe('missed');
    expect(two(0, 20 * MIN).status).toBe('ok');
  });

  it('lets someone follow a live share, and list and leave it', () => {
    const db = setup();
    const { token } = createShare(db, A, { legId: 'l1' }, NOW)!;
    expect(follow(db, B, 'nope', NOW)).toBe(false);
    expect(follow(db, B, token, NOW)).toBe(true);
    expect(follow(db, B, token, NOW)).toBe(true);
    expect(following(db, B, NOW).map((j) => j.token)).toEqual([token]);
    revokeShare(db, A, token, NOW);
    expect(following(db, B, NOW)).toEqual([]);
    const second = createShare(db, A, { legId: 'l1' }, NOW)!.token;
    follow(db, B, second, NOW);
    unfollow(db, B, second);
    expect(following(db, B, NOW)).toEqual([]);
  });

  it('removes the shares and followers with the user', () => {
    const db = setup();
    const { token } = createShare(db, A, { legId: 'l1' }, NOW)!;
    follow(db, B, token, NOW);
    db.delete(users).where(eqUser(A)).run();
    expect(db.select().from(sharedJourneys).all()).toHaveLength(0);
    expect(following(db, B, NOW)).toEqual([]);
  });
});

import { eq } from 'drizzle-orm';
const eqUser = (id: string) => eq(users.id, id);

async function appFor() {
  const db = setup();
  const app = Fastify();
  app.decorateRequest('userId', '');
  app.addHook('onRequest', async (req) => {
    req.userId = (req.headers['x-clack-user'] as string | undefined) ?? 'local';
  });
  await app.register(sharePageRoutes);
  await app.register(shareRoutes(db), { prefix: '/api' });
  return { db, app };
}

describe('the share routes', () => {
  it('shares, serves the public copy to anyone, and stops', async () => {
    const { app } = await appFor();
    const made = await app.inject({ method: 'POST', url: '/api/share/journey', headers: { 'x-clack-user': A }, payload: { legId: 'l1' } });
    expect(made.statusCode).toBe(200);
    const { token, url } = made.json();
    expect(url).toMatch(new RegExp(`/j/${token}$`));
    expect((await app.inject({ url: `/api/share?legId=l1`, headers: { 'x-clack-user': A } })).json().token).toBe(token);
    expect((await app.inject({ url: `/api/share?legId=l1`, headers: { 'x-clack-user': B } })).json().token).toBeNull();

    const open = await app.inject({ url: `/api/shared/${token}` });
    expect(open.statusCode).toBe(200);
    expect(open.headers['x-robots-tag']).toBe('noindex');
    expect(open.json().legs).toHaveLength(2);

    expect((await app.inject({ method: 'PUT', url: `/api/following/${token}`, headers: { 'x-clack-user': B } })).statusCode).toBe(200);
    expect((await app.inject({ url: '/api/following', headers: { 'x-clack-user': B } })).json()).toHaveLength(1);

    expect((await app.inject({ method: 'DELETE', url: `/api/share/${token}`, headers: { 'x-clack-user': B } })).statusCode).toBe(404);
    expect((await app.inject({ method: 'DELETE', url: `/api/share/${token}`, headers: { 'x-clack-user': A } })).statusCode).toBe(204);
    expect((await app.inject({ url: `/api/shared/${token}` })).statusCode).toBe(404);
    expect((await app.inject({ method: 'PUT', url: `/api/following/${token}`, headers: { 'x-clack-user': B } })).statusCode).toBe(404);
    expect((await app.inject({ url: '/api/shared/short' })).statusCode).toBe(404);
  });

  it('serves the page, its files and the file Apple reads, and nothing outside its folder', async () => {
    const { app } = await appFor();
    const page = await app.inject({ url: '/j/abcdefghijklmnopqrstuv' });
    expect(page.statusCode).toBe(200);
    expect(page.headers['content-type']).toContain('text/html');
    expect(page.headers['cache-control']).toBe('no-store');
    expect(page.headers['x-robots-tag']).toBe('noindex');
    expect((await app.inject({ url: '/share-assets/share.js' })).statusCode).toBe(200);
    expect((await app.inject({ url: '/share-assets/..%2F..%2Fpackage.json' })).statusCode).toBe(404);
    expect((await app.inject({ url: '/share-assets/.env' })).statusCode).toBe(404);
    const aasa = (await app.inject({ url: '/.well-known/apple-app-site-association' })).json();
    expect(aasa.applinks.details[0].appIDs).toEqual(['HJTCN7QR8M.com.garnerghering.Clack']);
    expect(aasa.applinks.details[0].components[0]['/']).toBe('/j/*');
  });
});
