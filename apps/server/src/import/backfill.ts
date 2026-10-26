// Backfilling Sweden's past timetables from the Sverige 2 archive, ahead of anyone asking (npm run import -- history).
// Four weeks at a time, each from the latest snapshot on or before the block's first day, so every day in the block
// comes from a snapshot that holds it in full (trustedDates). Days already covered are skipped, each snapshot is
// deleted after use, and it can be stopped and run again: it carries on where it left off.
import type { Db } from '../db/client.js';
import { addDays } from '../lib/time.js';
import { coveredDates, firstCurrentDay, importHistory } from './history.js';

const BLOCK_DAYS = 28;

export async function backfillSweden(db: Db, opts: { from: string; to?: string; log?: (m: string) => void; fetchImpl?: typeof fetch }) {
  const log = opts.log ?? console.log;
  const end = opts.to ?? addDays(firstCurrentDay(db), -1);
  const t0 = Date.now();
  let blocks = 0;
  for (let start = opts.from; start <= end; start = addDays(start, BLOCK_DAYS)) {
    const last = addDays(start, BLOCK_DAYS - 1) < end ? addDays(start, BLOCK_DAYS - 1) : end;
    const covered = coveredDates(db);
    let missing = 0;
    for (let d = start; d <= last; d = addDays(d, 1)) if (!covered.has(d)) missing++;
    if (!missing) continue;
    const r = await importHistory(db, start, { span: { from: start, to: last }, keepDownload: false, log, fetchImpl: opts.fetchImpl });
    blocks++;
    log(`backfill ${start}..${last}: ${r ? `${r.trips} trips from snapshot ${r.snapshot}` : 'no snapshot'} (${Math.round((Date.now() - t0) / 60_000)} min so far)`);
  }
  log(`backfill done: ${blocks} blocks in ${Math.round((Date.now() - t0) / 60_000)} min`);
}
