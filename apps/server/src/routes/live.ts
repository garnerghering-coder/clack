// Server-Sent Events for live tracking (DESIGN §9.2): the browser never talks to Trafikverket, it listens here.
import type { FastifyPluginAsync } from 'fastify';
import { and, eq } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legs } from '../db/schema.js';
import { liveBus, type LiveUpdate } from '../live/tracker.js';

const HEARTBEAT_MS = 20_000;

export const liveRoutes = (db: Db): FastifyPluginAsync => async (app) => {
  app.get('/live/stream', (req, reply) => {
    reply.hijack();
    const res = reply.raw;
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
    res.write('retry: 5000\n\n');
    // The tracker follows every user's trains; each listener hears only about its own.
    const owns = (legId: string) => !!db.select({ id: legs.id }).from(legs).where(and(eq(legs.id, legId), eq(legs.userId, req.userId))).get();
    const send = (u: LiveUpdate) => {
      if (owns(u.legId)) res.write(`event: live\ndata: ${JSON.stringify(u)}\n\n`);
    };
    const beat = setInterval(() => res.write(': ping\n\n'), HEARTBEAT_MS);
    liveBus.on('update', send);
    req.raw.on('close', () => {
      clearInterval(beat);
      liveBus.off('update', send);
    });
  });
};
