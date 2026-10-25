// Sharing a journey by link: the traveller's routes, the follower's routes, the public copy and the web page.
// `/j/<token>` is what a shared link points at: the app opens it (universal link), a browser gets the page.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { and, eq } from 'drizzle-orm';
import { appKeys, appString, type StringsLang } from '@clack/shared';
import type { FastifyPluginAsync, FastifyReply } from 'fastify';
import type { Db } from '../db/client.js';
import { legs } from '../db/schema.js';
import { getJourney } from '../legs/legs.js';
import { REPO_ROOT } from '../env.js';
import { createShare, findShare, follow, following, publicJourney, revokeShare, unfollow } from '../share/shared.js';

const PUBLIC_DIR = path.join(REPO_ROOT, 'apps/server/public/share');
const TOKEN = /^[A-Za-z0-9_-]{16,64}$/;
/** The app's identity for universal links: team id + bundle id (docs/IOS.md). */
const APP_ID = 'HJTCN7QR8M.com.garnerghering.Clack';
const TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
};

/** English or Swedish: `?lang=` first, else the browser's first language. */
function pageLanguage(req: { query: unknown; headers: Record<string, string | string[] | undefined> }): StringsLang {
  const asked = (req.query as { lang?: string } | undefined)?.lang;
  if (asked === 'sv' || asked === 'en') return asked;
  return /^\s*sv\b/i.test(String(req.headers['accept-language'] ?? '')) ? 'sv' : 'en';
}

/** Where a link to a journey points: this server's own address, as the phone reached it. */
const baseUrl = (req: { headers: Record<string, string | string[] | undefined>; protocol: string }) => {
  const forced = process.env.CLACK_PUBLIC_URL;
  if (forced) return forced.replace(/\/+$/, '');
  const host = String(req.headers['x-forwarded-host'] ?? req.headers.host ?? 'localhost');
  return `${req.protocol}://${host}`;
};

export const shareRoutes = (db: Db): FastifyPluginAsync => async (app) => {
  // ---------- the traveller ----------
  app.post<{ Body: { journeyId?: string; legId?: string } }>('/share/journey', async (req, reply) => {
    const { journeyId, legId } = req.body ?? {};
    if (!journeyId && !legId) return reply.code(400).send({ error: 'journeyId or legId is required' });
    const share = createShare(db, req.userId, { journeyId, legId }, Date.now());
    if (!share) return reply.code(404).send({ error: 'not found' });
    return { token: share.token, url: `${baseUrl(req)}/j/${share.token}`, expiresAt: share.expiresAt.getTime() };
  });
  /** Whether this journey (or leg's journey) is shared now. */
  app.get<{ Querystring: { journeyId?: string; legId?: string } }>('/share', async (req) => {
    const { journeyId, legId } = req.query;
    const created = journeyId || legId ? findShareFor(db, req.userId, { journeyId, legId }) : null;
    return created ? { token: created.token, url: `${baseUrl(req)}/j/${created.token}`, expiresAt: created.expiresAt.getTime() } : { token: null };
  });
  app.delete<{ Params: { token: string } }>('/share/:token', async (req, reply) => {
    if (!revokeShare(db, req.userId, req.params.token, Date.now())) return reply.code(404).send({ error: 'not found' });
    return reply.code(204).send();
  });

  // ---------- the follower ----------
  app.put<{ Params: { token: string } }>('/following/:token', async (req, reply) => {
    if (!TOKEN.test(req.params.token) || !follow(db, req.userId, req.params.token, Date.now())) return reply.code(404).send({ error: 'this link no longer works' });
    return { following: true };
  });
  app.delete<{ Params: { token: string } }>('/following/:token', async (req, reply) => {
    unfollow(db, req.userId, req.params.token);
    return reply.code(204).send();
  });
  app.get('/following', async (req) => following(db, req.userId, Date.now()));

  // ---------- anyone with the link ----------
  app.get<{ Params: { token: string } }>('/shared/:token', async (req, reply) => {
    const journey = TOKEN.test(req.params.token) ? publicJourney(db, req.params.token, Date.now()) : null;
    if (!journey) return reply.code(404).send({ error: 'this link no longer works' });
    return reply.header('Cache-Control', 'no-store').header('X-Robots-Tag', 'noindex').send(journey);
  });
};

