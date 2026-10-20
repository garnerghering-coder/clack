import { config } from './env.js';
import { openDb } from './db/client.js';
import { buildApp } from './app.js';
import { bootstrap } from './import/run.js';
import { startScheduler } from './jobs/scheduler.js';

const db = openDb(config.databasePath);
const app = buildApp(db, { logger: true });
await app.listen({ port: config.port, host: config.host });

const log = (msg: string) => app.log.info(msg);
if (process.env.JOBS !== 'off') {
  // Catch up in the background (first run imports stations and timetables), then keep to the schedule.
  void bootstrap(db, log).then(() => startScheduler(db, log));
}
