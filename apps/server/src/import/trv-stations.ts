// Weekly import of Trafikverket TrainStation into trv_locations.
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, trvLocations } from '../db/schema.js';
import { fetchTrainStations, parseWgs84 } from '../trafikverket/client.js';

export async function importTrvStations(db: Db, fetchImpl?: typeof fetch): Promise<number> {
  const startedAt = new Date();
  const rows = (await fetchTrainStations(fetchImpl)).filter((s) => !s.Deleted);
  db.transaction((tx) => {
    for (const s of rows) {
      const pos = parseWgs84(s.Geometry?.WGS84);
      const values = {
        signature: s.LocationSignature,
        name: s.AdvertisedLocationName,
        shortName: s.AdvertisedShortLocationName ?? null,
        officialName: s.OfficialLocationName ?? null,
        country: s.CountryCode ?? 'SE',
        lat: pos?.[0] ?? null,
        lon: pos?.[1] ?? null,
        advertised: s.Advertised,
        countyNo: s.CountyNo?.[0] ?? null,
        modifiedAt: s.ModifiedTime ? new Date(s.ModifiedTime) : null,
      };
      tx.insert(trvLocations).values(values).onConflictDoUpdate({ target: trvLocations.signature, set: values }).run();
    }
    tx.insert(importLog).values({ source: 'trv_stations', startedAt, finishedAt: new Date(), status: 'ok', notes: `${rows.length} locations` }).run();
  });
  return rows.length;
}

export const trvLocationCount = (db: Db) => db.select({ n: sql<number>`count(*)` }).from(trvLocations).get()?.n ?? 0;
