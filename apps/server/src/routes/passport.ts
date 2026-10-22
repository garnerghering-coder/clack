import type { FastifyPluginAsync } from 'fastify';
import { eq } from 'drizzle-orm';
import { CO2_COMPARISONS, DEFAULT_SETTINGS, type Co2Comparison, type Settings } from '@clack/shared';
import type { Db } from '../db/client.js';
import { users } from '../db/schema.js';
import { computeMilestones, computePassport, loadPassportLegs, passportRefs, reviewQueue, tripProgress } from '../stats/passport.js';

export const passportRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    app.get<{ Querystring: { year?: string; commuter?: string; comparison?: string } }>('/passport', async (req, reply) => {
      const settings = {
        ...DEFAULT_SETTINGS,
        ...((db.select({ s: users.settings }).from(users).where(eq(users.id, req.userId)).get()?.s as Partial<Settings>) ?? {}),
      };
      const year = req.query.year && req.query.year !== 'all' ? Number(req.query.year) : null;
      if (year !== null && !Number.isInteger(year)) return reply.code(400).send({ error: 'year must be a number or "all"' });
      const comparison = (req.query.comparison ?? settings.co2Comparison) as Co2Comparison;
      if (!CO2_COMPARISONS.includes(comparison)) return reply.code(400).send({ error: `unknown comparison: ${comparison}` });
      const includeCommuter = req.query.commuter === undefined ? settings.includeCommuter : req.query.commuter === 'true';
      const all = loadPassportLegs(db, req.userId);
      // Milestones are all-time and every counted trip, whatever the year and commuter filters show.
      return { ...computePassport(all, { year, includeCommuter, comparison }), milestones: computeMilestones(all), review: reviewQueue(db, req.userId), refs: passportRefs(db) };
    });

    // What one trip did for your Passport: unlocked milestones, progress, firsts.
    app.get<{ Params: { id: string } }>('/legs/:id/progress', async (req) => tripProgress(loadPassportLegs(db, req.userId), req.params.id));
  };
