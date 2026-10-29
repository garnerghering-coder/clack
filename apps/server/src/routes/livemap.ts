// Live map of all trains (ADDITIONS_01 A): snapshot + viewport-filtered SSE deltas from the shared ingest.
import type { FastifyPluginAsync } from 'fastify';
import { countryOfLiveId } from '../lib/countries.js';
import { journeyStopsView } from '../rejseplanen/stops.js';
import { mapHealth } from '../livemap/denmark.js';
import { networkStatus, type NetworkStatus } from '../livemap/network.js';
import { and, eq, inArray, lt } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { followedTrains, legs } from '../db/schema.js';
import { isMine, LiveMapIngest, type LiveDelta, type LiveTrain } from '../livemap/ingest.js';
import { stations, trvLocations } from '../db/schema.js';
import { segmentBetween, type StationPoint } from '../geo/trackSegments.js';
import { encodePolyline } from '@clack/shared';
import { searchByNumber, tripByKey, tripStops } from '../search/timetable.js';
import { matchTrip } from '../livemap/match.js';
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
const infoOf = ({ lat: _a, lon: _b, bearing: _c, speedKmh: _d, at: _e, estimated: _f, state: _g, progress: _h, fixAt: _i, ...info }: LiveTrain) => JSON.stringify(info);
const r5 = (v: number) => Math.round(v * 1e5) / 1e5;
/** [id, lat, lon, bearing, speedKmh, at, estimated, state, progress]: about a tenth of the full object. Apps from before build 54 read the first seven. */
export type MovedTuple = [string, number, number, number | null, number | null, number, boolean, LiveTrain['state'] | null, number | null];
const moved = (t: LiveTrain): MovedTuple => [t.id, r5(t.lat), r5(t.lon), t.bearing, t.speedKmh, t.at, t.estimated, t.state ?? null, t.progress === undefined || t.progress === null ? null : Math.round(t.progress * 1000) / 1000];

/** How often a live-map stream re-reads which trains are the viewer's (adding a trip shows up within this). */
const MINE_REFRESH_MS = 10_000;

