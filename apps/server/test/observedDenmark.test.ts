import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import { LOCAL_USER_ID, openDb } from '../src/db/client.js';
import { stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import { localMs, matchSwedish, parseCsv, project, stationOfStop, swedishTripsWithDanishStops, type SwedishTrip } from '../src/observed/dk-archive.js';
import { recordedStops } from '../src/observed/lookup.js';
import { saveRuns } from '../src/observed/store.js';
import { createLeg } from '../src/legs/legs.js';

// Rows as in train-archive.eu's dk-rejseplanen file for 2026-10-26 (shortened).
const CSV = `"service_date","provider","feed_id","route","trip_id","trip_start_time","stop_sequence","stop_id","stop_name","scheduled_arrival","scheduled_departure","arrival_delay_min","departure_delay_min","predicted_arrival","predicted_departure","observed_at","trip_status","stop_status","delay_source","route_id","timetable_version"
"2026-10-26","dk-rejseplanen","a","802 ","168912360",,18,"000008600857","Tårnby St.","2026-10-26 21:07:00","2026-10-26 21:08:00",22,24,"2026-10-26 21:29:00","2026-10-26 21:32:00","2026-10-26 21:33:38","scheduled",,"feed","25657_2","v1"
"2026-10-26","dk-rejseplanen","a","802 ","168912360",,17,"000008600858","CPH, Lufthavn","2026-10-26 20:58:00","2026-10-26 21:05:00",23,20,"2026-10-26 21:21:00","2026-10-26 21:25:00","2026-10-26 21:27:37","scheduled",,"feed","25657_2","v1"
"2026-10-26","dk-rejseplanen","a","802 ","168912360",,19,"000008600856","Ørestad St.","2026-10-26 21:10:00","2026-10-26 21:11:00",,,,,"2026-10-26 21:42:38","scheduled","skipped","propagated","25657_2","v1"
"2026-10-26","dk-rejseplanen","b","B ","169","",1,"000008600688","Emdrup St.","","2026-10-26 08:11:00",,,,,"2026-10-26 10:37:37","cancelled",,"","16449_109","v1"
`;

describe('train-archive.eu Danish day', () => {
  const rows = parseCsv(CSV);
  it('parses quoted fields and commas inside them', () => {
    expect(rows).toHaveLength(4);
    expect(rows[1]!.stop_name).toBe('CPH, Lufthavn');
  });
  it('reads Danish local time (CET after 25 Oct, UTC+1)', () => {
    expect(localMs('2026-10-26 21:07:00')).toBe(Date.UTC(2026, 9, 26, 20, 7));
    expect(localMs('')).toBeNull();
  });
  it('maps stops to our station ids', () => {
    expect(stationOfStop('000008600857', new Set(['860000857']))).toBe('860000857');
    expect(stationOfStop('000008600857', new Set())).toBeNull();
  });
  it('projects runs: actuals only from the feed, skipped and cancelled stops marked', () => {
    const runs = project('2026-10-26', rows, new Map([['168912360', { number: '802', operator: 'DSB S-tog' }]]), new Set(['860000857']), true);
    expect(runs).toHaveLength(2);
    const r = runs.find((x) => x.runId === '168912360')!;
    expect(r.trainNumber).toBe('802');
    expect(r.calls.map((c) => c.seq)).toEqual([1, 2, 3]);
    expect(r.calls[0]!.location).toBe('000008600858');
    expect(r.calls[1]!.stationId).toBe('860000857');
    expect(r.calls[1]!.actualDep! - r.calls[1]!.schedDep!).toBe(24 * 60_000);
    expect(r.calls[2]!.actualArr).toBeNull();
    expect(r.calls[2]!.canceledArr).toBe(true);
    expect(r.canceled).toBe(1);
    const c = runs.find((x) => x.runId === '169')!;
    expect(c.canceled).toBe(2);
    expect(c.trainNumber).toBeNull();
  });
});

describe('train-archive.eu catch-up', () => {
  it('fetches each missing day once, skips finished ones, and survives a missing day', async () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-dk-'));
    vi.stubEnv('OBSERVED_DIR', root);
    vi.stubEnv('TRAIN_ARCHIVE_TOKEN', 'test');
    vi.resetModules();
    const dk = await import('../src/observed/dk-archive.js');
    const db = openDb(':memory:');
    const asked: string[] = [];
    const fetchImpl = (async (url: string) => {
      const date = /date=([\d-]+)/.exec(url)![1]!;
      asked.push(date);
      if (date === '2026-10-25') return new Response('', { status: 404 });
      return new Response(CSV.replaceAll('2026-10-26', date));
    }) as typeof fetch;
    try {
      await dk.backfillRange(db, { from: '2026-10-24', to: '2026-10-26', fetchImpl, log: () => {} });
      expect(asked).toEqual(['2026-10-24', '2026-10-25', '2026-10-26']);
      const runs = db.$client.prepare(`select service_date, count(*) n from observed_runs where country = 'DK' group by 1 order by 1`).all();
      expect(runs).toEqual([
        { service_date: '2026-10-24', n: 2 },
        { service_date: '2026-10-26', n: 2 },
      ]);
      asked.length = 0;
      await dk.backfillRange(db, { from: '2026-10-24', to: '2026-10-26', fetchImpl, log: () => {} });
      expect(asked).toEqual(['2026-10-25']);
    } finally {
      vi.unstubAllEnvs();
      fs.rmSync(root, { recursive: true, force: true });
    }
  });
});

