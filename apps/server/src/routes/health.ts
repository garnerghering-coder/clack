import type { FastifyPluginAsync } from 'fastify';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { feedHealth } from '../lib/health.js';
import { trackerFixes } from '../live/tracker.js';

export const healthRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    app.get('/health', async () => {
      db.run(sql`select 1`);
      const mem = process.memoryUsage();
      return {
        ok: true,
        uptimeS: Math.round(process.uptime()),
        memoryMb: { rss: Math.round(mem.rss / 1e6), heap: Math.round(mem.heapUsed / 1e6) },
        // Each upstream feed: last answer, last failure, failures in a row (ok | degraded | down | unknown).
        feeds: feedHealth(),
        // Tracked trips' GPS: fixes taken and dropped as impossible jumps.
        gps: trackerFixes.stats,
      };
    });
  };