export const liveMapRoutes =
  (db: Db, ingest: LiveMapIngest, myTrainKeys: (userId: string) => Set<string> = () => new Set()): FastifyPluginAsync =>
  async (app) => {
    // The shared ingest doesn't know who's looking: "mine" is set here, per user.
    const forUser = (keys: Set<string>) => (t: LiveTrain): LiveTrain => (isMine(t, keys) === t.mine ? t : { ...t, mine: !t.mine });

    app.get<{ Querystring: { bbox?: string } }>('/live/trains', async (req) => {
      // A one-off look keeps the ingest warm for a minute, like a short visit to the map.
      ingest.acquire();
      ingest.release();
      const b = parseBbox(req.query.bbox);
      const mine = forUser(myTrainKeys(req.userId));
      return { trains: [...ingest.trains.values()].filter((t) => inside(t, b)).map(mine), total: ingest.trains.size, upstreamAt: ingest.upstreamAt, mode: ingest.mode };
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
      let mine = forUser(myTrainKeys(req.userId));
      let mineAt = Date.now();
      const snapshot = [...ingest.trains.values()].filter((t) => inside(t, b)).map(mine);
      for (const t of snapshot) sent.set(t.id, infoOf(t));
      res.write(`event: snapshot\ndata: ${JSON.stringify({ trains: snapshot, total: ingest.trains.size, upstreamAt: ingest.upstreamAt, mode: ingest.mode })}\n\n`);
      const onDelta = (d: LiveDelta) => {
        const changed: LiveTrain[] = [];
        const move: MovedTuple[] = [];
        const removed: string[] = d.removed.filter((id) => sent.delete(id));
        let changes = d.changed;
        if (Date.now() - mineAt >= MINE_REFRESH_MS) {
          mine = forUser(myTrainKeys(req.userId));
          mineAt = Date.now();
          // Trains that became (or stopped being) yours without moving still need telling.
          const ids = new Set(changes.map((t) => t.id));
          changes = [...changes, ...[...ingest.trains.values()].filter((t) => !ids.has(t.id) && sent.has(t.id))];
        }
        for (const raw of changes) {
          const t = mine(raw);
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
    /** The timetable trip of a train on the map: Norway's feed names it; otherwise the one that runs where it is. */
    const tripOf = (t: LiveTrain) => {
      if (t.date === 'sim') return undefined;
      const all = searchByNumber(db, t.number, t.date);
      if (t.tripKey) {
        const exact = all.find((r) => r.key === t.tripKey);
        if (exact) return exact;
        // The feed (or the Danish matcher) named the trip, but its number finds another: take the trip by its key.
        const byKey = tripByKey(db, t.tripKey, t.date);
        if (byKey) return byKey;
      }
      // A Danish train is its own timetable trip or none: its number alone can be another country's train (NT's "Re
      // 75" is a line number). Trains that cross into Sweden are Sweden's feed's, found by number as usual.
      if (countryOfLiveId(t.id) === 'DK' && !t.crossBorder) return undefined;
      return matchTrip(
        t,
        all.map((r) => ({ ...r, stops: tripStops(db, r.key, r.serviceDate)?.stops ?? [] })),
      );
    };

    // One train, with its timetable trip so the map can draw its route and "Add to my trips" works.
    app.get<{ Params: { id: string } }>('/live/trains/:id', async (req, reply) => {
      const t = ingest.trains.get(req.params.id);
      if (!t) return reply.code(404).send({ error: 'train not on the map any more' });
      const trip = tripOf(t);
      const yours = isMine(t, myTrainKeys(req.userId));
      const mine = yours
        ? db
            .select({ id: legs.id, trainNumber: legs.trainNumber, trv: legs.trvTrainNumbers, key: legs.timetableTripKey })
            .from(legs)
            .where(and(eq(legs.userId, req.userId), eq(legs.serviceDate, t.date), inArray(legs.status, ['planned', 'completed'])))
            .all()
            .find((l) => (l.trainNumber === t.number || l.trv.includes(t.number)) && (!trip || !l.key || l.key === trip.key))
        : undefined;
      return { train: yours === t.mine ? t : { ...t, mine: yours }, trip: trip ? { key: trip.key, serviceDate: trip.serviceDate, from: trip.from, to: trip.to } : null, legId: mine?.id ?? null };
    });

    // Its whole route, stop by stop, with actual and expected times (the train sheet's list).
    app.get<{ Params: { id: string } }>('/live/trains/:id/stops', async (req, reply) => {
      const t = ingest.trains.get(req.params.id);
      if (!t) return reply.code(404).send({ error: 'train not on the map any more' });
      const trip = tripOf(t);
      let stops = trip ? await trainStops(db, trip, t.number) : null;
      // Not in any timetable of ours: Rejseplanen's own list for a Danish train.
      const jid = !stops ? ingest.denmarkJourney(t.id) : undefined;
      if (jid) stops = await journeyStopsView(db, jid).catch(() => null);
      // Rejseplanen knows the train but couldn't answer just now: ask again (the app retries), not "not in the timetable".
      if (!stops && jid) return reply.code(503).send({ error: 'stops not available just now', retry: true });
      if (!stops) return reply.code(404).send({ error: 'train not in the timetable' });
      return { stops };
    });

    // Any train by number and day, on the map or not (a board row, a followed train that hasn't left yet): its
    // timetable trip, whole route with whatever live data there is, and its live position if it has one. Opening a
    // train is only looking at it: nothing here follows it or adds it to your trips.
    app.get<{ Params: { number: string; date: string }; Querystring: { key?: string } }>('/trains/:number/:date', async (req, reply) => {
      const { number, date } = req.params;
      if (!/^\d{1,6}$/.test(number) || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return reply.code(400).send({ error: 'train number and date (YYYY-MM-DD) are required' });
      const found = searchByNumber(db, number, date);
      // Several trains can share a number (SJ 441 in Sweden, SJ Nord 441 in Norway): the trip and the train on the
      // map must be the same one, so each map train is paired with its own trip, never another's.
      const onMap = [...ingest.trains.values()].filter((x) => x.number === number && x.date === date).map((t) => ({ t, trip: tripOf(t) }));
      const byKey = req.query.key ? found.find((r) => r.key === req.query.key) : undefined;
      const pair = byKey ? onMap.find((x) => x.trip?.key === byKey.key) : onMap.find((x) => x.trip) ?? onMap[0];
      const live = pair ? forUser(myTrainKeys(req.userId))(pair.t) : null;
      const trip = byKey ?? pair?.trip ?? (found.length === 1 ? found[0] : undefined);
      if (!trip && !live) return reply.code(404).send({ error: 'no such train on that day' });
      const stops = trip ? await trainStops(db, { key: trip.key, serviceDate: trip.serviceDate }, number) : null;
      const leg = db
        .select({ id: legs.id, trainNumber: legs.trainNumber, trv: legs.trvTrainNumbers, serviceDate: legs.serviceDate, key: legs.timetableTripKey })
        .from(legs)
        .where(and(eq(legs.userId, req.userId), eq(legs.serviceDate, date)))
        .all()
        .find((l) => (l.trainNumber === number || l.trv.includes(number)) && (!trip || !l.key || l.key === trip.key));
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
      const mine = forUser(myTrainKeys(req.userId));
      const onMap = new Map([...ingest.trains.values()].map((t) => [`${t.number}|${t.date}`, mine(t)]));
      return rows.map((r) => ({ trainNumber: r.trainNumber, serviceDate: r.serviceDate, operatorId: r.operatorId, label: r.label, journeyGroup: r.journeyGroup, journeyLabel: r.journeyLabel, train: onMap.get(`${r.trainNumber}|${r.serviceDate}`) ?? null }));
    });
    app.put<{ Body: { trainNumber?: string; serviceDate?: string; operatorId?: string | null; label?: string | null; journeyGroup?: string | null; journeyLabel?: string | null } }>('/follows', async (req, reply) => {
      const { trainNumber, serviceDate, operatorId = null, label = null, journeyGroup = null, journeyLabel = null } = req.body ?? {};
      if (journeyGroup !== null && !/^[A-Za-z0-9-]{1,64}$/.test(journeyGroup)) return reply.code(400).send({ error: 'bad journeyGroup' });
      if (!trainNumber || !/^\d{1,6}$/.test(trainNumber) || !serviceDate || !/^\d{4}-\d{2}-\d{2}$/.test(serviceDate)) return reply.code(400).send({ error: 'trainNumber and serviceDate (YYYY-MM-DD) are required' });
      // Following twice is still one follow.
      db.insert(followedTrains).values({ userId: req.userId, trainNumber, serviceDate, operatorId, label, journeyGroup, journeyLabel: journeyLabel?.slice(0, 120) ?? null }).onConflictDoNothing().run();
      return { following: true };
    });
    app.delete<{ Params: { number: string; date: string } }>('/follows/:number/:date', async (req) => {
      db.delete(followedTrains)
        .where(and(eq(followedTrains.userId, req.userId), eq(followedTrains.trainNumber, req.params.number), eq(followedTrains.serviceDate, req.params.date)))
        .run();
      return { following: false };
    });

    // What the map is missing, per country and operator (counts only, no personal data): checked before each build.
    app.get('/live/health', async () => mapHealth(ingest.trains.values(), ingest.denmarkMatchByHour));

    // Network status: corridors where most trains are running 10+ minutes late now (livemap/network.ts). Read off the
    // live map, so it is as fresh as the map; worked out at most every 15 s.
    let network: { at: number; body: NetworkStatus } | null = null;
    app.get('/live/network', async () => {
      const now = Date.now();
      if (!network || now - network.at > 15_000) {
        for (const id of ingest.context.keys()) if (!ingest.trains.has(id)) ingest.context.delete(id);
        const body = networkStatus(ingest.trains.values(), ingest.context, now);
        // Not kept while the map is still filling (no trains yet): the next ask works it out again.
        if (ingest.trains.size === 0) return body;
        network = { at: now, body };
      }
      return network.body;
    });

    // The track between two consecutive stops, as the live trains' prevId/nextId name them (our station ids, or
    // "trv:<signature>" for Swedish locations without one): the same geometry the server places trains on, so the
    // app can move a marker along it between updates (BUILDOUT §A, app). Cacheable: track doesn't change.
    const pointOf = (id: string | undefined): StationPoint | null => {
      if (!id || !/^[\w:.-]{1,64}$/.test(id)) return null;
      if (id.startsWith('trv:')) {
        const sig = id.slice(4);
        const l = db.select({ s: trvLocations.signature, lat: trvLocations.lat, lon: trvLocations.lon }).from(trvLocations).where(eq(trvLocations.signature, sig)).get();
        return l && l.lat !== null && l.lon !== null ? { id: `trv:${l.s}`, lat: l.lat, lon: l.lon } : null;
      }
      const s = db.select({ id: stations.id, lat: stations.lat, lon: stations.lon }).from(stations).where(eq(stations.id, id)).get();
      return s ? { id: s.id, lat: s.lat, lon: s.lon } : null;
    };
    app.get<{ Querystring: { from?: string; to?: string } }>('/live/segment', async (req, reply) => {
      const a = pointOf(req.query.from);
      const b = pointOf(req.query.to);
      if (!a || !b) return reply.code(404).send({ error: 'unknown station id' });
      const seg = segmentBetween(db, a, b);
      reply.header('Cache-Control', 'public, max-age=86400');
      return { from: a.id, to: b.id, polyline: encodePolyline(seg.points), lengthM: Math.round(seg.lengthM), estimated: seg.estimated };
    });

    // How good the positions are: delivery lag and timestamp offsets per source, the position check (old rule vs
    // new, standing placement) and track-side agreement (live/quality.ts). Counters only; admin token required.
    app.get('/live/quality', async (req, reply) => (req.isAdmin ? ingest.quality.report() : reply.callNotFound()));

    app.get('/live/status', async () => ({ mode: ingest.mode, viewers: ingest.viewers, trains: ingest.trains.size, upstreamAt: ingest.upstreamAt, upstreamOpens: ingest.upstreamOpens, announcementRows: ingest.announcementRows, norwayAt: ingest.norwayAt, finlandAt: ingest.finlandAt, denmarkAt: ingest.denmarkAt }));
  };
