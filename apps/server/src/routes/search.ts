import type { FastifyPluginAsync } from 'fastify';
import { dayIndexWithin, plan } from '../search/planner.js';
import type { Db } from '../db/client.js';
import { addDays, serviceTimeToUtc, todayIn } from '../lib/time.js';
import { createSmartSearch } from '../search/smartSearch.js';
import { ensureHistory } from '../import/history.js';
import { ensureRecordedDay, recordFrom } from '../observed/timetable.js';
import { stationIndexCache } from '../search/stationIndexCache.js';
import { productOf, searchByRoute, searchConnections, tripStops } from '../search/timetable.js';
import { typicalTrainType } from '../legs/trainTypes.js';
import { pathThrough } from '../geo/trackSegments.js';
import { encodePolyline } from '@clack/shared';
import { eq } from 'drizzle-orm';
import { stations } from '../db/schema.js';
import { COUNTRIES, tzOf } from '../lib/countries.js';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export const searchRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    const log = (m: string) => app.log.warn(m);
    const record = { ensure: (c: 'NO' | 'FI', date: string) => ensureRecordedDay(db, c, date, { log }), from: (c: 'NO' | 'FI') => recordFrom(db, c) };
    const search = createSmartSearch(db, stationIndexCache(db), (date) => ensureHistory(db, date, { log }), record);

    app.get<{ Querystring: { q?: string; date?: string; changes?: string } }>('/search', async (req, reply) => {
      const date = req.query.date ?? todayIn(COUNTRIES.SE.tz);
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      const out = search(req.query.q ?? '', date);
      // Two stations: the planner's journeys (direct and with changes) for the whole service day. The app hides the
      // ones that left earlier today unless asked, as it does for direct trains.
      const { from, to } = out.interpretation;
      if (from && to && !out.outsideTimetable && !out.interpretation.trainNumber) {
        const tz = tzOf(from.country) ?? COUNTRIES.SE.tz;
        const start = serviceTimeToUtc(date, 0, tz);
        const maxChanges = Math.max(0, Math.min(2, Number(req.query.changes ?? 2) || 0));
        // The day's index takes 10-50 s to build the first time a date is asked for: the search doesn't wait for it
        // (the app gives up after 15 s). It answers with the direct trains and `journeysPending`, and the app asks again.
        const ix = await dayIndexWithin(db, date, 2000);
        if (ix) out.journeys = plan(db, ix, from.id, to.id, start, start + 86400_000, req.query.changes === undefined ? 2 : maxChanges);
        else return { ...out, journeysPending: true };
      }
      return out;
    });

    // The app calls this as soon as an older day is picked, before anything is typed, so the archive import for that
    // day is under way (or done) by the time the search runs. Returns at once with where it stands.
    app.get<{ Querystring: { date?: string } }>('/history/prepare', async (req, reply) => {
      const date = req.query.date ?? '';
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      if (date >= addDays(todayIn(COUNTRIES.SE.tz), -1)) return { sweden: 'ready', norway: 'ready', finland: 'ready' };
      return { sweden: ensureHistory(db, date, { log }).state, norway: record.ensure('NO', date), finland: record.ensure('FI', date) };
    });

    // Other ways to get there (disruption help): direct trains leaving `from` for `to` at or after `after`, today and
    // tomorrow, without the train you can't take; with one change when there are none. Timetable only: the client
    // says so and links each one to its live view.
    app.get<{ Querystring: { from?: string; to?: string; after?: string; exclude?: string } }>('/alternatives', async (req, reply) => {
      const { from, to, exclude } = req.query;
      const after = Number(req.query.after);
      if (!from || !to || !Number.isFinite(after)) return reply.code(400).send({ error: 'from, to and after (ms) are required' });
      // The day where the journey starts: its station's time zone (Finland is an hour ahead of Sweden).
      const tz = db.select({ tz: stations.tz }).from(stations).where(eq(stations.id, from)).get()?.tz ?? COUNTRIES.SE.tz;
      const day = todayIn(tz, after);
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
