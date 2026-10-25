import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTrips } from '../src/db/schema.js';
import { popularStations } from '../src/routes/stations.js';

// The stations offered before you type: a few per country, Sweden first, commuter halts weighing a third.
describe('popular stations', () => {
  function seed() {
    const db = openDb(':memory:');
    const tz = 'Europe/Stockholm';
    const st = (id: string, country: string, kind = 'rail_station') => ({ id, name: id, country, lat: 60, lon: 15, tz, kind }) as typeof stations.$inferInsert;
    db.insert(stations)
      .values([st('SE1', 'SE'), st('SE2', 'SE'), st('SE3', 'SE'), st('SE4', 'SE'), st('SEC', 'SE'), st('NO1', 'NO'), st('NO2', 'NO'), st('NO3', 'NO'), st('FI1', 'FI'), st('FI2', 'FI'), st('DK1', 'DK')])
      .run();
    let n = 0;
    // `count` stops at the station on trains of the category.
    const stops = (stationId: string, category: string, count: number) => {
      for (let i = 0; i < count; i++) {
        const key = `t${n++}`;
        db.insert(timetableTrips).values({ key, source: 'gtfs_se3', tripId: key, trainNumber: key, routeType: '102', category, tz }).run();
        db.insert(timetableStopTimes).values({ tripKey: key, seq: 1, stationId, arrSec: 100, depSec: 100 }).run();
      }
    };
    stops('SEC', 'commuter', 30); // 9.9 weighted: loses to 10 long-distance stops
    stops('SE1', 'intercity', 10);
    stops('SE2', 'regional', 9);
    stops('SE3', 'regional', 8);
    stops('SE4', 'regional', 7);
    stops('NO1', 'regional', 5);
    stops('NO2', 'regional', 4);
    stops('NO3', 'regional', 3);
    stops('FI1', 'regional', 2);
    stops('FI2', 'regional', 1);
    stops('DK1', 'regional', 50);
    return db;
  }

  it('gives the top 3 Swedish, 2 Norwegian and 1 Finnish, Sweden first, with commuter weighed a third', () => {
    expect(popularStations(seed()).map((s) => s.id)).toEqual(['SE1', 'SEC', 'SE2', 'NO1', 'NO2', 'FI1']);
  });

  it('keeps the answer for an hour', () => {
    const db = seed();
    const first = popularStations(db, 0);
    db.delete(timetableStopTimes).run();
    expect(popularStations(db, 1000)).toBe(first);
    expect(popularStations(db, 3600_001)).toEqual([]);
  });
});
