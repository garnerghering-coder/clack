// In-process scheduler (spec §4/§8). Runs only while the server runs; bootstrap() catches up on start.
import cron from 'node-cron';
import type { Db } from '../db/client.js';
import { config } from '../env.js';
import { COUNTRIES } from '../lib/countries.js';
import { refreshTrvStations, runFinlandImport, runGtfsImport, runNorwayImport } from '../import/run.js';
import { refreshDueLegs } from '../legs/actuals.js';
import { runAudit } from '../audit/audit.js';
import { sampleTrains, SAMPLE_PER_HOUR } from '../audit/sample.js';

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
  // Digitraffic's passenger GTFS is rebuilt daily; the download guard keeps this to one call per day. Staggered
  // after Norway's job (06:50 Oslo = 07:50 Helsinki) so the two never run at once, and Haparanda is already in.
  const finland = config.finlandImport ? cron.schedule('5 8 * * *', wrap('daily Finland import', () => runFinlandImport(db, { log })), { timezone: COUNTRIES.FI.tz }) : null;
  // TrainStation rarely changes.
  const weekly = cron.schedule('10 7 * * 1', wrap('weekly Trafikverket stations', () => refreshTrvStations(db, log)), { timezone: 'Europe/Stockholm' });
  // Trafikverket keeps actual times ~4 days: keep legs fresh while they run, then freeze them (SPEC §10).
  const actuals = cron.schedule('*/5 * * * *', wrap('actual times', () => refreshDueLegs(db, log)), { timezone: 'Europe/Stockholm' });
  // The accuracy audit: trips that finished at least an hour ago, checked once each; the report is rewritten hourly.
  const audit = cron.schedule('20 * * * *', wrap('accuracy audit', () => runAudit(db, { log })), { timezone: 'Europe/Stockholm' });
  // Its sample: a couple of real trains every hour from 05 to 22, followed by a hidden user (AUDIT_SAMPLE_PER_HOUR).
  const sample = SAMPLE_PER_HOUR > 0 ? cron.schedule('5 5-22 * * *', wrap('audit sample', async () => sampleTrains(db, { log })), { timezone: 'Europe/Stockholm' }) : null;
  return () => {
    void audit.stop();
    void sample?.stop();
    void daily.stop();
    void norway.stop();
    void finland?.stop();
    void weekly.stop();
    void actuals.stop();
  };
}
