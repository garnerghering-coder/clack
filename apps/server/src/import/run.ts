// Import orchestration: first-run bootstrap, the daily GTFS job and the weekly station refresh.
import fs from 'node:fs';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, stations } from '../db/schema.js';
import { DATASETS, ensureDataset, importLegacyDownloadLog } from './downloads.js';
import { importGtfsSweden3, lastImportedFeed, refreshStationPopularity, type ImportSummary } from './gtfs-se3.js';
import { loadOfficialMapping } from './official-mapping.js';
import { hasBaseTracks, importTrvStations, trvLocationCount } from './trv-stations.js';
import { basemapInfo, extractBasemap } from './basemap.js';
import { refreshLogos } from './logos.js';

export interface RunOptions {
  forceDownload?: boolean;
  /** Re-import even if this feed version was already imported. */
  reimport?: boolean;
  /** Use this zip instead of the cached/downloaded one (no download, no quota). */
  zip?: string;
  log?: (msg: string) => void;
}

let running: Promise<unknown> | null = null;
/** One import at a time (the scheduler and a manual run must not overlap). */
function exclusive<T>(fn: () => Promise<T>): Promise<T> {
  if (running) return running.then(() => exclusive(fn)) as Promise<T>;
  const p = fn().finally(() => {
    running = null;
  });
  running = p;
  return p;
}

export function refreshTrvStations(db: Db, log: (m: string) => void = console.log) {
  return exclusive(async () => {
    const n = await importTrvStations(db);
    log(`Trafikverket: ${n} locations`);
    return n;
  });
}

export function runGtfsImport(db: Db, opts: RunOptions = {}): Promise<ImportSummary | null> {
  const log = opts.log ?? console.log;
  return exclusive(async () => {
    importLegacyDownloadLog(db);
    if (!trvLocationCount(db) || !hasBaseTracks(db)) log(`Trafikverket: ${await importTrvStations(db)} locations`);
    let zip = opts.zip;
    if (!zip) {
      const r = await ensureDataset(db, DATASETS.gtfs_se3, { force: opts.forceDownload, log });
      log(`GTFS Sweden 3: ${r.reason}`);
      zip = r.file;
    }
    if (!fs.existsSync(zip)) throw new Error(`zip not found: ${zip}`);
    const officialSigs = await loadOfficialMapping();
    // Cheap check before the 2-3 minute parse: skip if this feed version is already in.
    const { readAll } = await import('../lib/zip.js');
    const version = (await readAll(zip, 'feed_info.txt'))[0]?.feed_version;
    const hasStations = (db.select({ n: sql<number>`count(*)` }).from(stations).get()?.n ?? 0) > 0;
    if (!opts.reimport && hasStations && version && version === lastImportedFeed(db)) {
      log(`GTFS Sweden 3 feed ${version} already imported; skipping`);
      return null;
    }
    log('GTFS Sweden 3: importing rail trips (about a minute)…');
    return importGtfsSweden3(db, zip, { officialSigs, log });
  });
}

/** On server start: make sure there is something to search, without spending quota when a cached feed exists. */
export async function bootstrap(db: Db, log: (m: string) => void = console.log) {
  try {
    const imported = await runGtfsImport(db, { log });
    // Re-rank stations for search with the current weighting (a fresh import already did); the log row makes the
    // search index rebuild.
    if (!imported && trvLocationCount(db)) {
      refreshStationPopularity(db);
      db.insert(importLog).values({ source: 'station_popularity', startedAt: new Date(), finishedAt: new Date(), status: 'ok', notes: null }).run();
    }
  } catch (e) {
    log(`import skipped: ${(e as Error).message}`);
  }
  // Operator logos: each brand's app icon from its website (skipped when already downloaded this month).
  await refreshLogos(log).catch((e) => log(`logos skipped: ${(e as Error).message}`));
  // The map's basemap is a one-off download (no quota); later runs just reuse the file.
  if (!basemapInfo()) {
    try {
      log('Basemap: first run, downloading the Nordic map tiles (a few minutes, once)…');
      await extractBasemap({ log });
    } catch (e) {
      log(`basemap download failed (maps show without a background until it works): ${(e as Error).message}`);
    }
  }
}
