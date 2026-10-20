import type { FastifyPluginAsync } from 'fastify';
import { eq } from 'drizzle-orm';
import { DEFAULT_SETTINGS, mergeSettings, type Settings } from '@clack/shared';
import type { Db } from '../db/client.js';
import { users } from '../db/schema.js';

export const settingsRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    const load = (userId: string): Settings => {
      const row = db.select({ settings: users.settings }).from(users).where(eq(users.id, userId)).get();
      // Fill in keys added after the user was created.
      return { ...DEFAULT_SETTINGS, ...((row?.settings as Partial<Settings>) ?? {}) };
    };

    app.get('/settings', async (req) => load(req.userId));

    app.patch('/settings', async (req, reply) => {
      try {
        const next = mergeSettings(load(req.userId), req.body);
        db.update(users).set({ settings: next }).where(eq(users.id, req.userId)).run();
        return next;
      } catch (e) {
        return reply.code(400).send({ error: (e as Error).message });
      }
    });
  };
