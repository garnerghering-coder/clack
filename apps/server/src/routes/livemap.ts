// Live map of all trains (ADDITIONS_01 A): snapshot + viewport-filtered SSE deltas from the shared ingest.
import type { FastifyPluginAsync } from 'fastify';
import { inArray } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legs } from '../db/schema.js';
import { LiveMapIngest, type LiveDelta, type LiveTrain } from '../livemap/ingest.js';
import { searchByNumber } from '../search/timetable.js';
import { trainStops } from '../livemap/trainStops.js';

type Bbox = [number, number, number, number];

/** "w,s,e,n", padded by 20% so trains just outside the view are ready when you pan a little. */
function parseBbox(s: string | undefined): Bbox | null {
  if (!s) return null;
  const v = s.split(',').map(Number);
  if (v.length !== 4 || v.some((x) => !Number.isFinite(x))) return null;
  const [w, south, e, n] = v as Bbox;
  const px = (e - w) * 0.2;
  const py = (n - south) * 0.2;
  return [w - px, south - py, e + px, n + py];
}
const inside = (t: LiveTrain, b: Bbox | null) => !b || (t.lon >= b[0] && t.lon <= b[2] && t.lat >= b[1] && t.lat <= b[3]);

/** Everything but the position: when only this is unchanged, a delta sends the train as a short "moved" tuple. */
const infoOf = ({ lat: _a, lon: _b, bearing: _c, speedKmh: _d, at: _e, estimated: _f, ...info }: LiveTrain) => JSON.stringify(info);
const r5 = (v: number) => Math.round(v * 1e5) / 1e5;
/** [id, lat, lon, bearing, speedKmh, at, estimated]: about a tenth of the full object. */
export type MovedTuple = [string, number, number, number | null, number | null, number, boolean];
const moved = (t: LiveTrain): MovedTuple => [t.id, r5(t.lat), r5(t.lon), t.bearing, t.speedKmh, t.at, t.estimated];

export const liveMapRoutes =
  (db: Db, ingest: LiveMapIngest): FastifyPluginAsync =>
  async (app) => {
    app.get<{ Querystring: { bbox?: string } }>('/live/trains', async (req) => {
      // A one-off look keeps the ingest warm for a minute, like a short visit to the map.
      ingest.acquire();
      ingest.release();
      const b = parseBbox(req.query.bbox);
      return { trains: [...ingest.trains.values()].filter((t) => inside(t, b)), total: ingest.trains.size, upstreamAt: ingest.upstreamAt, mode: ingest.mode };
    });

    app.get<{ Querystring: { bbox?: string } }>('/live/trains/stream', (req, reply) => {
      const b = parseBbox(req.query.bbox);
      reply.hijack();
      const res = reply.raw;
      res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
      res.write('retry: 5000\n\n');
      ingest.acquire();
      // Trains this client has (and what it knows about each), so it can be told when one leaves its view.
      const sent = new Map<string, string>();
      const snapshot = [...ingest.trains.values()].filter((t) => inside(t, b));
      for (const t of snapshot) sent.set(t.id, infoOf(t));
      res.write(`event: snapshot\ndata: ${JSON.stringify({ trains: snapshot, total: ingest.trains.size, upstreamAt: ingest.upstreamAt, mode: ingest.mode })}\n\n`);
      const onDelta = (d: LiveDelta) => {
        const changed: LiveTrain[] = [];
        const move: MovedTuple[] = [];
        const removed: string[] = d.removed.filter((id) => sent.delete(id));
        for (const t of d.changed) {
          if (inside(t, b)) {
            const info = infoOf(t);
            if (sent.get(t.id) === info) move.push(moved(t));
            else changed.push(t);
            sent.set(t.id, info);
          } else if (sent.delete(t.id)) removed.push(t.id);
        }
        res.write(`event: delta\ndata: ${JSON.stringify({ changed, moved: move, removed, total: d.total, upstreamAt: d.upstreamAt, mode: ingest.mode })}\n\n`);
      };
      ingest.on('delta', onDelta);
      req.raw.on('close', () => {
        ingest.off('delta', onDelta);
        ingest.release();
      });
    });

    // The operator narrows it down where two companies share a number (Öresundståg 1378 and Pågatåg 1378).
    const tripOf = (t: LiveTrain) =>
      t.date === 'sim' ? undefined : ((t.operatorId ? searchByNumber(db, t.number, t.date, { operatorId: t.operatorId })[0] : undefined) ?? searchByNumber(db, t.number, t.date)[0]);

    // One train, with its timetable trip so the map can draw its route and "Add to my trips" works.
    app.get<{ Params: { id: string } }>('/live/trains/:id', async (req, reply) => {
      const t = ingest.trains.get(req.params.id);
      if (!t) return reply.code(404).send({ error: 'train not on the map any more' });
      const trip = tripOf(t);
      const mine = t.mine
        ? db
            .select({ id: legs.id, trainNumber: legs.trainNumber, trv: legs.trvTrainNumbers })
            .from(legs)
            .where(inArray(legs.status, ['planned', 'completed']))
            .all()
            .find((l) => l.trainNumber === t.number || l.trv.includes(t.number))
        : undefined;
      return { train: t, trip: trip ? { key: trip.key, serviceDate: trip.serviceDate, from: trip.from, to: trip.to } : null, legId: mine?.id ?? null };
    });

    // Its whole route, stop by stop, with actual and expected times (the train sheet's list).
    app.get<{ Params: { id: string } }>('/live/trains/:id/stops', async (req, reply) => {
      const t = ingest.trains.get(req.params.id);
      if (!t) return reply.code(404).send({ error: 'train not on the map any more' });
      const trip = tripOf(t);
      const stops = trip ? await trainStops(db, trip, t.number) : null;
      if (!stops) return reply.code(404).send({ error: 'train not in the timetable' });
      return { stops };
    });

    app.get('/live/status', async () => ({ mode: ingest.mode, viewers: ingest.viewers, trains: ingest.trains.size, upstreamAt: ingest.upstreamAt, upstreamOpens: ingest.upstreamOpens, announcementRows: ingest.announcementRows }));
  };
