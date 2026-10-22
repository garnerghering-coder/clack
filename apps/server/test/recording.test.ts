import { describe, expect, it } from 'vitest';
import { LOCAL_USER_ID, openDb } from '../src/db/client.js';
import { legs, legStops, stations } from '../src/db/schema.js';
import { answerRide, evaluateRide, RECORDING, updateRides, type RideEvidence } from '../src/legs/recording.js';
import { loadPassportLegs } from '../src/stats/passport.js';

const H = 3600_000;
const arr = Date.parse('2026-10-21T12:00:00Z');
const base: RideEvidence = { current: 'pending', schedArr: arr, actualDep: arr - H, actualArr: arr + 60_000, canceled: false, createdAt: arr - 5 * H, reportsGone: false, now: arr + 10 * 60_000 };

describe('did you ride it: the rules', () => {
  it('records a trip automatically when Trafikverket reported both your stops', () => {
    expect(evaluateRide(base)).toEqual({ ride: 'auto', reason: 'actual_times' });
  });
  it('waits before the train has arrived, and for late reports before asking', () => {
    expect(evaluateRide({ ...base, now: arr - 60_000, actualArr: null })).toEqual({ ride: 'pending', reason: 'not_arrived' });
    expect(evaluateRide({ ...base, actualArr: null, now: arr + H })).toEqual({ ride: 'pending', reason: 'waiting_reports' });
    expect(evaluateRide({ ...base, actualArr: null, now: arr + RECORDING.reviewAfterMs + 1 })).toEqual({ ride: 'review', reason: 'partial_reports' });
    expect(evaluateRide({ ...base, actualDep: null, actualArr: null, now: arr + 3 * H })).toEqual({ ride: 'review', reason: 'no_reports' });
    // Reports can't come any more: ask straight away.
    expect(evaluateRide({ ...base, actualDep: null, actualArr: null, reportsGone: true, now: arr + 60_000 })).toEqual({ ride: 'review', reason: 'no_reports' });
  });
  it('counts a trip that ends abroad, beyond live data, from the report at the border', () => {
    // Malmö → København H: Denmark has no live data; Hyllie reported the train leaving.
    const abroad = { ...base, actualArr: null, borderAlight: arr - 15 * 60_000 };
    expect(evaluateRide(abroad)).toEqual({ ride: 'auto', reason: 'border_reports' });
    // Boarding abroad works the same way, from the first reported stop.
    expect(evaluateRide({ ...base, actualDep: null, borderBoard: arr - 30 * 60_000 })).toEqual({ ride: 'auto', reason: 'border_reports' });
    // Not before the timetabled arrival, and a cancellation still asks.
    expect(evaluateRide({ ...abroad, now: arr - 60_000 })).toEqual({ ride: 'pending', reason: 'not_arrived' });
    expect(evaluateRide({ ...abroad, canceled: true })).toEqual({ ride: 'review', reason: 'cancelled' });
  });
  it('asks about a cancelled train (a replacement bus is possible)', () => {
    expect(evaluateRide({ ...base, canceled: true })).toEqual({ ride: 'review', reason: 'cancelled' });
  });
  it('counts a trip you logged after it happened, and never overrides your answer', () => {
    expect(evaluateRide({ ...base, createdAt: arr + 86400_000, actualDep: null, actualArr: null, now: arr + 86400_000 })).toEqual({ ride: 'confirmed', reason: 'added_after' });
    expect(evaluateRide({ ...base, current: 'not_taken' }).ride).toBe('not_taken');
    expect(evaluateRide({ ...base, current: 'confirmed', canceled: true }).ride).toBe('confirmed');
  });
  it('a late train arriving after its timetabled time is judged by the actual arrival', () => {
    expect(evaluateRide({ ...base, actualArr: arr + 40 * 60_000, now: arr + 30 * 60_000 })).toEqual({ ride: 'pending', reason: 'not_arrived' });
  });
});

