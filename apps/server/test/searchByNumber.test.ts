import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { operators, stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { searchByNumber } from '../src/search/timetable.js';

// Öresundståg via Denmark: Trafikverket calls it 21378, the GTFS feed 1378, and Pågatåg also runs a 1378
// (seen on the live map 2026-10-21).
function setup() {
  const db = openDb(':memory:');
  db.insert(stations)
    .values([
      { id: 'mc', name: 'Malmö C', country: 'SE', lat: 55.609, lon: 13.0, tz: 'Europe/Stockholm', trvSignature: 'M' },
      { id: 'hb', name: 'Helsingborg C', country: 'SE', lat: 56.043, lon: 12.695, tz: 'Europe/Stockholm', trvSignature: 'Hb' },
      { id: 'ys', name: 'Ystad', country: 'SE', lat: 55.43, lon: 13.82, tz: 'Europe/Stockholm', trvSignature: 'Ys' },
    ])
    .run();
  db.insert(operators)
    .values([
      { id: 'oresundstag', name: 'Öresundståg', shortName: 'ÖT', country: 'SE', brandColor: '#e5233c' },
      { id: 'pagatag', name: 'Pågatågen', shortName: 'PÅ', country: 'SE', brandColor: '#a71e2d' },
    ])
    .run();
  const trip = (key: string, number: string, operatorId: string, a: string, b: string) => {
    db.insert(timetableTrips).values({ key, source: 'gtfs_se3', tripId: key, trainNumber: number, operatorId, routeType: '100', category: 'regional', tz: 'Europe/Stockholm' }).run();
    db.insert(timetableTripDates).values({ tripKey: key, serviceDate: '2026-10-21' }).run();
    db.insert(timetableStopTimes)
      .values([
        { tripKey: key, seq: 1, stationId: a, arrSec: 17 * 3600, depSec: 17 * 3600 },
        { tripKey: key, seq: 2, stationId: b, arrSec: 18 * 3600, depSec: 18 * 3600 },
      ])
      .run();
  };
  trip('ore', '1378', 'oresundstag', 'mc', 'hb');
  trip('pag', '1378', 'pagatag', 'mc', 'ys');
  return db;
}

describe('train numbers with and without the prefix digit', () => {
  it("finds Trafikverket's 21378 as the timetable's 1378", () => {
    const db = setup();
    const r = searchByNumber(db, '21378', '2026-10-21');
    expect(r.map((t) => t.trainNumber)).toContain('1378');
  });

  it('still finds an exact number first', () => {
    const db = setup();
    expect(searchByNumber(db, '1378', '2026-10-21')[0]!.trainNumber).toBe('1378');
  });

  it('narrows a shared number down by operator', () => {
    const db = setup();
    const r = searchByNumber(db, '21378', '2026-10-21', { operatorId: 'oresundstag' });
    expect(r).toHaveLength(1);
    expect(r[0]!.to.name).toBe('Helsingborg C');
  });
});
