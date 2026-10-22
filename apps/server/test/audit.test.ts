import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { LOCAL_USER_ID, openDb } from '../src/db/client.js';
import { legs, legStops, liveQuality, shownValues, stations } from '../src/db/schema.js';
import { auditLeg, runAudit, shownAt } from '../src/audit/audit.js';

const M = 60_000;
const T = (hhmm: string) => Date.parse(`2026-10-21T${hhmm}:00+02:00`);

function setup() {
  process.env.TRAFIKVERKET_API_KEY ||= 'test';
  const db = openDb(':memory:');
  db.insert(stations)
    .values([
      { id: 'cst', name: 'Stockholm C', country: 'SE', lat: 59.33, lon: 18.06, tz: 'Europe/Stockholm', trvSignature: 'Cst' },
      { id: 'u', name: 'Uppsala C', country: 'SE', lat: 59.86, lon: 17.64, tz: 'Europe/Stockholm', trvSignature: 'U' },
    ])
    .run();
  db.insert(legs)
    .values({
      id: 'l1',
      userId: LOCAL_USER_ID,
      status: 'snapshotted',
      dataQuality: 'full',
      trainNumber: '582',
      trvTrainNumbers: ['582'],
      serviceDate: '2026-10-21',
      originStationId: 'cst',
      destStationId: 'u',
      schedDep: new Date(T('10:00')),
      schedArr: new Date(T('10:40')),
      actualDep: new Date(T('10:02')),
      actualArr: new Date(T('10:48')),
      distanceM: 66_000,
      createdAt: new Date(T('08:00')),
    })
    .run();
  db.insert(legStops)
    .values([
      { legId: 'l1', seq: 1, stationId: 'cst', role: 'board', schedDep: new Date(T('10:00')), actualDep: new Date(T('10:02')), platform: '14', reportSource: 'trafikverket' },
      { legId: 'l1', seq: 2, stationId: 'u', role: 'alight', schedArr: new Date(T('10:40')), actualArr: new Date(T('10:48')), platform: '3', reportSource: 'trafikverket' },
    ])
    .run();
  // What the trip showed: the departure on time until 09:58, then 10:02; the arrival on time, then 10:47 from 10:20.
  db.insert(shownValues)
    .values([
      { legId: 'l1', seq: 1, field: 'dep', value: String(T('10:00')), shownAt: new Date(T('09:00')) },
      { legId: 'l1', seq: 1, field: 'dep', value: String(T('10:02')), shownAt: new Date(T('09:58')) },
      { legId: 'l1', seq: 2, field: 'arr', value: String(T('10:40')), shownAt: new Date(T('09:00')) },
      { legId: 'l1', seq: 2, field: 'arr', value: String(T('10:47')), shownAt: new Date(T('10:20')) },
      // The track at Stockholm C changed from 15 to 14 at 09:40, 20 minutes before departure.
      { legId: 'l1', seq: 1, field: 'platform', value: '15', shownAt: new Date(T('09:00')) },
      { legId: 'l1', seq: 1, field: 'platform', value: '14', shownAt: new Date(T('09:40')) },
    ])
    .run();
  db.insert(liveQuality).values({ legId: 'l1', ticks: 300, gpsTicks: 100, estimatedTicks: 20, failedTicks: 3, rejectedFixes: 1 }).run();
  return db;
}

// Trafikverket asked by train number: agrees at Stockholm C, a minute off at Uppsala.
const fetchImpl = (async () =>
  new Response(
    JSON.stringify({
      RESPONSE: {
        RESULT: [
          {
            TrainAnnouncement: [
              { AdvertisedTrainIdent: '582', LocationSignature: 'Cst', ActivityType: 'Avgang', AdvertisedTimeAtLocation: '2026-10-21T10:00:00.000+02:00', TimeAtLocation: '2026-10-21T10:02:00.000+02:00' },
              { AdvertisedTrainIdent: '582', LocationSignature: 'U', ActivityType: 'Ankomst', AdvertisedTimeAtLocation: '2026-10-21T10:40:00.000+02:00', TimeAtLocation: '2026-10-21T10:50:00.000+02:00' },
            ],
          },
        ],
      },
    }),
  )) as unknown as typeof fetch;

describe('accuracy audit', () => {
  const dirs: string[] = [];
  afterEach(() => {
    for (const d of dirs.splice(0)) fs.rmSync(d, { recursive: true, force: true });
  });

  it('reads the value shown at a moment', () => {
    const h = [
      { shownAt: 1, value: 'a' },
      { shownAt: 5, value: 'b' },
    ];
    expect(shownAt(h, 0)).toBeUndefined();
    expect(shownAt(h, 4)).toBe('a');
    expect(shownAt(h, 5)).toBe('b');
  });

  it('checks the record independently, and scores what was shown before each event', async () => {
    const a = (await auditLeg(setup(), 'l1', { fetchImpl }))!;
    expect(a.record).toMatchObject({ checked: 2, agree: 1, disagree: 1, missing: 0 });
    expect(a.record.examples[0]).toContain('Uppsala C');
    // 60 min before: both on-time values; departure 2 min off, arrival 8 min off.
    expect(a.predictions['60min']).toMatchObject({ n: 2, within1: 0, within3: 1, late: 2 });
    // 15 min before: departure still 10:00 (2 min off; 10:02 only showed from 09:58), arrival 10:47 (1 min off).
    expect(a.predictions['15min']).toMatchObject({ n: 2, within1: 1, within3: 2 });
    // 5 min before departure (09:57) it still showed 10:00: the 10:02 came a minute later.
    expect(a.predictions['5min']).toMatchObject({ n: 2, within1: 1, within3: 2 });
    expect(a.platforms).toEqual({ stops: 1, changedAfterShown: 1, wrong10MinBefore: 0 });
    expect(a.position).toMatchObject({ ticks: 300, failedTicks: 3, rejectedFixes: 1 });
    expect(a.position!.gpsShare).toBeCloseTo(100 / 120);
    expect(a.tracked).toBe(true);
  });

  it('audits each finished trip once and writes a report', async () => {
    const db = setup();
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-audit-'));
    dirs.push(dir);
    const now = T('14:00');
    expect((await runAudit(db, { fetchImpl, now, dir })).audited).toBe(1);
    expect((await runAudit(db, { fetchImpl, now, dir })).audited).toBe(0);
    const md = fs.readFileSync(path.join(dir, 'latest.md'), 'utf8');
    expect(md).toContain('| 2 | 1 (50%) | 1 | 0 |');
    expect(md).toContain('Uppsala C');
  });
});
