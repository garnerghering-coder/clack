import type { FastifyPluginAsync } from 'fastify';
import { and, eq } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { devices, legs, liveActivities } from '../db/schema.js';

/** An APNs token is a hex string (32 bytes today, longer for Live Activities). */
const TOKEN = /^[0-9a-f]{32,400}$/i;
const ENV = new Set(['sandbox', 'production']);

export const pushRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    // This phone can receive alerts. The same token again just refreshes it (and moves it if the id changed).
    app.put<{ Body: { token?: string; environment?: string; startToken?: string | null } }>('/devices', async (req, reply) => {
      const { token, environment, startToken } = req.body ?? {};
      if (!token || !TOKEN.test(token) || !environment || !ENV.has(environment)) return reply.code(400).send({ error: 'token and environment (sandbox|production) required' });
      if (startToken != null && !TOKEN.test(startToken)) return reply.code(400).send({ error: 'invalid startToken' });
      const now = new Date();
      const row = { token: token.toLowerCase(), userId: req.userId, environment, startToken: startToken?.toLowerCase() ?? null, lastSeenAt: now };
      db.insert(devices).values(row).onConflictDoUpdate({ target: devices.token, set: { userId: row.userId, environment, startToken: row.startToken, lastSeenAt: now } }).run();
      return reply.code(204).send();
    });

    app.delete<{ Params: { token: string } }>('/devices/:token', async (req, reply) => {
      db.delete(devices).where(and(eq(devices.token, req.params.token.toLowerCase()), eq(devices.userId, req.userId))).run();
      return reply.code(204).send();
    });

    // A Live Activity for one of this person's trips is running on the phone: where to send its updates.
    app.put<{ Body: { token?: string; legId?: string; environment?: string } }>('/live-activities', async (req, reply) => {
      const { token, legId, environment } = req.body ?? {};
      if (!token || !TOKEN.test(token) || !legId || !environment || !ENV.has(environment)) return reply.code(400).send({ error: 'token, legId and environment required' });
      const own = db.select({ id: legs.id }).from(legs).where(and(eq(legs.id, legId), eq(legs.userId, req.userId))).get();
      if (!own) return reply.code(404).send({ error: 'not found' });
      const t = token.toLowerCase();
      db.insert(liveActivities).values({ token: t, userId: req.userId, legId, environment }).onConflictDoUpdate({ target: liveActivities.token, set: { legId, userId: req.userId, environment } }).run();
      return reply.code(204).send();
    });

    app.delete<{ Params: { token: string } }>('/live-activities/:token', async (req, reply) => {
      db.delete(liveActivities).where(and(eq(liveActivities.token, req.params.token.toLowerCase()), eq(liveActivities.userId, req.userId))).run();
      return reply.code(204).send();
    });
  };
