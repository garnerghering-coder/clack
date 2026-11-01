import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { legStops, stations, users } from '../src/db/schema.js';
import { createLiveLeg, getLeg, LegError } from '../src/legs/legs.js';
import { eq } from 'drizzle-orm';

const T = (hhmm: string) => Date.parse(`2026-11-01T${hhmm}:00+01:00`);

describe('a trip from live data', () => {
  const db = openDb(':memory:');
  db.insert(users).values({ id: 'u1', settings: {} as never }).run();
  for (const [id, name, lat, lon] of [['dk:K', 'Kolding St.', 55.49, 9.48], ['dk:F', 'Fredericia St.', 55.56, 9.74], ['dk:O', 'Odense St.', 55.4, 10.38], ['dk:KH', 'København H', 55.67, 12.56]] as const)
    db.insert(stations).values({ id, name, country: 'DK', lat, lon, tz: 'Europe/Copenhagen' }).run();
  // Snälltåget 306 Hamburg → Stockholm as Rejseplanen lists it (only the Danish stops are ours).
  const stops = [
    { stationId: 'dk:K', arr: T('13:30'), dep: T('13:32'), platform: '2' },
    { stationId: 'dk:F', arr: T('13:45'), dep: T('13:47'), platform: '3' },
    { stationId: 'dk:O', arr: T('14:15'), dep: T('14:17'), platform: '4' },
    { stationId: 'dk:KH', arr: T('15:40'), dep: null, platform: '6' },
  ];

  it('keeps the feed’s times and platforms between where you got on and off, and the whole run', () => {
    const id = createLiveLeg(db, 'u1', { number: '306', date: '2026-11-01', operatorId: null, product: 'night' }, stops, 'dk:F', 'dk:KH', T('12:00'));
    const leg = getLeg(db, 'u1', id)! as unknown as Record<string, unknown>;
    const l = (leg.leg ?? leg) as Record<string, unknown>;
    expect(l).toMatchObject({ dataQuality: 'live', trainNumber: '306', depPlatform: '3', arrPlatform: '6', category: 'night' });
    expect(new Date(l.schedDep as string | number).getTime()).toBe(T('13:47'));
    expect(new Date(l.schedArr as string | number).getTime()).toBe(T('15:40'));
    const roles = db.select().from(legStops).where(eq(legStops.legId, id)).all().map((s) => s.role);
    expect(roles).toEqual(['before', 'board', 'through', 'alight']);
  });

  it('refuses stops out of order or not on the train', () => {
    expect(() => createLiveLeg(db, 'u1', { number: '306', date: '2026-11-01', operatorId: null, product: null }, stops, 'dk:KH', 'dk:F')).toThrow(LegError);
    expect(() => createLiveLeg(db, 'u1', { number: '306', date: '2026-11-01', operatorId: null, product: null }, stops, 'dk:K', 'se:X')).toThrow(LegError);
  });
});
