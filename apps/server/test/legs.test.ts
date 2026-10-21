import { describe, expect, it } from 'vitest';
import { openDb, LOCAL_USER_ID } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { createLeg, getLeg, LegError } from '../src/legs/legs.js';

// SJ 1 as the owner rode it on 2026-10-21: Nässjö C 03:14 → Alvesta 04:03 (service date 2026-10-20).
function setup() {
  const db = openDb(':memory:');
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
  return db;
}

describe('saving a leg', () => {
  it('routes it along the rail network straight away, not as a straight line', () => {
    const db = setup();
    const id = createLeg(db, LOCAL_USER_ID, { tripKey: 'k1', serviceDate: '2026-10-20', fromSeq: 4, toSeq: 5 });
    const leg = getLeg(db, LOCAL_USER_ID, id)!;
    expect(leg.isEstimatedGeometry).toBe(false);
    expect(leg.geometry?.length).toBeGreaterThan(100);
    // Along the Södra stambanan: ~87 km, vs 84 km in a straight line.
    expect(leg.distanceM! / 1000).toBeGreaterThan(85);
    expect(leg.distanceM! / 1000).toBeLessThan(92);
  });

  it('warns about the same train twice on one date', () => {
    const db = setup();
    createLeg(db, LOCAL_USER_ID, { tripKey: 'k1', serviceDate: '2026-10-20', fromSeq: 4, toSeq: 5 });
    expect(() => createLeg(db, LOCAL_USER_ID, { tripKey: 'k1', serviceDate: '2026-10-20', fromSeq: 4, toSeq: 5 })).toThrow(LegError);
  });
});
