import type { FastifyPluginAsync } from 'fastify';
import { desc, sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, stations, timetableTrips } from '../db/schema.js';
import { DATASETS, FINLAND_DATASET, callsThisMonth } from '../import/downloads.js';

/** What's imported and how much download quota is left (for the About page / debugging). */
export const importStatusRoutes =
  (db: Db): FastifyPluginAsync =>
  async (app) => {
    app.get('/import/status', async () => {
      const count = (t: typeof stations | typeof timetableTrips) => db.select({ n: sql<number>`count(*)` }).from(t).get()?.n ?? 0;
      return {
        stations: count(stations),
        trips: count(timetableTrips),
        quota: [...Object.values(DATASETS), FINLAND_DATASET].map((d) => ({ source: d.source, usedThisMonth: callsThisMonth(db, d.source), monthlyQuota: d.monthlyQuota })),
        recent: db.select().from(importLog).orderBy(desc(importLog.id)).limit(10).all(),
      };
    });
  };
