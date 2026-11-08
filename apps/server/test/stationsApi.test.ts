import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { openDb, type Db } from '../src/db/client.js';
import { buildApp } from '../src/app.js';
import { importLog, stations } from '../src/db/schema.js';

describe('stations API', () => {
  let db: Db;
  let app: ReturnType<typeof buildApp>;
  beforeEach(() => {
    db = openDb(':memory:');
    db.insert(stations)
      .values([
        { id: '740000002', name: 'Göteborg C', country: 'SE', lat: 57.7, lon: 11.97, tz: 'Europe/Stockholm', trvSignature: 'G', departuresPerDay: 250 },
        { id: '740000491', name: 'Funäsdalen busstation', country: 'SE', lat: 62.5, lon: 12.5, tz: 'Europe/Stockholm', kind: 'bus_stop' },
      ])
      .run();
    app = buildApp(db);
  });
  afterEach(() => app.close());

  it('autocompletes accent-insensitively and hides bus stops', async () => {
    const res = await app.inject({ url: '/api/stations/search?q=goteb' });
    expect(res.json()).toEqual([{ id: '740000002', name: 'Göteborg C', code: 'G', country: 'SE', county: null }]);
    expect((await app.inject({ url: '/api/stations/search?q=funasdalen' })).json()).toEqual([]);
    // "ö" typed as o + a combining diaeresis (some keyboards, pasted text) matches too.
    expect((await app.inject({ url: `/api/stations/search?q=${encodeURIComponent('Go\u0308teborg C')}` })).json()).toHaveLength(1);
  });

  it('picks up stations added by a later import', async () => {
    await app.inject({ url: '/api/stations/search?q=x' });
    db.insert(stations).values({ id: '740000003', name: 'Malmö C', country: 'SE', lat: 55.6, lon: 13, tz: 'Europe/Stockholm', trvSignature: 'Mc' }).run();
    db.insert(importLog).values({ source: 'gtfs_se3', startedAt: new Date(), status: 'ok', notes: '{}' }).run();
    expect((await app.inject({ url: '/api/stations/search?q=malmo' })).json()[0].name).toBe('Malmö C');
  });

  it('serves a station map with an ETag and answers 304 when the phone has it', async () => {
    const first = await app.inject({ url: '/api/stations/740000002/map' });
    expect(first.statusCode).toBe(200);
    const etag = first.headers.etag as string;
    expect(etag).toMatch(/^"[0-9a-z]+-[0-9a-z]+"$/);
    expect(first.headers['cache-control']).toBe('public, max-age=3600');
    const again = await app.inject({ url: '/api/stations/740000002/map', headers: { 'if-none-match': etag } });
    expect(again.statusCode).toBe(304);
    expect(again.body).toBe('');
    expect((await app.inject({ url: '/api/stations/740000002/map', headers: { 'if-none-match': '"old"' } })).statusCode).toBe(200);
    expect((await app.inject({ url: '/api/stations/740000491/map' })).statusCode).toBe(404);
  });

  it('reports import status and quota', async () => {
    process.env.CLACK_ADMIN_TOKEN = 'test-admin-token';
    const body = (await app.inject({ url: '/api/import/status', headers: { 'x-clack-admin': 'test-admin-token' } })).json();
    delete process.env.CLACK_ADMIN_TOKEN;
    expect(body).toMatchObject({ stations: 2, trips: 0, quota: [
        { source: 'gtfs_se3', usedThisMonth: 0, monthlyQuota: 50 },
        { source: 'digitraffic_gtfs', usedThisMonth: 0, monthlyQuota: 40 },
      ],
    });
  });
});
