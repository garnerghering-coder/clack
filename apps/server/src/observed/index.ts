// The observed record's schedule (SPEC §5.6): what actually happened to every train, kept from now on.
//  - Sweden: each night at 04:10, every train of the last days that isn't final yet (Trafikverket keeps ~4 days),
//    plus the day's incidents and messages; Trafikverket's code list each Monday.
//  - Finland: each night at 04:40 (Helsinki); and a slow backfill of every day back to 2016.
//  - Norway: every 5 minutes, the journeys that have just arrived; disruption messages every 10 minutes; Entur's
//    BigQuery archive each morning at 07:30 (Oslo) for yesterday, and a backfill back to 2020 (one day every 2 minutes).
// OBSERVED=off turns it all off; OBSERVED_BACKFILL=off keeps the nightly rounds but not the backfills.
import cron from 'node-cron';
import type { Db } from '../db/client.js';
import * as bq from './bigquery.js';
import * as fi from './finland.js';
import * as no from './norway.js';
import * as se from './sweden.js';
import { refreshLegsOnDay } from '../legs/actuals.js';
import { addDays, todayIn } from '../lib/time.js';

const off = (v: string | undefined) => /^(0|false|no|off)$/i.test(v ?? '');

export function startObserved(db: Db, log: (m: string) => void): () => void {
  if (off(process.env.OBSERVED)) {
    log('observed record: off');
    return () => {};
  }
  const guard = (name: string, fn: () => Promise<unknown>) => {
    let running = false;
    return async () => {
      if (running) return;
      running = true;
      try {
        await fn();
      } catch (e) {
        log(`observed ${name} failed: ${(e as Error).message}`);
      } finally {
        running = false;
      }
    };
  };
  const sweden = guard('Sweden', async () => {
    await se.runSweden(db, { log });
    if (new Date().getDay() === 1) await se.collectReasonCodes(db);
  });
  const finland = guard('Finland', () => fi.runFinland(db, { log }));
  const norway = guard('Norway', () => no.tick(db, { log }));
  const situations = guard('Norway situations', () => no.pollSituations(db, { log }));
  const bigquery = guard('Norway BigQuery', async () => {
    await bq.runNightly(db, { log });
    await refreshLegsOnDay(db, addDays(todayIn('Europe/Oslo'), -1), log);
  });
  const jobs = [
    cron.schedule('10 4 * * *', sweden, { timezone: 'Europe/Stockholm' }),
    cron.schedule('40 4 * * *', finland, { timezone: 'Europe/Helsinki' }),
    cron.schedule('30 7 * * *', bigquery, { timezone: 'Europe/Oslo' }),
  ];
  const timers = [setInterval(norway, 5 * 60_000), setInterval(situations, 10 * 60_000)];

  if (!off(process.env.OBSERVED_BACKFILL)) {
    // Finland: two requests a step, one step a minute (Digitraffic allows 60 a minute; the app's own use shares 40).
    let fiDone = false;
    const fiStep = guard('Finland backfill', async () => {
      if (fiDone) return;
      const day = await fi.backfillStep(db, {});
      if (day === null) {
        fiDone = true;
        log('observed FI backfill complete');
      } else await refreshLegsOnDay(db, day, log);
    });
    // Norway: one day every 2 minutes (a day scans ~0.07 GB, measured 2026-10-26: 2020 to now is ~170 GB, well under
    // the month's budget, which backfillStep also checks).
    let bqIdle = false;
    const bqStep = guard('Norway BigQuery backfill', async () => {
      const day = await bq.backfillStep(db, { log });
      if (day) {
        bqIdle = false;
        await refreshLegsOnDay(db, day, log);
      } else if (bq.bigQueryEnabled() && !bqIdle) {
        // Said once, not every two minutes: it carries on by itself next month if it paused for the budget.
        bqIdle = true;
        log('observed NO backfill: done or paused for the month');
      }
    });
    timers.push(setInterval(fiStep, 60_000), setInterval(bqStep, 2 * 60_000));
  }

  // Catch up now: Trafikverket still has the last ~4 days, and anything missed while the server was down.
  void sweden().then(finland).then(bigquery);
  void norway();
  void situations();
  log(`observed record: on (BigQuery ${bq.bigQueryEnabled() ? 'on' : 'off: no GOOGLE_APPLICATION_CREDENTIALS'})`);
  return () => {
    for (const j of jobs) void j.stop();
    for (const t of timers) clearInterval(t);
  };
}
