import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { stations } from '../src/db/schema.js';
import { saveRuns, recordFetch } from '../src/observed/store.js';
import { ensureRecordedDay, recordFrom, writeDay } from '../src/observed/timetable.js';
import { createSmartSearch } from '../src/search/smartSearch.js';
import { stationIndexCache } from '../src/search/stationIndexCache.js';
import { tripStops } from '../src/search/timetable.js';

// Vy 61 Oslo S → Bergen on 2024-03-12, as Entur's archive has it.
const at = (hhmm: string) => Date.parse(`2024-03-12T${hhmm}:00+01:00`);
const call = (seq: number, stationId: string, o: Record<string, unknown>) => ({ seq, location: `q${seq}`, stationId, schedArr: null, schedDep: null, estArr: null, estDep: null, actualArr: null, actualDep: null, platform: null, canceledArr: false, canceledDep: false, causes: [], extra: {}, ...o });

function setup() {
  const db = openDb(':memory:');
  db.insert(stations)
    .values([
      { id: '760000100', name: 'Oslo S', country: 'NO', lat: 59.9111, lon: 10.7528, tz: 'Europe/Oslo', nsrId: 'NSR:StopPlace:337' },
      { id: 'NSR:StopPlace:548', name: 'Bergen', country: 'NO', lat: 60.3903, lon: 5.3331, tz: 'Europe/Oslo', nsrId: 'NSR:StopPlace:548' },
    ])
    .run();
  saveRuns(db, [
    {
      country: 'NO',
      serviceDate: '2024-03-12',
      runId: 'VYG:61',
      trainNumber: '61',
      source: 'entur-bigquery',
      operator: 'VYG',
      product: 'F4',
      canceled: 0,
      info: {},
      passages: [],
      final: true,
      calls: [call(1, '760000100', { schedDep: at('06:25'), actualDep: at('06:26') }), call(2, 'NSR:StopPlace:548', { schedArr: at('13:05'), actualArr: at('13:10') })],
    },
  ]);
  recordFetch(db, { source: 'entur-bigquery', kind: 'siri-et', date: '2024-03-12', records: 2, runs: 1, file: '', final: true });
  return db;
}

describe('older Norwegian and Finnish days from the record', () => {
  it("writes a recorded day's trains as timetable trips, planned times only", () => {
    const db = setup();
    expect(writeDay(db, 'NO', '2024-03-12')).toBe(1);
    const key = (db.$client.prepare(`select key from timetable_trips where source = 'observed_no'`).get() as { key: string }).key;
    expect(key).toMatch(/^no:obs:[0-9a-f]{14}$/);
    const trip = tripStops(db, key, '2024-03-12')!;
    expect(trip.trip.train_number).toBe('61');
    expect(trip.stops.map((s) => [s.name, s.dep ?? s.arr])).toEqual([
      ['Oslo S', at('06:25')],
      ['Bergen', at('13:05')],
    ]);
    // The same day again doesn't add a second train.
    writeDay(db, 'NO', '2024-03-12');
    expect((db.$client.prepare(`select count(*) n from timetable_trips where source = 'observed_no'`).get() as { n: number }).n).toBe(1);
  });

  it('finds the train by route on that day, and says from when a country is on record', () => {
    const db = setup();
    const record = { ensure: (c: 'NO' | 'FI', d: string) => ensureRecordedDay(db, c, d), from: (c: 'NO' | 'FI') => (c === 'FI' ? recordFrom(db, c) : '2020-01-01') };
    const search = createSmartSearch(db, stationIndexCache(db), () => ({ state: 'unavailable' }), { ...record, ensure: (c, d) => (c === 'NO' && d < '2020-01-01' ? 'unavailable' : record.ensure(c, d)) });
    const r = search('Oslo S Bergen', '2024-03-12');
    expect(r.history).toBe('ready');
    expect(r.results?.map((x) => x.trainNumber)).toEqual(['61']);
    const old = search('Oslo S Bergen', '2019-05-01');
    expect([old.history, old.historyFrom]).toEqual(['norway', '2020-01-01']);
  });
});