// An Öresundståg from Sweden on 2026-10-26 (CET): Hyllie 20:38/20:40, CPH Airport 20:58/21:05, Tårnby 21:07/21:08,
// København H 21:16. Its trip id is not in gtfs_dk (the Danish import leaves trains in Sweden's feed out), so only the
// Swedish feed can name it. Hyllie's stop id is Rejseplanen's (000007401585), not one of ours.
const ORESUND = `"service_date","provider","feed_id","route","trip_id","trip_start_time","stop_sequence","stop_id","stop_name","scheduled_arrival","scheduled_departure","arrival_delay_min","departure_delay_min","predicted_arrival","predicted_departure","observed_at","trip_status","stop_status","delay_source","route_id","timetable_version"
"2026-10-26","dk-rejseplanen","a","802 ","168912999",,1,"000007401585","Hyllie St.","2026-10-26 20:38:00","2026-10-26 20:40:00",3,3,"2026-10-26 20:41:00","2026-10-26 20:43:00","2026-10-26 20:44:00","scheduled",,"feed","25657_2","v1"
"2026-10-26","dk-rejseplanen","a","802 ","168912999",,2,"000008600858","CPH Lufthavn","2026-10-26 20:58:00","2026-10-26 21:05:00",4,2,"2026-10-26 21:02:00","2026-10-26 21:07:00","2026-10-26 21:08:00","scheduled",,"feed","25657_2","v1"
"2026-10-26","dk-rejseplanen","a","802 ","168912999",,3,"000008600857","Tårnby St.","2026-10-26 21:07:00","2026-10-26 21:08:00",2,2,"2026-10-26 21:09:00","2026-10-26 21:10:00","2026-10-26 21:11:00","scheduled",,"feed","25657_2","v1"
"2026-10-26","dk-rejseplanen","a","802 ","168912999",,4,"000008600626","København H","2026-10-26 21:16:00","2026-10-26 21:18:00",5,,"2026-10-26 21:21:00",,"2026-10-26 21:22:00","scheduled",,"feed","25657_2","v1"
`;
const SE_TZ = 'Europe/Stockholm';
const hm = (h: number, m: number) => h * 3600 + m * 60;

function oresundDb() {
  const db = openDb(':memory:');
  db.insert(stations)
    .values([
      { id: '740001586', name: 'Hyllie', country: 'SE', lat: 55.5629, lon: 12.9759, tz: SE_TZ, trvSignature: 'Hie' },
      { id: '860000858', name: 'CPH Airport', country: 'DK', lat: 55.6297, lon: 12.6494, tz: 'Europe/Copenhagen' },
      { id: '860000857', name: 'Tårnby', country: 'DK', lat: 55.6303, lon: 12.6005, tz: 'Europe/Copenhagen' },
      { id: '860000626', name: 'København H', country: 'DK', lat: 55.6728, lon: 12.5647, tz: 'Europe/Copenhagen' },
    ])
    .run();
  db.insert(timetableTrips).values({ key: 'se3:ore1072:a', source: 'gtfs_se3', tripId: 'ore1072', trainNumber: '1072', gtfsOperator: 'VR Sverige AB', operatorId: null, routeType: '106', category: 'regional', tz: SE_TZ }).run();
  db.insert(timetableTripDates).values({ tripKey: 'se3:ore1072:a', serviceDate: '2026-10-26' }).run();
  db.insert(timetableStopTimes)
    .values([
      { tripKey: 'se3:ore1072:a', seq: 1, stationId: '740001586', arrSec: hm(20, 38), depSec: hm(20, 40) },
      { tripKey: 'se3:ore1072:a', seq: 2, stationId: '860000858', arrSec: hm(20, 58), depSec: hm(21, 5) },
      { tripKey: 'se3:ore1072:a', seq: 3, stationId: '860000857', arrSec: hm(21, 7), depSec: hm(21, 8) },
      { tripKey: 'se3:ore1072:a', seq: 4, stationId: '860000626', arrSec: hm(21, 16), depSec: hm(21, 18) },
    ])
    .run();
  return db;
}
const KNOWN = new Set(['860000858', '860000857', '860000626']);

