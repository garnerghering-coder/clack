import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import Fastify from 'fastify';
import { afterAll, describe, expect, it, vi } from 'vitest';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-walks-'));
vi.stubEnv('WALKLOG_DIR', dir);
vi.stubEnv('WALKLOG_USERS', 'aaaaaaaa-1111-4111-8111-111111111111');
const { walkLogRoutes } = await import('../src/routes/walklogs.js');

async function server() {
  const app = Fastify();
  app.decorateRequest('userId', '');
  app.addHook('onRequest', async (req) => {
    req.userId = (req.headers['x-clack-user'] as string | undefined) ?? '';
  });
  await app.register(walkLogRoutes, { prefix: '/api' });
  return app;
}

afterAll(() => fs.rmSync(dir, { recursive: true, force: true }));

describe('station walk uploads', () => {
  const owner = { 'x-clack-user': 'aaaaaaaa-1111-4111-8111-111111111111', 'content-type': 'application/octet-stream' };
  const walk = zlib.deflateRawSync(Buffer.from(JSON.stringify({ id: 'walk-0001', title: 'Jönköping C' })));

  it('keeps the latest upload of a walk, as sent, and lets the owner read it back', async () => {
    const app = await server();
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0001', headers: owner, payload: walk })).statusCode).toBe(204);
    const list = (await app.inject({ url: '/api/walklogs', headers: owner })).json();
    expect(list.map((w: { id: string }) => w.id)).toEqual(['walk-0001']);
    const back = await app.inject({ url: '/api/walklogs/walk-0001', headers: owner });
    expect(JSON.parse(zlib.inflateRawSync(back.rawPayload).toString()).title).toBe('Jönköping C');
  });

  it('is invisible to anyone not listed, and refuses bad ids', async () => {
    const app = await server();
    const stranger = { ...owner, 'x-clack-user': 'bbbbbbbb-2222-4222-8222-222222222222' };
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0002', headers: stranger, payload: walk })).statusCode).toBe(404);
    expect((await app.inject({ url: '/api/walklogs', headers: stranger })).statusCode).toBe(404);
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/..%2Fescape', headers: owner, payload: walk })).statusCode).toBe(400);
  });
});
