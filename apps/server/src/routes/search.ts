import type { FastifyPluginAsync } from 'fastify';
import type { Db } from '../db/client.js';
import { addDays, todayIn } from '../lib/time.js';
import { createSmartSearch } from '../search/smartSearch.js';
import { ensureHistory } from '../import/history.js';
import { stationIndexCache } from '../search/stationIndexCache.js';
import { productOf, searchByRoute, searchConnections, tripStops } from '../search/timetable.js';
import { typicalTrainType } from '../legs/trainTypes.js';
import { pathThrough } from '../geo/trackSegments.js';
import { encodePolyline } from '@clack/shared';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export const searchRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    const search = createSmartSearch(db, stationIndexCache(db), (date) => ensureHistory(db, date, { log: (m) => app.log.warn(m) }));

    app.get<{ Querystring: { q?: string; date?: string } }>('/search', async (req, reply) => {
      const date = req.query.date ?? todayIn('Europe/Stockholm');
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      return search(req.query.q ?? '', date);
    });

    // Other ways to get there (disruption help): direct trains leaving `from` for `to` at or after `after`, today and
    // tomorrow, without the train you can't take; with one change when there are none. Timetable only: the client
    // says so and links each one to its live view.
    app.get<{ Querystring: { from?: string; to?: string; after?: string; exclude?: string } }>('/alternatives', async (req, reply) => {
      const { from, to, exclude } = req.query;
      const after = Number(req.query.after);
      if (!from || !to || !Number.isFinite(after)) return reply.code(400).send({ error: 'from, to and after (ms) are required' });
      const day = todayIn('Europe/Stockholm', after);
      const direct = [day, addDays(day, 1)]
        .flatMap((d) => searchByRoute(db, from, to, d))
        .filter((r) => r.from.time >= after && r.key !== exclude)
        .sort((a, b) => a.from.time - b.from.time)
        .slice(0, 4);
      const connections = direct.length
        ? []
        : [day, addDays(day, 1)]
            .flatMap((d) => searchConnections(db, from, to, d))
            .filter((c) => c.first.from.time >= after && c.first.key !== exclude)
            .slice(0, 3);
      return { direct, connections };
    });

    app.get<{ Params: { key: string }; Querystring: { date?: string } }>('/timetable/trips/:key', async (req, reply) => {
      const date = req.query.date ?? '';
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      const found = tripStops(db, req.params.key, date);
      if (!found) return reply.code(404).send({ error: 'trip not found on that date' });
      const product = productOf(found.trip.route_type, found.trip.category);
      return {
        key: found.trip.key,
        serviceDate: found.trip.service_date,
        trainNumber: found.trip.train_number,
        operatorId: found.trip.operator_id,
        category: found.trip.category,
        product,
        trainType: typicalTrainType(found.trip.operator_id, product, found.trip.train_number),
        stops: found.stops,
      };
    });

    // Track for every stop-to-stop pair of a trip: the confirm step's mini map shows the whole route and
    // highlights the chosen part.
    app.get<{ Params: { key: string }; Querystring: { date?: string } }>('/timetable/trips/:key/geometry', async (req, reply) => {
      const date = req.query.date ?? '';
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      const found = tripStops(db, req.params.key, date);
      if (!found) return reply.code(404).send({ error: 'trip not found on that date' });
      const stops = found.stops.map((s) => ({ id: s.stationId, lat: s.lat, lon: s.lon }));
      const p = pathThrough(db, stops);
      return {
        segments: p.segments.map((seg, i) => ({
          fromSeq: found.stops[i]!.seq,
          toSeq: found.stops[i + 1]!.seq,
          polyline: encodePolyline(seg.points),
          lengthM: Math.round(seg.lengthM),
          estimated: seg.estimated,
        })),
      };
    });
  };
