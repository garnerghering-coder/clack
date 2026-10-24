// Real Digitraffic answers, trimmed (saved 2026-10-24 from rata.digitraffic.fi), and a small Finnish timetable built
// from them, for the Finland tests. Not a test file itself.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Db } from '../src/db/client.js';
import { operators, stations, timetableStopTimes, timetableTripDates, timetableTrips } from '../src/db/schema.js';
import type { DtTrain } from '../src/digitraffic/trains.js';
import { cleanFiName } from '../src/import/fi-stations.js';
import { serviceTimeToUtc } from '../src/lib/time.js';

const DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures/digitraffic');
export const fixture = <T = unknown>(name: string): T => JSON.parse(fs.readFileSync(path.join(DIR, `${name}.json`), 'utf8')) as T;
export const trainFixture = (name: string) => fixture<DtTrain>(name);

export const HELSINKI = 'Europe/Helsinki';
/** Haparanda's id in our database: the Finnish importer reuses the Swedish station, which keeps Europe/Stockholm. */
export const HAPARANDA = '740000372';

/** Every station the fixtures call at: `fi:<CODE>`, with fi_id, except Haparanda (Swedish, with fi_id HPA). */
export function seedFinland(db: Db) {
  db.insert(operators).values([{ id: 'vr-fi', name: 'VR', shortName: 'VR', country: 'FI', brandColor: '#007a3d' }]).onConflictDoNothing().run();
  const list = fixture<{ code: string; name: string; lat: number; lon: number; country: string; uic: number }[]>('stations');
  for (const s of list) {
    if (s.code === 'HPA') {
      db.insert(stations).values({ id: HAPARANDA, name: 'Haparanda', country: 'SE', lat: s.lat, lon: s.lon, tz: 'Europe/Stockholm', trvSignature: 'Hp', fiId: 'HPA', fiUic: s.uic }).run();
      continue;
    }
    db.insert(stations).values({ id: `fi:${s.code}`, name: cleanFiName(s.name), country: 'FI', lat: s.lat, lon: s.lon, tz: HELSINKI, fiId: s.code, fiUic: s.uic }).run();
  }
}

export const stationId = (code: string) => (code === 'HPA' ? HAPARANDA : `fi:${code}`);

/**
 * A timetable trip made from a train's commercial calls, as Finland's GTFS import would store it: key
 * `fi:<number>_<date>:test`, source gtfs_fi, times as seconds after local noon minus 12 h. Returns the key.
 */
export function seedTrip(db: Db, t: DtTrain, opts: { operatorId?: string | null; category?: string } = {}): string {
  const key = `fi:${t.trainNumber}_${t.departureDate.replaceAll('-', '')}:test`;
  const commercial = t.timeTableRows.filter((r) => r.commercialStop === true);
  db.insert(timetableTrips)
    .values({
      key,
      source: 'gtfs_fi',
      tripId: `${t.trainNumber}_${t.departureDate.replaceAll('-', '')}`,
      trainNumber: String(t.trainNumber),
      operatorId: opts.operatorId === undefined ? 'vr-fi' : opts.operatorId,
      routeType: t.trainCategory === 'Commuter' ? '109' : '102',
      category: opts.category ?? (t.trainCategory === 'Commuter' ? 'commuter' : t.trainType === 'IC' ? 'intercity' : 'regional'),
      tz: HELSINKI,
    })
    .run();
  db.insert(timetableTripDates).values({ tripKey: key, serviceDate: t.departureDate }).run();
  const base = serviceTimeToUtc(t.departureDate, 0, HELSINKI);
  const secs = (iso: string) => Math.round((Date.parse(iso) - base) / 1000);
  let seq = 0;
  type Call = { code: string; arr: number | null; dep: number | null };
  let cur: Call | null = null;
  const calls: Call[] = [];
  for (const r of commercial) {
    if (r.type === 'ARRIVAL' || !cur || cur.code !== r.stationShortCode || cur.dep !== null) calls.push((cur = { code: r.stationShortCode, arr: null, dep: null }));
    if (r.type === 'ARRIVAL') cur!.arr = secs(r.scheduledTime);
    else cur!.dep = secs(r.scheduledTime);
  }
  for (const c of calls) db.insert(timetableStopTimes).values({ tripKey: key, seq: ++seq, stationId: stationId(c.code), arrSec: c.arr, depSec: c.dep }).run();
  return key;
}

/** A fetch that answers Digitraffic paths from a table; unknown paths are a 404, so a stray request fails loudly. */
export function fakeDigitraffic(answers: Record<string, unknown | (() => unknown)>) {
  const seen: string[] = [];
  const fetchImpl = (async (url: string) => {
    const p = String(url).replace('https://rata.digitraffic.fi/api/v1/', '');
    seen.push(p);
    const hit = Object.entries(answers).find(([k]) => (k.endsWith('*') ? p.startsWith(k.slice(0, -1)) : p === k));
    if (!hit) return new Response('not found', { status: 404 });
    const v = typeof hit[1] === 'function' ? (hit[1] as () => unknown)() : hit[1];
    return new Response(JSON.stringify(v));
  }) as unknown as typeof fetch;
  return { fetchImpl, seen };
}
