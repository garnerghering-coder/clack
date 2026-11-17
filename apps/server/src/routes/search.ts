import type { FastifyPluginAsync } from 'fastify';
import { dayIndex, dayIndexWithin, planCached, rank } from '../search/planner.js';
import type { Db } from '../db/client.js';
import { addDays, serviceTimeToUtc, todayIn } from '../lib/time.js';
import { createSmartSearch } from '../search/smartSearch.js';
import { ensureHistory } from '../import/history.js';
import { ensureRecordedDay, recordFrom } from '../observed/timetable.js';
import { stationIndexCache } from '../search/stationIndexCache.js';
import { daysWithNumber, productOf, searchByRoute, searchConnections, tripStops } from '../search/timetable.js';
import { typicalTrainType } from '../legs/trainTypes.js';
import { pathThrough } from '../geo/trackSegments.js';
import { encodePolyline } from '@clack/shared';
import { and, desc, eq, inArray, ne } from 'drizzle-orm';
import { legs, stations } from '../db/schema.js';
import { COUNTRIES, tzOf } from '../lib/countries.js';
import { searchHomeCountry } from '../search/homeCountry.js';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export const searchRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    const log = (m: string) => app.log.warn(m);
    const record = { ensure: (c: 'NO' | 'FI', date: string) => ensureRecordedDay(db, c, date, { log }), from: (c: 'NO' | 'FI') => recordFrom(db, c) };
    const search = createSmartSearch(db, stationIndexCache(db), (date) => ensureHistory(db, date, { log }), record);

    const countryOfResult = (r: { from: { country?: string } }) => r.from.country;

    // While the person types: how the text reads and the stations to pick from, nothing from the timetable, so it
    // answers at once. `from` (a station id): the origin is already picked and the text is the destination.
    app.get<{ Querystring: { q?: string; date?: string; from?: string } }>('/search/suggest', async (req, reply) => {
      const date = req.query.date ?? todayIn(COUNTRIES.SE.tz);
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      return search(req.query.q ?? '', date, { fromId: req.query.from, suggestOnly: true });
    });

    // Starts building a day's journey planner as soon as the app knows the day and the first station, so the search
    // that follows doesn't wait for it. Answers at once. Only that day: the cache holds four, and today and tomorrow
    // (which today's six-hour window runs into) are kept warm already (warmPlanner).
    app.get<{ Querystring: { date?: string } }>('/search/warm', async (req, reply) => {
      const date = req.query.date ?? '';
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      dayIndex(db, date).catch((e) => log(`planner: warming ${date} failed: ${(e as Error).message}`));
      return { warming: true };
    });

    // `from` and `to` (station ids): the stations picked in the app, searched as they are; `q` then carries only an
    // operator or a train number.
    app.get<{ Querystring: { q?: string; date?: string; changes?: string; after?: string; hours?: string; region?: string; from?: string; to?: string } }>('/search', async (req, reply) => {
      const date = req.query.date ?? todayIn(COUNTRIES.SE.tz);
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      const out = search(req.query.q ?? '', date, { fromId: req.query.from, toId: req.query.to });
      // A bare number matches trains in every country: the ones in this person's home country first (user test
      // 2026-11-07: "421" gave a Danish IC 421 above SJ's). Stable, so exact numbers still come before variants.
      if (out.interpretation.trainNumber && out.results && out.results.length > 0 && !out.interpretation.operator) {
        // Always a country: the settings', the first trip's, the phone's region, else Sweden (search/homeCountry.ts).
        const home = searchHomeCountry(db, req.userId, req.query.region);
        if (out.results.length > 1) out.results = out.results.map((r, i) => ({ r, i })).sort((a, b) => Number(countryOfResult(b.r) === home) - Number(countryOfResult(a.r) === home) || a.i - b.i).map((x) => x.r);
        // Only trains abroad on this day: the days the number runs at home, so a Swede's "421" on a Sunday reads
        // "no SJ 421 today, it runs Monday" and not "your train is Danish".
        if (!out.results.some((r) => countryOfResult(r) === home)) {
          const days = daysWithNumber(db, out.interpretation.trainNumber, date, { country: home });
          if (days.length) {
            out.otherDays = days;
            out.otherDaysCountry = home;
          }
        }
      }
      // Two stations: the planner's journeys (direct and with changes) for the whole service day. The app hides the
      // ones that left earlier today unless asked, as it does for direct trains.
      const { from, to } = out.interpretation;
      if (from && to && !out.outsideTimetable && !out.interpretation.trainNumber) {
        const tz = tzOf(from.country) ?? COUNTRIES.SE.tz;
        // Up to five changes (owner, 2026-10-28); two unless asked, as older apps expect.
        const maxChanges = Math.max(0, Math.min(5, Number(req.query.changes ?? 2) || 0));
        // The window: the whole service day (older apps), or `after` + `hours` for paging. The day planned is the one
        // `after` falls in (the app pages back and forth from any date with the same `date`); a window that runs
        // into the next date searches both days' indexes and ranks the results together.
        const after = Number(req.query.after);
        const paged = Number.isFinite(after) && after > 0;
        const hours = Math.max(1, Math.min(24, Number(req.query.hours) || 6));
        const planDate = paged ? todayIn(tz, after) : date;
        const dayStart = serviceTimeToUtc(planDate, 0, tz);
        const dayEnd = dayStart + 86400_000;
        const winStart = paged ? after : dayStart;
        const winEnd = paged ? after + hours * 3600_000 : dayEnd;
        // The day's index takes a moment to build the first time a date is asked for: the search doesn't wait for it
        // (the app gives up after 15 s). It answers with the direct trains and `journeysPending`, and the app asks again.
        const found: typeof out.journeys = [];
        let pending = false;
        if (winStart < dayEnd) {
          const ix = await dayIndexWithin(db, planDate, 2000);
          if (ix) found.push(...planCached(db, ix, from.id, to.id, winStart, Math.min(winEnd, dayEnd), maxChanges));
          else pending = true;
        }
        if (winEnd > dayEnd) {
          const next = addDays(planDate, 1);
          const ix = await dayIndexWithin(db, next, 2000);
          if (ix) found.push(...planCached(db, ix, from.id, to.id, Math.max(winStart, dayEnd), winEnd, maxChanges));
          else pending = true;
        }
        if (pending) return { ...out, journeysPending: true };
        out.journeys = rank(found);
        out.window = { start: winStart, end: winEnd };
      }
      return out;
    });

    // The person's own routes, the last added first, each pair once: one tap searches it again (DESIGN §5.6).
    app.get('/routes/recent', async (req) => recentRoutes(db, req.userId));

    // The app calls this as soon as an older day is picked, before anything is typed, so the archive import for that
    // day is under way (or done) by the time the search runs. Returns at once with where it stands.
    app.get<{ Querystring: { date?: string } }>('/history/prepare', async (req, reply) => {
      const date = req.query.date ?? '';
      if (!DATE.test(date)) return reply.code(400).send({ error: 'date must be YYYY-MM-DD' });
      if (date >= addDays(todayIn(COUNTRIES.SE.tz), -1)) return { sweden: 'ready', norway: 'ready', finland: 'ready' };
      return { sweden: ensureHistory(db, date, { log }).state, norway: record.ensure('NO', date), finland: record.ensure('FI', date) };
    });

    // Other ways to get there (disruption help): direct trains leaving `from` for `to` at or after `after`, today and
    // tomorrow, without the train you can't take; with one change when there are none. `before` (optional, ms): only
    // those arriving by then, to reach a train that starts later on your way in time for it (build 86). Timetable only:
    // the client says so and links each one to its live view.
    app.get<{ Querystring: { from?: string; to?: string; after?: string; before?: string; exclude?: string } }>('/alternatives', async (req, reply) => {
      const { from, to, exclude } = req.query;
      const after = Number(req.query.after);
      const before = req.query.before === undefined ? Infinity : Number(req.query.before);
      if (!from || !to || !Number.isFinite(after) || Number.isNaN(before)) return reply.code(400).send({ error: 'from, to and after (ms) are required; before (ms) is optional' });
      // The day where the journey starts: its station's time zone (Finland is an hour ahead of Sweden).
      const tz = db.select({ tz: stations.tz }).from(stations).where(eq(stations.id, from)).get()?.tz ?? COUNTRIES.SE.tz;
      const day = todayIn(tz, after);
      const direct = [day, addDays(day, 1)]
        .flatMap((d) => searchByRoute(db, from, to, d))
        .filter((r) => r.from.time >= after && r.to.time <= before && r.key !== exclude)
        .sort((a, b) => a.from.time - b.from.time)
        .slice(0, 4);
      const connections = direct.length
        ? []
        : [day, addDays(day, 1)]
            .flatMap((d) => searchConnections(db, from, to, d))
            .filter((c) => c.first.from.time >= after && c.second.to.time <= before && c.first.key !== exclude && c.second.key !== exclude)
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

/** The user's last distinct routes (origin → destination of the trips they added, newest first), at most `limit`, each
 * with how many trips it has and when the latest of them ran (its departure, else when it was added; epoch ms). Trips they said they didn't take are left out. */
export function recentRoutes(db: Db, userId: string, limit = 4) {
  const rows = db
    .select({ from: legs.originStationId, to: legs.destStationId, added: legs.createdAt, dep: legs.schedDep })
    .from(legs)
    .where(and(eq(legs.userId, userId), ne(legs.ride, 'not_taken')))
    .orderBy(desc(legs.createdAt))
    .limit(200)
    .all();
  const counts = new Map<string, number>();
  const latest = new Map<string, number>();
  for (const r of rows) {
    const key = `${r.from}>${r.to}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
    const at = (r.dep ?? r.added)?.getTime();
    if (at != null && at > (latest.get(key) ?? -Infinity)) latest.set(key, at);
  }
  const seen = new Set<string>();
  const pairs = rows.filter((r) => r.from !== r.to && !seen.has(`${r.from}>${r.to}`) && seen.add(`${r.from}>${r.to}`)).slice(0, limit);
  if (!pairs.length) return [];
  const ids = [...new Set(pairs.flatMap((p) => [p.from, p.to]))];
  const byId = new Map(
    db
      .select({ id: stations.id, name: stations.name, code: stations.trvSignature, country: stations.country })
      .from(stations)
      .where(inArray(stations.id, ids))
      .all()
      .map((s) => [s.id, s]),
  );
  return pairs.flatMap((p) => {
    const from = byId.get(p.from);
    const to = byId.get(p.to);
    return from && to ? [{ from, to, count: counts.get(`${p.from}>${p.to}`) ?? 1, last: latest.get(`${p.from}>${p.to}`) ?? null }] : [];
  });
}
