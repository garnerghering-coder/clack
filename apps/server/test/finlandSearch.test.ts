import { afterEach, describe, expect, it, vi } from 'vitest';
import { eq } from 'drizzle-orm';
import { openDb } from '../src/db/client.js';
import { legs, stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { AUDIT_USER_ID, sampleTrains } from '../src/audit/sample.js';
import { createSmartSearch } from '../src/search/smartSearch.js';
import { buildStationIndex } from '../src/search/stations.js';
import { searchByRoute } from '../src/search/timetable.js';
import { countryOfKey, countryOfLiveId } from '../src/lib/countries.js';
import { HAPARANDA, seedFinland, seedTrip, stationId, trainFixture } from './finlandFixtures.js';

const ic27 = trainFixture('ic-27');
const ic407 = trainFixture('ic-407-haparanda');

function setup() {
  // The fixtures are for 24 October 2026, and the search only reaches back to yesterday (Finland has no archive), so the
  // clock is set to that day: these tests must not depend on the day they are run.
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(Date.parse('2026-10-24T10:00:00Z'));
  const db = openDb(':memory:');
  seedFinland(db);
  seedTrip(db, ic27);
  seedTrip(db, ic407);
  const rows = db.select().from(stations).all();
  const index = buildStationIndex(rows, {});
  return { db, search: createSmartSearch(db, () => index) };
}

describe('searching Finnish trains', () => {
  afterEach(() => vi.useRealTimers());

  it('finds Helsinki to Tampere on the day, with the times in Helsinki time', () => {
    const { db, search } = setup();
    const r = search('Helsinki Tampere', '2026-10-24');
    expect(r.interpretation.from?.id).toBe('fi:HKI');
    expect(r.interpretation.to?.id).toBe('fi:TPE');
    expect(r.results).toHaveLength(1);
    expect(r.results![0]).toMatchObject({ trainNumber: '27', operatorId: 'vr-fi' });
    // 11:20 UTC is 14:20 in Helsinki (summer time, UTC+3).
    expect(new Date(r.results![0]!.from.time).toISOString()).toBe('2026-10-24T11:20:00.000Z');
    expect(searchByRoute(db, 'fi:HKI', 'fi:TPE', '2026-10-25')).toEqual([]);
  });

  it('finds Tornio to Haparanda, the Swedish station the Finnish train reaches', () => {
    const { search } = setup();
    const r = search('Tornio Haparanda', '2026-10-24');
    expect(r.interpretation.from?.id).toBe('fi:TOR');
    expect(r.interpretation.to?.id).toBe(HAPARANDA);
    expect(r.results).toHaveLength(1);
    expect(r.results![0]).toMatchObject({ trainNumber: '407', key: 'fi:407_20261024:test' });
    expect(r.results![0]!.to.country).toBe('SE');
  });

  it('finds a Finnish train by number', () => {
    const { search } = setup();
    expect(search('27', '2026-10-24').results?.map((x) => x.key)).toEqual(['fi:27_20261024:test']);
  });

  it('keeps the feed of the country you board in when one train is in two feeds', () => {
    const { db } = setup();
    // The same Helsinki to Tampere train, also in another feed under another number.
    db.insert(timetableTrips).values({ key: 'se3:dup:1', source: 'gtfs_se3', tripId: 'dup', trainNumber: '10027', operatorId: 'vr-fi', routeType: '102', category: 'intercity', tz: 'Europe/Helsinki' }).run();
    db.insert(timetableTripDates).values({ tripKey: 'se3:dup:1', serviceDate: '2026-10-24' }).run();
    const base = Date.parse('2026-10-24T00:00:00Z');
    const sec = (iso: string) => Math.round((Date.parse(iso) - (base - 3 * 3600_000)) / 1000);
    db.insert(timetableStopTimes)
      .values([
        { tripKey: 'se3:dup:1', seq: 1, stationId: stationId('HKI'), arrSec: null, depSec: sec('2026-10-24T11:20:00Z') },
        { tripKey: 'se3:dup:1', seq: 2, stationId: stationId('TPE'), arrSec: sec('2026-10-24T12:58:00Z'), depSec: null },
      ])
      .run();
    const r = searchByRoute(db, 'fi:HKI', 'fi:TPE', '2026-10-24');
    expect(r).toHaveLength(1);
    expect(r[0]!.key).toBe('fi:27_20261024:test');
    expect(r[0]!.alsoKnownAs).toEqual(['10027']);
  });

  it('says there is no archive for an older day in Finland, with the day decided in Helsinki time', () => {
    const { search } = setup();
    // 21:30 UTC on 24 October is already 25 October in Helsinki (00:30) but still the 24th in Stockholm (23:30).
    vi.useFakeTimers();
    vi.setSystemTime(Date.parse('2026-10-24T21:30:00Z'));
    const old = search('Helsinki Tampere', '2026-10-23');
    expect(old.history).toBe('finland');
    expect(old.outsideTimetable).toBe(true);
    expect(old.results).toEqual([]);
    // The day before "today" in Helsinki is still searchable (yesterday's trains stay in the timetable).
    const yesterday = search('Helsinki Tampere', '2026-10-24');
    expect(yesterday.history).toBeUndefined();
    expect(yesterday.results).toHaveLength(1);
  });

  it('keeps Norway as it was: the same shortcut under its own name', () => {
    const db = openDb(':memory:');
    db.insert(stations)
      .values([
        { id: 'no:1', name: 'Oslo S', country: 'NO', lat: 59.91, lon: 10.75, tz: 'Europe/Oslo' },
        { id: 'no:2', name: 'Lillehammer', country: 'NO', lat: 61.11, lon: 10.46, tz: 'Europe/Oslo' },
      ])
      .run();
    const index = buildStationIndex(db.select().from(stations).all(), {});
    vi.useFakeTimers();
    vi.setSystemTime(Date.parse('2026-10-24T10:00:00Z'));
    const r = createSmartSearch(db, () => index)('Oslo S Lillehammer', '2026-10-01');
    expect(r.history).toBe('norway');
  });
});

describe('the audit sample', () => {
  it('follows a Finnish train too: its own bucket, found in Helsinki time', () => {
    const db = openDb(':memory:');
    seedFinland(db);
    const key = seedTrip(db, ic27);
    // 35 minutes before IC 27 leaves Helsinki (14:20 local, 11:20 UTC); every bucket is asked once.
    const added = sampleTrains(db, { now: Date.parse('2026-10-24T10:45:00Z'), perHour: 5 });
    expect(added).toBe(1);
    const sampled = db.select().from(legs).where(eq(legs.userId, AUDIT_USER_ID)).all();
    expect(sampled.map((l) => l.timetableTripKey)).toEqual([key]);
    expect(sampled[0]!.countryCodes).toEqual(['FI']);
  });
});

describe('which country a key or a live id belongs to', () => {
  it('tells Finland from Sweden and Norway', () => {
    expect(countryOfKey('fi:27_20261024:abc')).toBe('FI');
    expect(countryOfKey('no:VYG:1:abc')).toBe('NO');
    expect(countryOfKey('se3:1:abc')).toBe('SE');
    expect(countryOfKey('sv2:1:abc')).toBe('SE');
    expect(countryOfLiveId('fi:27|2026-10-24')).toBe('FI');
    expect(countryOfLiveId('no:27|2026-10-24')).toBe('NO');
    expect(countryOfLiveId('27|2026-10-24')).toBe('SE');
  });
});
