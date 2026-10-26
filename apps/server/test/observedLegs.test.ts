import { describe, expect, it } from 'vitest';
import { openDb, LOCAL_USER_ID } from '../src/db/client.js';
import { legs, legStops, stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { createLeg } from '../src/legs/legs.js';
import { refreshLegActuals } from '../src/legs/actuals.js';
import { saveRuns } from '../src/observed/store.js';
import { serviceTimeToUtc } from '../src/lib/time.js';
import { eq } from 'drizzle-orm';

// SJ 1, Nässjö C 03:14 → Alvesta 04:03 on service date 2026-10-20, saved long after Trafikverket forgot it.
const TZ = 'Europe/Stockholm';
const dep = serviceTimeToUtc('2026-10-20', 27 * 3600 + 14 * 60, TZ);
const arr = serviceTimeToUtc('2026-10-20', 28 * 3600 + 3 * 60, TZ);

function setup(platforms: [string | null, string | null] = [null, null]) {
  const db = openDb(':memory:');
  db.insert(stations)
    .values([
      { id: '740000140', name: 'Nässjö C', country: 'SE', lat: 57.652625, lon: 14.693759, tz: TZ, trvSignature: 'N' },
      { id: '740000004', name: 'Alvesta', country: 'SE', lat: 56.898911, lon: 14.55679, tz: TZ, trvSignature: 'Av' },
    ])
    .run();
  db.insert(timetableTrips).values({ key: 'k1', source: 'gtfs_se3', tripId: 't1', trainNumber: '1', routeType: '102', category: 'intercity', tz: TZ }).run();
  db.insert(timetableTripDates).values({ tripKey: 'k1', serviceDate: '2026-10-20' }).run();
  db.insert(timetableStopTimes)
    .values([
      { tripKey: 'k1', seq: 4, stationId: '740000140', arrSec: 27 * 3600 + 14 * 60, depSec: 27 * 3600 + 14 * 60, platform: platforms[0] },
      { tripKey: 'k1', seq: 5, stationId: '740000004', arrSec: 28 * 3600 + 3 * 60, depSec: 28 * 3600 + 3 * 60, platform: platforms[1] },
    ])
    .run();
  return db;
}

const call = (seq: number, location: string, stationId: string, o: Record<string, unknown>) => ({
  seq,
  location,
  stationId,
  schedArr: null,
  schedDep: null,
  estArr: null,
  estDep: null,
  actualArr: null,
  actualDep: null,
  platform: null,
  canceledArr: false,
  canceledDep: false,
  causes: [],
  extra: {},
  ...o,
});

const later = Date.parse('2026-11-05T12:00:00Z');
const offline = (async () => {
  throw new Error('no network in tests');
}) as typeof fetch;

describe('saved trips and the observed record', () => {
  it('gets real times, platforms and causes from the record once Trafikverket has forgotten the day', async () => {
    const db = setup();
    saveRuns(db, [
      {
        country: 'SE',
        serviceDate: '2026-10-20',
        runId: '1',
        trainNumber: '1',
        source: 'trafikverket',
        operator: 'SJ',
        product: 'SJ InterCity',
        canceled: 0,
        info: {},
        passages: [],
        final: true,
        calls: [
          call(1, 'N', '740000140', { schedDep: dep, actualDep: dep + 120_000, platform: '2' }),
          call(2, 'Av', '740000004', { schedArr: arr, actualArr: arr + 9 * 60_000, platform: '1b', causes: [{ src: 'trv', code: 'ANA027', text: 'Banarbete' }] }),
        ],
      },
    ]);
    const id = createLeg(db, LOCAL_USER_ID, { tripKey: 'k1', serviceDate: '2026-10-20', fromSeq: 4, toSeq: 5 }, later);
    expect(await refreshLegActuals(db, id, { now: later, fetchImpl: offline })).toBe('full');
    const leg = db.select().from(legs).where(eq(legs.id, id)).get()!;
    expect(leg.arrDelayMin).toBe(9);
    expect([leg.depPlatform, leg.arrPlatform]).toEqual(['2', '1b']);
    const alight = db.select().from(legStops).where(eq(legStops.seq, 5)).get()!;
    expect(JSON.parse(alight.causes!)).toEqual([{ src: 'trv', code: 'ANA027', text: 'Banarbete' }]);
    expect(alight.reportSource).toBe('trafikverket');
  });

  it("shows the timetable's planned platform when no source has one", async () => {
    const db = setup(['3', null]);
    const id = createLeg(db, LOCAL_USER_ID, { tripKey: 'k1', serviceDate: '2026-10-20', fromSeq: 4, toSeq: 5 }, later);
    await refreshLegActuals(db, id, { now: later, fetchImpl: offline });
    const leg = db.select().from(legs).where(eq(legs.id, id)).get()!;
    expect(leg.depPlatform).toBe('3');
    expect(leg.arrPlatform).toBeNull();
    expect(leg.dataQuality).toBe('scheduled_only');
  });
});
