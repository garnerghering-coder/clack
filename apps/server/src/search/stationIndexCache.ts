// One in-memory station index shared by the search routes, rebuilt whenever an import has run since it was built.
import { eq, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, stations } from '../db/schema.js';
import { loadStationAliases } from '../dataFiles.js';
import { buildStationIndex, type StationIndex } from './stations.js';

export function stationIndexCache(db: Db) {
  let cache: { version: number; index: StationIndex } | null = null;
  return () => {
    const version = db.select({ v: sql<number>`coalesce(max(id), 0)` }).from(importLog).get()?.v ?? 0;
    if (!cache || cache.version !== version) {
      const rows = db.select().from(stations).where(eq(stations.kind, 'rail_station')).all();
      cache = { version, index: buildStationIndex(rows, loadStationAliases()) };
    }
    return cache.index;
  };
}
