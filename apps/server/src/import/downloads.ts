// Quota-guarded downloads (spec §5.2). Every real download is logged in import_log, including failures,
// because failed calls still count against the monthly quota.
import fs from 'node:fs';
import path from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { and, desc, eq, gte } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog } from '../db/schema.js';
import { REPO_ROOT, config } from '../env.js';

export interface Dataset {
  source: string;
  url: string;
  key: () => string;
  file: string;
  monthlyQuota: number;
}

export const CACHE_DIR = path.join(REPO_ROOT, 'data/cache');

export const DATASETS = {
  gtfs_se3: {
    source: 'gtfs_se3',
    url: 'https://opendata.samtrafiken.se/gtfs-sweden/sweden.zip',
    key: () => config.gtfsSweden3Key,
    file: path.join(CACHE_DIR, 'gtfs_se3/sweden.zip'),
    // Bronze: 50 calls/month (owner decision: plan for 50 even if the key allows 60).
    monthlyQuota: 50,
  },
} satisfies Record<string, Dataset>;

/** Don't download again within this many hours unless forced (spec §5.2). */
export const MIN_HOURS_BETWEEN_DOWNLOADS = 20;

export class QuotaError extends Error {}

export function callsThisMonth(db: Db, source: string, now = Date.now()): number {
  const d = new Date(now);
  const monthStart = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1);
  return db
    .select()
    .from(importLog)
    .where(and(eq(importLog.source, `download:${source}`), gte(importLog.startedAt, new Date(monthStart))))
    .all().length;
}

function lastDownload(db: Db, source: string) {
  return db
    .select()
    .from(importLog)
    .where(and(eq(importLog.source, `download:${source}`), eq(importLog.status, 'ok')))
    .orderBy(desc(importLog.startedAt))
    .get();
}

export interface EnsureResult {
  file: string;
  downloaded: boolean;
  reason: string;
}

/**
 * Make sure a fresh-enough copy of `ds` is on disk. Uses the cached file if it is < 20 h old (by the download log, or
 * by file age when the log is empty), refuses if the monthly quota is used up, and otherwise downloads once.
 */
export async function ensureDataset(db: Db, ds: Dataset, opts: { force?: boolean; now?: number; fetchImpl?: typeof fetch } = {}): Promise<EnsureResult> {
  const now = opts.now ?? Date.now();
  const cachedExists = fs.existsSync(ds.file);
  const last = lastDownload(db, ds.source);
  const lastAt = last?.startedAt.getTime() ?? (cachedExists ? fs.statSync(ds.file).mtimeMs : undefined);
  const ageH = lastAt === undefined ? Infinity : (now - lastAt) / 3600_000;

  if (!opts.force && cachedExists && ageH < MIN_HOURS_BETWEEN_DOWNLOADS) {
    return { file: ds.file, downloaded: false, reason: `cached copy is ${ageH.toFixed(1)} h old` };
  }
  if (!opts.force && !cachedExists && ageH < MIN_HOURS_BETWEEN_DOWNLOADS) {
    throw new QuotaError(`last ${ds.source} download was ${ageH.toFixed(1)} h ago but the file is missing; use --force to download again`);
  }
  const used = callsThisMonth(db, ds.source, now);
  if (used >= ds.monthlyQuota && !opts.force) {
    throw new QuotaError(`${ds.source}: ${used} of ${ds.monthlyQuota} monthly downloads used; not downloading`);
  }
  if (!ds.key()) throw new QuotaError(`${ds.source}: API key missing in .env`);

  fs.mkdirSync(path.dirname(ds.file), { recursive: true });
  const startedAt = new Date(now);
  const log = (status: string, bytes: number | null, notes: string) =>
    db.insert(importLog).values({ source: `download:${ds.source}`, startedAt, finishedAt: new Date(), status, bytes, notes }).run();
  let res: Response;
  try {
    res = await (opts.fetchImpl ?? fetch)(`${ds.url}?key=${ds.key()}`);
  } catch (e) {
    log('failed', null, String(e));
    throw e;
  }
  if (!res.ok || !res.body) {
    const text = await res.text().catch(() => '');
    log('failed', null, `HTTP ${res.status} ${text.slice(0, 200)}`);
    throw new Error(`${ds.source} download failed: HTTP ${res.status}`);
  }
  // Stream to disk: sweden.zip is ~800 MB.
  const tmp = `${ds.file}.part`;
  await pipeline(Readable.fromWeb(res.body as import('node:stream/web').ReadableStream), fs.createWriteStream(tmp));
  fs.renameSync(tmp, ds.file);
  const bytes = fs.statSync(ds.file).size;
  log('ok', bytes, `Last-Modified: ${res.headers.get('last-modified') ?? '-'}`);
  return { file: ds.file, downloaded: true, reason: `downloaded ${(bytes / 1e6).toFixed(0)} MB (${used + 1}/${ds.monthlyQuota} this month)` };
}

/** Bring Phase 0's JSON-lines download log into import_log once, so quota counting includes those calls. */
export function importLegacyDownloadLog(db: Db) {
  const file = path.join(CACHE_DIR, 'downloads.log');
  if (!fs.existsSync(file)) return;
  const names: Record<string, string> = { se3: 'gtfs_se3', 'se3-extra': 'gtfs_se3', sv2: 'gtfs_sv2' };
  for (const line of fs.readFileSync(file, 'utf8').split('\n').filter(Boolean)) {
    const e = JSON.parse(line) as { ts: string; dataset: string; status: number; bytes: number };
    const source = `download:${names[e.dataset] ?? e.dataset}`;
    const startedAt = new Date(e.ts);
    const exists = db.select().from(importLog).where(and(eq(importLog.source, source), eq(importLog.startedAt, startedAt))).get();
    if (exists) continue;
    db.insert(importLog)
      .values({ source, startedAt, finishedAt: startedAt, status: e.status === 200 ? 'ok' : 'failed', bytes: e.bytes, notes: 'from Phase 0 downloads.log' })
      .run();
  }
}
