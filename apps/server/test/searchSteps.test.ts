import { afterEach, describe, expect, it, vi } from 'vitest';
import { openDb } from '../src/db/client.js';
import { legs, stations, users } from '../src/db/schema.js';
import { createSmartSearch } from '../src/search/smartSearch.js';
import { buildStationIndex } from '../src/search/stations.js';
import { recentRoutes } from '../src/routes/search.js';
import { DEFAULT_SETTINGS } from '@clack/shared';
import { seedFinland, seedTrip, trainFixture } from './finlandFixtures.js';

// The app suggests stations while you type and searches once the route is picked (owner, 2026-11-17): the suggest step
// must read the text as the search does, never touch the timetable, and a search by the picked ids must find what the
// text finds.
function setup() {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(Date.parse('2026-10-24T10:00:00Z'));
  const db = openDb(':memory:');
  seedFinland(db);
  seedTrip(db, trainFixture('ic-27'));
  const index = buildStationIndex(db.select().from(stations).all(), {});
  return { db, search: createSmartSearch(db, () => index) };
}

describe('the search, step by step', () => {
  afterEach(() => vi.useRealTimers());

  it('suggests without searching: the first station read, the second still being typed', () => {
    const { search } = setup();
    const r = search('Helsinki Tam', '2026-10-24', { suggestOnly: true });
    expect(r.interpretation.from?.id).toBe('fi:HKI');
    expect(r.interpretation.to).toBeUndefined();
    expect(r.interpretation.typing).toBe('to');
    expect(r.suggestions.map((s) => s.id)).toContain('fi:TPE');
    expect(r.results).toBeNull();
  });

  it('suggests the origin while it is typed', () => {
    const { search } = setup();
    const r = search('Helsin', '2026-10-24', { suggestOnly: true });
    expect(r.interpretation.typing).toBe('from');
    expect(r.suggestions[0]?.id).toBe('fi:HKI');
    expect(r.results).toBeNull();
  });

  it('with the origin picked, the text is the destination', () => {
    const { search } = setup();
    const r = search('Tamp', '2026-10-24', { fromId: 'fi:HKI', suggestOnly: true });
    expect(r.interpretation.from?.id).toBe('fi:HKI');
    expect(r.interpretation.typing).toBe('to');
    expect(r.suggestions.map((s) => s.id)).toEqual(expect.arrayContaining(['fi:TPE']));
    expect(r.suggestions.map((s) => s.id)).not.toContain('fi:HKI');
  });

  it('finds the same trains by the picked ids as by the text', () => {
    const { search } = setup();
    const byText = search('Helsinki Tampere', '2026-10-24');
    const byId = search('', '2026-10-24', { fromId: 'fi:HKI', toId: 'fi:TPE' });
    expect(byId.interpretation.from?.id).toBe('fi:HKI');
    expect(byId.interpretation.to?.id).toBe('fi:TPE');
    expect(byId.results?.map((r) => r.key)).toEqual(byText.results?.map((r) => r.key));
    expect(byId.results).toHaveLength(1);
  });

  it('ignores an id the index does not have', () => {
    const { search } = setup();
    const r = search('Helsinki Tampere', '2026-10-24', { fromId: 'nope', toId: 'fi:TPE' });
    expect(r.interpretation.from?.id).toBe('fi:HKI');
    expect(r.interpretation.to?.id).toBe('fi:TPE');
  });
});

describe('recent routes', () => {
  it('lists each route once, the last added first, without trips not taken', () => {
    const db = openDb(':memory:');
    const user = '3f1c2b4a-8d9e-4f00-a1b2-c3d4e5f60718';
    db.insert(users).values({ id: user, settings: DEFAULT_SETTINGS }).run();
    db.insert(stations)
      .values([
        { id: 'cst', name: 'Stockholm C', country: 'SE', lat: 59.33, lon: 18.06, tz: 'Europe/Stockholm', trvSignature: 'Cst' },
        { id: 'u', name: 'Uppsala C', country: 'SE', lat: 59.86, lon: 17.64, tz: 'Europe/Stockholm', trvSignature: 'U' },
        { id: 'g', name: 'Göteborg C', country: 'SE', lat: 57.7, lon: 11.97, tz: 'Europe/Stockholm', trvSignature: 'G' },
      ])
      .run();
    const leg = (id: string, from: string, to: string, at: number, ride = 'pending') =>
      ({ id, userId: user, status: 'planned' as const, dataQuality: 'full', originStationId: from, destStationId: to, ride, createdAt: new Date(at) });
    db.insert(legs)
      .values([leg('a', 'u', 'cst', 1), leg('b', 'cst', 'g', 2), leg('c', 'u', 'cst', 3), leg('d', 'g', 'u', 4, 'not_taken')])
      .run();
    const routes = recentRoutes(db, user);
    expect(routes.map((r) => `${r.from.name} → ${r.to.name}`)).toEqual(['Uppsala C → Stockholm C', 'Stockholm C → Göteborg C']);
    expect(routes.map((r) => [r.count, r.last])).toEqual([[2, 3], [1, 2]]);
  });
});
