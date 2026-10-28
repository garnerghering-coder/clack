// Shared board polling (ADDITIONS_01 B): one Trafikverket query per station and direction every BOARD_POLL_MS,
// however many people watch it. Viewers are ref-counted; the poller stops shortly after the last one leaves.
// A recent board is served from memory so opening a busy station is instant.
import type { Db } from '../db/client.js';
import { brandMatcher, fetchBoardRows, normalizeBoard, type Board, type BoardType, type PlatformMemory } from './board.js';
import { callsAtStation } from '../search/timetable.js';
import { loadBrands } from '../dataFiles.js';
import { stations, trvLocations } from '../db/schema.js';
import { eq } from 'drizzle-orm';
import { fetchNorwayCalls, normalizeNorwayBoard } from './norway.js';
import { fetchFinlandBoardTrains, normalizeFinlandBoard } from './finland.js';
import { fetchDayVehicles } from '../digitraffic/trains.js';
import { COUNTRIES } from '../lib/countries.js';
import { recordObservations } from '../legs/risk.js';
import { normalizeDenmarkBoard, timetableRows } from './denmark.js';
import { rejseplanen } from '../rejseplanen/client.js';
import { stationOfUic, TripMatcher, uicOfStation } from '../rejseplanen/match.js';

export const BOARD_POLL_MS = Number(process.env.BOARD_POLL_MS ?? 20_000);
/** Kept warm this long after the last viewer leaves (quick back-and-forth navigation stays cheap). */
const IDLE_MS = 60_000;
/** The calendar day of an instant in a station's time zone (Sweden's unless told otherwise). */
const localDate = (ms: number, tz: string = COUNTRIES.SE.tz) => new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(ms);
/** The live window: an hour back (so a just-missed train still shows) to 12 hours ahead. */
export const WINDOW_BEFORE_MS = 60 * 60_000;
export const WINDOW_AFTER_MS = 12 * 3600_000;

type Listener = (b: Board) => void;

interface Poller {
  listeners: Set<Listener>;
  memory: PlatformMemory;
  last: Board | null;
  inflight: Promise<Board> | null;
  timer: ReturnType<typeof setInterval> | null;
  idleSince: number | null;
}

export interface BoardHubOptions {
  fetchImpl?: typeof fetch;
  now?: () => number;
  pollMs?: number;
  log?: (m: string) => void;
}

export class BoardHub {
  private pollers = new Map<string, Poller>();
  private names = new Map<string, string>();
  private matchBrand = brandMatcher(loadBrands());
  /** Upstream queries made, for tests and the acceptance check "two tabs, one poll". */
  upstreamCalls = 0;

  constructor(
    private db: Db,
    private opts: BoardHubOptions = {},
  ) {}

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  private stationName(sig: string): string {
    if (!this.names.size)
      for (const l of this.db.select({ s: trvLocations.signature, n: trvLocations.name }).from(trvLocations).all()) this.names.set(l.s.toLowerCase(), l.n);
    return this.names.get(sig.toLowerCase()) ?? sig;
  }

  signatureOf(stationId: string): string | null {
    return this.db.select({ sig: stations.trvSignature }).from(stations).where(eq(stations.id, stationId)).get()?.sig ?? null;
  }

  /**
   * Where a station's board comes from: Trafikverket for Swedish stations (its codes for foreign ones, "No.osl",
   * have no announcements), Entur's Journey Planner for stations Norway's feeds serve, Digitraffic for Finland's,
   * Rejseplanen for Denmark's (by UIC number), and the timetable alone for any other rail station.
   */
  sourceOf(stationId: string): { kind: 'trv' | 'entur' | 'digitraffic' | 'rejseplanen' | 'timetable'; id: string } | null {
    const s = this.db
      .select({ sig: stations.trvSignature, nsr: stations.nsrId, fi: stations.fiId, country: stations.country, kind: stations.kind })
      .from(stations)
      .where(eq(stations.id, stationId))
      .get();
    if (s?.sig && !s.sig.includes('.')) return { kind: 'trv', id: s.sig };
    if (s?.nsr) return { kind: 'entur', id: s.nsr };
    // Haparanda has a Swedish signature too, so its board is Trafikverket's; Finnish stations are Digitraffic's.
    if (s?.fi) return { kind: 'digitraffic', id: s.fi };
    const uic = s?.country === 'DK' ? uicOfStation(stationId) : null;
    if (uic) return { kind: 'rejseplanen', id: uic };
    if (s?.kind === 'rail_station') return { kind: 'timetable', id: stationId };
    return null;
  }

  private _matcher: TripMatcher | null = null;
  private get matcher() {
    return (this._matcher ??= new TripMatcher(this.db));
  }

  /** A station's name by UIC number (Danish ids, else uic:…); null when we don't have it. */
  private uicName(uic: string): string | null {
    return stationOfUic(this.db, uic)?.name ?? null;
  }

  private tzOf(stationId: string): string {
    return this.db.select({ tz: stations.tz }).from(stations).where(eq(stations.id, stationId)).get()?.tz ?? COUNTRIES.SE.tz;
  }

