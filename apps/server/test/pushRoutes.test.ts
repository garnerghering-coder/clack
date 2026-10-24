import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { openDb } from '../src/db/client.js';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { devices, legs, liveActivities, stations, users } from '../src/db/schema.js';

const U = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const V = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';
const TOKEN = 'ab'.repeat(32);

describe('push routes', () => {
  // One app and database for the file, emptied between tests. Building one per test made the first test pay for
  // loading every route and the data behind it, which went past vitest's 5 s limit when other test files were running
  // alongside.
  let db: ReturnType<typeof openDb>;
  let app: ReturnType<typeof buildApp>;
  beforeAll(() => {
    db = openDb(':memory:');
    app = buildApp(db);
  }, 60_000);
  afterAll(async () => app?.close());
  beforeEach(() => {
    db.delete(liveActivities).run();
    db.delete(devices).run();
  });
  const make = () => ({ db, app });
  const put = (app: ReturnType<typeof buildApp>, user: string, body: unknown) => app.inject({ method: 'PUT', url: '/api/devices', headers: { 'x-clack-user': user }, payload: body as object });

  it('saves a phone, refreshes it, and moves it to a new id', async () => {
    const { db, app } = make();
    expect((await put(app, U, { token: TOKEN, environment: 'sandbox' })).statusCode).toBe(204);
    expect((await put(app, U, { token: TOKEN.toUpperCase(), environment: 'production', startToken: 'cd'.repeat(32) })).statusCode).toBe(204);
    const rows = db.select().from(devices).all();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ userId: U, environment: 'production', startToken: 'cd'.repeat(32) });
    await put(app, V, { token: TOKEN, environment: 'production' });
    expect(db.select().from(devices).all()[0]!.userId).toBe(V);
  });

  it('keeps the start and widget addresses when a key is left out, and clears them on null', async () => {
    const { db, app } = make();
    const START = 'cd'.repeat(32);
    const WIDGET = 'ef'.repeat(32);
    await put(app, U, { token: TOKEN, environment: 'sandbox', startToken: START, widgetToken: WIDGET.toUpperCase() });
    expect(db.select().from(devices).get()).toMatchObject({ startToken: START, widgetToken: WIDGET });
    // The app's first registration after a launch: neither address known yet, so the keys are left out.
    await put(app, U, { token: TOKEN, environment: 'sandbox' });
    expect(db.select().from(devices).get()).toMatchObject({ startToken: START, widgetToken: WIDGET });
    await put(app, U, { token: TOKEN, environment: 'sandbox', startToken: null });
    expect(db.select().from(devices).get()).toMatchObject({ startToken: null, widgetToken: WIDGET });
    await put(app, U, { token: TOKEN, environment: 'sandbox', widgetToken: null });
    expect(db.select().from(devices).get()).toMatchObject({ startToken: null, widgetToken: null });
    expect((await put(app, U, { token: TOKEN, environment: 'sandbox', widgetToken: 'zz' })).statusCode).toBe(400);
    expect((await put(app, U, { token: TOKEN, environment: 'sandbox', widgetToken: 5 })).statusCode).toBe(400);
  });

  it('ties a Live Activity to its phone when the app says which', async () => {
    const { db, app } = make();
    db.insert(users).values({ id: U, settings: DEFAULT_SETTINGS }).onConflictDoNothing().run();
    db.insert(stations).values([{ id: 'N', name: 'N', country: 'SE', lat: 57, lon: 14, tz: 'Europe/Stockholm', coordSource: 'gtfs' }]).run();
    db.insert(legs).values({ id: 'L1', userId: U, dataQuality: 'full', originStationId: 'N', destStationId: 'N', schedDep: new Date(), schedArr: new Date() }).run();
    const reg = (payload: object) => app.inject({ method: 'PUT', url: '/api/live-activities', headers: { 'x-clack-user': U }, payload });
    expect((await reg({ token: 'cd'.repeat(32), legId: 'L1', environment: 'sandbox', deviceToken: TOKEN.toUpperCase() })).statusCode).toBe(204);
    expect(db.select().from(liveActivities).get()).toMatchObject({ legId: 'L1', deviceToken: TOKEN });
    expect((await reg({ token: 'cd'.repeat(32), legId: 'L1', environment: 'sandbox' })).statusCode).toBe(204);
    expect(db.select().from(liveActivities).get()!.deviceToken).toBe(TOKEN);
    expect((await reg({ token: 'cd'.repeat(32), legId: 'L1', environment: 'sandbox', deviceToken: 'no' })).statusCode).toBe(400);
  });

  it('refuses bad tokens and environments', async () => {
    const { app } = make();
    expect((await put(app, U, { token: 'not hex', environment: 'sandbox' })).statusCode).toBe(400);
    expect((await put(app, U, { token: TOKEN, environment: 'nope' })).statusCode).toBe(400);
    expect((await put(app, U, { token: TOKEN, environment: 'sandbox', startToken: 'zz' })).statusCode).toBe(400);
  });

  it('only forgets your own phone', async () => {
    const { db, app } = make();
    await put(app, U, { token: TOKEN, environment: 'sandbox' });
    await app.inject({ method: 'DELETE', url: `/api/devices/${TOKEN}`, headers: { 'x-clack-user': V } });
    expect(db.select().from(devices).all()).toHaveLength(1);
    await app.inject({ method: 'DELETE', url: `/api/devices/${TOKEN}`, headers: { 'x-clack-user': U } });
    expect(db.select().from(devices).all()).toHaveLength(0);
  });

  it('a Live Activity must belong to one of your trips', async () => {
    const { app } = make();
    const r = await app.inject({ method: 'PUT', url: '/api/live-activities', headers: { 'x-clack-user': U }, payload: { token: TOKEN, legId: 'nope', environment: 'sandbox' } });
    expect(r.statusCode).toBe(404);
  });

  it('"Delete my data" removes the phone too', async () => {
    const { db, app } = make();
    await put(app, U, { token: TOKEN, environment: 'sandbox' });
    await app.inject({ method: 'DELETE', url: '/api/me', headers: { 'x-clack-user': U } });
    expect(db.select().from(devices).all()).toHaveLength(0);
    expect(db.select().from(liveActivities).all()).toHaveLength(0);
  });
});
