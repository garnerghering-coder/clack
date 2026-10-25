import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { trainsSoon } from '../src/legs/soon.js';
import { serviceTimeToUtc } from '../src/lib/time.js';

// Real trains leaving soon, for the first screen: next hour, whole run to the last stop, one per destination.
describe('trains leaving soon', () => {
  const date = '2026-10-20';
  const tz = 'Europe/Stockholm';
  const at = (h: number, m: number) => serviceTimeToUtc(date, h * 3600 + m * 60, tz);
  function seed() {
    const db = openDb(':memory:');
    db.insert(stations)
      .values([
        { id: 'A', name: 'Stockholm C', country: 'SE', lat: 59.33, lon: 18.06, tz },
        { id: 'B', name: 'Uppsala C', country: 'SE', lat: 59.86, lon: 17.64, tz },
        { id: 'C', name: 'Göteborg C', country: 'SE', lat: 57.71, lon: 11.97, tz },
      ])
      .run();
    const trip = (key: string, number: string, category: string, stops: [string, number][]) => {
      db.insert(timetableTrips).values({ key, source: 'gtfs_se3', tripId: key, trainNumber: number, routeType: '102', category, tz }).run();
      db.insert(timetableTripDates).values({ tripKey: key, serviceDate: date }).run();
      db.insert(timetableStopTimes).values(stops.map(([stationId, sec], i) => ({ tripKey: key, seq: i + 1, stationId, arrSec: sec, depSec: sec }))).run();
    };
    trip('soon', '100', 'intercity', [['A', 10 * 3600 + 20 * 60], ['C', 13 * 3600]]);
    trip('later', '200', 'intercity', [['A', 12 * 3600], ['C', 15 * 3600]]);
    trip('gone', '300', 'regional', [['A', 9 * 3600 + 50 * 60], ['B', 10 * 3600 + 30 * 60]]);
    trip('short', '400', 'regional', [['A', 10 * 3600 + 30 * 60], ['B', 10 * 3600 + 40 * 60]]);
    trip('same', '500', 'intercity', [['A', 10 * 3600 + 40 * 60], ['C', 13 * 3600 + 20 * 60]]);
    return db;
  }

  it('gives trains in the next hour near you, to their last stop, one per destination, no short hops', () => {
    const db = seed();
    const soon = trainsSoon(db, { lat: 59.33, lon: 18.06, now: at(10, 0) });
    expect(soon.map((t) => t.trainNumber)).toEqual(['100']);
    expect(soon[0]).toMatchObject({ tripKey: 'soon', serviceDate: date, fromSeq: 1, toSeq: 2, from: { name: 'Stockholm C' }, to: { name: 'Göteborg C' } });
    expect(soon[0]!.dep).toBe(at(10, 20));
  });

  it('falls back to the big stations far from any (or without a location)', () => {
    expect(trainsSoon(seed(), { lat: 40, lon: 0, now: at(10, 0) }).map((t) => t.trainNumber)).toEqual(['100']);
    expect(trainsSoon(seed(), { now: at(10, 0) }).map((t) => t.trainNumber)).toEqual(['100']);
  });
});
