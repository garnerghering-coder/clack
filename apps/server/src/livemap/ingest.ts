// Live map ingest (ADDITIONS_01 A): one upstream TrainPosition stream for everyone, held in memory.
// - Trafikverket SSE (Phase 0 §9: 3–5 s lag), opened with a full query that doubles as the catch-up after every
//   reconnect (the stream doesn't replay missed events). After 3 failed streams in a row it falls back to polling.
// - Positions are joined with the announcement cache for delay, destination and next stop.
// - Runs only while someone has the map open (acquire/release), and nothing is written to the database.
import { EventEmitter } from 'node:events';
import type { Db } from '../db/client.js';
import { stations, trvLocations } from '../db/schema.js';
import { parseWgs84, trvQuery } from '../trafikverket/client.js';
import { brandMatcher } from '../boards/board.js';
import { loadBrands } from '../dataFiles.js';
import { brandOnLine, trainTypeFor } from '../legs/trainTypes.js';
import { AnnouncementCache, trainKey, type TrainInfo } from './announcements.js';
import { segmentBetween, segmentCached, type StationPoint } from '../geo/trackSegments.js';
import type { RailGraph } from '../geo/railGraph.js';
import { cumulative, GPS_FRESH_MS, pointAt } from '../live/progress.js';
import { countsAsStanding, estimateAlong, type TrainState } from '../live/positioning.js';
import { locateOnSegment } from '../live/locate.js';
import { Placement } from '../live/placement.js';
import type { LatLon } from '@clack/shared';
import { LiveQuality } from '../live/quality.js';
import { haversineM } from '../lib/geo.js';
import { REPO_ROOT } from '../env.js';
import path from 'node:path';
import { productOf, searchByNumber, tripStops, type Product } from '../search/timetable.js';
import { NORWAY_POLL_MS, NorwayFeed } from './norway.js';
import { FINLAND_POLL_MS, FinlandFeed } from './finland.js';
import { DENMARK_POLL_MS, DenmarkFeed } from './denmark.js';
import type { RejseplanenClient } from '../rejseplanen/client.js';
import { countryOfLiveId } from '../lib/countries.js';
import type { DelayCause } from '@clack/shared';
import { FixFilter, SPEED_FRESH_MS } from '../live/sanitize.js';

export interface LiveTrain {
  id: string;
  number: string;
  date: string;
  lat: number;
  lon: number;
  bearing: number | null;
  speedKmh: number | null;
  /** When the GPS fix was taken. */
  at: number;
  estimated: boolean;
  operatorId: string | null;
  productName: string | null;
  product: Product;
  trainType: string | null;
  origin: string | null;
  destination: string | null;
  next: string | null;
  nextEta: number | null;
  delayMin: number | null;
  /** One of the asking user's tracked trains. False in the shared ingest; the routes set it per user (isMine). */
  mine: boolean;
  /** The timetable trip, when the feed names it (Norway's does, Finland's finds it by number and day). Set (maybe null) on those trains only. */
  tripKey?: string | null;
  /** A Norwegian train that also runs in Sweden, where Trafikverket knows it by number. */
  crossBorder?: boolean;
  /** Cars today where the feed says (Sweden's coach order, Finland's composition), the locomotive not counted. */
  cars?: number | null;
  /**
   * Where it is in its run (BUILDOUT §A.1): running between prevId and nextId, standing at a station, or waiting at
   * its first one before departure. Added in build 54; older apps ignore these fields.
   */
  state?: TrainState;
  /** The stop passed and the next one: our station ids, or "trv:<signature>" for a Swedish location without one. The track between them is GET /api/live/segment?from&to. */
  prevId?: string | null;
  nextId?: string | null;
  /** The station it stands or waits at, and its platform or track there when the feed says. */
  atStation?: string | null;
  platform?: string | null;
  /** 0 … 1 along prevId → nextId while running; null when standing, waiting or off the track. */
  progress?: number | null;
  /** When the shown position was carried forward from a GPS fix (by the delivery lag), the fix's own time; `at` is then the time the position is for. */
  fixAt?: number;
}

/**
 * Whether a train on the map is one of a user's tracked trains. keys: "number|date" for Trafikverket's trains, and
 * "trip:key|date" for Norway's and Finland's, whose feeds name (or let us find) the trip. A number alone isn't enough
 * there: SJ 441 and SJ Nord's 441 run on the same day. A Finnish train whose trip isn't in the timetable (an extra
 * train) is matched by "fi:number|date", which a Finnish leg adds.
 */
export function isMine(t: LiveTrain, keys: Set<string>): boolean {
  if (t.tripKey !== undefined) {
    if (keys.has(`trip:${t.tripKey}|${t.date}`) || (!!t.crossBorder && keys.has(`${t.number}|${t.date}`))) return true;
    const country = countryOfLiveId(t.id);
    if (country === 'FI') return keys.has(`fi:${t.number}|${t.date}`);
    // A Danish train the timetable doesn't have is found by its number (a Danish leg adds "dk:number|date").
    return country === 'DK' && !t.tripKey && keys.has(`dk:${t.number}|${t.date}`);
  }
  return keys.has(`${t.number}|${t.date}`);
}

export interface LiveDelta {
  changed: LiveTrain[];
  removed: string[];
  total: number;
  /** Last time anything arrived from Trafikverket (for the "Delayed data" state). */
  upstreamAt: number;
}

interface TrvPos {
  Train?: { AdvertisedTrainNumber?: string; JourneyPlanDepartureDate?: string; OperationalTrainDepartureDate?: string };
  Position?: { WGS84?: string };
  TimeStamp: string;
  Bearing?: number;
  Speed?: number;
  Status?: { Active?: boolean };
  Deleted?: boolean;
  /** Ours: when Speed was read (earlier than TimeStamp when this fix came without one). */
  speedAt?: number;
}

export const POSITION_MAX_AGE_MS = 10 * 60_000;
const FLUSH_MS = 2_000;
const PRUNE_MS = 30_000;
const ANNOUNCE_MS = Number(process.env.LIVE_MAP_ANNOUNCE_MS ?? 30_000);
const POLL_MS = Number(process.env.LIVE_MAP_POLL_MS ?? 20_000);
const IDLE_STOP_MS = 60_000;
const ESTIMATE_MS = 10_000;
/** A train whose last stop is behind it this long, with nothing ahead, has parked. */
const FINISHED_MS = 5 * 60_000;

