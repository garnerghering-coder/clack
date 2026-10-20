// Quota-guarded downloader for keyed Trafiklab/Samtrafiken files.
// Every real download is appended to data/cache/downloads.log (JSON lines) so quota use is visible.
// Refuses to re-download a dataset fetched < 20h ago unless --force is passed.
//
// Usage: node scripts/phase0/download.mjs <dataset> [--force]
//   datasets: se3 | se3-extra | sv2
import fs from 'node:fs';
import path from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { CACHE } from './lib.mjs';

const DATASETS = {
  se3: { url: 'https://opendata.samtrafiken.se/gtfs-sweden/sweden.zip', keyEnv: 'TRAFIKLAB_GTFS_SWEDEN3_KEY', file: 'gtfs_se3/sweden.zip', monthlyQuota: 50 },
  'se3-extra': { url: 'https://opendata.samtrafiken.se/gtfs-sweden/sweden_extra.zip', keyEnv: 'TRAFIKLAB_GTFS_SWEDEN3_KEY', file: 'gtfs_se3/sweden_extra.zip', monthlyQuota: 50 },
  sv2: { url: 'https://api.resrobot.se/gtfs/sweden.zip', keyEnv: 'TRAFIKLAB_GTFS_SVERIGE2_KEY', file: 'gtfs_sv2/sweden.zip', monthlyQuota: 50 },
};
// se3 and se3-extra share one key and one quota.
const QUOTA_GROUP = { se3: 'se3', 'se3-extra': 'se3', sv2: 'sv2' };
const MIN_AGE_H = 20;
const LOG = path.join(CACHE, 'downloads.log');

function readLog() {
  if (!fs.existsSync(LOG)) return [];
  return fs.readFileSync(LOG, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
}

export function callsThisMonth(group) {
  const month = new Date().toISOString().slice(0, 7);
  return readLog().filter((e) => QUOTA_GROUP[e.dataset] === group && e.ts.startsWith(month)).length;
}

const [name, flag] = process.argv.slice(2);
const ds = DATASETS[name];
if (!ds) {
  console.error(`Unknown dataset. Choose one of: ${Object.keys(DATASETS).join(', ')}`);
  process.exit(1);
}
const key = process.env[ds.keyEnv];
if (!key) throw new Error(`${ds.keyEnv} missing from .env`);

const dest = path.join(CACHE, ds.file);
const last = readLog().filter((e) => e.dataset === name).at(-1);
const ageH = last ? (Date.now() - Date.parse(last.ts)) / 3600e3 : Infinity;
const group = QUOTA_GROUP[name];
console.log(`${name}: ${callsThisMonth(group)} logged calls this month for quota group "${group}" (monthly limit ~${ds.monthlyQuota})`);

if (fs.existsSync(dest) && ageH < MIN_AGE_H && flag !== '--force') {
  console.log(`Cached copy is ${ageH.toFixed(1)}h old (< ${MIN_AGE_H}h). Not downloading. Use --force to override.`);
  process.exit(0);
}

fs.mkdirSync(path.dirname(dest), { recursive: true });
const started = new Date().toISOString();
const res = await fetch(`${ds.url}?key=${key}`, { headers: { 'Accept-Encoding': 'gzip' } });
// Log the call even if it fails: it still counts against the quota.
const entry = { ts: started, dataset: name, status: res.status, bytes: 0 };
if (!res.ok) {
  fs.appendFileSync(LOG, JSON.stringify(entry) + '\n');
  throw new Error(`${name} download failed: HTTP ${res.status} ${await res.text().then((t) => t.slice(0, 300))}`);
}
// Stream to disk: sweden.zip is ~800 MB.
const tmp = dest + '.part';
await pipeline(Readable.fromWeb(res.body), fs.createWriteStream(tmp));
fs.renameSync(tmp, dest);
entry.bytes = fs.statSync(dest).size;
entry.lastModified = res.headers.get('last-modified');
fs.appendFileSync(LOG, JSON.stringify(entry) + '\n');
console.log(`Saved ${dest} (${(entry.bytes / 1e6).toFixed(1)} MB), Last-Modified: ${entry.lastModified}`);