  /** Fetch and normalise a board for any window (used by the poller and for "Show earlier"). */
  async load(stationId: string, type: BoardType, from: number, to: number, memory: PlatformMemory = new Map()): Promise<Board> {
    const source = this.sourceOf(stationId);
    if (!source) throw new Error('This station has no live departures');
    this.upstreamCalls++;
    const now = this.now();
    const tz = this.tzOf(stationId);
    const dates = [...new Set([localDate(from, tz), localDate(now, tz), localDate(to, tz)])];
    const calls = callsAtStation(this.db, stationId, dates);
    let rows;
    let live = true;
    if (source.kind === 'rejseplanen') {
      try {
        // One answer holds about 100 trains, so it starts 20 minutes back rather than the window's hour: a busy
        // station's board then reaches a few hours ahead instead of ending soon after now.
        const start = Math.max(from, now - 20 * 60_000);
        const entries = await rejseplanen().stationBoard(source.id, type === 'departures' ? 'DEP' : 'ARR', start, Math.ceil((to - start) / 60_000));
        rows = normalizeDenmarkBoard(entries, { type, now, from, to, calls, memory, matcher: this.matcher, names: (u) => this.uicName(u) });
      } catch (e) {
        // Rejseplanen resting, at its limit or down: the timetable, saying so.
        this.opts.log?.(`board ${stationId}: Rejseplanen unavailable (${(e as Error).message}); timetable only`);
        rows = timetableRows(this.db, stationId, calls, type, from, to, now);
        live = false;
      }
    } else if (source.kind === 'timetable') {
      rows = timetableRows(this.db, stationId, calls, type, from, to, now);
      live = false;
    } else if (source.kind === 'digitraffic') {
      const trains = await fetchFinlandBoardTrains(source.id, { fetchImpl: this.opts.fetchImpl, now });
      // The unit types for today's trains: one cached request a quarter of an hour, and the board is fine without it.
      const vehicles = await fetchDayVehicles(localDate(now, tz), { fetchImpl: this.opts.fetchImpl, now }).catch(() => new Map<string, string>());
      rows = normalizeFinlandBoard(trains, {
        type,
        now,
        code: source.id,
        from,
        to,
        names: (code) => this.fiName(code),
        calls,
        memory,
        vehicleOf: (n, d) => (d === localDate(now, tz) ? (vehicles.get(n) ?? null) : null),
      });
    } else if (source.kind === 'trv') {
      rows = normalizeBoard(await fetchBoardRows(source.id, type, from, to, this.opts.fetchImpl), {
        type,
        now,
        names: (s) => this.stationName(s),
        matchBrand: this.matchBrand,
        calls,
        memory,
      });
    } else {
      rows = normalizeNorwayBoard(await fetchNorwayCalls(source.id, type, from, to, this.opts.fetchImpl), { type, now, calls, memory });
    }
    // What left, and how late: the history behind "this train has often left late" (legs/risk.ts).
    if (source.kind === 'trv' && type === 'departures')
      recordObservations(
        this.db,
        rows.filter((r) => r.done || r.canceled).map((r) => ({ trainNumber: r.trainNumber, signature: source.id, advertised: r.advertised, actual: r.actual, canceled: r.canceled, serviceDate: r.trip?.serviceDate ?? localDate(r.advertised, tz) })),
      );
    return { stationId, signature: source.id, type, from, to, updatedAt: now, live, rows } satisfies Board;
  }

  /** A Finnish station's name by Digitraffic short code (stations.fi_id); the code itself when we don't have it. */
  private fiName(code: string): string {
    return this.db.select({ name: stations.name }).from(stations).where(eq(stations.fiId, code)).get()?.name ?? code;
  }

  private key(stationId: string, type: BoardType) {
    return `${stationId}|${type}`;
  }

  private poller(stationId: string, type: BoardType): Poller {
    const k = this.key(stationId, type);
    let p = this.pollers.get(k);
    if (!p) {
      p = { listeners: new Set(), memory: new Map(), last: null, inflight: null, timer: null, idleSince: null };
      this.pollers.set(k, p);
    }
    return p;
  }

  private refresh(stationId: string, type: BoardType): Promise<Board> {
    const p = this.poller(stationId, type);
    if (p.inflight) return p.inflight;
    const now = this.now();
    p.inflight = this.load(stationId, type, now - WINDOW_BEFORE_MS, now + WINDOW_AFTER_MS, p.memory)
      .then((b) => {
        p.last = b;
        for (const l of p.listeners) l(b);
        return b;
      })
      .finally(() => {
        p.inflight = null;
      });
    return p.inflight;
  }

  /** The current live board: from memory when fresh, otherwise fetched (shared with anyone else asking). */
  async current(stationId: string, type: BoardType): Promise<Board> {
    const p = this.poller(stationId, type);
    if (p.last && this.now() - p.last.updatedAt < (this.opts.pollMs ?? BOARD_POLL_MS)) return p.last;
    return this.refresh(stationId, type);
  }

  /** Start receiving live updates. Returns the unsubscribe function. */
  subscribe(stationId: string, type: BoardType, listener: Listener): () => void {
    const p = this.poller(stationId, type);
    p.listeners.add(listener);
    p.idleSince = null;
    if (!p.timer) {
      p.timer = setInterval(() => {
        if (!p.listeners.size) {
          // Nobody watching: stop after the idle grace period.
          if (p.idleSince !== null && this.now() - p.idleSince > IDLE_MS) this.stop(stationId, type);
          return;
        }
        this.refresh(stationId, type).catch((e) => this.opts.log?.(`board ${stationId}: ${(e as Error).message}`));
      }, this.opts.pollMs ?? BOARD_POLL_MS);
    }
    return () => {
      p.listeners.delete(listener);
      if (!p.listeners.size) p.idleSince = this.now();
    };
  }

  viewers(stationId: string, type: BoardType) {
    return this.pollers.get(this.key(stationId, type))?.listeners.size ?? 0;
  }

  private stop(stationId: string, type: BoardType) {
    const k = this.key(stationId, type);
    const p = this.pollers.get(k);
    if (p?.timer) clearInterval(p.timer);
    this.pollers.delete(k);
  }

  close() {
    for (const p of this.pollers.values()) if (p.timer) clearInterval(p.timer);
    this.pollers.clear();
  }
}
