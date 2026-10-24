// Request limits (APP_STORE.md, guideline 1.6). Phone ids are anonymous and free to make, so the server needs a ceiling
// per id and per address before the app is public. Limits are per minute, kept in memory (one server process).
//
// How the Swift app really behaves (read from apps/Clack, 2026-10): everything that updates by itself either rides an
// SSE stream (live map, station boards, trip updates: exempt below, one request each) or polls slowly: the scheduled
// train and the stop list every 30 s, the risk card every 5 min, the arrival watcher every 30 s. That is about 5 to 10
// requests a minute while a screen is open. Bursts are what cost requests: opening a trip or the passport fires a few
// dozen GETs at once, and typing in the station or train search sends a request every ~150 ms (about 7 a second).
// So:
//   - an id gets 300 a minute (5 a second sustained, 30 times a busy screen's polling; a burst of 100 still passes);
//   - a request without a usable id (the laptop demo, a stray script) is counted per address, at 120 a minute;
//   - map tiles, glyphs and operator logos have their own, larger bucket (1500 a minute per id or address): one pan
//     or zoom loads dozens of tiles at once, and MapLibre fetches them itself, so they must not eat the trip budget;
//   - SSE streams and /api/health are not limited (a stream is one long request; health is the supervisor's check).
// The numbers can be changed without code: CLACK_RATE_LIMIT, CLACK_RATE_LIMIT_ANON and CLACK_RATE_LIMIT_MAP.
//
// Behind Caddy every request comes from 127.0.0.1, so the address is only meaningful with `trustProxy` on
// (app.ts: CLACK_TRUST_PROXY, on by default because the server listens on 127.0.0.1 and only Caddy can reach it).
import type { FastifyInstance, FastifyRequest } from 'fastify';
import rateLimit from '@fastify/rate-limit';

/** Same shape app.ts accepts as a phone id (a UUID v4). An unchecked header would let a client pick a new bucket per request. */
const USER_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const STREAM = /^\/api\/(live\/stream|live\/trains\/stream|stations\/[^/]+\/board\/stream)$/;
const UNLIMITED = /^\/api\/health$/;
const FILES = /^\/api\/(map\/|operators\/[a-z0-9-]+\/logo$)/;

const num = (name: string, fallback: number) => {
  const n = Number(process.env[name]);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : fallback;
};

const pathOf = (req: FastifyRequest) => req.url.split('?')[0]!;

/** Same lookup as app.ts: the header, or ?u= where a header can't be set. */
const idOf = (req: FastifyRequest) => {
  const raw = (req.headers['x-clack-user'] as string | undefined) ?? (req.query as { u?: string } | undefined)?.u;
  return raw && USER_ID.test(raw) ? raw.toLowerCase() : null;
};

export async function rateLimitPlugin(app: FastifyInstance) {
  const perUser = num('CLACK_RATE_LIMIT', 300);
  const perAddress = num('CLACK_RATE_LIMIT_ANON', 120);
  const perFiles = num('CLACK_RATE_LIMIT_MAP', 1500);
  await app.register(rateLimit, {
    global: true,
    timeWindow: '1 minute',
    cache: 10_000,
    // Key: "files:" for tiles and logos, then the id, else the address.
    keyGenerator: (req) => `${FILES.test(pathOf(req)) ? 'files' : 'api'}:${idOf(req) ?? `ip:${req.ip}`}`,
    max: (_req, key) => (String(key).startsWith('files:') ? perFiles : String(key).includes(':ip:') ? perAddress : perUser),
    allowList: (req) => STREAM.test(pathOf(req)) || UNLIMITED.test(pathOf(req)),
    // The same shape as the server's own errors: { error: string } (the code is the status, 429).
    errorResponseBuilder: (_req, ctx) => ({ statusCode: 429, error: `too many requests, try again in ${Math.max(1, Math.ceil(ctx.ttl / 1000))} seconds` }),
  });
}
// Not encapsulated: the limit has to cover the routes registered after it in app.ts.
(rateLimitPlugin as unknown as Record<symbol, boolean>)[Symbol.for('skip-override')] = true;
