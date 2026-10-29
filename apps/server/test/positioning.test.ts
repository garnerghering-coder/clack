// The positioning engine (BUILDOUT §A, docs/POSITIONING.md): each rule on its own, then through the Swedish ingest.
import fs from 'node:fs';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { cumulative, platformPoint, type LatLon, type StationMap } from '@clack/shared';
import { openDb } from '../src/db/client.js';
import { stations, trvLocations } from '../src/db/schema.js';
import { LiveMapIngest, WAITING_BEFORE_MS } from '../src/livemap/ingest.js';
import { summarizeTrain } from '../src/livemap/announcements.js';
import {
  ACCEL_MPS2,
  advanceM,
  APPROACH_GRACE_MS,
  APPROACH_M,
  blendM,
  crossingTime,
  DECEL_MPS2,
  distanceAt,
  estimateAlong,
  passageTime,
  pickTrack,
  runningSide,
  runProfile,
  snapToLine,
  speedAt,
  standingByGps,
} from '../src/live/positioning.js';
import { locateOnSegment } from '../src/live/locate.js';
import { Placement } from '../src/live/placement.js';
import { Histogram, LiveQuality } from '../src/live/quality.js';
import { haversineM } from '../src/lib/geo.js';
import { REPO_ROOT } from '../src/env.js';

const T = (hhmm: string, ss = '00') => `2026-10-21T${hhmm}:${ss}.000+02:00`;
const ms = (hhmm: string, ss = '00') => Date.parse(T(hhmm, ss));

describe('run profile (§A.3)', () => {
  it('covers the whole segment in exactly the scheduled time, accelerating at 0.5 and braking at 0.6 m/s²', () => {
    const p = runProfile(20_000, 600);
    expect(p.accel).toBe(ACCEL_MPS2);
    expect(p.decel).toBe(DECEL_MPS2);
    expect(distanceAt(p, 0)).toBe(0);
    expect(distanceAt(p, 600)).toBeCloseTo(20_000, 6);
    expect(distanceAt(p, 601)).toBe(20_000);
    // The phases add up, and the train is slower at the start than in the middle.
    expect(p.tAcc + p.tCruise + p.tDec).toBeCloseTo(600, 6);
    expect(distanceAt(p, 60)).toBeLessThan(distanceAt(p, 300) - distanceAt(p, 240));
    expect(speedAt(p, 300)).toBeCloseTo(p.vMax, 6);
    expect(speedAt(p, 600)).toBe(0);
    // 20 km in 10 minutes: cruising well under line speed, above the average.
    expect(p.vMax * 3.6).toBeGreaterThan(120);
    expect(p.vMax * 3.6).toBeLessThan(160);
  });

  it('is monotonic and never beyond the segment, even when the schedule is quicker than the accelerations allow', () => {
    const p = runProfile(5_000, 60);
    let last = 0;
    for (let t = 0; t <= 60; t += 1) {
      const d = distanceAt(p, t);
      expect(d).toBeGreaterThanOrEqual(last);
      expect(d).toBeLessThanOrEqual(5_000);
      last = d;
    }
    expect(last).toBeCloseTo(5_000, 6);
    expect(p.tCruise).toBeCloseTo(0, 6);
  });

  it('degenerates safely', () => {
    expect(distanceAt(runProfile(0, 100), 50)).toBe(0);
    expect(distanceAt(runProfile(1000, 0), 50)).toBe(1000);
  });
});

describe('no 95% freeze: the approach and then the platform (§A.3)', () => {
  const left = ms('11:00');
  const due = ms('11:30');
  it('follows the profile to the approach, creeps the last 50 m when overdue, then stands at the platform', () => {
    expect(estimateAlong(30_000, left, due, ms('11:15')).state).toBe('running');
    expect(estimateAlong(30_000, left, due, ms('11:29', '59')).m).toBeCloseTo(30_000 - APPROACH_M, -1);
    const late = estimateAlong(30_000, left, due, ms('11:30', '30'));
    expect(late.state).toBe('running');
    expect(late.speedKmh).toBeNull();
    expect(late.m).toBeGreaterThan(30_000 - APPROACH_M);
    expect(late.m).toBeLessThan(30_000);
    const given = estimateAlong(30_000, left, due, due + APPROACH_GRACE_MS);
    expect(given).toMatchObject({ m: 30_000, state: 'standing', progress: 1 });
  });
  it('never moves backwards as time goes on', () => {
    let last = -1;
    for (let t = left; t <= due + 3 * 60_000; t += 10_000) {
      const m = estimateAlong(30_000, left, due, t).m;
      expect(m).toBeGreaterThanOrEqual(last);
      last = m;
    }
  });
});