function productOfText(text: string | null, brand: string | null): Product {
  const p = text ?? '';
  if (/snabbtåg/i.test(p)) return 'high_speed';
  if (/natt/i.test(p)) return 'night';
  if (/intercity/i.test(p)) return 'intercity';
  if (/pendel/i.test(p) || (brand && ['sl', 'pagatag', 'ostgotapendeln'].includes(brand))) return 'commuter';
  return 'regional';
}

export interface IngestOptions {
  fetchImpl?: typeof fetch;
  now?: () => number;
  log?: (m: string) => void;
  /** Synthetic trains instead of Trafikverket (demo and load testing). */
  simulate?: number;
  simulateTracks?: () => [number, number][][];
  /** Draw trains without (fresh) GPS at a position worked out from the timetable. Default on. */
  includeEstimated?: boolean;
  /** Rail network for estimated positions; straight lines between stations without it. */
  graph?: () => RailGraph | null;
  /** Norway's trains from Entur (the server turns this on; never while simulating). */
  norway?: boolean;
  /** Finland's trains from Digitraffic (the same). */
  finland?: boolean;
  /** Denmark's trains from Rejseplanen. */
  denmark?: boolean;
  /** For tests: the Rejseplanen client (else the shared one). */
  rejseplanen?: RejseplanenClient;
  /** Where the quality counters are kept between restarts (default data/cache/live-quality.json); null keeps them in memory only (tests). */
  qualityFile?: string | null;
}

type Fix = Pick<LiveTrain, 'lat' | 'lon' | 'bearing' | 'speedKmh' | 'at' | 'estimated' | 'state' | 'prevId' | 'nextId' | 'atStation' | 'platform' | 'progress' | 'fixAt'>;
/** A Swedish train is drawn waiting at its first stop this long before its advertised departure (a chosen window, not measured: long-distance trains are usually at the platform by then). */
export const WAITING_BEFORE_MS = 10 * 60_000;
const QUALITY_FILE = path.join(REPO_ROOT, 'data/cache/live-quality.json');
const QUALITY_SAVE_MS = 5 * 60_000;
/** One position-check sample per train per minute, so Sweden's 3-second fixes don't outweigh the rest. */
const CHECK_EVERY_MS = 60_000;
interface GpsPoint {
  lat: number;
  lon: number;
  at: number;
  bearing: number | null;
  /** The checked speed while it is fresh. */
  speedKmh: number | null;
  /** The last checked speed however old, for dead reckoning. */
  lastSpeedKmh: number | null;
}
interface TailStop {
  id: string;
  name: string;
  lat: number;
  lon: number;
  arr: number | null;
  dep: number | null;
}

export class LiveMapIngest extends EventEmitter {
  readonly trains = new Map<string, LiveTrain>();
  /** What the network status reads beside each train and the stream doesn't send: the station it passed last, and the reasons its feed gives. */
  readonly context = new Map<string, { prev: string | null; prevId: string | null; causes: DelayCause[] }>();
  private positions = new Map<string, TrvPos>();
  /** Every position report passes through here first: impossible jumps are dropped, speeds checked. */
  readonly fixes = new FixFilter();
  /** Where standing trains go (platforms, track points) and the parallel-track choice; shared with the other feeds. */
  readonly placement: Placement;
  /** Delivery lag, timestamp offsets, the position check and track-side agreement (GET /api/live/quality). */
  readonly quality: LiveQuality;
  /** When each train was last sampled for the position check. */
  private checked = new Map<string, number>();
  private changed = new Set<string>();
  private removed = new Set<string>();
  private ann: AnnouncementCache;
  private matchBrand = brandMatcher(loadBrands());
  private names = new Map<string, string>();
  private points: Map<string, StationPoint> | null = null;
  /** Trains currently drawn from an estimate rather than GPS. */
  private estimatedKeys = new Set<string>();
  private no: NorwayFeed | null;
  private fi: FinlandFeed | null;
  private dk: DenmarkFeed | null;
  /** Danish trains on the map now. */
  private dkIds = new Set<string>();
  /** Swedish keys of cross-border trains drawn from Rejseplanen in Denmark instead of a Swedish estimate abroad. */
  private denmarkPos = new Set<string>();
  /** Rejseplanen's journey id per Danish train on the map, for its stop list when the timetable doesn't have it. */
  private dkJourneys = new Map<string, string>();
  /** Finnish trains on the map now. */
  private fiIds = new Set<string>();
  /** Norwegian trains on the map now. */
  private noIds = new Set<string>();
  /** Swedish keys of cross-border trains drawn from Norway's GPS instead of a Swedish estimate. */
  private norwayGps = new Set<string>();
  /** Timetabled stops abroad after a train's last Trafikverket report, per train (cached 10 minutes). */
  private tails = new Map<string, { at: number; stops: TailStop[] }>();
  /** The same before a train's first Trafikverket report (København H → Hyllie). */
  private heads = new Map<string, { at: number; stops: TailStop[] }>();
  private users = 0;
  private running = false;
  private abort: AbortController | null = null;
  private timers: ReturnType<typeof setInterval>[] = [];
  private idleTimer: ReturnType<typeof setTimeout> | null = null;
  upstreamAt = 0;
  /** Upstream connections opened (streams + polls), to show there's one per server, not per user. */
  upstreamOpens = 0;
  mode: 'stream' | 'poll' | 'simulate' | 'stopped' = 'stopped';
  get announcementRows() {
    return this.ann.size;
  }

  constructor(
    private db: Db,
    private opts: IngestOptions = {},
  ) {
    super();
    this.setMaxListeners(200);
    this.placement = new Placement(() => opts.graph?.() ?? null);
    this.quality = opts.qualityFile === null ? new LiveQuality(() => this.now()) : LiveQuality.load(opts.qualityFile ?? QUALITY_FILE, () => this.now());
    const shared = { fetchImpl: opts.fetchImpl, now: opts.now, log: opts.log, graph: opts.graph, placement: this.placement, quality: this.quality };
    this.ann = new AnnouncementCache({ fetchImpl: opts.fetchImpl, now: opts.now, log: opts.log });
    this.no = !opts.norway || opts.simulate ? null : new NorwayFeed(db, shared);
    this.fi = !opts.finland || opts.simulate ? null : new FinlandFeed(db, shared);
    this.dk = !opts.denmark || opts.simulate ? null : new DenmarkFeed(db, { ...shared, client: opts.rejseplanen });
  }

