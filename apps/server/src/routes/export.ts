import type { FastifyPluginAsync } from 'fastify';
import { eq, inArray } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { followedTrains, journeys, legEvents, legs, legStops, stationFavorites, stationRecent, stationRequests, users } from '../db/schema.js';

/**
 * Everything "Delete my data" removes that is the person's own, as JSON they can keep. Same user-owned tables as the
 * delete (users, journeys, legs and their stops and events, followed trains, favourite and recent stations, station
 * requests). Left out on purpose: the phone's Apple push addresses (devices, live_activities) are keys, not data, and
 * the server's own bookkeeping (push_log, leg_audits) is not theirs.
 */
export const exportRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    app.get('/me/export', async (req, reply) => {
      const userId = req.userId;
      const now = new Date();
      const userLegs = db.select().from(legs).where(eq(legs.userId, userId)).all();
      const ids = userLegs.map((l) => l.id);
      const stops = ids.length ? db.select().from(legStops).where(inArray(legStops.legId, ids)).all() : [];
      const events = ids.length ? db.select().from(legEvents).where(inArray(legEvents.legId, ids)).all() : [];
      const settings = db.select({ settings: users.settings }).from(users).where(eq(users.id, userId)).get()?.settings ?? null;
      reply.header('Content-Disposition', `attachment; filename="clack-export-${now.toISOString().slice(0, 10)}.json"`);
      return {
        exportedAt: now.toISOString(),
        userId,
        legs: userLegs.map((l) => ({
          ...l,
          stops: stops.filter((s) => s.legId === l.id).sort((a, b) => a.seq - b.seq),
          events: events.filter((e) => e.legId === l.id).sort((a, b) => a.ts.getTime() - b.ts.getTime()),
        })),
        journeys: db.select().from(journeys).where(eq(journeys.userId, userId)).all(),
        follows: db.select().from(followedTrains).where(eq(followedTrains.userId, userId)).all(),
        settings,
        stationFavorites: db.select().from(stationFavorites).where(eq(stationFavorites.userId, userId)).all(),
        stationRecent: db.select().from(stationRecent).where(eq(stationRecent.userId, userId)).all(),
        stationRequests: db.select().from(stationRequests).where(eq(stationRequests.userId, userId)).all(),
      };
    });
  };
