import { config } from './env.js';
import { openDb } from './db/client.js';
import { buildApp } from './app.js';
import { bootstrap } from './import/run.js';
import { startScheduler } from './jobs/scheduler.js';
import { refreshDueLegs, refreshLegActuals } from './legs/actuals.js';
import { backfillLegGeometry } from './geo/trackSegments.js';
import { startLiveTracker } from './live/tracker.js';

const db = openDb(config.databasePath);
let log = (msg: string) => console.log(msg);
const app = buildApp(db, {
  logger: true,
  // Attach real times straight away for trains that have run (or are about to).
  afterLegCreated: (id) => void refreshLegActuals(db, id).catch((e) => log(`actuals for new leg failed: ${(e as Error).message}`)),
});
await app.listen({ port: config.port, host: config.host });
log = (msg: string) => app.log.info(msg);
// Trips saved before routing existed get their track lines now (fast: cached per station pair).
backfillLegGeometry(db, log);

if (process.env.JOBS !== 'off') {
  // Catch up in the background (first run imports stations and timetables; legs get any actuals they missed),
  // then keep to the schedule.
  void refreshDueLegs(db, log)
    .catch((e) => log(`actual times catch-up failed: ${(e as Error).message}`))
    .then(() => bootstrap(db, log))
    .then(() => startScheduler(db, log));
  // Live tracking runs alongside the imports (it only needs saved trips).
  startLiveTracker(db, { log });
}
