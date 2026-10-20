// Manual imports: npm run import -- <gtfs|trv-stations|basemap|bootstrap> [--force-download] [--reimport] [--zip=path] [--maxzoom=N]
import { config } from './env.js';
import { openDb } from './db/client.js';
import { bootstrap, refreshTrvStations, runGtfsImport } from './import/run.js';
import { extractBasemap } from './import/basemap.js';

const [cmd = 'bootstrap', ...flags] = process.argv.slice(2);
const flag = (name: string) => flags.includes(`--${name}`);
const zip = flags.find((f) => f.startsWith('--zip='))?.slice(6);
const maxZoom = flags.find((f) => f.startsWith('--maxzoom='))?.slice(10);
const db = openDb(config.databasePath);

if (cmd === 'gtfs') {
  const summary = await runGtfsImport(db, { forceDownload: flag('force-download'), reimport: flag('reimport'), zip });
  if (summary?.needsReview.length) console.log(`stations needing review:\n  ${summary.needsReview.join('\n  ')}`);
} else if (cmd === 'trv-stations') {
  await refreshTrvStations(db);
} else if (cmd === 'basemap') {
  await extractBasemap({ maxZoom: maxZoom ? Number(maxZoom) : undefined, out: flags.find((f) => f.startsWith('--out='))?.slice(6) });
} else if (cmd === 'bootstrap') {
  await bootstrap(db);
} else {
  console.error(`unknown command "${cmd}"; use gtfs | trv-stations | basemap | bootstrap`);
  process.exitCode = 1;
}