const LINE: LatLon[] = [
  [59.33, 18.06],
  [59.5, 17.9],
  [59.86, 17.65],
];

describe('snapping onto the track (§A.3)', () => {
  it('lands a fix within 60 m on the line, with the heading along the track towards the next station', () => {
    const cum = cumulative(LINE);
    // 30 m east of the first leg.
    const s = snapToLine(LINE, cum, { lat: 59.4, lon: 17.994 + 30 / (111_320 * Math.cos((59.4 * Math.PI) / 180)) })!;
    expect(s).not.toBeNull();
    expect(s.offM).toBeGreaterThan(20);
    expect(s.offM).toBeLessThan(40);
    expect(haversineM(s.lat, s.lon, 59.4, 17.994)).toBeLessThan(60);
    // The first leg runs north-north-west (lat up, lon down): a bearing around 330°.
    expect(s.bearing).toBeGreaterThan(315);
    expect(s.bearing).toBeLessThan(345);
    expect(s.m).toBeGreaterThan(0);
    expect(s.m).toBeLessThan(cum[1]!);
  });
  it('leaves a fix further off alone', () => {
    expect(snapToLine(LINE, cumulative(LINE), { lat: 59.4, lon: 18.1 })).toBeNull();
  });
});

describe('dead reckoning and the blend (§A.3)', () => {
  it('carries a position on at its speed, never past the station', () => {
    expect(advanceM(1000, 72, 10_000, 5000)).toBe(1200);
    expect(advanceM(4900, 72, 60_000, 5000)).toBe(5000);
    expect(advanceM(1000, null, 60_000, 5000)).toBe(1000);
    expect(advanceM(1000, 0, 60_000, 5000)).toBe(1000);
  });
  it('blends over 30 s', () => {
    expect(blendM(1000, 2000, 0)).toBe(1000);
    expect(blendM(1000, 2000, 15_000)).toBe(1500);
    expect(blendM(1000, 2000, 60_000)).toBe(2000);
  });
});

describe('standing and parallel tracks (§A.2, §A.5)', () => {
  it('calls a slow fix next to a station standing', () => {
    expect(standingByGps(2, 150)).toBe(true);
    expect(standingByGps(2, 800)).toBe(false);
    expect(standingByGps(40, 150)).toBe(false);
    expect(standingByGps(null, 150)).toBe(false);
  });
  it('knows each country’s side, and turns the rule off where the sources name an exception', () => {
    expect(runningSide('SE', 59.33, 18.06)).toBe('left');
    expect(runningSide('NO', 59.91, 10.75)).toBe('right');
    expect(runningSide('DK', 55.67, 12.56)).toBe('right');
    expect(runningSide('FI', 61.5, 23.77)).toBe('right');
    // Öresund link and the Helsinki commuter area: no rule.
    expect(runningSide('SE', 55.58, 12.95)).toBeNull();
    expect(runningSide('FI', 60.2, 24.9)).toBeNull();
    expect(runningSide(null, 59.33, 18.06)).toBeNull();
  });
  it('picks the left of two tracks 8 m apart when heading north in Sweden, the right in Norway, the nearest without a heading', () => {
    const kx = 111_320 * Math.cos((59.4 * Math.PI) / 180);
    const west = { point: [59.4, 18.0 - 4 / kx] as LatLon, d: 5 };
    const east = { point: [59.4, 18.0 + 4 / kx] as LatLon, d: 3 };
    expect(pickTrack([west, east], 0, 'left')).toBe(west);
    expect(pickTrack([west, east], 0, 'right')).toBe(east);
    expect(pickTrack([west, east], 180, 'left')).toBe(east);
    expect(pickTrack([west, east], null, 'left')).toBe(east);
    // A track 40 m away is another line, not a parallel track.
    const far = { point: [59.4, 18.0 + 40 / kx] as LatLon, d: 38 };
    expect(pickTrack([west, far], 0, 'right')).toBe(west);
  });
});

