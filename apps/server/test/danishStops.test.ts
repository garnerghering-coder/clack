import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { tripByKey } from '../src/search/timetable.js';
import { journeyStopsView } from '../src/rejseplanen/stops.js';
import { RejseplanenUnavailable, type Journey, type RejseplanenClient } from '../src/rejseplanen/client.js';

describe('Danish trains always get their stops', () => {
  it('finds a trip by its key when the train number is the line number (Lokaltog 910 is train 240353)', () => {
    const db = openDb(':memory:');
    db.insert(stations).values([
      { id: 'jb', name: 'Jægersborg', country: 'DK', lat: 55.76, lon: 12.53, tz: 'Europe/Copenhagen' },
      { id: 'nr', name: 'Nærum', country: 'DK', lat: 55.81, lon: 12.53, tz: 'Europe/Copenhagen' },
    ]).run();
    db.insert(timetableTrips).values({ key: 'dk:169807381:f1', source: 'gtfs_dk', tripId: '169807381', trainNumber: '240353', operatorId: null, routeType: '2', category: 'regional', routeName: '910 Nærum', tz: 'Europe/Copenhagen' }).run();
    db.insert(timetableTripDates).values({ tripKey: 'dk:169807381:f1', serviceDate: '2026-10-28' }).run();
    db.insert(timetableStopTimes).values([
      { tripKey: 'dk:169807381:f1', seq: 1, stationId: 'jb', arrSec: 36000, depSec: 36000 },
      { tripKey: 'dk:169807381:f1', seq: 2, stationId: 'nr', arrSec: 36900, depSec: 36900 },
    ]).run();
    const r = tripByKey(db, 'dk:169807381:f1', '2026-10-28');
    expect(r?.trainNumber).toBe('240353');
    expect([r?.from.name, r?.to.name]).toEqual(['Jægersborg', 'Nærum']);
    expect(tripByKey(db, 'dk:169807381:f1', '2026-10-29')).toBeNull();
  });

  it('serves the last stop list when Rejseplanen is out of requests, and nothing once it is too old', async () => {
    const db = openDb(':memory:');
    const journey = {
      jid: 'J1', date: '2026-10-28', name: 'Re 2968', number: '2968', line: null, category: 'Re', operator: 'DSB', admin: null, direction: null,
      cancelled: false, notices: [], pos: null, ends: null,
      stops: ['Horsens', 'Vejle'].map((name, i) => ({ uic: null, name, lat: null, lon: null, arrPlanned: 1e12 + i * 6e5, arrLive: null, depPlanned: 1e12 + i * 6e5, depLive: null, arrPlatform: null, depPlatform: null, arrPlatformPlanned: null, depPlatformPlanned: null, arrCancelled: false, depCancelled: false, prognosis: null })),
    } as Journey;
    let limited = false;
    const client = {
      available: () => true,
      journeyDetails: async () => {
        if (limited) throw new RejseplanenUnavailable('Rejseplanen request limit reached');
        return journey;
      },
    } as unknown as RejseplanenClient;
    const t0 = 1e12;
    expect((await journeyStopsView(db, 'J1', { client, now: t0 }))?.map((s) => s.name)).toEqual(['Horsens', 'Vejle']);
    limited = true;
    // A minute later the cache is past its 50 s but Rejseplanen is limited: the remembered list.
    expect((await journeyStopsView(db, 'J1', { client, now: t0 + 60_000 }))?.length).toBe(2);
    // Eleven minutes later: too old to show as current.
    expect(await journeyStopsView(db, 'J1', { client, now: t0 + 11 * 60_000 })).toBeNull();
  }, 20_000);
});
