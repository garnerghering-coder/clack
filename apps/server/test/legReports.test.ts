import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { buildApp } from '../src/app.js';
import { legReports, shownValues, stations } from '../src/db/schema.js';
import { cleanNote, cleanShown, fileReport, ReportError } from '../src/legs/reports.js';
import { formatReports, listLegReports } from '../src/tools/legReports.js';

// "This is wrong" from a trip page (owner, 2026-11-07): kept with what the phone showed and what the server held.
const A = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
const B = '9a8b7c6d-5e4f-4a3b-9c2d-1e0f2a3b4c5d';

describe('leg reports', () => {
  let db: ReturnType<typeof openDb>;
  let app: ReturnType<typeof buildApp>;
  beforeEach(() => {
    db = openDb(':memory:');
    db.insert(stations)
      .values([
        { id: '740000140', name: 'Nässjö C', country: 'SE', lat: 57.652625, lon: 14.693759, tz: 'Europe/Stockholm', trvSignature: 'N' },
        { id: '740000004', name: 'Alvesta', country: 'SE', lat: 56.898911, lon: 14.55679, tz: 'Europe/Stockholm', trvSignature: 'Av' },
      ])
      .run();
    app = buildApp(db);
  });
  afterEach(() => app.close());

  const headers = (u: string) => ({ 'x-clack-user': u });
  const create = async () => {
    const res = await app.inject({
      method: 'POST', url: '/api/legs/manual', headers: headers(A),
      payload: { fromStationId: '740000140', toStationId: '740000004', date: '2026-10-20', dep: '10:00', arr: '11:00', trainNumber: '1' },
    });
    expect(res.statusCode).toBe(201);
    return res.json() as { id: string };
  };
  const report = (u: string, id: string, payload: object) => app.inject({ method: 'POST', url: `/api/legs/${id}/report`, headers: headers(u), payload });

  it("stores the note, what was shown and the server's state, for the owner's trip only", async () => {
    const leg = await create();
    db.insert(shownValues).values({ legId: leg.id, seq: 2, field: 'arr', value: '1760954400000', shownAt: new Date('2026-10-20T08:00:00Z') }).run();
    const res = await report(A, leg.id, { note: '  The train was 20 minutes late, the app said on time. ', shown: { arr: '11:00', platform: '2' } });
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ id: expect.any(String), createdAt: expect.any(Number) });
    const rows = db.select().from(legReports).all();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ legId: leg.id, userId: A, note: 'The train was 20 minutes late, the app said on time.', shown: { arr: '11:00', platform: '2' } });
    const state = rows[0]!.serverState as { leg: { trainNumber: string }; stops: unknown[]; shownValues: Record<string, { value: string }> };
    expect(state.leg.trainNumber).toBe('1');
    expect(state.stops).toHaveLength(2);
    expect(state.shownValues['2.arr']!.value).toBe('1760954400000');
    // Someone else's trip is not there to report on; an unknown trip neither.
    expect((await report(B, leg.id, { note: 'x' })).statusCode).toBe(404);
    expect((await report(A, 'nope', { note: 'x' })).statusCode).toBe(404);
  });

  it('takes an empty report, refuses a bad one, and one report per ten minutes', async () => {
    const leg = await create();
    expect((await report(A, leg.id, {})).statusCode).toBe(201);
    const again = await report(A, leg.id, { note: 'again' });
    expect(again.statusCode).toBe(429);
    expect(db.select().from(legReports).all()).toHaveLength(1);
    expect(() => fileReport(db, A, leg.id, { note: 'later' }, Date.now() + 11 * 60_000)).not.toThrow();
    expect((await report(A, leg.id, { note: 'x'.repeat(501) })).statusCode).toBe(400);
    expect((await report(A, leg.id, { shown: [1, 2] })).statusCode).toBe(400);
    expect((await report(A, leg.id, { note: 42 })).statusCode).toBe(400);
  });

  it('cleans the fields', () => {
    expect(cleanNote(undefined)).toBeNull();
    expect(cleanNote('   ')).toBeNull();
    expect(cleanNote(' late ')).toBe('late');
    expect(() => cleanNote('x'.repeat(501))).toThrow(ReportError);
    expect(cleanShown(null)).toBeNull();
    expect(cleanShown({ a: 1 })).toEqual({ a: 1 });
    expect(() => cleanShown('a')).toThrow(ReportError);
    expect(() => cleanShown({ big: 'x'.repeat(9000) })).toThrow(ReportError);
  });

  it('lists recent reports with the trip they are about', async () => {
    const leg = await create();
    await report(A, leg.id, { note: 'Platform was 3, not 2', shown: { platform: '2' } });
    const rows = listLegReports(db, { days: 1 });
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ legId: leg.id, trainNumber: '1', serviceDate: '2026-10-20', from: 'Nässjö C', to: 'Alvesta', note: 'Platform was 3, not 2' });
    const text = formatReports(rows);
    expect(text).toContain('1 2026-10-20 Nässjö C → Alvesta');
    expect(text).toContain('"Platform was 3, not 2"');
    expect(text).toContain('shown {"platform":"2"}');
    expect(formatReports([])).toBe('no reports');
    // Gone with the trip.
    await app.inject({ method: 'DELETE', url: `/api/legs/${leg.id}`, headers: headers(A) });
    expect(listLegReports(db)).toHaveLength(0);
  });
});