  /** Last time Digitraffic's feeds answered (0 without Finland). */
  get finlandAt() {
    return this.fi?.upstreamAt ?? 0;
  }

  /** Per hour of the day, Danish trains seen and matched to the timetable (empty without Denmark). */
  get denmarkMatchByHour() {
    return this.dk?.matchByHour ?? new Map<number, { trains: number; matched: number }>();
  }

  /** Rejseplanen's journey id for a Danish train on the map. */
  denmarkJourney(id: string): string | undefined {
    return this.dkJourneys.get(id);
  }

  /** Last time Rejseplanen answered for the map (0 without Denmark). */
  get denmarkAt() {
    return this.dk?.upstreamAt ?? 0;
  }

  /** Last time Entur's feeds answered (0 without Norway). */
  get norwayAt() {
    return this.no?.upstreamAt ?? 0;
  }

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  private name(sig: string | null) {
    if (!sig) return null;
    if (!this.names.size) for (const l of this.db.select({ s: trvLocations.signature, n: trvLocations.name }).from(trvLocations).all()) this.names.set(l.s.toLowerCase(), l.n);
    return this.names.get(sig.toLowerCase()) ?? sig;
  }

  /** Where a Trafikverket location is, keyed like the track cache (our station id when there is one). */
  private point(sig: string | null): StationPoint | null {
    if (!sig) return null;
    if (!this.points) {
      this.points = new Map();
      for (const l of this.db.select({ s: trvLocations.signature, lat: trvLocations.lat, lon: trvLocations.lon }).from(trvLocations).all())
        if (l.lat !== null && l.lon !== null) this.points.set(l.s.toLowerCase(), { id: `trv:${l.s}`, lat: l.lat, lon: l.lon });
      for (const st of this.db.select({ id: stations.id, sig: stations.trvSignature, lat: stations.lat, lon: stations.lon }).from(stations).all())
        if (st.sig) this.points.set(st.sig.toLowerCase(), { id: st.id, lat: st.lat, lon: st.lon });
    }
    return this.points.get(sig.toLowerCase()) ?? null;
  }

  /** A viewer opened the map. The first one starts the ingest. */
  acquire() {
    this.users++;
    if (this.idleTimer) clearTimeout(this.idleTimer);
    this.idleTimer = null;
    if (!this.running) this.start();
  }

  /** A viewer left. The ingest stops a minute after the last one. */
  release() {
    this.users = Math.max(0, this.users - 1);
    if (!this.users && this.running && !this.idleTimer) this.idleTimer = setTimeout(() => this.stop(), IDLE_STOP_MS);
  }

  get viewers() {
    return this.users;
  }

  start() {
    if (this.running) return;
    this.running = true;
    if (this.opts.simulate) {
      this.mode = 'simulate';
      this.startSimulation(this.opts.simulate);
    } else {
      void this.streamLoop();
      // One announcement request at a time: a slow full load mustn't pile up behind the 30 s timer.
      let busy = false;
      const refreshAnn = () => {
        if (busy) return;
        busy = true;
        this.ann
          .refresh()
          .then(
            () => this.reenrich(),
            (e) => this.opts.log?.(`live map: announcements failed: ${(e as Error).message}`),
          )
          .finally(() => {
            busy = false;
          });
      };
      void refreshAnn();
      this.timers.push(setInterval(refreshAnn, ANNOUNCE_MS));
      if (this.opts.includeEstimated !== false) this.timers.push(setInterval(() => this.estimateAll(), ESTIMATE_MS));
      if (this.no) {
        const no = this.no;
        let polling = false;
        const pollNorway = () => {
          if (polling) return;
          polling = true;
          no.poll()
            .then(() => this.applyNorway())
            .catch((e) => this.opts.log?.(`live map: Norway failed: ${(e as Error).message}`))
            .finally(() => {
              polling = false;
            });
        };
        pollNorway();
        this.timers.push(setInterval(pollNorway, NORWAY_POLL_MS));
        // Estimated Norwegian trains move between polls too.
        this.timers.push(setInterval(() => this.applyNorway(), ESTIMATE_MS));
      }
      if (this.fi) {
        const fi = this.fi;
        let polling = false;
        const pollFinland = () => {
          if (polling) return;
          polling = true;
          fi.poll()
            .then(() => this.applyFinland())
            .catch((e) => this.opts.log?.(`live map: Finland failed: ${(e as Error).message}`))
            .finally(() => {
              polling = false;
            });
        };
        pollFinland();
        this.timers.push(setInterval(pollFinland, FINLAND_POLL_MS));
        this.timers.push(setInterval(() => this.applyFinland(), ESTIMATE_MS));
      }
      if (this.dk) {
        const dk = this.dk;
        let polling = false;
        const pollDenmark = () => {
          if (polling) return;
          polling = true;
          dk.poll()
            .then(() => this.applyDenmark())
            .catch((e) => this.opts.log?.(`live map: Denmark failed: ${(e as Error).message}`))
            .finally(() => {
              polling = false;
            });
        };
        pollDenmark();
        this.timers.push(setInterval(pollDenmark, DENMARK_POLL_MS));
      }
    }
    this.timers.push(setInterval(() => this.flush(), FLUSH_MS));
    this.timers.push(setInterval(() => this.prune(), PRUNE_MS));
    if (this.opts.qualityFile !== null)
      this.timers.push(
        setInterval(() => {
          try {
            this.quality.save(this.opts.qualityFile ?? QUALITY_FILE);
          } catch (e) {
            this.opts.log?.(`live map: could not save quality counters: ${(e as Error).message}`);
          }
        }, QUALITY_SAVE_MS),
      );
  }

  stop() {
    this.running = false;
    this.mode = 'stopped';
    this.abort?.abort();
    for (const t of this.timers) clearInterval(t);
    this.timers = [];
    if (this.idleTimer) clearTimeout(this.idleTimer);
    this.idleTimer = null;
  }

  private posKey(p: TrvPos): string | null {
    const n = p.Train?.AdvertisedTrainNumber;
    const d = (p.Train?.JourneyPlanDepartureDate ?? p.Train?.OperationalTrainDepartureDate)?.slice(0, 10);
    return n && d ? trainKey(n, d) : null;
  }