describe("a Swedish train's Danish day", () => {
  it("names the run from the Swedish feed by its Danish calls, and gives its Swedish call our station", () => {
    const db = oresundDb();
    const swedish = swedishTripsWithDanishStops(db, '2026-10-26');
    expect(swedish).toHaveLength(1);
    const [run] = project('2026-10-26', parseCsv(ORESUND), new Map(), KNOWN, true, swedish);
    expect(run!.trainNumber).toBe('1072');
    expect(run!.operator).toBe('VR Sverige AB');
    expect(run!.info).toMatchObject({ matchedBy: 'se-stop-times', timetableTripKey: 'se3:ore1072:a', matchedCalls: 3 });
    expect(run!.calls[0]).toMatchObject({ location: '000007401585', stationId: '740001586', extra: expect.objectContaining({ stationFrom: 'se-stop-times' }) });
    expect(run!.calls[3]!.stationId).toBe('860000626');
    // Without the Swedish trips, as before: no number, and Hyllie unknown.
    const [bare] = project('2026-10-26', parseCsv(ORESUND), new Map(), KNOWN, true);
    expect(bare!.trainNumber).toBeNull();
    expect(bare!.calls[0]!.stationId).toBeNull();
    expect(bare!.info.matchedBy).toBeUndefined();
  });

  it('keeps the Danish timetable match first, and says so', () => {
    const [run] = project('2026-10-26', parseCsv(ORESUND), new Map([['168912999', { number: '802', operator: 'Skånetrafiken' }]]), KNOWN, true, swedishTripsWithDanishStops(oresundDb(), '2026-10-26'));
    expect(run!.trainNumber).toBe('802');
    expect(run!.info.matchedBy).toBe('gtfs_dk');
  });

  it('needs two agreeing calls and one candidate only', () => {
    const [run] = project('2026-10-26', parseCsv(ORESUND), new Map(), KNOWN, true);
    const trip = swedishTripsWithDanishStops(oresundDb(), '2026-10-26')[0]!;
    expect(matchSwedish(run!.calls, [trip])?.trip.number).toBe('1072');
    // A minute off at every stop still matches; three minutes off does not.
    const shift = (t: SwedishTrip, min: number): SwedishTrip => ({ ...t, stops: t.stops.map((s) => ({ ...s, arr: s.arr === null ? null : s.arr + min * 60_000, dep: s.dep === null ? null : s.dep + min * 60_000 })) });
    expect(matchSwedish(run!.calls, [shift(trip, 1)])?.trip.number).toBe('1072');
    expect(matchSwedish(run!.calls, [shift(trip, 3)])).toBeNull();
    // Only one Danish call in common: not enough.
    expect(matchSwedish(run!.calls, [{ ...trip, stops: trip.stops.slice(0, 2) }])).toBeNull();
    // Two trips agreeing equally well: nobody is named.
    expect(matchSwedish(run!.calls, [trip, { ...trip, key: 'other', number: '1074' }])).toBeNull();
  });

  it("reaches a saved Swedish trip's Danish stops through the record once named", () => {
    const db = oresundDb();
    const runs = project('2026-10-26', parseCsv(ORESUND), new Map(), KNOWN, true, swedishTripsWithDanishStops(db, '2026-10-26'));
    saveRuns(db, runs);
    const stored = db.$client.prepare(`select train_number, info from observed_runs where country = 'DK' and run_id = '168912999'`).get() as { train_number: string; info: string };
    expect(stored.train_number).toBe('1072');
    expect(JSON.parse(stored.info).matchedBy).toBe('se-stop-times');
    const id = createLeg(db, LOCAL_USER_ID, { tripKey: 'se3:ore1072:a', serviceDate: '2026-10-26', fromSeq: 1, toSeq: 4 }, Date.parse('2026-10-26T18:00:00Z'));
    const legStops = db.$client.prepare(`select seq, station_id, sched_arr, sched_dep from leg_stops where leg_id = ? order by seq`).all(id) as { seq: number; station_id: string; sched_arr: number | null; sched_dep: number | null }[];
    const found = recordedStops(db, { trainNumber: '1072', serviceDate: '2026-10-26', stops: legStops.map((s) => ({ seq: s.seq, stationId: s.station_id, schedArr: s.sched_arr, schedDep: s.sched_dep })) });
    expect([...found.keys()]).toEqual([1, 2, 3, 4]);
    expect(found.get(4)).toMatchObject({ source: 'rejseplanen', actualArr: Date.UTC(2026, 9, 26, 20, 21) });
    expect(found.get(1)!.actualDep).toBe(Date.UTC(2026, 9, 26, 19, 43));
  });
});
