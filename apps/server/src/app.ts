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
import { boardRoutes } from './routes/boards.js';
import { BoardHub, type BoardHubOptions } from './boards/hub.js';
import { liveMapRoutes } from './routes/livemap.js';
import { LiveMapIngest, type IngestOptions } from './livemap/ingest.js';
import { trackedLegIds } from './live/tracker.js';
import { legs } from './db/schema.js';
import { inArray } from 'drizzle-orm';
import { railGraph } from './geo/railGraph.js';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
}

export function buildApp(db: Db, opts: { logger?: boolean; afterLegCreated?: (legId: string) => void; boards?: BoardHubOptions; liveMap?: IngestOptions } = {}) {
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
  const hub = new BoardHub(db, { log: (m) => app.log.warn(m), ...opts.boards });
  app.addHook('onClose', async () => hub.close());
  app.register(boardRoutes(db, hub), api);
  const ingest = new LiveMapIngest(db, {
    log: (m) => app.log.warn(m),
    // Your own trains are drawn on top (ADDITIONS_01 A): numbers of legs inside their live-tracking window.
    myNumbers: () => {
      const ids = trackedLegIds(db, Date.now());
      if (!ids.length) return new Set();
      const rows = db.select({ n: legs.trainNumber, trv: legs.trvTrainNumbers }).from(legs).where(inArray(legs.id, ids)).all();
      return new Set(rows.flatMap((r) => [...(r.n ? [r.n] : []), ...r.trv]));
    },
    simulate: Number(process.env.LIVE_MAP_SIMULATE ?? 0) || undefined,
    includeEstimated: !/^(0|false|no|off)$/i.test(process.env.LIVE_MAP_INCLUDE_ESTIMATED ?? ''),
    graph: railGraph,
    simulateTracks: () => (railGraph()?.edges ?? []).filter((e) => e.length > 8000).map((e) => Array.from({ length: e.pts.length / 2 }, (_, i) => [e.pts[2 * i]!, e.pts[2 * i + 1]!] as [number, number])),
    ...opts.liveMap,
  });
  app.addHook('onClose', async () => ingest.stop());
  app.register(liveMapRoutes(db, ingest), api);
  return app;
}
