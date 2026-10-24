import { cpSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { migrate } from 'drizzle-orm/better-sqlite3/migrator';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { buildApp } from '../src/app.js';
import { followedTrains, stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';

const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const B = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';
const NEW = '11111111-2222-4333-8444-555555555555';
const MIGRATIONS = join(__dirname, '..', 'drizzle');

function seed(db: ReturnType<typeof openDb>) {
  db.insert(stations)
    .values([
      { id: '740000140', name: 'Nässjö C', country: 'SE', lat: 57.652625, lon: 14.693759, tz: 'Europe/Stockholm', trvSignature: 'N' },
      { id: '740000004', name: 'Alvesta', country: 'SE', lat: 56.898911, lon: 14.55679, tz: 'Europe/Stockholm', trvSignature: 'Av' },
    ])
    .run();
  db.insert(timetableTrips).values({ key: 'k1', source: 'gtfs_se3', tripId: 't1', trainNumber: '1', routeType: '102', category: 'intercity', tz: 'Europe/Stockholm' }).run();
  db.insert(timetableTripDates).values({ tripKey: 'k1', serviceDate: '2026-10-20' }).run();
  db.insert(timetableStopTimes)
    .values([
      { tripKey: 'k1', seq: 4, stationId: '740000140', arrSec: 27 * 3600 + 14 * 60, depSec: 27 * 3600 + 14 * 60 },
      { tripKey: 'k1', seq: 5, stationId: '740000004', arrSec: 28 * 3600 + 3 * 60, depSec: 28 * 3600 + 3 * 60 },
    ])
    .run();
}

describe('coach and seat, and the export', () => {
  let db: ReturnType<typeof openDb>;
  let app: ReturnType<typeof buildApp>;
  beforeEach(() => {
    db = openDb(':memory:');
    seed(db);
    app = buildApp(db);
  });
  afterEach(() => app.close());

  const headers = (u: string) => ({ 'x-clack-user': u });
  const manual = { fromStationId: '740000140', toStationId: '740000004', date: '2015-07-01', dep: '10:00', arr: '11:00' };
  const create = async (u: string, extra: object = {}) => {
    const res = await app.inject({ method: 'POST', url: '/api/legs/manual', headers: headers(u), payload: { ...manual, ...extra } });
    expect(res.statusCode).toBe(201);
    return res.json();
  };
  const patch = (u: string, id: string, payload: object) => app.inject({ method: 'PATCH', url: `/api/legs/${id}`, headers: headers(u), payload });

  it('is null when not given and stored trimmed when given (manual and timetable legs)', async () => {
    const plain = await create(A);
    expect(plain.coach).toBeNull();
    expect(plain.seat).toBeNull();
    const seated = await create(A, { coach: ' 5 ', seat: '12A' });
    expect(seated.coach).toBe('5');
    expect(seated.seat).toBe('12A');
    const tt = await app.inject({ method: 'POST', url: '/api/legs', headers: headers(A), payload: { tripKey: 'k1', serviceDate: '2026-10-20', fromSeq: 4, toSeq: 5, coach: '3', seat: '44' } });
    expect(tt.statusCode).toBe(201);
    expect(tt.json()).toMatchObject({ coach: '3', seat: '44' });
    const list = (await app.inject({ method: 'GET', url: '/api/legs', headers: headers(A) })).json();
    expect(list.map((l: { coach: string | null }) => l.coach).sort()).toEqual(['3', '5', null]);
    const one = (await app.inject({ method: 'GET', url: `/api/legs/${seated.id}`, headers: headers(A) })).json();
    expect(one).toMatchObject({ coach: '5', seat: '12A' });
    const journey = (await app.inject({ method: 'GET', url: `/api/journeys/${seated.journeyId}`, headers: headers(A) })).json();
    expect(journey.legs[0]).toMatchObject({ coach: '5', seat: '12A' });
  });

  it('PATCH sets, clears and leaves them alone', async () => {
    const leg = await create(A, { coach: '5', seat: '12A' });
    let res = await patch(A, leg.id, { seat: '13B' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ coach: '5', seat: '13B' });
    res = await patch(A, leg.id, { coach: null });
    expect(res.json()).toMatchObject({ coach: null, seat: '13B' });
    res = await patch(A, leg.id, { seat: '  ' });
    expect(res.json()).toMatchObject({ coach: null, seat: null });
    res = await patch(A, leg.id, { trainType: null });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ coach: null, seat: null });
    expect((await patch(A, leg.id, {})).statusCode).toBe(400);
  });

  it('refuses too long or non-text values, and another user\'s leg', async () => {
    const leg = await create(A, { coach: '5' });
    expect((await patch(A, leg.id, { seat: '123456789' })).statusCode).toBe(400);
    expect((await patch(A, leg.id, { coach: 5 })).statusCode).toBe(400);
    expect((await patch(A, leg.id, { trainType: 'no-such-type', seat: '1' })).statusCode).toBe(400);
    expect((await app.inject({ method: 'GET', url: `/api/legs/${leg.id}`, headers: headers(A) })).json().seat).toBeNull();
    expect((await patch(B, leg.id, { seat: '1' })).statusCode).toBe(404);
    const bad = await app.inject({ method: 'POST', url: '/api/legs/manual', headers: headers(A), payload: { ...manual, seat: 'much too long' } });
    expect(bad.statusCode).toBe(400);
  });

  it('exports only this user\'s data, with a dated attachment name', async () => {
    const mine = await create(A, { coach: '5', seat: '12A' });
    await create(B, { coach: '9', seat: '99' });
    db.insert(followedTrains).values([
      { userId: A, trainNumber: '1', serviceDate: '2026-10-20' },
      { userId: B, trainNumber: '2', serviceDate: '2026-10-20' },
    ]).run();
    await app.inject({ method: 'PATCH', url: '/api/settings', headers: headers(A), payload: { distanceUnit: 'mi' } });
    const res = await app.inject({ method: 'GET', url: '/api/me/export', headers: headers(A) });
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-disposition']).toMatch(/^attachment; filename="clack-export-\d{4}-\d{2}-\d{2}\.json"$/);
    const body = res.json();
    expect(body.userId).toBe(A);
    expect(Number.isNaN(Date.parse(body.exportedAt))).toBe(false);
    expect(body.legs.map((l: { id: string }) => l.id)).toEqual([mine.id]);
    expect(body.legs[0]).toMatchObject({ coach: '5', seat: '12A' });
    expect(body.legs[0].stops).toHaveLength(2);
    expect(body.journeys).toHaveLength(1);
    expect(body.follows.map((f: { trainNumber: string }) => f.trainNumber)).toEqual(['1']);
    expect(body.settings.distanceUnit).toBe('mi');
    expect(JSON.stringify(body)).not.toContain('"99"');
    expect(JSON.stringify(body)).not.toContain(B);
  });

  it('gives a new user an empty export', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/me/export', headers: headers(NEW) });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ userId: NEW, legs: [], journeys: [], follows: [] });
    expect(res.json().settings).toBeTruthy();
  });
});

