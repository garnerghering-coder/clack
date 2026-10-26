// How the observed record and its backups are doing, for /api/health (admin view).
import fs from 'node:fs';
import path from 'node:path';
import type { Db } from '../db/client.js';
import { bytesThisMonth, bigQueryEnabled } from './bigquery.js';

/** Where the nightly database copies go, and where the Mac's pulls leave their mark (scripts/backup/). */
export const BACKUP_DIR = process.env.BACKUP_DIR ?? '/home/clack/backups';
/** No pull from the Mac for this long and the backups are behind. */
const STALE_MS = 3 * 86400_000;

export function observedHealth(db: Db, now = Date.now()) {
  // The newest day and its counts for each source and kind, plus how far back each goes.
  const latest = db.$client
    .prepare(
      `select source, kind, max(date) newest, min(date) oldest, count(*) days,
              (select records from observed_fetches f2 where f2.source = f.source and f2.kind = f.kind order by date desc limit 1) records,
              (select runs from observed_fetches f2 where f2.source = f.source and f2.kind = f.kind order by date desc limit 1) runs
       from observed_fetches f group by source, kind order by source, kind`,
    )
    .all();
  const runs = db.$client.prepare(`select country, count(*) n, max(service_date) newest, min(service_date) oldest from observed_runs group by country`).all();
  return { fetches: latest, runs, bigQuery: { on: bigQueryEnabled(), gbThisMonth: Math.round(bytesThisMonth(now) / 1e8) / 10 }, backup: backupHealth(now) };
}

export function backupHealth(now = Date.now(), dir = BACKUP_DIR) {
  const mtime = (f: string) => {
    try {
      return fs.statSync(f).mtimeMs;
    } catch {
      return null;
    }
  };
  const copies = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.db.zst')).sort() : [];
  const lastPull = mtime(path.join(dir, '.last-pull'));
  return {
    newestCopy: copies.at(-1) ?? null,
    copies: copies.length,
    lastPullAt: lastPull,
    status: !copies.length ? 'none' : lastPull === null || now - lastPull > STALE_MS ? 'behind' : 'ok',
  };
}
