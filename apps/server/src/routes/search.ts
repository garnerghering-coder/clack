import type { FastifyPluginAsync } from 'fastify';
import type { Db } from '../db/client.js';
import { todayIn } from '../lib/time.js';
import { createSmartSearch } from '../search/smartSearch.js';
import { stationIndexCache } from '../search/stationIndexCache.js';
import { tripStops } from '../search/timetable.js';

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
      return { key: found.trip.key, serviceDate: found.trip.service_date, trainNumber: found.trip.train_number, operatorId: found.trip.operator_id, category: found.trip.category, stops: found.stops };
    });
  };