function setup(extra: Partial<typeof legs.$inferInsert> = {}) {
  const db = openDb(':memory:');
  db.insert(stations)
    .values([
      { id: 'a', name: 'A', country: 'SE', lat: 59, lon: 18, tz: 'Europe/Stockholm' },
      { id: 'b', name: 'B', country: 'SE', lat: 59.5, lon: 17.5, tz: 'Europe/Stockholm' },
    ])
    .run();
  db.insert(legs)
    .values({ id: 'l1', userId: LOCAL_USER_ID, status: 'completed', dataQuality: 'full', originStationId: 'a', destStationId: 'b', schedDep: new Date(arr - H), schedArr: new Date(arr), actualDep: new Date(arr - H), actualArr: new Date(arr), distanceM: 50_000, createdAt: new Date(arr - 5 * H), ...extra })
    .run();
  db.insert(legStops)
    .values([
      { legId: 'l1', seq: 1, stationId: 'a', role: 'board' },
      { legId: 'l1', seq: 2, stationId: 'b', role: 'alight' },
    ])
    .run();
  return db;
}

describe('trip records in the database', () => {
  it('updates once and is idempotent; only counted trips reach the Passport', () => {
    const db = setup();
    expect(loadPassportLegs(db, LOCAL_USER_ID, arr + H)).toHaveLength(0);
    expect(updateRides(db, { now: arr + H })).toBe(1);
    expect(updateRides(db, { now: arr + H })).toBe(0);
    expect(loadPassportLegs(db, LOCAL_USER_ID, arr + H)).toHaveLength(1);
  });
  it('"I didn\'t take it" removes it from the Passport, undo puts the evidence back', () => {
    const db = setup();
    updateRides(db, { now: arr + H });
    answerRide(db, LOCAL_USER_ID, 'l1', 'no', arr + H);
    expect(loadPassportLegs(db, LOCAL_USER_ID, arr + H)).toHaveLength(0);
    // New reports don't bring it back.
    updateRides(db, { now: arr + 2 * H });
    expect(db.select({ r: legs.ride }).from(legs).get()!.r).toBe('not_taken');
    answerRide(db, LOCAL_USER_ID, 'l1', 'undo', arr + H);
    expect(db.select({ r: legs.ride }).from(legs).get()!.r).toBe('auto');
  });
  it('a trip with no reports is asked about, and counts once you say yes', () => {
    const db = setup({ actualDep: null, actualArr: null, dataQuality: 'scheduled_only' });
    updateRides(db, { now: arr + 3 * H });
    expect(db.select({ r: legs.ride, why: legs.rideReason }).from(legs).get()).toEqual({ r: 'review', why: 'no_reports' });
    expect(loadPassportLegs(db, LOCAL_USER_ID, arr + 3 * H)).toHaveLength(0);
    answerRide(db, LOCAL_USER_ID, 'l1', 'yes');
    expect(loadPassportLegs(db, LOCAL_USER_ID, arr + 3 * H)).toHaveLength(1);
    expect(answerRide(db, 'someone-else', 'l1', 'no')).toBe(false);
  });
});

describe('milestones', () => {
  it('are reached on the trip that crosses the line, and the next ones show progress', async () => {
    const { computeMilestones } = await import('../src/stats/passport.js');
    const leg = (id: string, dep: number, km: number, country = 'SE') => ({
      id, journeyId: null, dep, arr: dep + H, schedDep: dep, distanceM: km * 1000, operatorId: 'sj', product: 'intercity', category: 'intercity', trainType: null, trainNumber: null, dataQuality: 'full', arrDelayMin: 0, canceled: false, geometry: null,
      stops: [
        { stationId: `${id}a`, name: 'A', country: 'SE', lat: 0, lon: 0, role: 'board' },
        { stationId: `${id}b`, name: 'B', country, lat: 0, lon: 0, role: 'alight' },
      ],
    });
    const m = computeMilestones([leg('x', 1, 60), leg('y', 2, 60, 'DK'), { ...leg('z', 3, 500), canceled: true }]);
    const got = m.achieved.map((a) => `${a.family}:${a.target}@${a.legId}`);
    expect(got).toContain('journeys:1@x');
    expect(got).toContain('distanceKm:100@y');
    expect(got).toContain('borderCrossings:1@y');
    expect(got).toContain('countries:2@y');
    expect(got).not.toContain('distanceKm:500@z');
    // Nearest first: 2 of 3 countries, then 4 of 10 stations.
    expect(m.next[0]).toMatchObject({ family: 'countries', target: 3, value: 2 });
    expect(m.next[1]).toMatchObject({ family: 'stations', target: 10, value: 4 });
  });
});
