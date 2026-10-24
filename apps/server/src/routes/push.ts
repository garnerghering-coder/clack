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
    // `startToken` and `widgetToken`: a missing key leaves the stored one as it is; `null` clears it. The app often doesn't
    // have its push-to-start or widget address yet when it first registers after launch, and must not wipe the one it gave before.
    app.put<{ Body: { token?: string; environment?: string; startToken?: string | null; widgetToken?: string | null } }>('/devices', async (req, reply) => {
      const { token, environment, startToken, widgetToken } = req.body ?? {};
      if (!token || !TOKEN.test(token) || !environment || !ENV.has(environment)) return reply.code(400).send({ error: 'token and environment (sandbox|production) required' });
      if (startToken != null && (typeof startToken !== 'string' || !TOKEN.test(startToken))) return reply.code(400).send({ error: 'invalid startToken' });
      if (widgetToken != null && (typeof widgetToken !== 'string' || !TOKEN.test(widgetToken))) return reply.code(400).send({ error: 'invalid widgetToken' });
      const now = new Date();
      const optional: { startToken?: string | null; widgetToken?: string | null } = {};
      if (startToken !== undefined) optional.startToken = startToken?.toLowerCase() ?? null;
      if (widgetToken !== undefined) optional.widgetToken = widgetToken?.toLowerCase() ?? null;
      const row = { token: token.toLowerCase(), userId: req.userId, environment, lastSeenAt: now };
      db.insert(devices).values({ ...row, ...optional }).onConflictDoUpdate({ target: devices.token, set: { userId: row.userId, environment, lastSeenAt: now, ...optional } }).run();
      return reply.code(204).send();
    });

    app.delete<{ Params: { token: string } }>('/devices/:token', async (req, reply) => {
      db.delete(devices).where(and(eq(devices.token, req.params.token.toLowerCase()), eq(devices.userId, req.userId))).run();
      return reply.code(204).send();
    });

    // A Live Activity for one of this person's trips is running on the phone: where to send its updates. `deviceToken`
    // (optional, the phone's own alert token) ties the card to its phone, so a phone Apple says is gone takes its cards with it.
    app.put<{ Body: { token?: string; legId?: string; environment?: string; deviceToken?: string } }>('/live-activities', async (req, reply) => {
      const { token, legId, environment, deviceToken } = req.body ?? {};
      if (!token || !TOKEN.test(token) || !legId || !environment || !ENV.has(environment)) return reply.code(400).send({ error: 'token, legId and environment required' });
      if (deviceToken != null && (typeof deviceToken !== 'string' || !TOKEN.test(deviceToken))) return reply.code(400).send({ error: 'invalid deviceToken' });
      const own = db.select({ id: legs.id }).from(legs).where(and(eq(legs.id, legId), eq(legs.userId, req.userId))).get();
      if (!own) return reply.code(404).send({ error: 'not found' });
      const t = token.toLowerCase();
      const device = deviceToken ? { deviceToken: deviceToken.toLowerCase() } : {};
      db.insert(liveActivities).values({ token: t, userId: req.userId, legId, environment, ...device }).onConflictDoUpdate({ target: liveActivities.token, set: { legId, userId: req.userId, environment, ...device } }).run();
      return reply.code(204).send();
    });

    app.delete<{ Params: { token: string } }>('/live-activities/:token', async (req, reply) => {
      db.delete(liveActivities).where(and(eq(liveActivities.token, req.params.token.toLowerCase()), eq(liveActivities.userId, req.userId))).run();
      return reply.code(204).send();
    });
  };
