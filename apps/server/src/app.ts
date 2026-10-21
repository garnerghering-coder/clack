// Builds the Fastify app. Kept separate from index.ts so tests can use app.inject().
import Fastify from 'fastify';
import type { Db } from './db/client.js';
import { LOCAL_USER_ID } from './db/client.js';
import { healthRoutes } from './routes/health.js';
import { settingsRoutes } from './routes/settings.js';
import { stationRoutes } from './routes/stations.js';
import { importStatusRoutes } from './routes/importStatus.js';
import { searchRoutes } from './routes/search.js';
import { legRoutes } from './routes/legs.js';
import { mapRoutes } from './routes/map.js';
import { liveRoutes } from './routes/live.js';
import { passportRoutes } from './routes/passport.js';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
}

export function buildApp(db: Db, opts: { logger?: boolean; afterLegCreated?: (legId: string) => void } = {}) {
  const app = Fastify({ logger: opts.logger ?? false });
  app.decorateRequest('userId', '');
  // No accounts in Phase 1: every request acts as the seeded local user.
  app.addHook('onRequest', async (req) => {
    req.userId = LOCAL_USER_ID;
  });
  // Per-request logs are noise for a local demo: API routes log at warn, so only problems show.
  // Startup and import messages still log at info.
  const api = { prefix: '/api', logLevel: 'warn' } as const;
  app.register(healthRoutes(db), api);
  app.register(settingsRoutes(db), api);
  app.register(stationRoutes(db), api);
  app.register(importStatusRoutes(db), api);
  app.register(searchRoutes(db), api);
  app.register(legRoutes(db, { afterCreate: opts.afterLegCreated }), api);
  app.register(mapRoutes(db), api);
  app.register(liveRoutes(), api);
  app.register(passportRoutes(db), api);
  return app;
}