  /** Position report in; re-derive that train. */
  ingest(rows: TrvPos[]) {
    this.upstreamAt = this.now();
    for (const p of rows) {
      const k = this.posKey(p);
      if (!k) continue;
      const old = this.positions.get(k);
      if (old && Date.parse(old.TimeStamp) > Date.parse(p.TimeStamp)) continue;
      if (p.Deleted || p.Status?.Active === false) {
        this.positions.delete(k);
        if (this.trains.delete(k)) this.removed.add(k);
        continue;
      }
      const ll = parseWgs84(p.Position?.WGS84);
      if (!ll) continue;
      const at = Date.parse(p.TimeStamp);
      if (!this.fixes.push(k, { lat: ll[0], lon: ll[1], at, bearing: p.Bearing ?? null, speedKmh: p.Speed ?? null })) continue;
      const cur = this.fixes.current(k);
      this.positions.set(k, { ...p, Speed: cur?.speedKmh ?? undefined, speedAt: cur?.speedAt });
      this.quality.recordFix('trafikverket', k, { lat: ll[0], lon: ll[1], at }, this.now());
      this.sampleCheck(k, { lat: ll[0], lon: ll[1], at, speedKmh: cur?.speedKmh ?? null });
      this.derive(k);
    }
  }

  /** The raw fix the filter accepted, with the speed as checked. */
  private gpsOf(k: string): (GpsPoint & { fresh: boolean; ageMs: number }) | null {
    const p = this.positions.get(k);
    const ll = p && parseWgs84(p.Position?.WGS84);
    if (!p || !ll) return null;
    const at = Date.parse(p.TimeStamp);
    const ageMs = this.now() - at;
    // A speed only from a fresh reading: an old one says nothing about how fast it's going now.
    return { lat: ll[0], lon: ll[1], at, bearing: p.Bearing ?? null, speedKmh: this.now() - (p.speedAt ?? at) <= SPEED_FRESH_MS ? (p.Speed ?? null) : null, lastSpeedKmh: p.Speed ?? null, fresh: ageMs <= GPS_FRESH_MS, ageMs };
  }

  private derive(k: string) {
    const gps = this.gpsOf(k);
    if (!gps) return;
    // A stale fix is left to the estimate (if that's on); a fresh one always wins over it.
    if (this.opts.includeEstimated !== false && !gps.fresh && this.estimatedKeys.has(k)) return;
    this.estimatedKeys.delete(k);
    const [number, date] = k.split('|') as [string, string];
    const info = this.ann.info(number, date);
    this.passages(k, info);
    const where = this.locate(k, info, gps, this.now());
    if (where) this.put(k, where.fix, where.next);
    else this.put(k, { lat: gps.lat, lon: gps.lon, bearing: gps.bearing, speedKmh: gps.speedKmh, at: gps.at, estimated: false, state: 'running', prevId: null, nextId: null, atStation: null, platform: null, progress: null });
  }

  /** The feed's passage times with seconds against the GPS run, for the timestamp offset (§A.8). */
  private passages(k: string, info: TrainInfo | null) {
    if (!info || info.lastAtSeconds === null) return;
    const a = this.point(info.lastSig);
    if (a) this.quality.recordPassage('trafikverket', productOfText(info.productName, null), k, a, info.lastAtSeconds, info.lastWasArrival ? 'arr' : 'dep');
  }

  /**
   * The position check (BUILDOUT "Measuring it"): when a fix comes for a train we could also have estimated, how far
   * the old rule (a constant fraction of the time, capped at 95%) and the new one (the run profile) would have put it
   * from where it really was; and for a train reported standing at a mapped platform, how far that platform's point
   * is from the fix. One sample per train per minute.
   */
  private sampleCheck(k: string, fix: { lat: number; lon: number; at: number; speedKmh: number | null }) {
    if (fix.at - (this.checked.get(k) ?? 0) < CHECK_EVERY_MS) return;
    const [number, date] = k.split('|') as [string, string];
    const info = this.ann.info(number, date);
    if (!info || info.lastAt === null || !info.lastSig || !info.nextSig) return;
    const a = this.point(info.lastSig);
    const b = this.point(info.nextSig);
    if (!a || !b) return;
    const product = productOfText(info.productName, null);
    if (info.lastWasArrival) {
      if (!countsAsStanding(fix.at, info.lastAt, fix.speedKmh)) return;
      const placed = this.placement.standing(a.id, a.lat, a.lon, info.lastTrack);
      if (placed.how === 'platform') {
        this.checked.set(k, fix.at);
        this.quality.recordStanding(this.name(info.lastSig) ?? a.id, haversineM(fix.lat, fix.lon, placed.lat, placed.lon));
      }
      return;
    }
    if (a.id === b.id || info.nextEta === null || fix.at < info.lastAt) return;
    const seg = segmentCached(this.db, a, b, this.opts.graph?.() ?? null);
    const cum = seg.cum;
    const L = cum.at(-1)!;
    const span = info.nextEta - info.lastAt;
    const f = span > 0 ? Math.min(0.95, Math.max(0, (fix.at - info.lastAt) / span)) : 0;
    const oldPt = pointAt(seg.points, cum, f * L);
    const newPt = pointAt(seg.points, cum, estimateAlong(L, info.lastAt, info.nextEta, fix.at).m);
    this.checked.set(k, fix.at);
    this.quality.recordCheck(product, haversineM(fix.lat, fix.lon, oldPt.lat, oldPt.lon), haversineM(fix.lat, fix.lon, newPt.lat, newPt.lon));
  }

