import type { FastifyPluginAsync } from 'fastify';
import { and, eq, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, stations } from '../db/schema.js';
import { loadStationAliases } from '../dataFiles.js';
import { buildStationIndex, searchStations, type StationIndex } from '../search/stations.js';

export const stationRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    // The index is small (~700 stations); rebuild it whenever an import has run since it was built.
    let cache: { version: number; index: StationIndex } | null = null;
    const currentIndex = () => {
      const version = db.select({ v: sql<number>`coalesce(max(id), 0)` }).from(importLog).get()?.v ?? 0;
      if (!cache || cache.version !== version) {
        const rows = db.select().from(stations).where(and(eq(stations.kind, 'rail_station'))).all();
        cache = { version, index: buildStationIndex(rows, loadStationAliases()) };
      }
      return cache.index;
    };

    app.get<{ Querystring: { q?: string; limit?: string } }>('/stations/search', async (req) => {
      const limit = Math.min(Number(req.query.limit) || 8, 20);
      return searchStations(currentIndex(), req.query.q ?? '', limit).map(({ score, ...hit }) => (void score, hit));
    });

    // Shown before the user types (Flighty's "Frequently used"; becomes the user's own stations once trips exist).
    // Ranked by long-distance and regional trains so hubs beat busy commuter halts.
    app.get('/stations/popular', async () =>
      db.all(sql`
        select s.id, s.name, s.trv_signature as code, s.country
        from stations s
        join timetable_stop_times st on st.station_id = s.id
        join timetable_trips t on t.key = st.trip_key and t.category <> 'commuter'
        where s.kind = 'rail_station'
        group by s.id
        order by count(*) desc
        limit 6`),
    );
  };
