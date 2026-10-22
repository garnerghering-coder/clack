// Records what Trafikverket and Entur answer for real trips while they run, for replay tests
// (docs/RELIABILITY_PLAN.md §3). Copies the legs from the app's database into a scratch one, runs the live tracker
// against it every 20 s as the server would, and saves every request and answer (the API key is never written).
//
//   npx tsx --env-file=.env scripts/replay/record.ts <leg id>... [--out=data/fixtures/replay/name.json]
import fs from 'node:fs';
import path from 'node:path';
import { eq, inArray } from 'drizzle-orm';
import { LOCAL_USER_ID, openDb } from '../../apps/server/src/db/client.js';
import { legStops, legs, stations } from '../../apps/server/src/db/schema.js';
import { trackOnce, POLL_MS } from '../../apps/server/src/live/tracker.js';
import { REPO_ROOT } from '../../apps/server/src/env.js';

const ids = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const out = process.argv.find((a) => a.startsWith('--out='))?.slice(6) ?? path.join(REPO_ROOT, 'data/fixtures/replay', `${new Date().toISOString().slice(0, 10)}.json`);
const src = openDb(path.join(REPO_ROOT, 'data/app.db'));
const db = openDb(':memory:');
// Only the trips are copied, not the operators and timetables they point at.
db.$client.pragma('foreign_keys = OFF');

const legRows = src.select().from(legs).where(inArray(legs.id, ids)).all();
const stopRows = src.select().from(legStops).where(inArray(legStops.legId, ids)).all();
const stationRows = src.select().from(stations).where(inArray(stations.id, [...new Set(stopRows.map((s) => s.stationId))])).all();
// The trips as they were saved: no actual times yet.
const fresh = legRows.map((l) => ({ ...l, userId: LOCAL_USER_ID, status: 'planned', actualDep: null, actualArr: null, depDelayMin: null, arrDelayMin: null, journeyId: null }));
const freshStops = stopRows.map((s) => ({ ...s, actualArr: null, actualDep: null, estimatedArr: null, estimatedDep: null, platform: null, canceled: false, deviations: [] }));
db.insert(stations).values(stationRows).onConflictDoNothing().run();
db.insert(legs).values(fresh).run();
db.insert(legStops).values(freshStops).run();

interface Call {
  url: string;
  body: string | null;
  status: number;
  /** Text, or base64 for protobuf. */
  response: string;
  binary: boolean;
}
const ticks: { now: number; calls: Call[] }[] = [];
let calls: Call[] = [];
const recording = (async (input: string | URL | Request, init?: RequestInit) => {
  const url = String(input instanceof Request ? input.url : input);
  const res = await fetch(input, init);
  const buf = Buffer.from(await res.arrayBuffer());
  const binary = url.includes('gtfs-rt');
  const body = typeof init?.body === 'string' ? init.body.replace(/<LOGIN [^>]*\/>/, '<LOGIN/>') : null;
  calls.push({ url, body, status: res.status, response: binary ? buf.toString('base64') : buf.toString('utf8'), binary });
  return new Response(buf, { status: res.status, headers: res.headers });
}) as typeof fetch;

const end = Math.max(...legRows.map((l) => (l.schedArr?.getTime() ?? 0) + 20 * 60_000));
console.log(`recording ${ids.length} trip(s) until ${new Date(end).toISOString()} → ${out}`);
const save = () => {
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify({ recordedAt: new Date().toISOString(), legs: fresh, stops: freshStops, stations: stationRows, ticks }));
};
while (Date.now() < end) {
  const now = Date.now();
  calls = [];
  try {
    const u = await trackOnce(db, { now: () => now, fetchImpl: recording, log: (m) => console.log(m) });
    for (const x of u) console.log(new Date(now).toISOString(), x.legId.slice(0, 8), x.live.status, x.live.positionSource, x.live.speedKmh, x.live.arrivalDelayMin);
  } catch (e) {
    console.log('tick failed', (e as Error).message);
  }
  ticks.push({ now, calls });
  if (ticks.length % 15 === 0) save();
  await new Promise((r) => setTimeout(r, POLL_MS));
}
save();
console.log('done', ticks.length, 'ticks;', db.select().from(legs).where(eq(legs.id, ids[0]!)).get()?.status);