describe('passage times for the timestamp offset (§A.8)', () => {
  const run = [
    { lat: 59.0, lon: 18.0, at: 0 },
    { lat: 59.01, lon: 18.0, at: 30_000 },
    { lat: 59.02, lon: 18.0, at: 60_000 },
    { lat: 59.03, lon: 18.0, at: 90_000 },
  ];
  it('interpolates the closest approach of a run of fixes to a point', () => {
    expect(passageTime(run, { lat: 59.015, lon: 18.0002 })).toBeCloseTo(45_000, -2);
    // Not bracketed: the point is beyond the last fix.
    expect(passageTime(run, { lat: 59.05, lon: 18.0 })).toBeNull();
    // Too far from the point.
    expect(passageTime(run, { lat: 59.015, lon: 18.01 })).toBeNull();
  });
  it('finds when a run first came within 150 m of a stop and last left it', () => {
    const stop = { lat: 59.02, lon: 18.0 };
    const inAt = crossingTime(run, stop, 'in')!;
    const outAt = crossingTime(run, stop, 'out')!;
    expect(inAt).toBeGreaterThan(30_000);
    expect(inAt).toBeLessThan(60_000);
    expect(outAt).toBeGreaterThan(60_000);
    expect(outAt).toBeLessThan(90_000);
    expect(crossingTime(run, { lat: 59.1, lon: 18.0 }, 'in')).toBeNull();
  });
  it('records each passage once and sums up the offsets', () => {
    const q = new LiveQuality(() => 100_000);
    for (const f of run) q.recordFix('trafikverket', 't', f, f.at + 4000);
    const reported = crossingTime(run, { lat: 59.02, lon: 18.0 }, 'in')! - 2000;
    expect(q.recordPassage('trafikverket', 'regional', 't', { lat: 59.02, lon: 18.0 }, reported, 'arr')).toBeCloseTo(2, 3);
    expect(q.recordPassage('trafikverket', 'regional', 't', { lat: 59.02, lon: 18.0 }, reported, 'arr')).toBeNull();
    const r = q.report();
    expect(r.delivery.trafikverket!.n).toBe(4);
    expect(r.delivery.trafikverket!.median).toBe(4);
    expect(r.offset['trafikverket|regional|arr']!.n).toBe(1);
  });
  it('histograms keep counts, median and p90', () => {
    const h = new Histogram([1, 2, 5]);
    for (const v of [0.5, 1.5, 1.5, 3, 7]) h.add(v);
    const s = h.summary();
    expect(s.n).toBe(5);
    expect(s.buckets).toEqual({ '≤1': 1, '≤2': 2, '≤5': 1, '>5': 1 });
    expect(s.median).toBe(1.5);
    expect(s.p90).toBe(7);
  });
});

// ---------- Through the ingest: Swedish trains with announcements ----------

const ann = (sig: string, type: 'Ankomst' | 'Avgang', adv: string, extra: Record<string, unknown> = {}) => ({
  ActivityId: `${sig}-${type}-${adv}`,
  ActivityType: type,
  AdvertisedTimeAtLocation: T(adv),
  AdvertisedTrainIdent: '270',
  LocationSignature: sig,
  FromLocation: [{ LocationName: 'Cst' }],
  ToLocation: [{ LocationName: 'Jö' }],
  ProductInformation: [{ Description: 'SJ InterCity' }],
  TypeOfTraffic: [{ Description: 'Tåg' }],
  ...extra,
});
const pos = (n: string, lat: number, lon: number, at: string, extra: Record<string, unknown> = {}) => ({
  Train: { AdvertisedTrainNumber: n, JourneyPlanDepartureDate: '2026-10-21T00:00:00.000+02:00' },
  Position: { WGS84: `POINT (${lon} ${lat})` },
  TimeStamp: at,
  Bearing: 10,
  Speed: 120,
  ...extra,
});

const mapOf = (id: string) => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'data/stations', `${id}.json`), 'utf8')) as StationMap;

