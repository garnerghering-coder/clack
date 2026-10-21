import type { FastifyPluginAsync } from 'fastify';
import type { Db } from '../db/client.js';
import { todayIn } from '../lib/time.js';
import { createSmartSearch } from '../search/smartSearch.js';
import { stationIndexCache } from '../search/stationIndexCache.js';
import { productOf, tripStops } from '../search/timetable.js';
import { typicalTrainType } from '../legs/trainTypes.js';
import { pathThrough } from '../geo/trackSegments.js';
import { encodePolyline } from '@clack/shared';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export const searchRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    const search = createSmartSearch(db, stationIndexCache(db));

    app.get<{ Querystring: { q?: string; date?: string } }>('/search', async (req, reply) => {
      const date = req.query.date ?? todayIn('Europe/Stockholm');
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      return search(req.query.q ?? '', date);
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
