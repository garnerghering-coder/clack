import type { FastifyPluginAsync } from 'fastify';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';

export const healthRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    app.get('/health', async () => {
      db.run(sql`select 1`);
      return { ok: true };
    });
  };
