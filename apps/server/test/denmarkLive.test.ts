import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { openDb } from '../src/db/client.js';
import { LiveMapIngest, type LiveTrain } from '../src/livemap/ingest.js';
import { bearingOf } from '../src/livemap/denmark.js';
import { RejseplanenClient } from '../src/rejseplanen/client.js';

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
    expect(gps.ingest.trains.has('dk:1127|2026-10-27')).toBe(false);

    const guess = ingestWith({ ...base, id: '1127|2026-10-27', estimated: true });
    await guess.dk.poll();
    guess.ingest.applyDenmark();
    expect(guess.ingest.trains.has('1127|2026-10-27')).toBe(false);
    expect(guess.ingest.trains.get('dk:1127|2026-10-27')?.crossBorder).toBe(true);
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
