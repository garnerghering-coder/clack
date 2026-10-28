import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { dayIndex, plan } from '../src/search/planner.js';
import { serviceTimeToUtc } from '../src/lib/time.js';

// A small network on 29 Oct 2026, modelled on the owner's Jönköping → Kolding: change at Nässjö onto the Berlin train,
// or two changes via Alvesta and København H. Stations are default tier (7 min) except København H, a hub in
// data/station_tiers.json (15 min).
const D = '2026-10-29';
async function setup() {
  const db = openDb(':memory:');
  const st = (id: string, name: string, country = 'SE') => ({ id, name, country, lat: 57, lon: 14, tz: 'Europe/Stockholm' });
  db.insert(stations).values([st('jo', 'Jönköping C'), st('ns', 'Nässjö C'), st('av', 'Alvesta'), st('860000626', 'København H', 'DK'), st('kd', 'Kolding', 'DK')]).run();
  const hm = (s: string) => Number(s.slice(0, 2)) * 3600 + Number(s.slice(3)) * 60;
  const trip = (key: string, number: string, calls: [string, string][]) => {
    db.insert(timetableTrips).values({ key, source: 'gtfs_se3', tripId: key, trainNumber: number, operatorId: null, routeType: '2', category: 'regional', tz: 'Europe/Stockholm' }).run();
    db.insert(timetableTripDates).values({ tripKey: key, serviceDate: D }).run();
    db.insert(timetableStopTimes).values(calls.map(([stationId, time], i) => ({ tripKey: key, seq: i + 1, stationId, arrSec: hm(time), depSec: hm(time) }))).run();
  };
  trip('a', '27616', [['jo', '12:39'], ['ns', '13:20']]);
  trip('b', '307', [['ns', '13:42'], ['kd', '18:52']]);
  trip('c', '17601', [['jo', '04:48'], ['av', '05:50']]);
  trip('d', '1033', [['av', '06:00'], ['860000626', '09:00']]);
  trip('e', '835', [['860000626', '09:48'], ['kd', '11:46']]);
  // Too tight at Nässjö (3 min, under the 7-min default): never offered.
  trip('f', '27618', [['jo', '13:30'], ['ns', '14:15']]);
  trip('g', '309', [['ns', '14:18'], ['kd', '19:30']]);
  return db;
}
const day = serviceTimeToUtc(D, 0, 'Europe/Stockholm');

describe('the journey planner', () => {
  it('finds the one-change and the two-change journeys, with the real wait at each change', async () => {
    const db = await setup();
    const js = plan(db, await dayIndex(db, D), 'jo', 'kd', day, day + 86400_000);
    expect(js.map((j) => j.legs.map((l) => l.trainNumber))).toEqual([['17601', '1033', '835'], ['27616', '307']]);
    expect(js[1]!.changes).toEqual([{ stationId: 'ns', name: 'Nässjö C', gapMin: 22, minMin: 7, comfort: 'relaxed' }]);
    // København H: a cross-border change at a hub needs 15, not 7 + 10.
    expect(js[0]!.changes.map((c) => [c.name, c.gapMin, c.minMin])).toEqual([['Alvesta', 10, 7], ['København H', 48, 15]]);
  });
  it('never offers a change below the minimum, and limits the changes when asked', async () => {
    const db = await setup();
    const ix = await dayIndex(db, D);
    expect(plan(db, ix, 'jo', 'kd', day, day + 86400_000).some((j) => j.legs[0]!.trainNumber === '27618')).toBe(false);
    expect(plan(db, ix, 'jo', 'kd', day, day + 86400_000, 1).map((j) => j.changes.length)).toEqual([1]);
    expect(plan(db, ix, 'jo', 'kd', day, day + 86400_000, 0)).toEqual([]);
  });
});
