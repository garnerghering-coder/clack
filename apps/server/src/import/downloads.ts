// Quota-guarded downloads (spec §5.2). Every real download is logged in import_log, including failures,
// because failed calls still count against the monthly quota.
import fs from 'node:fs';
import path from 'node:path';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { and, desc, eq, gte } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog } from '../db/schema.js';
import { REPO_ROOT, config } from '../env.js';
import { DIGITRAFFIC_BASE, digitrafficHeaders } from '../digitraffic/client.js';

export interface Dataset {
  source: string;
  url: string;
  /** API key appended as ?key= (Trafiklab). Keyless sources (Entur) leave it out. */
  key?: () => string;
  headers?: () => Record<string, string>;
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

/** Entur's rail GTFS, one file per operator (NORWAY_DATA_FINDINGS.md). No key; at most one download a day each. */
const entur = (code: string): Dataset => ({
  source: `entur_${code}`,
  url: `https://storage.googleapis.com/marduk-production/outbound/gtfs/rb_${code}-aggregated-gtfs.zip`,
  headers: () => ({ 'ET-Client-Name': config.enturClientName }),
  file: path.join(CACHE_DIR, `entur/rb_${code}.zip`),
  monthlyQuota: 40,
});
export const ENTUR_DATASETS = ['vyg', 'goa', 'sjn', 'flt'].map(entur);

/**
 * Finland's passenger-train GTFS from Digitraffic (FINLAND_DATA_FINDINGS.md): one 5 MB zip, no key. The request needs
 * the exact `Accept-Encoding: gzip` header (digitrafficHeaders). Same once-a-day rule as the others.
 */
export const FINLAND_DATASET: Dataset = {
  source: 'digitraffic_gtfs',
  url: `${DIGITRAFFIC_BASE}trains/gtfs-passenger.zip`,
  headers: () => digitrafficHeaders(config.digitrafficUser, '*/*'),
  file: path.join(CACHE_DIR, 'digitraffic/gtfs-passenger.zip'),
  monthlyQuota: 40,
};

/** Don't download again within this many hours unless forced (spec §5.2). */
export const MIN_HOURS_BETWEEN_DOWNLOADS = 20;

export class QuotaError extends Error {}

/** A download with no data for this long is treated as failed. */
const STALL_MS = 60_000;

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
export async function ensureDataset(
  db: Db,
  ds: Dataset,
  opts: { force?: boolean; now?: number; fetchImpl?: typeof fetch; log?: (msg: string) => void } = {},
): Promise<EnsureResult> {
  const log = opts.log ?? (() => {});
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
  if (ds.key && !ds.key()) throw new QuotaError(`${ds.source}: API key missing in .env`);

  fs.mkdirSync(path.dirname(ds.file), { recursive: true });
  const startedAt = new Date(now);
  const record = (status: string, bytes: number | null, notes: string) =>
    db.insert(importLog).values({ source: `download:${ds.source}`, startedAt, finishedAt: new Date(), status, bytes, notes }).run();
  log(`${ds.source}: downloading (${used + 1}/${ds.monthlyQuota} this month)…`);
  // Abort if no data arrives for a minute, so a stalled connection fails loudly instead of hanging forever.
  const abort = new AbortController();
  let idle: NodeJS.Timeout | undefined;
  const touch = () => {
    clearTimeout(idle);
    idle = setTimeout(() => abort.abort(new Error(`no data for ${STALL_MS / 1000} s`)), STALL_MS);
  };
  touch();
  let res: Response;
  try {
    res = await (opts.fetchImpl ?? fetch)(ds.key ? `${ds.url}?key=${ds.key()}` : ds.url, { signal: abort.signal, headers: ds.headers?.() });
  } catch (e) {
    clearTimeout(idle);
    record('failed', null, String(e));
    throw e;
  }
  if (!res.ok || !res.body) {
    clearTimeout(idle);
    const text = await res.text().catch(() => '');
    record('failed', null, `HTTP ${res.status} ${text.slice(0, 200)}`);
    throw new Error(`${ds.source} download failed: HTTP ${res.status}`);
  }
  // Stream to disk: sweden.zip is ~800 MB. Log progress so a long download doesn't look frozen.
  const tmp = `${ds.file}.part`;
  const total = Number(res.headers.get('content-length')) || 0;
  let received = 0;
  let nextReport = 100e6;
  const progress = new Transform({
    transform(chunk: Buffer, _enc, done) {
      received += chunk.length;
      touch();
      if (received >= nextReport) {
        log(`${ds.source}: ${(received / 1e6).toFixed(0)} MB${total ? ` of ${(total / 1e6).toFixed(0)} MB` : ''} downloaded`);
        nextReport += 100e6;
      }
      done(null, chunk);
    },
  });
  try {
    await pipeline(Readable.fromWeb(res.body as import('node:stream/web').ReadableStream), progress, fs.createWriteStream(tmp));
  } catch (e) {
    record('failed', received, `stream interrupted after ${received} bytes: ${String(e)}`);
    throw new Error(`${ds.source} download stopped after ${(received / 1e6).toFixed(0)} MB (${String((e as Error).message ?? e)}); it will retry on the next start or tomorrow`);
  } finally {
    clearTimeout(idle);
  }
  fs.renameSync(tmp, ds.file);
  const bytes = fs.statSync(ds.file).size;
  record('ok', bytes, `Last-Modified: ${res.headers.get('last-modified') ?? '-'}`);
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
