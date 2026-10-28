import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { LiveMapIngest, type LiveTrain } from '../src/livemap/ingest.js';
import { bearingOf } from '../src/livemap/denmark.js';
import { RejseplanenClient, type Journey } from '../src/rejseplanen/client.js';

// Rejseplanen's position answer for all of Denmark, 2026-10-27 ~17:05 (trimmed to 10 trains).
const geopos = fs.readFileSync(new URL('./fixtures/rejseplanen/geopos.json', import.meta.url), 'utf8');
const NOW = Date.UTC(2026, 9, 27, 16, 5);

function ingestWith(swedish?: LiveTrain) {
  const client = new RejseplanenClient({ fetchImpl: (async () => new Response(geopos)) as typeof fetch, now: () => NOW });
  const ingest = new LiveMapIngest(openDb(':memory:'), { denmark: true, rejseplanen: client, now: () => NOW, includeEstimated: false });
  if (swedish) ingest.trains.set(swedish.id, swedish);
  return { ingest, dk: (ingest as unknown as { dk: { poll: () => Promise<void> } }).dk };
}

describe('Danish trains on the map', () => {
  it('draws every train Rejseplanen places, as estimated, with dk: ids', async () => {
    const { ingest, dk } = ingestWith();
    await dk.poll();
    ingest.applyDenmark();
    const dkTrains = [...ingest.trains.values()].filter((t) => t.id.startsWith('dk:'));
    expect(dkTrains.length).toBeGreaterThan(3);
    expect(dkTrains.every((t) => t.estimated)).toBe(true);
    expect(dkTrains.find((t) => t.number === '1127')?.productName).toBe('Re');
  });

  it("draws a cross-border train once: Trafikverket's GPS wins, its guess abroad gives way", async () => {
    const base = { number: '1127', date: '2026-10-27', lat: 55.6, lon: 13.0, bearing: null, speedKmh: null, at: NOW, operatorId: null, productName: null, product: 'regional', trainType: null, origin: null, destination: null, next: null, nextEta: null, delayMin: null, mine: false } as const;
    const gps = ingestWith({ ...base, id: '1127|2026-10-27', estimated: false });
    await gps.dk.poll();
    gps.ingest.applyDenmark();
    expect(gps.ingest.trains.has('1127|2026-10-27')).toBe(true);
    expect([...gps.ingest.trains.keys()].some((k) => k.startsWith('dk:1127@'))).toBe(false);

    const guess = ingestWith({ ...base, id: '1127|2026-10-27', estimated: true });
    await guess.dk.poll();
    guess.ingest.applyDenmark();
    expect(guess.ingest.trains.has('1127|2026-10-27')).toBe(false);
    expect([...guess.ingest.trains.values()].find((t) => t.id.startsWith('dk:1127@'))?.crossBorder).toBe(true);
  });

  it('works out a heading', () => {
    expect(bearingOf({ lat: 55, lon: 12 }, { lat: 56, lon: 12 })).toBe(0);
    expect(bearingOf({ lat: 55, lon: 12 }, { lat: 55, lon: 13 })).toBe(90);
  });
});

describe('Danish trains from the archive while Rejseplanen is down', () => {
  it('asks for the 15-minute files that exist by now, newest first', async () => {
    const { recentWindows } = await import('../src/livemap/denmarkFallback.js');
    // 17:47 in Copenhagen (CET): the 17:15–17:30 file appears around 17:50, so 17:00–17:15 is the newest there.
    expect(recentWindows(Date.UTC(2026, 9, 27, 16, 47)).map((w) => w.name)).toEqual(['17-00-00_to_17-15-00', '16-45-00_to_17-00-00', '16-30-00_to_16-45-00']);
    expect(recentWindows(Date.UTC(2026, 9, 27, 16, 47))[0]!.date).toBe('2026-10-27');
  });
  it("keeps each trip's newest update", async () => {
    const { latestUpdates } = await import('../src/livemap/denmarkFallback.js');
    const u = latestUpdates([
      { trip_tripId: '1', trip_startDate: '20261027', fetchTime: '2026-10-27T16:15:00Z', stopTimeUpdate: [{ stopId: '000008600626', departure: { time: 100 } }] },
      { trip_tripId: '1', trip_startDate: '20261027', fetchTime: '2026-10-27T16:20:00Z', stopTimeUpdate: [{ stopId: '000008600626', departure: { time: 160n } }] },
      { trip_tripId: '2', stopTimeUpdate: [] },
    ]);
    expect(u.size).toBe(1);
    expect(u.get('1')).toMatchObject({ date: '2026-10-27', stops: [{ stopId: '000008600626', arr: null, dep: 160_000 }] });
  });
});

describe('Danish trains that share a number, and Rejseplanen\'s stubs', () => {
  const j = (over: Partial<Journey>): Journey => ({
    jid: 'x', date: '2026-10-27', name: 'Re 75', number: '75', line: '75', category: 'Re', operator: 'NT', admin: null, direction: null,
    cancelled: false, stops: [], messages: [], pos: { lat: 57, lon: 10 }, ends: { firstUic: '8600032', firstMin: 1421, lastUic: '8600020', lastMin: 1458 }, ...over,
  });
  it('keeps four trains called "Re 75" apart, and drops a no-number stub of a numbered train', async () => {
    const { withoutStubs } = await import('../src/livemap/denmark.js');
    const four = [1421, 1367, 1398, 1427].map((m, i) => j({ jid: `j${i}`, ends: { firstUic: `860003${i}`, firstMin: m, lastUic: '8600020', lastMin: m + 40 } }));
    expect(withoutStubs(four)).toHaveLength(4);
    const full = j({ jid: 'full', name: 'Snälltåget 21509', number: '21509', stops: [{} as never, {} as never, {} as never, {} as never], ends: { firstUic: '7400003', firstMin: 1315, lastUic: '8010102', lastMin: 1891 } });
    const stub = j({ jid: 'stub', name: 'Snälltåget 21509', number: null, stops: [{} as never], ends: { firstUic: '7400003', firstMin: 1322, lastUic: '8600100', lastMin: 1504 } });
    expect(withoutStubs([stub, full]).map((x) => x.jid)).toEqual(['full']);
  });
  it('names the operator from Rejseplanen when the timetable has no match', async () => {
    const { operatorOfJourney } = await import('../src/livemap/denmark.js');
    expect(operatorOfJourney({ operator: 'NT', admin: null, category: 'Re' })).toBe('nt');
    expect(operatorOfJourney({ operator: null, admin: '000087', category: 'RA' })).toBe('vores-tog');
    expect(operatorOfJourney({ operator: 'Snälltåget AB', admin: null, category: 'Snälltåget' })).toBe('snalltaget');
    expect(operatorOfJourney({ operator: 'Skånetrafiken', admin: null, category: 'Re' })).toBe('oresundstag');
    expect(operatorOfJourney({ operator: 'Skånetrafiken', admin: null, category: 'Pågatog' })).toBe('pagatag');
    expect(operatorOfJourney({ operator: null, admin: null, category: 'RJ' })).toBeNull();
  });
});