  /**
   * Where a Swedish train is now (BUILDOUT §A), from its announcements and its GPS:
   * - a fresh fix is snapped onto the prev → next track, pointed along it, and carried forward by the delivery lag;
   *   a fix that is slow next to a station, or a train the feed says has arrived, stands at its platform;
   * - a stale fix is dead-reckoned along the track at its last speed, then blended into the estimate;
   * - without GPS, the estimate follows the run profile, moves to the approach after the expected arrival, and then
   *   stands at the platform; a train the feed says has arrived stands at its platform;
   * - before its first departure, it waits at its first stop (its platform when the announcement names the track).
   * Null when there is nothing to draw it from (then a fresh fix is shown raw by the caller).
   */
  private locate(k: string, info: TrainInfo | null, gps: (GpsPoint & { fresh: boolean; ageMs: number }) | null, now: number): { fix: Fix; next?: { name: string; eta: number | null } | null } | null {
    const graph = this.opts.graph?.() ?? null;
    const raw = (): Fix | null => (gps?.fresh ? { lat: gps.lat, lon: gps.lon, bearing: gps.bearing, speedKmh: gps.speedKmh, at: gps.at, estimated: false, state: 'running', prevId: null, nextId: null, atStation: null, platform: null, progress: null } : null);
    if (!info) {
      const r = raw();
      return r ? { fix: r } : null;
    }
    const standingAt = (p: StationPoint, sig: string | null, track: string | null, prevId: string | null, nextId: string | null, state: TrainState, estimated: boolean): Fix => {
      const placed = this.placement.standing(p.id.startsWith('trv:') ? null : p.id, p.lat, p.lon, track);
      // With a fix and no mapped platform, the fix beats the station's point.
      const at = gps?.fresh && placed.how !== 'platform' ? gps : placed;
      return { lat: at.lat, lon: at.lon, bearing: null, speedKmh: estimated ? null : 0, at: now, estimated, state, prevId, nextId, atStation: this.name(sig), platform: placed.how === 'platform' ? track : null, progress: null, ...(gps?.fresh ? { fixAt: gps.at } : {}) };
    };

    // Not left its first stop yet: a train from abroad is on its way (head); otherwise it waits at the first stop.
    if (info.lastAt === null) {
      const abroad = this.estimateAbroad(info, now, graph);
      if (abroad && !gps?.fresh) return abroad;
      const first = this.point(info.nextSig);
      if (!first) {
        const r = raw();
        return r ? { fix: r } : null;
      }
      const due = info.nextEta ?? info.nextAdvertised;
      if (gps?.fresh || (due !== null && due - now <= WAITING_BEFORE_MS)) return { fix: standingAt(first, info.nextSig, info.nextTrack, null, first.id, 'waiting', !gps?.fresh) };
      return null;
    }
    // Past its last Swedish stop: the timetable abroad (tail), or just the fix.
    if (!info.nextSig) {
      if (gps?.fresh) {
        const r = raw()!;
        return { fix: r, next: null };
      }
      return this.estimateAbroad(info, now, graph);
    }
    const a = this.point(info.lastSig);
    const b = this.point(info.nextSig);
    if (!a || !b) {
      const r = raw();
      return r ? { fix: r } : null;
    }
    const seg = a.id === b.id ? { points: [[a.lat, a.lon]] as LatLon[], lengthM: 0, estimated: false } : segmentCached(this.db, a, b, graph);
    const fix = locateOnSegment(
      { seg, placement: this.placement, quality: this.quality },
      {
        prev: { id: a.id, name: this.name(info.lastSig), lat: a.lat, lon: a.lon, track: info.lastTrack },
        next: { id: b.id, name: this.name(info.nextSig), lat: b.lat, lon: b.lon, track: info.nextTrack },
        left: info.lastAt,
        arriving: info.nextEta,
        standingAtPrev: info.lastWasArrival,
        gps,
        now,
        country: 'SE',
        source: 'trafikverket',
      },
    );
    return fix ? { fix } : null;
  }

  /** Train k at this position, with what the announcements say about it; or off the map if it shouldn't show. */
  private put(k: string, fix: Fix, abroadNext?: { name: string; eta: number | null } | null) {
    const [number, date] = k.split('|') as [string, string];
    const info = this.ann.info(number, date);
    if (!this.shows(info)) {
      if (this.trains.delete(k)) this.removed.add(k);
      return;
    }
    const origin = this.name(info?.originSig ?? null);
    const destination = this.name(info?.destinationSig ?? null);
    const brand = brandOnLine((info?.productName && this.matchBrand(info.productName)) || (info?.operatorText && this.matchBrand(info.operatorText)) || null, [origin, destination]);
    const product = productOfText(info?.productName ?? null, brand);
    const t: LiveTrain = {
      id: k,
      number,
      date,
      ...fix,
      operatorId: brand,
      productName: info?.productName ?? null,
      product,
      trainType: trainTypeFor(brand, product, number, info?.composition ?? null, [origin, destination]),
      cars: info?.composition?.totalCars ?? null,
      origin,
      destination,
      next: abroadNext !== undefined ? (abroadNext?.name ?? null) : this.name(info?.nextSig ?? null),
      nextEta: abroadNext !== undefined ? (abroadNext?.eta ?? null) : (info?.nextEta ?? null),
      delayMin: info?.delayMin ?? null,
      mine: false,
    };
    this.trains.set(k, t);
    this.context.set(k, { prev: abroadNext !== undefined ? null : this.name(info?.lastSig ?? null), prevId: fix.prevId ?? null, causes: info?.causes ?? [] });
    this.changed.add(k);
    this.removed.delete(k);
  }

  /**
   * Shown: passenger trains that are running. Cancelled trains and replacement buses aren't, nor (once all the
   * announcements are in) trains with none (freight, empty runs) or that finished a while ago (parked).
   */
  private shows(info: TrainInfo | null): boolean {
    if (!info) return !this.ann.complete;
    if (info.canceled || !info.isTrain) return false;
    if (!(info.nextSig === null && info.lastAt !== null && this.now() - info.lastAt > FINISHED_MS)) return true;
    // Past its last Swedish stop: still running if its timetable goes on abroad.
    const tail = this.tail(info);
    const end = tail.at(-1)?.arr ?? tail.at(-1)?.dep ?? null;
    return end !== null && this.now() <= end + FINISHED_MS;
  }

  /**
   * The stops abroad after a train's last Trafikverket report (Hyllie → København H, Arvika → Oslo S), from the
   * timetable, shifted by its last known delay. Empty for a train that ends in Sweden. Trafikverket's GPS and
   * reports stop at the border, so these are what the map can estimate from.
   */
  private tail(info: TrainInfo): TailStop[] {
    const k = trainKey(info.number, info.date);
    const hit = this.tails.get(k);
    if (hit && this.now() - hit.at < 10 * 60_000) return hit.stops;
    let stops: TailStop[] = [];
    const last = info.lastSig?.toLowerCase();
    // Only trains Trafikverket says end abroad (a foreign destination such as "Dk.kh"), to keep lookups few.
    for (const r of last && info.destinationSig?.includes('.') ? searchByNumber(this.db, info.number, info.date) : []) {
      const found = tripStops(this.db, r.key, r.serviceDate);
      const i = found?.stops.findIndex((x) => x.code?.toLowerCase() === last) ?? -1;
      if (!found || i < 0) continue;
      const after = found.stops.slice(i + 1);
      if (!after.length || after.some((x) => x.country === 'SE' && x.code && !x.code.includes('.'))) continue;
      const delay = Math.max(0, (info.delayMin ?? 0) * 60_000);
      const from = found.stops[i]!;
      stops = [
        { id: from.stationId, name: from.name, lat: from.lat, lon: from.lon, arr: null, dep: info.lastAt },
        ...after.map((x) => ({ id: x.stationId, name: x.name, lat: x.lat, lon: x.lon, arr: x.arr === null ? null : x.arr + delay, dep: x.dep === null ? null : x.dep + delay })),
      ];
      break;
    }
    this.tails.set(k, { at: this.now(), stops });
    if (this.tails.size > 2000) this.tails.delete(this.tails.keys().next().value!);
    return stops;
  }

