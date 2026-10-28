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
import { privacyRoutes } from './routes/privacy.js';
import { shareRoutes, sharePageRoutes } from './routes/share.js';
import { liveRoutes } from './routes/live.js';
import { pushRoutes } from './routes/push.js';
import { exportRoutes } from './routes/export.js';
import { passportRoutes } from './routes/passport.js';
import { usageRoutes } from './routes/usage.js';
import { walkLogRoutes } from './routes/walklogs.js';
import { boardRoutes } from './routes/boards.js';
import { BoardHub, type BoardHubOptions } from './boards/hub.js';
import { liveMapRoutes } from './routes/livemap.js';
import { LiveMapIngest, type IngestOptions } from './livemap/ingest.js';
import { trackedLegIds } from './live/tracker.js';
import { legs, liveState, users } from './db/schema.js';
import { ringStillOn } from './livemap/mine.js';
import { eq, inArray } from 'drizzle-orm';
import { railGraph } from './geo/railGraph.js';
import { rateLimitPlugin } from './plugins/rateLimit.js';
import { adminAuthPlugin } from './plugins/adminAuth.js';
import { countryOfKey } from './lib/countries.js';

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
const OPEN_WITHOUT_USER = /^\/api\/(health$|map\/|shared\/[A-Za-z0-9_-]+$|operators\/[a-z0-9-]+\/logo$)/;


export function buildApp(db: Db, opts: { logger?: boolean; afterLegCreated?: (legId: string) => void; boards?: BoardHubOptions; liveMap?: IngestOptions } = {}) {
  // Behind Caddy every request comes from 127.0.0.1; trust X-Forwarded-For so req.ip (the rate limit's key for
  // requests without a phone id) is the real client. Safe while the server listens on 127.0.0.1 only; CLACK_TRUST_PROXY=0 turns it off.
  const app = Fastify({ logger: opts.logger ?? false, trustProxy: !/^(0|false|no|off)$/i.test(process.env.CLACK_TRUST_PROXY ?? '') });
  app.register(rateLimitPlugin);
  app.register(adminAuthPlugin);
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
  app.register(privacyRoutes);
  app.register(sharePageRoutes);
  app.register(shareRoutes(db), api);
  app.register(liveRoutes(db), api);
  app.register(pushRoutes(db), api);
  app.register(exportRoutes(db), api);
  app.register(passportRoutes(db), api);
  app.register(usageRoutes(db), api);
  app.register(walkLogRoutes, api);
  const hub = new BoardHub(db, { log: (m) => app.log.warn(m), ...opts.boards });
  app.addHook('onClose', async () => hub.close());
  app.register(boardRoutes(db, hub), api);
  const ingest = new LiveMapIngest(db, {
    log: (m) => app.log.warn(m),
    simulate: Number(process.env.LIVE_MAP_SIMULATE ?? 0) || undefined,
    includeEstimated: !/^(0|false|no|off)$/i.test(process.env.LIVE_MAP_INCLUDE_ESTIMATED ?? ''),
    graph: railGraph,
    norway: !/^(0|false|no|off)$/i.test(process.env.LIVE_MAP_NORWAY ?? ''),
    finland: !/^(0|false|no|off)$/i.test(process.env.LIVE_MAP_FINLAND ?? ''),
    denmark: !/^(0|false|no|off)$/i.test(process.env.LIVE_MAP_DENMARK ?? ''),
    simulateTracks: () => (railGraph()?.edges ?? []).filter((e) => e.length > 8000).map((e) => Array.from({ length: e.pts.length / 2 }, (_, i) => [e.pts[2 * i]!, e.pts[2 * i + 1]!] as [number, number])),
    ...opts.liveMap,
  });
  app.addHook('onClose', async () => ingest.stop());
  // Your own trains are drawn on top (ADDITIONS_01 A): legs inside their live-tracking window, as "number|date" for
  // Trafikverket's trains (Swedish legs only) and "trip:key|date" for Norway's and Finland's (isMine in livemap/ingest.ts).
  const myTrainKeys = (userId: string) => {
    const ids = trackedLegIds(db, Date.now(), userId);
    if (!ids.length) return new Set<string>();
    const rows = db
      .select({
        n: legs.trainNumber, trv: legs.trvTrainNumbers, date: legs.serviceDate, key: legs.timetableTripKey, countries: legs.countryCodes,
        actualArr: legs.actualArr, schedArr: legs.schedArr, arrDelayMin: legs.arrDelayMin, arrivalEta: liveState.arrivalEta,
      })
      .from(legs)
      .leftJoin(liveState, eq(liveState.legId, legs.id))
      .where(inArray(legs.id, ids))
      .all();
    // The ring is for a train you are on or about to board; the tracker keeps a leg half an hour after it ends.
    const now = Date.now();
    return new Set(
      rows.filter((r) => ringStillOn(r, now)).flatMap((r) => [
        // Not for a Finnish train that reaches Haparanda: Trafikverket doesn't report it, and a Swedish train can share its number.
        ...(r.countries.includes('SE') && !(r.key && countryOfKey(r.key) === 'FI') ? [...(r.n ? [r.n] : []), ...r.trv].map((n) => `${n}|${r.date}`) : []),
        ...(r.key ? [`trip:${r.key}|${r.date}`] : []),
        // A Finnish train whose trip the timetable doesn't have (an extra train) is found by its number (isMine).
        ...(r.countries.includes('FI') && r.n ? [`fi:${r.n}|${r.date}`] : []),
        ...(r.countries.includes('DK') && r.n ? [`dk:${r.n}|${r.date}`] : []),
      ]),
    );
  };
  app.register(liveMapRoutes(db, ingest, myTrainKeys), api);
  return app;
}
