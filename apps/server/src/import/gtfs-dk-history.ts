// Denmark's past timetables (DENMARK_DATA_FINDINGS.md): every old copy of Rejseplanen's GTFS that the Mobility Database
// (mdb-1292) holds, imported newest first with importGtfsDenmark's fillGaps mode, so a date keeps the newest copy that
// has it and nothing already in is deleted. Each copy is downloaded, imported and deleted again (53 MB each); what was
// done is kept in data/cache/rejseplanen/history.json so a rerun skips it. Licence CC BY 4.0.
// The refresh token (.env, MOBILITY_DB_REFRESH_TOKEN) is exchanged for an hour-long access token; it is never logged.
import fs from 'node:fs';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import type { Db } from '../db/client.js';
import { CACHE_DIR } from './downloads.js';
import { importGtfsDenmark } from './gtfs-dk.js';

const API = 'https://api.mobilitydatabase.org/v1';
const FEED = 'mdb-1292';
const DIR = path.join(CACHE_DIR, 'rejseplanen');
const DONE = path.join(DIR, 'history.json');

interface Dataset {
  id: string;
  hosted_url: string;
  downloaded_at: string;
}

let cached: { token: string; at: number } | null = null;
async function accessToken(): Promise<string> {
  if (cached && Date.now() - cached.at < 55 * 60_000) return cached.token;
  const refresh = process.env.MOBILITY_DB_REFRESH_TOKEN;
  if (!refresh) throw new Error('MOBILITY_DB_REFRESH_TOKEN is not set');
  const r = await fetch(`${API}/tokens`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refresh_token: refresh }), signal: AbortSignal.timeout(30_000) });
  if (!r.ok) throw new Error(`Mobility Database token: HTTP ${r.status}`);
  cached = { token: ((await r.json()) as { access_token: string }).access_token, at: Date.now() };
  return cached.token;
}

export async function importDenmarkHistory(db: Db, opts: { limit?: number; log?: (m: string) => void } = {}) {
  const log = opts.log ?? console.log;
  fs.mkdirSync(DIR, { recursive: true });
  const done: Record<string, string> = fs.existsSync(DONE) ? JSON.parse(fs.readFileSync(DONE, 'utf8')) : {};
  const r = await fetch(`${API}/gtfs_feeds/${FEED}/datasets`, { headers: { Authorization: `Bearer ${await accessToken()}` }, signal: AbortSignal.timeout(60_000) });
  if (!r.ok) throw new Error(`Mobility Database list: HTTP ${r.status}`);
  const all = ((await r.json()) as Dataset[]).sort((a, b) => b.downloaded_at.localeCompare(a.downloaded_at));
  log(`Mobility Database: ${all.length} copies of ${FEED}; ${Object.keys(done).length} done before`);
  let n = 0;
  for (const d of all) {
    if (done[d.id]) continue;
    if (opts.limit && n >= opts.limit) break;
    n++;
    const day = d.downloaded_at.slice(0, 10);
    const file = path.join(DIR, `${d.id}.zip`);
    try {
      const res = await fetch(d.hosted_url, { signal: AbortSignal.timeout(600_000) });
      if (!res.ok || !res.body) throw new Error(`download HTTP ${res.status}`);
      await pipeline(Readable.fromWeb(res.body as never), fs.createWriteStream(file));
      const s = await importGtfsDenmark(db, file, { today: day, daysAhead: 100, fillGaps: true, log });
      done[d.id] = `${day}: ${s.trips} trips, ${s.tripDates} new trip-dates`;
      log(`${d.id}: ${done[d.id]}`);
    } catch (e) {
      // Old copies may be in another shape (2016 to 2019): note it and go on.
      done[d.id] = `${day}: failed, ${(e as Error).message.slice(0, 120)}`;
      log(`${d.id}: ${done[d.id]}`);
    } finally {
      fs.rmSync(file, { force: true });
      fs.writeFileSync(DONE, JSON.stringify(done, null, 1));
    }
  }
}