  /**
   * Trains without fresh GPS: along the track between the last stop passed and the next one on the run profile, at
   * the approach once overdue, standing at their platform when arrived, waiting at their first stop before leaving,
   * and dead-reckoned from a fix that has gone quiet (locate, BUILDOUT §A). Drawn hollow.
   */
  estimateAll() {
    if (this.opts.includeEstimated === false || !this.ann.size) return;
    const now = this.now();
    const seen = new Set<string>();
    for (const [number, date] of this.ann.trains()) {
      const k = trainKey(number, date);
      const gps = this.gpsOf(k);
      if (gps?.fresh) continue;
      if (this.norwayGps.has(k) || this.denmarkPos.has(k)) continue;
      const info = this.ann.info(number, date);
      if (!info || !this.shows(info)) continue;
      const where = this.locate(k, info, gps, now);
      if (!where) continue;
      seen.add(k);
      this.estimatedKeys.add(k);
      this.put(k, where.fix, where.next);
    }
    // Estimates that no longer apply (arrived, cancelled, or GPS came back fresh and took over).
    for (const k of this.estimatedKeys)
      if (!seen.has(k)) {
        this.estimatedKeys.delete(k);
        if (this.trains.get(k)?.estimated && this.trains.delete(k)) this.removed.add(k);
      }
  }

  /**
   * Norway's trains onto the map. A cross-border train Trafikverket also reports is drawn once: Trafikverket's GPS
   * wins, then Norway's GPS, then Trafikverket's estimate (it knows the Swedish stops' real times).
   */
  applyNorway() {
    if (!this.no) return;
    const seen = new Set<string>();
    const taken = new Set<string>();
    for (const n of this.no.trains()) {
      const id = `no:${n.number}|${n.date}`;
      if (n.crossBorder) {
        const sk = trainKey(n.number, n.date);
        const swe = this.trains.get(sk);
        if (swe && (!swe.estimated || n.estimated)) continue;
        if (swe && this.trains.delete(sk)) this.removed.add(sk);
        if (!n.estimated) taken.add(sk);
      }
      seen.add(id);
      const product = productOf(n.routeType, n.category);
      const t: LiveTrain = {
        id,
        number: n.number,
        date: n.date,
        lat: n.lat,
        lon: n.lon,
        bearing: n.bearing,
        speedKmh: n.speedKmh,
        at: n.at,
        estimated: n.estimated,
        operatorId: n.operatorId,
        productName: null,
        product,
        trainType: trainTypeFor(n.operatorId, product, n.number, null, [n.origin, n.destination], n.vehicle),
        origin: n.origin,
        destination: n.destination,
        next: n.next,
        nextEta: n.nextEta,
        delayMin: n.delayMin,
        mine: false,
        tripKey: n.tripKey,
        ...(n.crossBorder ? { crossBorder: true } : {}),
        ...n.where,
      };
      this.trains.set(id, t);
      this.context.set(id, { prev: n.prev ?? null, prevId: n.where.prevId, causes: [] });
      this.changed.add(id);
      this.removed.delete(id);
    }
    for (const id of this.noIds) if (!seen.has(id) && this.trains.delete(id)) this.removed.add(id);
    this.noIds = seen;
    this.norwayGps = taken;
  }

  /**
   * Denmark's trains onto the map, from Rejseplanen: all estimated (Rejseplanen works the positions out from delays).
   * A train Trafikverket also announces (Öresundståg, SJ, Snälltåget) is drawn once: Trafikverket's GPS wins, and so
   * does Trafikverket while the train is in Sweden; abroad, where Trafikverket only guesses from the timetable,
   * Rejseplanen's position replaces the guess.
   */
  applyDenmark() {
    if (!this.dk) return;
    const seen = new Set<string>();
    const taken = new Set<string>();
    for (const d of this.dk.trains()) {
      // Numbers repeat in Denmark (NT's trains carry their line number), so the id names where the train started.
      const id = `dk:${d.number}@${d.ref}|${d.date}`;
      if (d.jid) this.dkJourneys.set(id, d.jid);
      let crossBorder = false;
      if (!d.inDanishTimetable) {
        // Trafikverket may carry an Öresundståg with a leading 2 (21378 for Rejseplanen's 1378).
        const sk = [trainKey(d.number, d.date), trainKey(`2${d.number}`, d.date)].find((k) => this.trains.has(k) || this.ann.info(...(k.split('|') as [string, string])));
        if (sk) {
          crossBorder = true;
          const swe = this.trains.get(sk);
          const info = this.ann.info(...(sk.split('|') as [string, string]));
          if (swe && !swe.estimated) continue;
          if (info?.nextSig && info.lastAt !== null) continue;
          if (swe && this.trains.delete(sk)) this.removed.add(sk);
          taken.add(sk);
        }
      }
      seen.add(id);
      const t: LiveTrain = {
        id,
        number: d.number,
        date: d.date,
        lat: d.lat,
        lon: d.lon,
        bearing: d.bearing,
        speedKmh: null,
        at: d.at,
        estimated: true,
        operatorId: d.operatorId,
        productName: d.productName,
        product: d.product,
        trainType: trainTypeFor(d.operatorId, d.product, d.number, null, [d.origin, d.destination], null),
        origin: d.origin,
        destination: d.destination,
        next: d.next,
        nextEta: d.nextEta,
        delayMin: d.delayMin,
        mine: false,
        tripKey: d.tripKey,
        ...(crossBorder ? { crossBorder: true } : {}),
        ...(d.where ?? {}),
      };
      this.trains.set(id, t);
      this.context.set(id, { prev: d.prev ?? null, prevId: d.where?.prevId ?? null, causes: [] });
      this.changed.add(id);
      this.removed.delete(id);
    }
    for (const id of this.dkIds) if (!seen.has(id) && this.trains.delete(id)) this.removed.add(id);
    for (const id of this.dkJourneys.keys()) if (!seen.has(id)) this.dkJourneys.delete(id);
    this.dkIds = seen;
    this.denmarkPos = taken;
  }

