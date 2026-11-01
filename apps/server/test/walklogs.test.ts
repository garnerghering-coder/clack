import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import Fastify from 'fastify';
import { afterAll, describe, expect, it, vi } from 'vitest';

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clack-walks-'));
vi.stubEnv('WALKLOG_DIR', dir);
vi.stubEnv('WALKLOG_USERS', 'aaaaaaaa-1111-4111-8111-111111111111');
const { walkLogRoutes, deleteWalksOf } = await import('../src/routes/walklogs.js');

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

  it('takes walks from any phone, which only the listed users can read, and never lets one phone replace another\'s', async () => {
    const app = await server();
    const borrowed = { ...owner, 'x-clack-user': 'bbbbbbbb-2222-4222-8222-222222222222' };
    const other = { ...owner, 'x-clack-user': 'cccccccc-3333-4333-8333-333333333333' };
    // A borrowed phone uploads (and re-uploads after an edit) its own walk.
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0002', headers: borrowed, payload: walk })).statusCode).toBe(204);
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0002', headers: borrowed, payload: walk })).statusCode).toBe(204);
    // Another phone can't overwrite it, nor the owner's walk from before owners were kept.
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0002', headers: other, payload: walk })).statusCode).toBe(409);
    fs.rmSync(path.join(dir, 'walk-0001.owner'), { force: true });
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0001', headers: other, payload: walk })).statusCode).toBe(409);
    // Only the listed users see walks; the owner sees the borrowed phone's.
    expect((await app.inject({ url: '/api/walklogs', headers: borrowed })).statusCode).toBe(404);
    expect((await app.inject({ url: '/api/walklogs/walk-0002', headers: borrowed })).statusCode).toBe(404);
    expect((await app.inject({ url: '/api/walklogs', headers: owner })).json().map((w: { id: string }) => w.id).sort()).toEqual(['walk-0001', 'walk-0002']);
    // Without a phone id, nothing.
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0003', headers: { 'content-type': 'application/octet-stream' }, payload: walk })).statusCode).toBe(404);
  });

  it('refuses bad ids', async () => {
    const app = await server();
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/..%2Fescape', headers: owner, payload: walk })).statusCode).toBe(400);
  });

  it("deletes a phone's walks with its data, and nobody else's", async () => {
    const app = await server();
    const a = { ...owner, 'x-clack-user': 'dddddddd-4444-4444-8444-444444444444' };
    expect((await app.inject({ method: 'PUT', url: '/api/walklogs/walk-0100', headers: a, payload: walk })).statusCode).toBe(204);
    expect(deleteWalksOf('dddddddd-4444-4444-8444-444444444444')).toBe(1);
    expect(fs.existsSync(path.join(dir, 'walk-0100.walk'))).toBe(false);
    expect(fs.existsSync(path.join(dir, 'walk-0002.walk'))).toBe(true);
  });
});
