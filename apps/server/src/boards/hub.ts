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

export const BOARD_POLL_MS = Number(process.env.BOARD_POLL_MS ?? 20_000);
/** Kept warm this long after the last viewer leaves (quick back-and-forth navigation stays cheap). */
const IDLE_MS = 60_000;
const localDate = (ms: number) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Stockholm' }).format(ms);
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
   * have no announcements), Entur's Journey Planner for stations Norway's feeds serve.
   */
  sourceOf(stationId: string): { kind: 'trv'; id: string } | { kind: 'entur'; id: string } | null {
    const s = this.db.select({ sig: stations.trvSignature, nsr: stations.nsrId }).from(stations).where(eq(stations.id, stationId)).get();
    if (s?.sig && !s.sig.includes('.')) return { kind: 'trv', id: s.sig };
    if (s?.nsr) return { kind: 'entur', id: s.nsr };
    return null;
  }

  /** Fetch and normalise a board for any window (used by the poller and for "Show earlier"). */
  async load(stationId: string, type: BoardType, from: number, to: number, memory: PlatformMemory = new Map()): Promise<Board> {
    const source = this.sourceOf(stationId);
    if (!source) throw new Error('This station has no live departures');
    this.upstreamCalls++;
    const now = this.now();
    const dates = [...new Set([localDate(from), localDate(now), localDate(to)])];
    const calls = callsAtStation(this.db, stationId, dates);
    const rows =
      source.kind === 'trv'
        ? normalizeBoard(await fetchBoardRows(source.id, type, from, to, this.opts.fetchImpl), {
            type,
            now,
            names: (s) => this.stationName(s),
            matchBrand: this.matchBrand,
            calls,
            memory,
          })
        : normalizeNorwayBoard(await fetchNorwayCalls(source.id, type, from, to, this.opts.fetchImpl), { type, now, calls, memory });
    return { stationId, signature: source.id, type, from, to, updatedAt: now, rows } satisfies Board;
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