  /**
   * Finland's trains onto the map. Their ids start with "fi:", so they never meet Trafikverket's or Norway's. Trafikverket
   * doesn't announce Finnish trains at Haparanda (the only Swedish station they reach), so there is no second report of
   * the same train to choose between: a Finnish train is drawn from Digitraffic's GPS, or placed from its calls.
   */
  applyFinland() {
    if (!this.fi) return;
    const seen = new Set<string>();
    for (const f of this.fi.trains()) {
      const id = `fi:${f.number}|${f.date}`;
      seen.add(id);
      const t: LiveTrain = {
        id,
        number: f.number,
        date: f.date,
        lat: f.lat,
        lon: f.lon,
        bearing: f.bearing,
        speedKmh: f.speedKmh,
        at: f.at,
        estimated: f.estimated,
        operatorId: f.operatorId,
        productName: null,
        product: f.product,
        trainType: trainTypeFor(f.operatorId, f.product, f.number, null, [f.origin, f.destination], f.vehicle),
        cars: f.cars,
        origin: f.origin,
        destination: f.destination,
        next: f.next,
        nextEta: f.nextEta,
        delayMin: f.delayMin,
        mine: false,
        tripKey: f.tripKey,
        ...f.where,
      };
      this.trains.set(id, t);
      this.context.set(id, { prev: f.prev ?? null, prevId: f.where.prevId, causes: f.causes ?? [] });
      this.changed.add(id);
      this.removed.delete(id);
    }
    for (const id of this.fiIds) if (!seen.has(id) && this.trains.delete(id)) this.removed.add(id);
    this.fiIds = seen;
  }

  /**
   * The stops abroad before a train's first Trafikverket report (København H → … → Hyllie), from the timetable,
   * shifted by the delay expected at that first Swedish stop. Empty for a train that starts in Sweden.
   */
  private head(info: TrainInfo): TailStop[] {
    const k = trainKey(info.number, info.date);
    const hit = this.heads.get(k);
    if (hit && this.now() - hit.at < 10 * 60_000) return hit.stops;
    let stops: TailStop[] = [];
    const next = info.nextSig?.toLowerCase();
    for (const r of next && info.lastAt === null && info.originSig?.includes('.') ? searchByNumber(this.db, info.number, info.date) : []) {
      const found = tripStops(this.db, r.key, r.serviceDate);
      const i = found?.stops.findIndex((x) => x.code?.toLowerCase() === next) ?? -1;
      if (!found || i <= 0) continue;
      const before = found.stops.slice(0, i);
      if (before.some((x) => x.country === 'SE' && x.code && !x.code.includes('.'))) continue;
      const to = found.stops[i]!;
      const planned = to.arr ?? to.dep;
      const delay = info.nextEta !== null && planned !== null ? Math.max(0, info.nextEta - planned) : 0;
      stops = [
        ...before.map((x) => ({ id: x.stationId, name: x.name, lat: x.lat, lon: x.lon, arr: x.arr === null ? null : x.arr + delay, dep: x.dep === null ? null : x.dep + delay })),
        { id: to.stationId, name: to.name, lat: to.lat, lon: to.lon, arr: info.nextEta ?? planned, dep: null },
      ];
      break;
    }
    this.heads.set(k, { at: this.now(), stops });
    if (this.heads.size > 2000) this.heads.delete(this.heads.keys().next().value!);
    return stops;
  }

  /** Where a train is abroad, between two of its timetabled stops there (or standing at one). */
  private estimateAbroad(info: TrainInfo, now: number, graph: RailGraph | null): { fix: Fix; next: { name: string; eta: number | null } | null } | null {
    const tail = info.lastAt === null ? this.head(info) : this.tail(info);
    if (info.lastAt === null && tail.length >= 2 && now < (tail[0]!.dep ?? tail[0]!.arr ?? Infinity)) return null;
    if (tail.length < 2) return null;
    const leaves = (x: TailStop) => x.dep ?? x.arr;
    const standing = (s: TailStop, prevId: string | null, nextId: string | null): Fix => {
      const p = this.placement.standing(s.id, s.lat, s.lon, null);
      return { lat: p.lat, lon: p.lon, bearing: null, speedKmh: null, at: now, estimated: true, state: 'standing', prevId, nextId, atStation: s.name, platform: null, progress: null };
    };
    const i = tail.findIndex((x, j) => j > 0 && (x.arr ?? x.dep ?? 0) > now);
    if (i < 0) {
      const end = tail.at(-1)!;
      return { fix: standing(end, end.id, null), next: null };
    }
    const a = tail[i - 1]!;
    const b = tail[i]!;
    const left = leaves(a);
    if (left === null || now < left) return { fix: standing(a, a.id, b.id), next: { name: b.name, eta: b.arr ?? b.dep } };
    const seg = segmentBetween(this.db, { id: a.id, lat: a.lat, lon: a.lon }, { id: b.id, lat: b.lat, lon: b.lon }, graph);
    const cum = cumulative(seg.points);
    const arrive = b.arr ?? b.dep!;
    const est = estimateAlong(cum.at(-1)!, left, arrive, now);
    if (est.state === 'standing' && est.progress >= 1) return { fix: standing(b, a.id, b.id), next: { name: b.name, eta: arrive } };
    const pt = pointAt(seg.points, cum, est.m);
    return {
      fix: { lat: pt.lat, lon: pt.lon, bearing: Math.round(pt.bearing), speedKmh: est.speedKmh === null ? null : Math.round(est.speedKmh), at: now, estimated: true, state: 'running', prevId: a.id, nextId: b.id, atStation: null, platform: null, progress: est.progress },
      next: { name: b.name, eta: arrive },
    };
  }

  /** New announcement data: refresh every train's delay/next stop. */
  private reenrich() {
    for (const k of this.positions.keys()) this.derive(k);
    this.estimateAll();
  }

