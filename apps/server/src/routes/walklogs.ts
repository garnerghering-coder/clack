// Station walks recorded with the app's test tool (owner only): uploaded as the phone saved them (a WalkLog as JSON,
// compressed with raw DEFLATE) and kept as files under data/walklogs/, one per walk, the latest version only. They are
// precise location tracks, so only the user ids listed in WALKLOG_USERS may upload or read them; everyone else gets 404.
// Read them with `zlib.inflateRawSync`. The daily backup includes data/.
import fs from 'node:fs';
import path from 'node:path';
import type { FastifyPluginAsync } from 'fastify';
import { REPO_ROOT } from '../env.js';

export const WALKLOG_DIR = process.env.WALKLOG_DIR ?? path.join(REPO_ROOT, 'data/walklogs');
const MAX_BYTES = 50 * 1024 * 1024;
const ID = /^[A-Za-z0-9-]{8,64}$/;

const allowed = (userId: string | undefined) =>
  !!userId && (process.env.WALKLOG_USERS ?? '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean).includes(userId.toLowerCase());

export const walkLogRoutes: FastifyPluginAsync = async (app) => {
  app.addContentTypeParser('application/octet-stream', { parseAs: 'buffer', bodyLimit: MAX_BYTES }, (_req, body, done) => done(null, body));

  app.put<{ Params: { id: string } }>('/walklogs/:id', { bodyLimit: MAX_BYTES }, async (req, reply) => {
    if (!allowed(req.userId)) return reply.code(404).send({ error: 'not found' });
    if (!ID.test(req.params.id)) return reply.code(400).send({ error: 'bad id' });
    const body = req.body;
    if (!Buffer.isBuffer(body) || body.length === 0) return reply.code(400).send({ error: 'empty' });
    fs.mkdirSync(WALKLOG_DIR, { recursive: true });
    const file = path.join(WALKLOG_DIR, `${req.params.id}.walk`);
    fs.writeFileSync(`${file}.tmp`, body);
    fs.renameSync(`${file}.tmp`, file);
    return reply.code(204).send();
  });

  app.get('/walklogs', async (req, reply) => {
    if (!allowed(req.userId)) return reply.code(404).send({ error: 'not found' });
    const files = fs.existsSync(WALKLOG_DIR) ? fs.readdirSync(WALKLOG_DIR).filter((f) => f.endsWith('.walk')) : [];
    return files.map((f) => {
      const st = fs.statSync(path.join(WALKLOG_DIR, f));
      return { id: f.replace(/\.walk$/, ''), bytes: st.size, updatedAt: st.mtimeMs };
    });
  });

  app.get<{ Params: { id: string } }>('/walklogs/:id', async (req, reply) => {
    if (!allowed(req.userId) || !ID.test(req.params.id)) return reply.code(404).send({ error: 'not found' });
    const file = path.join(WALKLOG_DIR, `${req.params.id}.walk`);
    if (!fs.existsSync(file)) return reply.code(404).send({ error: 'not found' });
    return reply.type('application/octet-stream').send(fs.readFileSync(file));
  });
};
