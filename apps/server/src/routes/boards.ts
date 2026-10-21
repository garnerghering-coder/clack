// Station pages and live boards (ADDITIONS_01 B).
import type { FastifyPluginAsync } from 'fastify';
import { and, desc, eq, sql } from 'drizzle-orm';
import { SE_COUNTIES } from '@clack/shared';
import type { Db } from '../db/client.js';
import { stationFavorites, stationRecent, stations, trvLocations } from '../db/schema.js';
import { BoardHub } from '../boards/hub.js';
import type { BoardType } from '../boards/board.js';

const TYPES = new Set(['departures', 'arrivals']);
const MAX_SPAN_MS = 24 * 3600_000;

export const boardRoutes =
  (db: Db, hub: BoardHub): FastifyPluginAsync =>
  async (app) => {
    const stationInfo = (id: string, userId: string) => {
      const s = db
        .select({
          id: stations.id,
          name: stations.name,
          code: stations.trvSignature,
          country: stations.country,
          tz: stations.tz,
          lat: stations.lat,
          lon: stations.lon,
          countyNo: trvLocations.countyNo,
        })
        .from(stations)
        .leftJoin(trvLocations, sql`lower(${trvLocations.signature}) = lower(${stations.trvSignature})`)
        .where(eq(stations.id, id))
        .get();
      if (!s) return null;
      const favorite = Boolean(
        db
          .select()
          .from(stationFavorites)
          .where(and(eq(stationFavorites.userId, userId), eq(stationFavorites.stationId, id)))
          .get(),
      );
      return {
        ...s,
        county: s.countyNo ? (SE_COUNTIES[s.countyNo] ?? null) : null,
        hasBoard: Boolean(s.code && !s.code.includes('.')),
        hasMap: false,
        favorite,
      };
    };

    app.get<{ Params: { id: string } }>(
      '/stations/:id',
      async (req, reply) => stationInfo(req.params.id, req.userId) ?? reply.code(404).send({ error: 'not found' }),
    );

    app.get<{ Params: { id: string }; Querystring: { type?: string; from?: string; to?: string } }>('/stations/:id/board', async (req, reply) => {
      const type = (req.query.type ?? 'departures') as BoardType;
      if (!TYPES.has(type)) return reply.code(400).send({ error: 'type must be departures or arrivals' });
      if (!stationInfo(req.params.id, req.userId)?.hasBoard) return reply.code(404).send({ error: 'no board for this station' });
      // A custom window (e.g. "Show earlier") is a one-off fetch; the default is the shared live board.
      if (req.query.from || req.query.to) {
        const from = Number(req.query.from);
        const to = Number(req.query.to);
        if (!Number.isFinite(from) || !Number.isFinite(to) || to <= from || to - from > MAX_SPAN_MS)
          return reply.code(400).send({ error: 'from/to must be epoch ms, at most 24 h apart' });
        return hub.load(req.params.id, type, from, to);
      }
      return hub.current(req.params.id, type);
    });

    // Live updates while a board is open: the full board after every shared poll.
    app.get<{ Params: { id: string }; Querystring: { type?: string } }>('/stations/:id/board/stream', (req, reply) => {
      const type = (req.query.type ?? 'departures') as BoardType;
      if (!TYPES.has(type) || !hub.signatureOf(req.params.id)) return reply.code(404).send({ error: 'no board' });
      reply.hijack();
      const res = reply.raw;
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
        'X-Accel-Buffering': 'no',
      });
      res.write('retry: 5000\n\n');
      const send = (b: unknown) => res.write(`event: board\ndata: ${JSON.stringify(b)}\n\n`);
      const unsubscribe = hub.subscribe(req.params.id, type, send);
      hub.current(req.params.id, type).then(send, () => undefined);
      const beat = setInterval(() => res.write(': ping\n\n'), 20_000);
      req.raw.on('close', () => {
        clearInterval(beat);
        unsubscribe();
      });
    });

    app.put<{ Params: { id: string } }>('/stations/:id/favorite', async (req, reply) => {
      if (!stationInfo(req.params.id, req.userId)) return reply.code(404).send({ error: 'not found' });
      db.insert(stationFavorites).values({ userId: req.userId, stationId: req.params.id }).onConflictDoNothing().run();
      return { favorite: true };
    });
    app.delete<{ Params: { id: string } }>('/stations/:id/favorite', async (req) => {
      db.delete(stationFavorites)
        .where(and(eq(stationFavorites.userId, req.userId), eq(stationFavorites.stationId, req.params.id)))
        .run();
      return { favorite: false };
    });

    app.post<{ Params: { id: string } }>('/stations/:id/viewed', async (req, reply) => {
      if (!stationInfo(req.params.id, req.userId)) return reply.code(404).send({ error: 'not found' });
      const row = { userId: req.userId, stationId: req.params.id, lastViewed: new Date() };
      db.insert(stationRecent)
        .values(row)
        .onConflictDoUpdate({ target: [stationRecent.userId, stationRecent.stationId], set: { lastViewed: row.lastViewed } })
        .run();
      return reply.code(204).send();
    });

    app.get('/stations/favorites', async (req) =>
      db
        .select({ id: stations.id, name: stations.name, code: stations.trvSignature, country: stations.country })
        .from(stationFavorites)
        .innerJoin(stations, eq(stations.id, stationFavorites.stationId))
        .where(eq(stationFavorites.userId, req.userId))
        .orderBy(stations.name)
        .all(),
    );
    app.get('/stations/recent', async (req) =>
      db
        .select({ id: stations.id, name: stations.name, code: stations.trvSignature, country: stations.country })
        .from(stationRecent)
        .innerJoin(stations, eq(stations.id, stationRecent.stationId))
        .where(eq(stationRecent.userId, req.userId))
        .orderBy(desc(stationRecent.lastViewed))
        .limit(8)
        .all(),
    );
  };