  private prune() {
    const cutoff = this.now() - POSITION_MAX_AGE_MS;
    this.fixes.prune(this.now() - 60 * 60_000);
    this.quality.prune(this.now() - 60 * 60_000);
    for (const [k, at] of this.checked) if (at < cutoff) this.checked.delete(k);
    for (const [k, p] of this.positions)
      if (Date.parse(p.TimeStamp) < cutoff) {
        this.positions.delete(k);
        if (!this.trains.get(k)?.estimated && this.trains.delete(k)) this.removed.add(k);
      }
  }

  private flush() {
    if (!this.changed.size && !this.removed.size) {
      // Still tell clients how old the data is, so "Delayed data" can show when the feed stalls.
      this.emit('delta', { changed: [], removed: [], total: this.trains.size, upstreamAt: this.upstreamAt } satisfies LiveDelta);
      return;
    }
    const delta: LiveDelta = {
      changed: [...this.changed].map((k) => this.trains.get(k)!).filter(Boolean),
      removed: [...this.removed],
      total: this.trains.size,
      upstreamAt: this.upstreamAt,
    };
    this.changed.clear();
    this.removed.clear();
    this.emit('delta', delta);
  }

  private positionQuery(sinceMs: number, sse: boolean) {
    return (
      `<QUERY objecttype="TrainPosition" namespace="järnväg.trafikinfo" schemaversion="1.1"${sse ? ' sseurl="true"' : ''}>` +
      `<FILTER><GT name="TimeStamp" value="${new Date(sinceMs).toISOString()}"/></FILTER>` +
      ['Train.AdvertisedTrainNumber', 'Train.JourneyPlanDepartureDate', 'Train.OperationalTrainDepartureDate', 'Position.WGS84', 'TimeStamp', 'Bearing', 'Speed', 'Status.Active', 'Deleted']
        .map((f) => `<INCLUDE>${f}</INCLUDE>`)
        .join('') +
      `</QUERY>`
    );
  }

  private async streamLoop() {
    let failures = 0;
    while (this.running) {
      try {
        // Full query first: today's positions, and the catch-up for anything missed while disconnected.
        this.upstreamOpens++;
        const since = Math.max(this.now() - POSITION_MAX_AGE_MS, this.upstreamAt ? this.upstreamAt - 60_000 : 0);
        const r = await trvQuery<{ TrainPosition?: TrvPos[]; INFO?: { SSEURL?: string } }>(this.positionQuery(since, failures < 3), this.opts.fetchImpl);
        this.ingest(r.TrainPosition ?? []);
        if (failures >= 3 || !r.INFO?.SSEURL) {
          this.mode = 'poll';
          await this.sleep(POLL_MS);
          continue;
        }
        this.mode = 'stream';
        await this.readStream(r.INFO.SSEURL);
        failures = 0;
      } catch (e) {
        if (!this.running) return;
        failures++;
        this.opts.log?.(`live map: upstream ${this.mode} failed (${failures}): ${(e as Error).message}`);
        await this.sleep(Math.min(30_000, 2_000 * 2 ** Math.min(failures, 4)));
      }
    }
  }

  private async readStream(url: string) {
    this.abort = new AbortController();
    const res = await (this.opts.fetchImpl ?? fetch)(url, { headers: { Accept: 'text/event-stream' }, signal: this.abort.signal });
    if (!res.ok || !res.body) throw new Error(`stream HTTP ${res.status}`);
    const reader = res.body.getReader();
    const dec = new TextDecoder();
    let buf = '';
    for (;;) {
      const { done, value } = await reader.read();
      if (done) throw new Error('stream closed');
      buf += dec.decode(value, { stream: true }).replace(/\r\n/g, '\n');
      let i: number;
      while ((i = buf.indexOf('\n\n')) >= 0) {
        const block = buf.slice(0, i);
        buf = buf.slice(i + 2);
        const data = block
          .split('\n')
          .filter((l) => l.startsWith('data:'))
          .map((l) => l.slice(5))
          .join('');
        this.upstreamAt = this.now();
        if (!data.trim()) continue;
        try {
          const rows = JSON.parse(data)?.RESPONSE?.RESULT?.[0]?.TrainPosition as TrvPos[] | undefined;
          if (rows) this.ingest(rows);
        } catch {
          // A malformed event: skip it; the next one carries fresh positions.
        }
      }
    }
  }

  private sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
  }

  // ---------- Simulation (LIVE_MAP_SIMULATE=1000): synthetic trains moving along real track ----------
  private startSimulation(n: number) {
    const tracks = (this.opts.simulateTracks?.() ?? []).filter((t) => t.length > 1);
    if (!tracks.length) return;
    const brands = loadBrands();
    const sims = Array.from({ length: n }, (_, i) => ({ i, track: tracks[i % tracks.length]!, pos: (i * 7919) % 1000 / 1000, dir: i % 2 ? 1 : -1, speed: 0.00002 + ((i * 31) % 50) / 2_000_000 }));
    const tick = () => {
      const now = this.now();
      this.upstreamAt = now;
      for (const s of sims) {
        s.pos += s.dir * s.speed * 1000;
        if (s.pos > 1 || s.pos < 0) {
          s.dir = -s.dir;
          s.pos = Math.min(1, Math.max(0, s.pos));
        }
        const f = s.pos * (s.track.length - 1);
        const a = s.track[Math.floor(f)]!;
        const b = s.track[Math.min(s.track.length - 1, Math.floor(f) + 1)]!;
        const t = f - Math.floor(f);
        const brand = brands[s.i % brands.length]!;
        const k = `S${s.i}|sim`;
        this.trains.set(k, {
          id: k,
          number: String(9000 + s.i),
          date: 'sim',
          lat: a[0] + (b[0] - a[0]) * t,
          lon: a[1] + (b[1] - a[1]) * t,
          bearing: (Math.atan2(b[1] - a[1], b[0] - a[0]) * 180) / Math.PI,
          speedKmh: 120,
          at: now,
          estimated: s.i % 7 === 0,
          operatorId: brand.id,
          productName: brand.name,
          product: 'regional',
          trainType: null,
          origin: null,
          destination: 'Simulated',
          next: null,
          nextEta: null,
          delayMin: (s.i * 13) % 40 - 5,
          mine: false,
        });
        this.changed.add(k);
      }
    };
    tick();
    this.timers.push(setInterval(tick, 5_000));
  }
}
