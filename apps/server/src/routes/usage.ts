// Usage counts and crash summaries from the app (owner, 2026-10-25: "what features are used the most, what routes,
// what isn't used, where do people have to restart after an error"). Nothing about who: the rows are daily counts with
// no user id or device; the X-Clack-User header every request carries is not stored here. Phones send only when the
// Usage data switch in Settings is on (default on). The summary is for whoever has the admin token.
import type { FastifyPluginAsync } from 'fastify';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { diagnostics, usageCounts } from '../db/schema.js';

export const USAGE_KINDS = ['screen', 'feature', 'route', 'error', 'relaunch'] as const;
const DIAGNOSTIC_KINDS = ['crash', 'hang', 'cpu', 'disk'] as const;
/** Names are short identifiers ("trips.add", "740000001>740000005"), never free text from a person. */
const NAME = /^[\w.:>\-]{1,80}$/;
const MAX_EVENTS = 200;
const MAX_COUNT = 1000;

interface UsageBody { day?: string; events?: { kind?: string; name?: string; count?: number }[] }
interface DiagnosticsBody { build?: string; reports?: { kind?: string; signature?: string; count?: number }[] }

const today = () => new Date().toISOString().slice(0, 10);
/** The day the phone counted on, if it is a real day within the last week; else today. */
function dayOf(day: unknown): string {
  if (typeof day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(day)) return today();
  const age = Date.now() - Date.parse(`${day}T12:00:00Z`);
  return age >= -2 * 86400_000 && age <= 7 * 86400_000 ? day : today();
}

export const usageRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    app.post<{ Body: UsageBody }>('/usage', async (req, reply) => {
      const events = Array.isArray(req.body?.events) ? req.body!.events!.slice(0, MAX_EVENTS) : [];
      const day = dayOf(req.body?.day);
      let kept = 0;
      for (const e of events) {
        if (!USAGE_KINDS.includes(e?.kind as (typeof USAGE_KINDS)[number]) || typeof e.name !== 'string' || !NAME.test(e.name)) continue;
        const count = Math.min(Math.max(Math.round(Number(e.count) || 1), 1), MAX_COUNT);
        db.insert(usageCounts)
          .values({ day, kind: e.kind!, name: e.name, count })
          .onConflictDoUpdate({ target: [usageCounts.day, usageCounts.kind, usageCounts.name], set: { count: sql`${usageCounts.count} + ${count}` } })
          .run();
        kept++;
      }
      return reply.code(202).send({ kept });
    });

    app.post<{ Body: DiagnosticsBody }>('/diagnostics', async (req, reply) => {
      const build = typeof req.body?.build === 'string' && /^[\w.]{1,20}$/.test(req.body.build) ? req.body.build : 'unknown';
      const reports = Array.isArray(req.body?.reports) ? req.body!.reports!.slice(0, 50) : [];
      let kept = 0;
      for (const r of reports) {
        if (!DIAGNOSTIC_KINDS.includes(r?.kind as (typeof DIAGNOSTIC_KINDS)[number]) || typeof r.signature !== 'string') continue;
        const signature = r.signature.replace(/[^\w.:+\- ]/g, '').slice(0, 160) || 'unknown';
        const count = Math.min(Math.max(Math.round(Number(r.count) || 1), 1), MAX_COUNT);
        db.insert(diagnostics)
          .values({ day: today(), build, kind: r.kind!, signature, count })
          .onConflictDoUpdate({
            target: [diagnostics.day, diagnostics.build, diagnostics.kind, diagnostics.signature],
            set: { count: sql`${diagnostics.count} + ${count}` },
          })
          .run();
        kept++;
      }
      return reply.code(202).send({ kept });
    });

    // The last N days in numbers: the most and least used, the top routes, errors and relaunches, crashes by build.
    app.get<{ Querystring: { days?: string } }>('/usage/summary', async (req, reply) => {
      if (!req.isAdmin) return reply.callNotFound();
      const days = Math.min(Math.max(Number(req.query.days) || 30, 1), 365);
      const since = new Date(Date.now() - days * 86400_000).toISOString().slice(0, 10);
      const top = (kind: string, order: 'desc' | 'asc', limit = 25) =>
        db.all<{ name: string; count: number }>(sql`
          select name, sum(count) as count from usage_counts where kind = ${kind} and day >= ${since}
          group by name order by count ${sql.raw(order)} limit ${limit}`);
      return {
        since,
        perDay: db.all(sql`select day, kind, sum(count) as count from usage_counts where day >= ${since} group by day, kind order by day`),
        features: top('feature', 'desc'),
        leastUsedFeatures: top('feature', 'asc', 15),
        screens: top('screen', 'desc'),
        routes: top('route', 'desc'),
        errors: top('error', 'desc'),
        relaunchesAfterError: top('relaunch', 'desc'),
        crashes: db.all(sql`select build, kind, signature, sum(count) as count from diagnostics where day >= ${since} group by build, kind, signature order by count desc limit 50`),
      };
    });
  };
