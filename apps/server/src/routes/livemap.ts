// Live map of all trains (ADDITIONS_01 A): snapshot + viewport-filtered SSE deltas from the shared ingest.
import type { FastifyPluginAsync } from 'fastify';
import { and, eq, inArray, lt } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { followedTrains, legs } from '../db/schema.js';
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
    // Norway's feed names the exact trip.
    const tripOf = (t: LiveTrain) => {
      if (t.date === 'sim') return undefined;
      const all = t.operatorId ? searchByNumber(db, t.number, t.date, { operatorId: t.operatorId }) : [];
      if (t.tripKey) {
        const exact = (all.length ? all : searchByNumber(db, t.number, t.date)).find((r) => r.key === t.tripKey);
        if (exact) return exact;
      }
      return all[0] ?? searchByNumber(db, t.number, t.date)[0];
    };

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

    // Any train by number and day, on the map or not (a board row, a followed train that hasn't left yet): its
    // timetable trip, whole route with whatever live data there is, and its live position if it has one. Opening a
    // train is only looking at it: nothing here follows it or adds it to your trips.
    app.get<{ Params: { number: string; date: string }; Querystring: { key?: string } }>('/trains/:number/:date', async (req, reply) => {
      const { number, date } = req.params;
      if (!/^\d{1,6}$/.test(number) || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return reply.code(400).send({ error: 'train number and date (YYYY-MM-DD) are required' });
      const live = [...ingest.trains.values()].find((x) => x.number === number && x.date === date) ?? null;
      const found = searchByNumber(db, number, date);
      const trip = (req.query.key && found.find((r) => r.key === req.query.key)) || (live ? tripOf(live) : undefined) || found[0];
      if (!trip && !live) return reply.code(404).send({ error: 'no such train on that day' });
      const stops = trip ? await trainStops(db, { key: trip.key, serviceDate: trip.serviceDate }, number) : null;
      const leg = db
        .select({ id: legs.id, trainNumber: legs.trainNumber, trv: legs.trvTrainNumbers, serviceDate: legs.serviceDate })
        .from(legs)
        .where(and(eq(legs.userId, req.userId), eq(legs.serviceDate, date)))
        .all()
        .find((l) => l.trainNumber === number || l.trv.includes(number));
      return {
        number,
        date,
        live,
        trip: trip ? { key: trip.key, serviceDate: trip.serviceDate, from: trip.from, to: trip.to } : null,
        operatorId: live?.operatorId ?? trip?.operatorId ?? null,
        productName: live?.productName ?? null,
        product: trip?.product ?? live?.product ?? null,
        trainType: live?.trainType ?? trip?.trainType ?? null,
        stops,
        legId: leg?.id ?? null,
      };
    });

    // Followed trains (brief §6.2): watching a train, which is not travelling on it. Kept for its day and the next.
    const stockholmDate = (ms: number) => new Date(ms).toLocaleDateString('sv-SE', { timeZone: 'Europe/Stockholm' });
    app.get('/follows', async (req) => {
      const cutoff = stockholmDate(Date.now() - 86400_000);
      db.delete(followedTrains).where(and(eq(followedTrains.userId, req.userId), lt(followedTrains.serviceDate, cutoff))).run();
      const rows = db.select().from(followedTrains).where(eq(followedTrains.userId, req.userId)).all();
      const onMap = new Map([...ingest.trains.values()].map((t) => [`${t.number}|${t.date}`, t]));
      return rows.map((r) => ({ trainNumber: r.trainNumber, serviceDate: r.serviceDate, operatorId: r.operatorId, label: r.label, train: onMap.get(`${r.trainNumber}|${r.serviceDate}`) ?? null }));
    });
    app.put<{ Body: { trainNumber?: string; serviceDate?: string; operatorId?: string | null; label?: string | null } }>('/follows', async (req, reply) => {
      const { trainNumber, serviceDate, operatorId = null, label = null } = req.body ?? {};
      if (!trainNumber || !/^\d{1,6}$/.test(trainNumber) || !serviceDate || !/^\d{4}-\d{2}-\d{2}$/.test(serviceDate)) return reply.code(400).send({ error: 'trainNumber and serviceDate (YYYY-MM-DD) are required' });
      // Following twice is still one follow.
      db.insert(followedTrains).values({ userId: req.userId, trainNumber, serviceDate, operatorId, label }).onConflictDoNothing().run();
      return { following: true };
    });
    app.delete<{ Params: { number: string; date: string } }>('/follows/:number/:date', async (req) => {
      db.delete(followedTrains)
        .where(and(eq(followedTrains.userId, req.userId), eq(followedTrains.trainNumber, req.params.number), eq(followedTrains.serviceDate, req.params.date)))
        .run();
      return { following: false };
    });

    app.get('/live/status', async () => ({ mode: ingest.mode, viewers: ingest.viewers, trains: ingest.trains.size, upstreamAt: ingest.upstreamAt, upstreamOpens: ingest.upstreamOpens, announcementRows: ingest.announcementRows, norwayAt: ingest.norwayAt }));
  };
