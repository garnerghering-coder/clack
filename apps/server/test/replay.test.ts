// Replays real feed answers recorded while trains ran (scripts/replay/record.ts) through the live tracker, tick by
// tick, and checks what a traveller would have seen for things that must never happen: an actual time vanishing,
// the train going backwards or jumping, the status going back, an event twice.
import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { eq } from 'drizzle-orm';
import { REPO_ROOT } from '../src/env.js';
import { openDb } from '../src/db/client.js';
import { legEvents, legStops, legs, liveState, stations } from '../src/db/schema.js';
import { trackOnce } from '../src/live/tracker.js';
import { haversineM } from '../src/lib/geo.js';
import { MAX_IMPLIED_KMH, MAX_REPORTED_KMH } from '../src/live/sanitize.js';

const DIR = path.join(REPO_ROOT, 'data/fixtures/replay');
const fixtures = fs.existsSync(DIR) ? fs.readdirSync(DIR).filter((f) => f.endsWith('.json')) : [];

interface Call {
  url: string;
  body: string | null;
  status: number;
  response: string;
  binary: boolean;
}
interface Fixture {
  legs: (typeof legs.$inferInsert & Record<string, unknown>)[];
  stops: (typeof legStops.$inferInsert & Record<string, unknown>)[];
  stations: (typeof stations.$inferInsert)[];
  ticks: { now: number; calls: Call[] }[];
}

/** Dates come back from JSON as strings. */
const revive = <T extends Record<string, unknown>>(row: T): T =>
  Object.fromEntries(Object.entries(row).map(([k, v]) => [k, typeof v === 'string' && /^\d{4}-\d\d-\d\dT[\d:.]+Z$/.test(v) ? new Date(v) : v])) as T;

const normal = (body: string | null) => (body ?? '').replace(/<LOGIN [^>]*\/>/, '<LOGIN/>');

const STATUS_ORDER = ['scheduled', 'boarding', 'en_route', 'at_stop', 'arrived'];

describe.skipIf(!fixtures.length)('replaying recorded trips through the live tracker', () => {
  for (const file of fixtures)
    it(`never shows an impossible state (${file})`, async () => {
      process.env.TRAFIKVERKET_API_KEY ||= 'replay';
      const fx = JSON.parse(fs.readFileSync(path.join(DIR, file), 'utf8')) as Fixture;
      const db = openDb(':memory:');
      db.$client.pragma('foreign_keys = OFF');
      db.insert(stations).values(fx.stations).onConflictDoNothing().run();
      db.insert(legs).values(fx.legs.map(revive)).run();
      db.insert(legStops).values(fx.stops.map(revive)).run();

      const problems: string[] = [];
      const actuals = new Map<string, number>();
      const last = new Map<string, { progress: number | null; status: string; lat: number | null; lon: number | null; at: number | null }>();
      let unmatched = 0;
      for (const tick of fx.ticks) {
        const pending = [...tick.calls];
        const fetchImpl = (async (input: string | URL | Request, init?: RequestInit) => {
          const url = String(input instanceof Request ? input.url : input);
          const body = normal(typeof init?.body === 'string' ? init.body : null);
          const i = pending.findIndex((c) => c.url === url && normal(c.body) === body);
          if (i < 0) {
            unmatched++;
            throw new TypeError('not recorded');
          }
          const [c] = pending.splice(i, 1);
          return new Response(c!.binary ? Buffer.from(c!.response, 'base64') : c!.response, { status: c!.status });
        }) as unknown as typeof fetch;
        await trackOnce(db, { now: () => tick.now, fetchImpl });

        for (const l of fx.legs) {
          const id = l.id as string;
          // Actual times never vanish once reported, and never move by more than a correction.
          for (const s of db.select().from(legStops).where(eq(legStops.legId, id)).all())
            for (const [k, v] of [
              [`${id}|${s.seq}|arr`, s.actualArr],
              [`${id}|${s.seq}|dep`, s.actualDep],
            ] as const) {
              const before = actuals.get(k);
              if (before !== undefined && v === null) problems.push(`${k}: actual time vanished at ${new Date(tick.now).toISOString()}`);
              if (before !== undefined && v && Math.abs(v.getTime() - before) > 2 * 60_000) problems.push(`${k}: actual time moved ${Math.round((v.getTime() - before) / 60_000)} min`);
              if (v) actuals.set(k, v.getTime());
            }
          const live = db.select().from(liveState).where(eq(liveState.legId, id)).get();
          if (!live) continue;
          const prev = last.get(id);
          if (prev && STATUS_ORDER.indexOf(live.status) >= 0 && STATUS_ORDER.indexOf(prev.status) > STATUS_ORDER.indexOf(live.status) && !(prev.status === 'at_stop' && live.status === 'en_route'))
            problems.push(`${id}: status went back from ${prev.status} to ${live.status}`);
          if (prev?.progress != null && live.progress != null && live.progress < prev.progress - 0.02) problems.push(`${id}: progress went back ${prev.progress.toFixed(3)} → ${live.progress.toFixed(3)}`);
          const at = live.positionAt?.getTime() ?? null;
          if (prev?.lat != null && live.lat != null && live.positionSource === 'gps' && prev.at && at && at > prev.at) {
            const kmh = (haversineM(prev.lat, prev.lon!, live.lat, live.lon!) / ((at - prev.at) / 1000)) * 3.6;
            if (kmh > MAX_IMPLIED_KMH && haversineM(prev.lat, prev.lon!, live.lat, live.lon!) > 500) problems.push(`${id}: GPS jumped at ${Math.round(kmh)} km/h`);
          }
          if (live.speedKmh != null && (live.speedKmh < 0 || live.speedKmh > MAX_REPORTED_KMH)) problems.push(`${id}: speed ${live.speedKmh}`);
          last.set(id, { progress: live.progress, status: live.status, lat: live.positionSource === 'gps' ? live.lat : (prev?.lat ?? null), lon: live.positionSource === 'gps' ? live.lon : (prev?.lon ?? null), at: live.positionSource === 'gps' ? at : (prev?.at ?? null) });
        }
      }
      for (const l of fx.legs) {
        const types = db.select({ type: legEvents.type }).from(legEvents).where(eq(legEvents.legId, l.id as string)).all().map((e) => e.type);
        for (const once of ['departed', 'arrived', 'cancelled'])
          if (types.filter((t) => t === once).length > 1) problems.push(`${l.id}: "${once}" more than once`);
      }
      expect(unmatched, 'requests the recording has no answer for').toBe(0);
      expect(problems).toEqual([]);
      // The recording has to contain a real run for the test to mean anything.
      expect([...last.values()].some((v) => v.status === 'en_route' || v.status === 'at_stop' || v.status === 'arrived')).toBe(true);
    }, 120_000);
});
