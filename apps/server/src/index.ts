import { config } from './env.js';
import { LOCAL_USER_ID, openDb } from './db/client.js';
import { buildApp } from './app.js';
import { bootstrap } from './import/run.js';
import { startScheduler } from './jobs/scheduler.js';
import { refreshDueLegs, refreshLegActuals } from './legs/actuals.js';
import { backfillLegGeometry } from './geo/trackSegments.js';
import { startLiveTracker } from './live/tracker.js';
import { ApnsClient, loadApnsConfig } from './push/apns.js';
import { Notifier } from './push/notifier.js';
import { syncBrands } from './import/brands.js';
import { backfillTrainTypes } from './legs/trainTypes.js';
import { regroupJourneys } from './legs/journeys.js';
import { updateRides } from './legs/recording.js';
import { sampleTrains } from './audit/sample.js';

// Plain lines among the JSON log, so start-up has a clear beginning and end in the Terminal.
const banner = (lines: string[]) => {
  const w = Math.max(...lines.map((l) => l.length)) + 4;
  const bar = '═'.repeat(w);
  console.log(`\n\x1b[1;32m╔${bar}╗\n${lines.map((l) => `║  ${l.padEnd(w - 2)}║`).join('\n')}\n╚${bar}╝\x1b[0m\n`);
};
const ready = () => banner(['✓ Clack server is ready', `Listening on ${config.host}:${config.port}`, 'Stop with Ctrl+C']);

const db = openDb(config.databasePath);
// A failed promise somewhere (a feed timing out mid-request) is logged and the server carries on; a thrown error
// nobody caught leaves things in an unknown state, so the server stops and the supervisor starts it again.
process.on('unhandledRejection', (e) => console.error('unhandled rejection:', e));
process.on('uncaughtException', (e) => {
  console.error('uncaught exception, restarting:', e);
  process.exit(1);
});
syncBrands(db);
let log = (msg: string) => console.log(msg);
const app = buildApp(db, {
  logger: true,
  // Attach real times straight away for trains that have run (or are about to).
  afterLegCreated: (id) => void refreshLegActuals(db, id).catch((e) => log(`actuals for new leg failed: ${(e as Error).message}`)),
});
await app.listen({ port: config.port, host: config.host });
// Stopped (Ctrl+C, or the supervisor restarting it): finish what's in flight and close the database cleanly.
for (const sig of ['SIGINT', 'SIGTERM'] as const)
  process.once(sig, () => {
    void app
      .close()
      .catch(() => {})
      .finally(() => {
        db.$client.close();
        process.exit(0);
      });
  });
log = (msg: string) => app.log.info(msg);
// Trips saved before routing existed get their track lines now (fast: cached per station pair).
backfillLegGeometry(db, log);
backfillTrainTypes(db);
regroupJourneys(db, LOCAL_USER_ID);
// Trip records (did you ride it?) for trips saved before records existed, and any whose wait is over.
updateRides(db);

if (process.env.JOBS !== 'off') {
  // Catch up in the background (first run imports stations and timetables; legs get any actuals they missed),
  // then keep to the schedule.
  console.log('\n\x1b[1;33m… Starting up: checking timetables, logos and map tiles. Wait for "Clack is ready".\x1b[0m\n');
  void refreshDueLegs(db, log)
    .catch((e) => log(`actual times catch-up failed: ${(e as Error).message}`))
    .then(() => bootstrap(db, log))
    .then(() => startScheduler(db, log))
    // The accuracy audit's first sample trains, rather than waiting for the hour.
    .then(() => sampleTrains(db, { log }))
    .then(ready);
  // Live tracking runs alongside the imports (it only needs saved trips).
  startLiveTracker(db, { log });
  // Alerts and Live Activities: only when the Apple key is set up (APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_PATH, APNS_TOPIC).
  const apns = loadApnsConfig();
  if (apns) {
    new Notifier(db, new ApnsClient(apns), { log }).start();
    log('push: alerts on');
  } else log('push: alerts off (no Apple key in .env)');
} else ready();
