// Older Danish days in search: ready where a copy of Rejseplanen's timetable has trains, else "Denmark" with the first
// day on record and the stretches no copy covers (search/danishDays.ts).
import { afterEach, describe, expect, it, vi } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { createSmartSearch } from '../src/search/smartSearch.js';
import { buildStationIndex } from '../src/search/stations.js';
import { danishDays, forgetDanishDays, gapsIn } from '../src/search/danishDays.js';

const CPH = 'Europe/Copenhagen';
const VEJLE = '860000041';
const FREDERICIA = '860000040';

/** IC trains Vejle → Fredericia (one key per day, as the import's pattern hash would differ) on the given dates. */
function setup(dates: string[]) {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(Date.parse('2026-11-15T10:00:00Z'));
  const db = openDb(':memory:');
  db.insert(stations)
    .values([
      { id: VEJLE, name: 'Vejle', country: 'DK', lat: 55.7083, lon: 9.5361, tz: CPH },
      { id: FREDERICIA, name: 'Fredericia', country: 'DK', lat: 55.5644, lon: 9.7408, tz: CPH },
    ])
    .run();
  for (const d of dates) {
    const key = `dk:t${d}:h`;
    db.insert(timetableTrips).values({ key, source: 'gtfs_dk', tripId: `t${d}`, trainNumber: '140', routeType: '2', category: 'intercity', tz: CPH }).run();
    db.insert(timetableTripDates).values({ tripKey: key, serviceDate: d }).run();
    db.insert(timetableStopTimes)
      .values([
        { tripKey: key, seq: 1, stationId: VEJLE, depSec: 8 * 3600 },
        { tripKey: key, seq: 2, stationId: FREDERICIA, arrSec: 8 * 3600 + 900 },
      ])
      .run();
  }
  // A Swedish trip on a gap day doesn't count for Denmark.
  db.insert(timetableTrips).values({ key: 'se3:x', source: 'gtfs_se3', tripId: 'x', routeType: '2', category: 'regional', tz: 'Europe/Stockholm' }).run();
  db.insert(timetableTripDates).values({ tripKey: 'se3:x', serviceDate: '2023-10-15' }).run();
  const index = buildStationIndex(db.select().from(stations).all(), {});
  return { db, search: createSmartSearch(db, () => index) };
}

describe('older Danish days in search', () => {
  afterEach(() => vi.useRealTimers());

  it('lists the stretches between days as inclusive ranges', () => {
    expect(gapsIn(['2021-12-21', '2021-12-22', '2025-02-12', '2025-02-14'])).toEqual([
      { from: '2021-12-23', to: '2025-02-11' },
      { from: '2025-02-13', to: '2025-02-13' },
    ]);
    expect(gapsIn([])).toEqual([]);
  });

  it('a day no copy covers: Denmark, with the first day on record and the gaps', () => {
    const { search } = setup(['2016-07-26', '2021-12-22', '2025-02-12', '2025-02-13']);
    const r = search('Vejle Fredericia', '2023-10-15');
    expect(r).toMatchObject({ outsideTimetable: true, results: [], history: 'denmark', historyFrom: '2016-07-26' });
    expect(r.historyGaps).toEqual([
      { from: '2016-07-27', to: '2021-12-21' },
      { from: '2021-12-23', to: '2025-02-11' },
    ]);
    // Before the first day too.
    expect(search('Vejle Fredericia', '2014-05-01')).toMatchObject({ history: 'denmark', historyFrom: '2016-07-26' });
  });

  it('a day a copy covers: ready, with its trains', () => {
    const { search } = setup(['2016-07-26', '2021-12-22', '2025-02-12']);
    const r = search('Vejle Fredericia', '2021-12-22');
    expect(r.history).toBe('ready');
    expect(r.historyGaps).toBeUndefined();
    expect(r.results?.map((x) => x.trainNumber)).toEqual(['140']);
  });

  it('with no Danish timetable at all, stays unavailable', () => {
    const { search } = setup([]);
    expect(search('Vejle Fredericia', '2023-10-15')).toMatchObject({ history: 'unavailable', outsideTimetable: true });
  });

  it('keeps the days for an hour, or until forgotten after an import', () => {
    const { db } = setup(['2021-12-22']);
    const t0 = Date.now();
    expect(danishDays(db, t0).to).toBe('2021-12-22');
    db.insert(timetableTrips).values({ key: 'dk:new:h', source: 'gtfs_dk', tripId: 'new', routeType: '2', category: 'intercity', tz: CPH }).run();
    db.insert(timetableTripDates).values({ tripKey: 'dk:new:h', serviceDate: '2022-01-05' }).run();
    expect(danishDays(db, t0 + 60_000).to).toBe('2021-12-22');
    expect(danishDays(db, t0 + 61 * 60_000).to).toBe('2022-01-05');
    db.insert(timetableTripDates).values({ tripKey: 'dk:new:h', serviceDate: '2022-01-06' }).run();
    forgetDanishDays(db);
    expect(danishDays(db, t0 + 62 * 60_000).to).toBe('2022-01-06');
  });
});