describe('migration 0015 on an existing database', () => {
  it('adds coach and seat to a database that has legs already', () => {
    const dir = mkdtempSync(join(tmpdir(), 'clack-mig-'));
    cpSync(MIGRATIONS, dir, { recursive: true });
    const journalPath = join(dir, 'meta', '_journal.json');
    const journal = JSON.parse(readFileSync(journalPath, 'utf8'));
    const full = JSON.stringify(journal);
    journal.entries = journal.entries.filter((e: { tag: string }) => e.tag !== '0015_leg_coach_seat');
    writeFileSync(journalPath, JSON.stringify(journal));
    const sqlite = new Database(join(dir, 'old.db'));
    sqlite.pragma('foreign_keys = ON');
    migrate(drizzle(sqlite), { migrationsFolder: dir });
    sqlite.exec(`INSERT INTO users (id, settings) VALUES ('u', '{}');
      INSERT INTO stations (id, name, country, lat, lon, tz) VALUES ('s1','A','SE',1,1,'Europe/Stockholm'),('s2','B','SE',2,2,'Europe/Stockholm');
      INSERT INTO legs (id, user_id, data_quality, origin_station_id, dest_station_id) VALUES ('l1','u','manual','s1','s2');`);
    expect(() => sqlite.prepare('SELECT coach FROM legs').all()).toThrow();
    writeFileSync(journalPath, full);
    migrate(drizzle(sqlite), { migrationsFolder: dir });
    expect(sqlite.prepare('SELECT id, coach, seat FROM legs').all()).toEqual([{ id: 'l1', coach: null, seat: null }]);
    sqlite.close();
  });
});
