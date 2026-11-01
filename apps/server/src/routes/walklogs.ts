// Station walks recorded with the app's test tool: uploaded as the phone saved them (a WalkLog as JSON, compressed with
// raw DEFLATE) and kept as files under data/walklogs/, one per walk, the latest version only. Any phone may upload
// (owner, 2026-11-01: so a walk on a borrowed phone, e.g. one with LiDAR, reaches the server); a walk can be replaced
// only by the phone that first sent it (`<id>.owner` beside it), and each phone keeps at most MAX_PER_USER. They are
// precise location tracks, so only the user ids listed in WALKLOG_USERS may list or read them; everyone else gets 404.
// Read them with `zlib.inflateRawSync`. The daily backup includes data/.
import fs from 'node:fs';
import path from 'node:path';
import type { FastifyPluginAsync } from 'fastify';
import { REPO_ROOT } from '../env.js';
import { LOCAL_USER_ID } from '../db/client.js';

export const WALKLOG_DIR = process.env.WALKLOG_DIR ?? path.join(REPO_ROOT, 'data/walklogs');
const MAX_BYTES = 50 * 1024 * 1024;
const ID = /^[A-Za-z0-9-]{8,64}$/;
export const MAX_PER_USER = 100;

const allowed = (userId: string | undefined) =>
  !!userId && (process.env.WALKLOG_USERS ?? '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean).includes(userId.toLowerCase());

export const walkLogRoutes: FastifyPluginAsync = async (app) => {
  app.addContentTypeParser('application/octet-stream', { parseAs: 'buffer', bodyLimit: MAX_BYTES }, (_req, body, done) => done(null, body));

  app.put<{ Params: { id: string } }>('/walklogs/:id', { bodyLimit: MAX_BYTES }, async (req, reply) => {
    const user = (req.userId ?? '').toLowerCase();
    if (!user || user === LOCAL_USER_ID) return reply.code(404).send({ error: 'not found' });
    if (!ID.test(req.params.id)) return reply.code(400).send({ error: 'bad id' });
    const body = req.body;
    if (!Buffer.isBuffer(body) || body.length === 0) return reply.code(400).send({ error: 'empty' });
    fs.mkdirSync(WALKLOG_DIR, { recursive: true });
    const file = path.join(WALKLOG_DIR, `${req.params.id}.walk`);
    const ownerFile = `${file.slice(0, -5)}.owner`;
    const owner = fs.existsSync(ownerFile) ? fs.readFileSync(ownerFile, 'utf8').trim() : null;
    // Someone else's walk (or one from before owners were kept, which only the listed users made) isn't replaced.
    if (owner ? owner !== user : fs.existsSync(file) && !allowed(user)) return reply.code(409).send({ error: 'walk belongs to another phone' });
    if (!owner) {
      const mine = fs.readdirSync(WALKLOG_DIR).filter((f) => f.endsWith('.owner') && fs.readFileSync(path.join(WALKLOG_DIR, f), 'utf8').trim() === user).length;
      if (mine >= MAX_PER_USER && !allowed(user)) return reply.code(429).send({ error: 'too many walks from this phone' });
      fs.writeFileSync(ownerFile, user);
    }
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

/** Delete my data: every walk this phone uploaded (its `<id>.owner` names it), with the owner file. */
export function deleteWalksOf(userId: string) {
  const user = userId.toLowerCase();
  if (!fs.existsSync(WALKLOG_DIR)) return 0;
  let n = 0;
  for (const f of fs.readdirSync(WALKLOG_DIR).filter((x) => x.endsWith('.owner'))) {
    const owner = path.join(WALKLOG_DIR, f);
    if (fs.readFileSync(owner, 'utf8').trim() !== user) continue;
    fs.rmSync(path.join(WALKLOG_DIR, f.replace(/\.owner$/, '.walk')), { force: true });
    fs.rmSync(owner, { force: true });
    n++;
  }
  return n;
}
