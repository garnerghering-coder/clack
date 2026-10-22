import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { searchConnections } from '../src/search/timetable.js';

// The owner's Alvesta → Rocksjön on 6 April 2026: no train ran through, so it was Alvesta → Värnamo, then
// Värnamo → Rocksjön (times from that day's archive timetable).
function setup() {
  const db = openDb(':memory:');
  const st = (id: string, name: string) => ({ id, name, country: 'SE', lat: 57, lon: 14, tz: 'Europe/Stockholm' });
  db.insert(stations).values([st('av', 'Alvesta'), st('vo', 'Värnamo C'), st('va', 'Vaggeryd'), st('rk', 'Rocksjön'), st('jo', 'Jönköping C')]).run();
  const hm = (s: string) => Number(s.slice(0, 2)) * 3600 + Number(s.slice(3)) * 60;
  const trip = (key: string, number: string, calls: [string, string][]) => {
    db.insert(timetableTrips).values({ key, source: 'gtfs_sv2', tripId: key, trainNumber: number, operatorId: null, routeType: '106', category: 'regional', tz: 'Europe/Stockholm' }).run();
    db.insert(timetableTripDates).values({ tripKey: key, serviceDate: '2026-04-06' }).run();
    db.insert(timetableStopTimes)
      .values(calls.map(([stationId, time], i) => ({ tripKey: key, seq: i + 1, stationId, arrSec: hm(time), depSec: hm(time) })))
      .run();
  };
  trip('a1', '17656', [['av', '09:36'], ['vo', '10:08']]);
  trip('b1', '7608', [['vo', '11:50'], ['va', '12:20'], ['rk', '12:53'], ['jo', '12:56']]);
  // Too tight to make (2 min), and a later pair that a better option beats.
  trip('a2', '17660', [['av', '11:00'], ['vo', '11:48']]);
  trip('a3', '17662', [['av', '09:00'], ['vo', '09:40']]);
  return db;
}

describe('trains with one change', () => {
  it('finds Alvesta → Värnamo → Rocksjön', () => {
    const r = searchConnections(setup(), 'av', 'rk', '2026-04-06');
    expect(r).toHaveLength(1);
    const c = r[0]!;
    expect([c.first.trainNumber, c.changeAt.name, c.second.trainNumber, c.changeMin]).toEqual(['17656', 'Värnamo C', '7608', 102]);
    expect([c.first.from.name, c.second.to.name]).toEqual(['Alvesta', 'Rocksjön']);
  });

  it('needs at least 5 minutes to change, and drops an option that leaves earlier for the same arrival', () => {
    const r = searchConnections(setup(), 'av', 'rk', '2026-04-06');
    expect(r.map((c) => c.first.trainNumber)).not.toContain('17660');
    expect(r.map((c) => c.first.trainNumber)).not.toContain('17662');
  });

  it('finds nothing when a single train runs between the stations', () => {
    expect(searchConnections(setup(), 'vo', 'rk', '2026-04-06')).toEqual([]);
  });
});
