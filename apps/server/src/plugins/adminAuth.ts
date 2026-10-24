// Admin-only details. The hosted server is on the open internet, and these routes show how it is doing inside:
// import quotas and logs, the accuracy audit, live-feed internals, and (on /api/health) memory and upstream feed state.
// They need the header `X-Clack-Admin: <CLACK_ADMIN_TOKEN>`. The app never sends it.
//
// Without a token set on the server, or with a missing or wrong one, a protected route answers 404, exactly like a
// path that doesn't exist (reply.callNotFound). Not 403/401: that would tell a scanner the route is there, and with no
// token configured there is nothing to authenticate against, so "off" should look the same as "not built".
import { createHash, timingSafeEqual } from 'node:crypto';
import type { FastifyInstance, FastifyRequest } from 'fastify';

declare module 'fastify' {
  interface FastifyRequest {
    /** True when the request carried the right X-Clack-Admin token. */
    isAdmin: boolean;
  }
}

const PROTECTED = /^\/api\/(import\/status|audit|live\/status)$/;

/** Constant-time compare: both sides are hashed first, so length doesn't leak and timingSafeEqual gets equal sizes. */
export function tokenMatches(given: unknown, expected: string | undefined): boolean {
  if (!expected || typeof given !== 'string') return false;
  const a = createHash('sha256').update(given).digest();
  const b = createHash('sha256').update(expected).digest();
  return timingSafeEqual(a, b);
}

export async function adminAuthPlugin(app: FastifyInstance) {
  // Read per request, so the token can't go stale and tests can set it.
  app.decorateRequest('isAdmin', false);
  app.addHook('onRequest', async (req: FastifyRequest, reply) => {
    req.isAdmin = tokenMatches(req.headers['x-clack-admin'], process.env.CLACK_ADMIN_TOKEN);
    if (!req.isAdmin && PROTECTED.test(req.url.split('?')[0]!)) return reply.callNotFound();
  });
}
(adminAuthPlugin as unknown as Record<symbol, boolean>)[Symbol.for('skip-override')] = true;
