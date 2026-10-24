// Manual imports and checks: npm run import -- <gtfs|norway|finland|trv-stations|basemap|logos|bootstrap|audit> [--force-download] [--reimport] [--zip=path] [--maxzoom=N]
import { config } from './env.js';
import { openDb } from './db/client.js';
import { bootstrap, refreshTrvStations, runFinlandImport, runGtfsImport, runNorwayImport } from './import/run.js';
import { extractBasemap } from './import/basemap.js';
import { refreshLogos } from './import/logos.js';
import { AUDIT_DIR, runAudit } from './audit/audit.js';

const [cmd = 'bootstrap', ...flags] = process.argv.slice(2);
const flag = (name: string) => flags.includes(`--${name}`);
const zip = flags.find((f) => f.startsWith('--zip='))?.slice(6);
const maxZoom = flags.find((f) => f.startsWith('--maxzoom='))?.slice(10);
const db = openDb(config.databasePath);

if (cmd === 'gtfs') {
  const summary = await runGtfsImport(db, { forceDownload: flag('force-download'), reimport: flag('reimport'), zip });
  if (summary?.needsReview.length) console.log(`stations needing review:\n  ${summary.needsReview.join('\n  ')}`);
} else if (cmd === 'norway') {
  await runNorwayImport(db, { forceDownload: flag('force-download'), reimport: flag('reimport') });
} else if (cmd === 'finland') {
  await runFinlandImport(db, { forceDownload: flag('force-download'), reimport: flag('reimport'), zip });
} else if (cmd === 'trv-stations') {
  await refreshTrvStations(db);
} else if (cmd === 'basemap') {
  await extractBasemap({ maxZoom: maxZoom ? Number(maxZoom) : undefined, out: flags.find((f) => f.startsWith('--out='))?.slice(6) });
} else if (cmd === 'logos') {
  await refreshLogos(console.log, { force: flag('force') });
} else if (cmd === 'bootstrap') {
  await bootstrap(db);
} else if (cmd === 'audit') {
  const r = await runAudit(db, { log: console.log });
  console.log(`audited ${r.audited} new trip(s); report: ${AUDIT_DIR}/latest.md`);
} else {
  console.error(`unknown command "${cmd}"; use gtfs | norway | finland | trv-stations | basemap | logos | bootstrap | audit`);
  process.exitCode = 1;
}
