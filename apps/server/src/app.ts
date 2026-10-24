// Builds the Fastify app. Kept separate from index.ts so tests can use app.inject().
import Fastify from 'fastify';
import { DEFAULT_SETTINGS } from '@clack/shared';
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
import { pushRoutes } from './routes/push.js';
import { passportRoutes } from './routes/passport.js';
import { boardRoutes } from './routes/boards.js';
import { BoardHub, type BoardHubOptions } from './boards/hub.js';
import { liveMapRoutes } from './routes/livemap.js';
import { LiveMapIngest, type IngestOptions } from './livemap/ingest.js';
import { trackedLegIds } from './live/tracker.js';
import { legs, users } from './db/schema.js';
import { eq, inArray } from 'drizzle-orm';
import { railGraph } from './geo/railGraph.js';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
}

/** A device's id: a random UUID (v4 from crypto.randomUUID on the phone). */
const USER_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
/**
 * On a server phones share, a request without a phone id must not fall back to the local user (whose trips are the
 * laptop owner's): CLACK_REQUIRE_USER=1 refuses it. Shared, user-free data stays open: health, the map files (MapLibre
 * fetches them itself) and operator logos.
 */
const requireUser = /^(1|true|yes|on)$/i.test(process.env.CLACK_REQUIRE_USER ?? '');
const OPEN_WITHOUT_USER = /^\/api\/(health$|map\/|operators\/[a-z0-9-]+\/logo$)/;


export function buildApp(db: Db, opts: { logger?: boolean; afterLegCreated?: (legId: string) => void; boards?: BoardHubOptions; liveMap?: IngestOptions } = {}) {
  const app = Fastify({ logger: opts.logger ?? false });
  app.decorateRequest('userId', '');
  // Who's asking. No sign-in (App Review 5.1.1(v): no login unless the app needs one): the iOS app makes a random id on
  // first launch and sends it with every request (header, or ?u= where a header can't be set, as on EventSource). The
  // id is the key to that phone's trips, so it's a long random UUID. Without one (the laptop demo) it's the local user.
  const known = new Set<string>([LOCAL_USER_ID]);
  app.addHook('onRequest', async (req, reply) => {
    const raw = (req.headers['x-clack-user'] as string | undefined) ?? (req.query as { u?: string } | undefined)?.u;
    const valid = !!raw && USER_ID.test(raw);
    if (!valid && requireUser && req.url.startsWith('/api/') && !OPEN_WITHOUT_USER.test(req.url.split('?')[0]!)) {
      return reply.code(401).send({ error: 'missing or invalid X-Clack-User' });
    }
    const id = valid ? raw.toLowerCase() : LOCAL_USER_ID;
    if (!known.has(id)) {
      db.insert(users).values({ id, settings: DEFAULT_SETTINGS }).onConflictDoNothing().run();
      known.add(id);
    }
    req.userId = id;
  });
  app.addHook('onClose', async () => known.clear());
  // Everything a user has (trips, journeys, follows, settings) goes with the user row (ON DELETE CASCADE).
  app.delete('/api/me', { logLevel: 'warn' }, async (req, reply) => {
    db.delete(users).where(eq(users.id, req.userId)).run();
    known.delete(req.userId);
    if (req.userId === LOCAL_USER_ID) {
      db.insert(users).values({ id: LOCAL_USER_ID, settings: DEFAULT_SETTINGS }).onConflictDoNothing().run();
      known.add(LOCAL_USER_ID);
    }
    return reply.code(204).send();
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
  app.register(liveRoutes(db), api);
  app.register(pushRoutes(db), api);
  app.register(passportRoutes(db), api);
  const hub = new BoardHub(db, { log: (m) => app.log.warn(m), ...opts.boards });
  app.addHook('onClose', async () => hub.close());
  app.register(boardRoutes(db, hub), api);
  const ingest = new LiveMapIngest(db, {
    log: (m) => app.log.warn(m),
    simulate: Number(process.env.LIVE_MAP_SIMULATE ?? 0) || undefined,
    includeEstimated: !/^(0|false|no|off)$/i.test(process.env.LIVE_MAP_INCLUDE_ESTIMATED ?? ''),
    graph: railGraph,
    norway: !/^(0|false|no|off)$/i.test(process.env.LIVE_MAP_NORWAY ?? ''),
    simulateTracks: () => (railGraph()?.edges ?? []).filter((e) => e.length > 8000).map((e) => Array.from({ length: e.pts.length / 2 }, (_, i) => [e.pts[2 * i]!, e.pts[2 * i + 1]!] as [number, number])),
    ...opts.liveMap,
  });
  app.addHook('onClose', async () => ingest.stop());
  // Your own trains are drawn on top (ADDITIONS_01 A): legs inside their live-tracking window, as "number|date" for
  // Trafikverket's trains (Swedish legs only) and "trip:key|date" for Norway's (isMine in livemap/ingest.ts).
  const myTrainKeys = (userId: string) => {
    const ids = trackedLegIds(db, Date.now(), userId);
    if (!ids.length) return new Set<string>();
    const rows = db
      .select({ n: legs.trainNumber, trv: legs.trvTrainNumbers, date: legs.serviceDate, key: legs.timetableTripKey, countries: legs.countryCodes })
      .from(legs)
      .where(inArray(legs.id, ids))
      .all();
    return new Set(
      rows.flatMap((r) => [
        ...(r.countries.includes('SE') ? [...(r.n ? [r.n] : []), ...r.trv].map((n) => `${n}|${r.date}`) : []),
        ...(r.key ? [`trip:${r.key}|${r.date}`] : []),
      ]),
    );
  };
  app.register(liveMapRoutes(db, ingest, myTrainKeys), api);
  return app;
}
