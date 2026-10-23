import type { FastifyPluginAsync } from 'fastify';
import { gt, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { feedHealth } from '../lib/health.js';
import { trackerFixes } from '../live/tracker.js';
import { legAudits } from '../db/schema.js';
import { SERVER_VERSION } from '../lib/version.js';
import { summarize, type LegAudit } from '../audit/audit.js';

export const healthRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    app.get('/health', async () => {
      db.run(sql`select 1`);
      const mem = process.memoryUsage();
      return {
        ok: true,
        version: SERVER_VERSION,
        uptimeS: Math.round(process.uptime()),
        memoryMb: { rss: Math.round(mem.rss / 1e6), heap: Math.round(mem.heapUsed / 1e6) },
        // Each upstream feed: last answer, last failure, failures in a row (ok | degraded | down | unknown).
        feeds: feedHealth(),
        // Tracked trips' GPS: fixes taken and dropped as impossible jumps.
        gps: trackerFixes.stats,
      };
    });
    // The last week's accuracy audit in numbers (the readable report is data/audit/latest.md).
    app.get('/audit', async () =>
      summarize(
        db
          .select()
          .from(legAudits)
          .where(gt(legAudits.auditedAt, new Date(Date.now() - 7 * 86400_000)))
          .all()
          .map((r) => r.result as unknown as LegAudit),
      ),
    );
  };
