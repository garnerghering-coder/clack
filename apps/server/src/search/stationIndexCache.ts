// One in-memory station index shared by the search routes, rebuilt whenever an import has run since it was built.
import { eq, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, stations, trvLocations } from '../db/schema.js';
import { SE_COUNTIES } from '@clack/shared';
import { loadStationAliases } from '../dataFiles.js';
import { buildStationIndex, type StationIndex } from './stations.js';

export function stationIndexCache(db: Db) {
  let cache: { version: number; index: StationIndex } | null = null;
  return () => {
    const version = db.select({ v: sql<number>`coalesce(max(id), 0)` }).from(importLog).get()?.v ?? 0;
    if (!cache || cache.version !== version) {
      const rows = db
        .select({ s: stations, countyNo: trvLocations.countyNo })
        .from(stations)
        .leftJoin(trvLocations, sql`lower(${trvLocations.signature}) = lower(${stations.trvSignature})`)
        .where(eq(stations.kind, 'rail_station'))
        .all()
        .map((r) => ({ ...r.s, county: r.countyNo ? (SE_COUNTIES[r.countyNo] ?? null) : null }));
      cache = { version, index: buildStationIndex(rows, loadStationAliases()) };
    }
    return cache.index;
  };
}
