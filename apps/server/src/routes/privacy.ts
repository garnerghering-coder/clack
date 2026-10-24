// The privacy page App Review and the app's Settings link to: plain HTML in apps/server/public/privacy (English) and
// apps/server/public/privacy/sv (Swedish), with the same words as the privacy.* strings in packages/shared/locales.
import fs from 'node:fs';
import path from 'node:path';
import type { FastifyPluginAsync } from 'fastify';
import { REPO_ROOT } from '../env.js';

const PUBLIC_DIR = path.join(REPO_ROOT, 'apps/server/public/privacy');

export const privacyRoutes: FastifyPluginAsync = async (app) => {
  const page = (file: string) => async (_req: unknown, reply: import('fastify').FastifyReply) =>
    reply.header('Content-Type', 'text/html; charset=utf-8').header('Cache-Control', 'max-age=300').send(fs.readFileSync(file));
  for (const [url, file] of [['/privacy', 'index.html'], ['/privacy/sv', 'sv/index.html']] as const) {
    app.get(url, page(path.join(PUBLIC_DIR, file)));
    app.get(`${url}/`, page(path.join(PUBLIC_DIR, file)));
  }
};
