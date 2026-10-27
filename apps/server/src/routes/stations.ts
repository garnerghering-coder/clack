import type { FastifyPluginAsync } from 'fastify';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { searchStations } from '../search/stations.js';
import { stationIndexCache } from '../search/stationIndexCache.js';
import { trainsSoon } from '../legs/soon.js';
import { COUNTRY_CODES } from '../lib/countries.js';

interface PopularStation { id: string; name: string; code: string | null; country: string }

const popularCache = new WeakMap<Db, { at: number; rows: PopularStation[] }>();
/** How many of each country to show, Sweden first (the app's home). */
const POPULAR_PER_COUNTRY: [string, number][] = [['SE', 3], ['NO', 2], ['DK', 2], ['FI', 1]];

/**
 * Shown before the user types (Flighty's "Frequently used"). Ranked by timetable stops with a commuter train counting a
 * third (as in the search ranking), so hubs beat busy commuter halts; the top 3 Swedish, 2 Norwegian, 2 Danish and 1
 * Finnish. Ranked within each country, so one country's timetable (Denmark's has years of history) can't crowd out the others.
 * The query is a big GROUP BY, so the answer is kept for an hour.
 */
export function popularStations(db: Db, now = Date.now()): PopularStation[] {
  const hit = popularCache.get(db);
  if (hit && now - hit.at < 3600_000) return hit.rows;
  const ranked = db.all<PopularStation>(sql`
    select id, name, code, country from (
      select s.id, s.name, s.trv_signature as code, s.country,
             row_number() over (partition by s.country order by sum(case when t.category = 'commuter' then 0.33 else 1.0 end) desc) as rk
      from stations s
      join timetable_stop_times st on st.station_id = s.id
      join timetable_trips t on t.key = st.trip_key
      where s.kind = 'rail_station' and s.country in (${sql.join(COUNTRY_CODES.map((c) => sql`${c}`), sql`, `)})
      group by s.id)
    where rk <= 3
    order by rk`);
  const rows = POPULAR_PER_COUNTRY.flatMap(([country, n]) => ranked.filter((r) => r.country === country).slice(0, n));
  popularCache.set(db, { at: now, rows });
  return rows;
}

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
    app.get('/stations/popular', async () => popularStations(db));
  };
