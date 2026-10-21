// In-process scheduler (spec §4/§8). Runs only while the server runs; bootstrap() catches up on start.
import cron from 'node-cron';
import type { Db } from '../db/client.js';
import { refreshTrvStations, runGtfsImport, runNorwayImport } from '../import/run.js';
import { refreshDueLegs } from '../legs/actuals.js';

export function startScheduler(db: Db, log: (m: string) => void) {
  const wrap = (name: string, fn: () => Promise<unknown>) => async () => {
    try {
      await fn();
    } catch (e) {
      log(`${name} failed: ${(e as Error).message}`);
    }
  };
  // Samtrafiken publishes ~05:00-06:00; the download guard keeps this to one call per day.
  const daily = cron.schedule('35 6 * * *', wrap('daily GTFS import', () => runGtfsImport(db, { log })), { timezone: 'Europe/Stockholm' });
  // Entur refreshes its rail feeds through the night; the download guard keeps this to one call per feed per day.
  const norway = cron.schedule('50 6 * * *', wrap('daily Norway import', () => runNorwayImport(db, { log })), { timezone: 'Europe/Oslo' });
  // TrainStation rarely changes.
  const weekly = cron.schedule('10 7 * * 1', wrap('weekly Trafikverket stations', () => refreshTrvStations(db, log)), { timezone: 'Europe/Stockholm' });
  // Trafikverket keeps actual times ~4 days: keep legs fresh while they run, then freeze them (SPEC §10).
  const actuals = cron.schedule('*/5 * * * *', wrap('actual times', () => refreshDueLegs(db, log)), { timezone: 'Europe/Stockholm' });
  return () => {
    void daily.stop();
    void norway.stop();
    void weekly.stop();
    void actuals.stop();
  };
}