describe('the Swedish ingest places trains (§A)', () => {
  let ingest: LiveMapIngest | null = null;
  afterEach(() => ingest?.stop());

  const setup = async (rows: ReturnType<typeof ann>[], now: number) => {
    process.env.TRAFIKVERKET_API_KEY ||= 'test';
    const db = openDb(':memory:');
    const alvesta = mapOf('740000004');
    const jonkoping = mapOf('740000090');
    for (const [s, lat, lon] of [
      ['Cst', 59.33, 18.06],
      ['U', 59.86, 17.65],
      ['N', 57.65, 14.69],
      ['Av', alvesta.origin.lat, alvesta.origin.lon],
      ['Jö', jonkoping.origin.lat, jonkoping.origin.lon],
    ] as const)
      db.insert(trvLocations).values({ signature: s, name: s, country: 'SE', lat, lon, advertised: true }).run();
    db.insert(stations).values({ id: '740000004', name: 'Alvesta', country: 'SE', lat: alvesta.origin.lat, lon: alvesta.origin.lon, tz: 'Europe/Stockholm', trvSignature: 'Av' }).run();
    db.insert(stations).values({ id: '740000090', name: 'Jönköping C', country: 'SE', lat: jonkoping.origin.lat, lon: jonkoping.origin.lon, tz: 'Europe/Stockholm', trvSignature: 'Jö' }).run();
    const fetchImpl = (async () => new Response(JSON.stringify({ RESPONSE: { RESULT: [{ TrainAnnouncement: rows }] } }))) as unknown as typeof fetch;
    let clock = now;
    ingest = new LiveMapIngest(db, { fetchImpl, now: () => clock, graph: () => null, qualityFile: null });
    await (ingest as unknown as { ann: { refresh(): Promise<void> } }).ann.refresh();
    return { db, train: () => ingest!.trains.get('270|2026-10-21'), tick: (t: number) => (clock = t), alvesta, jonkoping };
  };

  it('stands an arrived train on its platform at Alvesta (track → platform node → WGS84)', async () => {
    const { train, alvesta } = await setup(
      [ann('N', 'Avgang', '13:10', { TimeAtLocation: T('13:10') }), ann('Av', 'Ankomst', '13:40', { TimeAtLocation: T('13:41'), TrackAtLocation: '3a' }), ann('Av', 'Avgang', '13:43', { TrackAtLocation: '3a' }), ann('Jö', 'Ankomst', '14:40', { TrackAtLocation: '2' })],
      ms('13:42'),
    );
    ingest!.estimateAll();
    const expected = platformPoint(alvesta, '3a')!;
    // The next event is its own departure from Alvesta, so prev and next are both Alvesta.
    expect(train()).toMatchObject({ estimated: true, state: 'standing', atStation: 'Av', platform: '3a', prevId: '740000004', nextId: '740000004', progress: null });
    expect(haversineM(train()!.lat, train()!.lon, expected[0], expected[1])).toBeLessThan(1);
    // A platform is tens of metres from the station's own point, so this is a different place.
    expect(haversineM(train()!.lat, train()!.lon, alvesta.origin.lat, alvesta.origin.lon)).toBeGreaterThan(10);
  });

  it('moves an overdue train to the approach at Jönköping C, then onto platform 2 there', async () => {
    const { train, jonkoping, tick } = await setup(
      [ann('Av', 'Avgang', '13:43', { TimeAtLocation: T('13:44'), TrackAtLocation: '3a' }), ann('Jö', 'Ankomst', '14:40', { TrackAtLocation: '2' })],
      // Left Alvesta a minute late, so it is expected at 14:41; 30 s after that, nothing reported.
      ms('14:41', '30'),
    );
    ingest!.estimateAll();
    expect(train()).toMatchObject({ state: 'running', prevId: '740000004', nextId: '740000090', speedKmh: null });
    expect(haversineM(train()!.lat, train()!.lon, jonkoping.origin.lat, jonkoping.origin.lon)).toBeLessThan(APPROACH_M + 1);
    expect(train()!.progress).toBeGreaterThan(0.99);
    tick(ms('14:43'));
    ingest!.estimateAll();
    const p2 = platformPoint(jonkoping, '2')!;
    expect(train()).toMatchObject({ state: 'standing', atStation: 'Jö', platform: '2' });
    expect(haversineM(train()!.lat, train()!.lon, p2[0], p2[1])).toBeLessThan(1);
  });

  it('follows the run profile instead of a constant fraction, and never freezes at 95%', async () => {
    const { train, tick } = await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40')], ms('11:05'));
    ingest!.estimateAll();
    const early = train()!;
    expect(early).toMatchObject({ estimated: true, state: 'running', prevId: 'trv:Cst', nextId: 'trv:U' });
    // 1/8 of the time in, but accelerating: less than 1/8 of the way, and the profile gives a speed.
    expect(early.progress!).toBeLessThan(0.125);
    expect(early.progress!).toBeGreaterThan(0.05);
    expect(early.speedKmh).toBeGreaterThan(50);
    tick(ms('11:20'));
    ingest!.estimateAll();
    expect(train()!.progress!).toBeCloseTo(0.5, 1);
    // Overdue: at the approach, then at the station, never stuck short of it.
    tick(ms('11:45'));
    ingest!.estimateAll();
    expect(train()).toMatchObject({ state: 'standing', atStation: 'U', progress: null });
    expect(haversineM(train()!.lat, train()!.lon, 59.86, 17.65)).toBeLessThan(1);
  });

  it('snaps a fresh fix onto the track, points it along the track and carries it forward by the lag', async () => {
    const { train, tick } = await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40')], ms('11:10'));
    const mid = { lat: (59.33 + 59.86) / 2, lon: (18.06 + 17.65) / 2 };
    const kx = 111_320 * Math.cos((mid.lat * Math.PI) / 180);
    // 20 m east of the (straight) line, 6 s old, 120 km/h.
    tick(ms('11:10', '06'));
    ingest!.ingest([pos('270', mid.lat, mid.lon + 20 / kx, T('11:10'))]);
    const t = train()!;
    expect(t).toMatchObject({ estimated: false, state: 'running', speedKmh: 120, fixAt: ms('11:10'), at: ms('11:10', '06') });
    // On the line (within a metre of it), ahead of the fix by about 6 s × 33 m/s = 200 m, heading along the track (not the feed's 10°).
    const cum = cumulative([
      [59.33, 18.06],
      [59.86, 17.65],
    ]);
    const s = snapToLine(
      [
        [59.33, 18.06],
        [59.86, 17.65],
      ],
      cum,
      t,
      5,
    );
    expect(s).not.toBeNull();
    const ahead = haversineM(t.lat, t.lon, mid.lat, mid.lon);
    expect(ahead).toBeGreaterThan(150);
    expect(ahead).toBeLessThan(260);
    expect(t.bearing).toBeGreaterThan(320);
    expect(t.bearing).toBeLessThan(340);
    expect(t.progress).toBeGreaterThan(0.5);
  });

  it('dead-reckons from a fix that has gone quiet, then blends into the estimate', async () => {
    const { train, tick } = await setup([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:00') }), ann('U', 'Ankomst', '11:40')], ms('11:10'));
    const fixLat = 59.33 + (59.86 - 59.33) * 0.3;
    const fixLon = 18.06 + (17.65 - 18.06) * 0.3;
    ingest!.ingest([pos('270', fixLat, fixLon, T('11:10'), { Speed: 90 })]);
    // 3 min later: stale. Dead-reckoned on from the fix at 90 km/h for 3 min (4.5 km), not jumped to the estimate.
    tick(ms('11:13'));
    ingest!.estimateAll();
    const dr = train()!;
    expect(dr.estimated).toBe(true);
    expect(dr.state).toBe('running');
    expect(haversineM(dr.lat, dr.lon, fixLat, fixLon)).toBeGreaterThan(4000);
    expect(haversineM(dr.lat, dr.lon, fixLat, fixLon)).toBeLessThan(5000);
    // 5 min 15 s: halfway through the blend between the dead-reckoned place (7.5 km on) and the estimate.
    tick(ms('11:15', '15'));
    ingest!.estimateAll();
    const half = train()!;
    tick(ms('11:16'));
    ingest!.estimateAll();
    const settled = train()!;
    const fromFix = (t: { lat: number; lon: number }) => haversineM(t.lat, t.lon, fixLat, fixLon);
    expect(fromFix(half)).toBeGreaterThan(Math.min(7500, fromFix(settled)) - 1);
    expect(settled.state).toBe('running');
  });

  it('draws a train waiting at its first stop shortly before departure, and not long before', async () => {
    const { train, tick } = await setup([ann('Av', 'Avgang', '11:00', { TrackAtLocation: '4' }), ann('Jö', 'Ankomst', '12:00')], ms('11:00') - WAITING_BEFORE_MS - 60_000);
    ingest!.estimateAll();
    expect(train()).toBeUndefined();
    tick(ms('11:00') - WAITING_BEFORE_MS + 60_000);
    ingest!.estimateAll();
    expect(train()).toMatchObject({ state: 'waiting', atStation: 'Av', platform: '4', estimated: true, prevId: null, nextId: '740000004' });
  });

  it('calls a slow fix next to the station standing, on the platform when mapped', async () => {
    const { train, tick, alvesta } = await setup(
      [ann('N', 'Avgang', '13:10', { TimeAtLocation: T('13:10') }), ann('Av', 'Ankomst', '13:40', { TrackAtLocation: '1' }), ann('Av', 'Avgang', '13:43', { TrackAtLocation: '1' })],
      ms('13:39'),
    );
    tick(ms('13:39', '05'));
    // Two fixes 20 s apart at the same place: the filter reads a speed of 0 when none is sent.
    ingest!.ingest([pos('270', alvesta.origin.lat + 0.001, alvesta.origin.lon, T('13:38', '40'), { Speed: undefined })]);
    ingest!.ingest([pos('270', alvesta.origin.lat + 0.001, alvesta.origin.lon, T('13:39'), { Speed: undefined })]);
    const p = platformPoint(alvesta, '1')!;
    expect(train()).toMatchObject({ estimated: false, state: 'standing', atStation: 'Av', platform: '1', speedKmh: 0 });
    expect(haversineM(train()!.lat, train()!.lon, p[0], p[1])).toBeLessThan(1);
  });

  it('reads the track and the passage second from the announcements', () => {
    const s = summarizeTrain([ann('Cst', 'Avgang', '11:00', { TimeAtLocation: T('11:02'), TimeAtLocationWithSeconds: T('11:02', '37'), TrackAtLocation: '11' }), ann('U', 'Ankomst', '11:40', { TrackAtLocation: 'x' })], ms('11:10'))!;
    expect(s).toMatchObject({ lastTrack: '11', nextTrack: null, lastAtSeconds: ms('11:02', '37'), nextAdvertised: ms('11:40') });
  });
});

describe('locateOnSegment for the other feeds', () => {
  const placement = new Placement(() => null);
  const seg = { points: LINE, lengthM: cumulative(LINE).at(-1)!, estimated: false };
  const prev = { id: 'a', name: 'A', lat: 59.33, lon: 18.06, track: '2' };
  const next = { id: 'b', name: 'B', lat: 59.86, lon: 17.65, track: null };
  it('stands at prev before leaving, runs by the profile, and stands at next when overdue', () => {
    const base = { prev, next, left: ms('11:00'), arriving: ms('11:40'), standingAtPrev: false, gps: null, country: 'NO' as const, source: 'entur' as const };
    expect(locateOnSegment({ seg, placement }, { ...base, now: ms('10:58') })).toMatchObject({ state: 'standing', atStation: 'A', lat: 59.33 });
    expect(locateOnSegment({ seg, placement }, { ...base, now: ms('11:20') })).toMatchObject({ state: 'running', prevId: 'a', nextId: 'b' });
    expect(locateOnSegment({ seg, placement }, { ...base, now: ms('11:43') })).toMatchObject({ state: 'standing', atStation: 'B', lat: 59.86 });
    expect(locateOnSegment({ seg, placement }, { ...base, left: null, arriving: null, now: ms('11:20') })).toBeNull();
  });
  it('uses a fresh fix as it is when it is off the track', () => {
    const gps = { lat: 59.5, lon: 18.3, at: ms('11:20'), bearing: 45, speedKmh: 80, lastSpeedKmh: 80, fresh: true, ageMs: 5000 };
    expect(locateOnSegment({ seg, placement }, { prev, next, left: ms('11:00'), arriving: ms('11:40'), standingAtPrev: false, gps, now: ms('11:20', '05'), country: 'FI', source: 'digitraffic' })).toMatchObject({ lat: 59.5, lon: 18.3, bearing: 45, estimated: false, progress: null });
  });
});
