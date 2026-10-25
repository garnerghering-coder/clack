import type { FastifyPluginAsync } from 'fastify';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { searchStations } from '../search/stations.js';
import { stationIndexCache } from '../search/stationIndexCache.js';
import { trainsSoon } from '../legs/soon.js';

export const stationRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    const currentIndex = stationIndexCache(db);

    app.get<{ Querystring: { q?: string; limit?: string } }>('/stations/search', async (req) => {
      const limit = Math.min(Number(req.query.limit) || 8, 20);
      return searchStations(currentIndex(), req.query.q ?? '', limit).map(({ score, ...hit }) => (void score, hit));
    });

    // Real trains leaving in the next hour, near ?lat&lon or from the big hubs: the first screen's one-tap trips.
    app.get<{ Querystring: { lat?: string; lon?: string } }>('/trains/soon', async (req) => {
      const lat = req.query.lat != null ? Number(req.query.lat) : undefined;
      const lon = req.query.lon != null ? Number(req.query.lon) : undefined;
      const ok = (v: number | undefined) => v != null && Number.isFinite(v);
      return trainsSoon(db, ok(lat) && ok(lon) ? { lat, lon } : {});
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