/** The page itself and its files, outside `/api` (a link is a page, not a call). */
export const sharePageRoutes: FastifyPluginAsync = async (app) => {
  const file = (reply: FastifyReply, name: string, extra: Record<string, string> = {}) => {
    const full = path.join(PUBLIC_DIR, name);
    if (!full.startsWith(PUBLIC_DIR + path.sep) || !fs.existsSync(full)) return reply.code(404).send({ error: 'not found' });
    reply.header('Content-Type', TYPES[path.extname(full)] ?? 'application/octet-stream');
    for (const [k, v] of Object.entries(extra)) reply.header(k, v);
    return reply.send(fs.readFileSync(full));
  };
  const page = async (req: { query: unknown; headers: Record<string, string | string[] | undefined> }, reply: FastifyReply) => {
    const lang = pageLanguage(req);
    const strings: Record<string, string> = {};
    for (const key of [...appKeys('share.'), 'live.livePosition', 'live.estimatedPosition', 'journey.tight', 'journey.missed', 'trips.platform', 'connection.tracks']) {
      strings[key] = appString(key, lang) ?? key;
    }
    // The download address is a server setting; without one the page still shows the button, as a dead end.
    const config = { lang, strings, downloadUrl: process.env.CLACK_APP_DOWNLOAD_URL || null };
    // The page's own files carry their age in the address, so a changed file is never read from an old copy.
    const age = (name: string) => Math.floor(fs.statSync(path.join(PUBLIC_DIR, name)).mtimeMs);
    const html = fs
      .readFileSync(path.join(PUBLIC_DIR, 'index.html'), 'utf8')
      .replace('/*CLACK_SHARE*/null', () => JSON.stringify(config).replace(/</g, '\\u003c'))
      .replace('/share-assets/share.js', `/share-assets/share.js?v=${age('share.js')}`)
      .replace('/share-assets/share.css', `/share-assets/share.css?v=${age('share.css')}`);
    return reply
      .header('Content-Type', TYPES['.html']!)
      .header('Cache-Control', 'no-store')
      .header('X-Robots-Tag', 'noindex')
      .send(html);
  };
  app.get('/j/:token', page);
  app.get('/j/:token/', page);
  // The map library comes from the installed package, not from anywhere on the internet.
  const library: Record<string, string> = { 'maplibre-gl.js': 'maplibre-gl/dist/maplibre-gl.js', 'maplibre-gl.css': 'maplibre-gl/dist/maplibre-gl.css' };
  const require = createRequire(import.meta.url);
  app.get<{ Params: { name: string } }>('/share-assets/:name', async (req, reply) => {
    const lib = library[req.params.name];
    if (lib) {
      return reply.header('Content-Type', TYPES[path.extname(lib)]!).header('Cache-Control', 'public, max-age=86400').send(fs.readFileSync(require.resolve(lib)));
    }
    // A file name only: no folders, no dots at the start.
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(req.params.name)) return reply.code(404).send({ error: 'not found' });
    // The page's own files are revalidated each time (they change with the server); the big ones are kept for a day.
    return file(reply, req.params.name, { 'Cache-Control': /\.(ttf|woff2)$/.test(req.params.name) ? 'public, max-age=86400' : 'no-cache' });
  });
  // Apple reads this to learn that links to /j/… open the app (no file extension, served as JSON).
  const association = async (_req: unknown, reply: FastifyReply) =>
    reply.header('Content-Type', 'application/json').header('Cache-Control', 'max-age=300').send({
      applinks: { details: [{ appIDs: [APP_ID], components: [{ '/': '/j/*', comment: 'A shared journey' }] }] },
    });
  app.get('/.well-known/apple-app-site-association', association);
  app.get('/apple-app-site-association', association);
};

/** The live share of a journey (or a leg's journey) for this user, without making one. */
function findShareFor(db: Db, userId: string, ref: { journeyId?: string; legId?: string }) {
  let journeyId = ref.journeyId;
  let ids: string[] = [];
  if (!journeyId && ref.legId) {
    const leg = db.select({ id: legs.id, journeyId: legs.journeyId }).from(legs).where(and(eq(legs.id, ref.legId), eq(legs.userId, userId))).get();
    if (!leg) return null;
    journeyId = leg.journeyId ?? undefined;
    ids = [leg.id];
  }
  if (journeyId) ids = (getJourney(db, userId, journeyId)?.legs ?? []).filter((l) => l.ride !== 'not_taken').map((l) => l.id);
  return ids.length ? findShare(db, userId, ids, Date.now()) : null;
}
