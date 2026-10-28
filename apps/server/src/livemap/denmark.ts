// Denmark's trains for the live map, from Rejseplanen (rejseplanen/client.ts): one position answer for the whole
// country every DENMARK_POLL_MS while someone is looking at the map. Rejseplanen works the positions out from live
// delays (not GPS), so every Danish train is drawn as estimated. Trains are linked to the Danish timetable by their
// journey's ends (rejseplanen/match.ts); trains Sweden's feed also has are left to the ingest to draw once.
import type { Db } from '../db/client.js';
import { productOfCategory } from '../boards/denmark.js';
import { rejseplanen, type Journey, type RejseplanenClient } from '../rejseplanen/client.js';
import { stationOfUic, TripMatcher } from '../rejseplanen/match.js';
import { loadBrands } from '../dataFiles.js';
import { rememberJourney } from '../rejseplanen/stops.js';
import type { RailGraph } from '../geo/railGraph.js';
import { DenmarkArchiveFallback } from './denmarkFallback.js';
import type { Product } from '../search/timetable.js';

export const DENMARK_POLL_MS = 20_000;
/** A train whose last position is older than this is dropped (Rejseplanen stopped listing it). */
const MAX_AGE_MS = 2 * 60_000;

/**
 * Rejseplanen's administration codes, for trains whose operator name isn't given (position answers often leave it out).
 * Seen in Rejseplanen's answers on 2026-10-27 (test/fixtures/rejseplanen): the product's `admin`, or the middle of its
 * `lineId` (`030_000087_4653`), next to the operator name in the same answer.
 */
const ADMIN: Record<string, string> = { '000002': 'DSB', '000022': 'DSB S-tog', '000087': 'DSB Vores Tog', '001202': 'Skånetrafiken', '003051': 'Snälltåget AB' };

/** Our brand for a Rejseplanen journey's operator: by its name, or its administration code. Pure given the brands. */
export function operatorOfJourney(j: Pick<Journey, 'operator' | 'admin' | 'category'>, brands = loadBrands()): string | null {
  const name = j.operator ?? (j.admin ? ADMIN[j.admin] : undefined);
  if (!name) return null;
  // Skånetrafiken runs both the Öresund trains (in Denmark since 11 Dec 2022, newsoresund.dk) and Pågatåg.
  if (name === 'Skånetrafiken') return j.category === 'Pågatog' ? 'pagatag' : 'oresundstag';
  return brands.find((b) => b.gtfs_operators.includes(name) || b.gtfs_operators.includes(name.replace(/ AB$| A\/S$/, '')))?.id ?? null;
}

/** Rejseplanen can list a train twice: the full journey, and a stub with no number and the same name and first stop
 * (Snälltåget 21509 Malmö → Berlin, and "Snälltåget 21509" Malmö → Padborg, 27 Oct). Keep the one with a number and
 * the most stops. Pure. */
export function withoutStubs(journeys: Journey[]): Journey[] {
  const best = new Map<string, Journey>();
  const rank = (j: Journey) => (j.number ? 1000 : 0) + j.stops.length;
  const out: Journey[] = [];
  for (const j of journeys) {
    if (!j.name) {
      out.push(j);
      continue;
    }
    const k = `${j.name}|${j.date}|${j.ends?.firstUic ?? ''}`;
    const have = best.get(k);
    // Same name and first stop is a stub only when one of the two has no number: NT runs many "Re 75" at once.
    if (have && (!have.number || !j.number)) {
      if (rank(j) > rank(have)) best.set(k, j);
      continue;
    }
    best.set(have ? `${k}|${j.jid}` : k, j);
  }
  return [...out, ...best.values()];
}

export interface DenmarkTrain {
  /** Unique on the map: the first stop and its planned minute (numbers repeat: four "Re 75" ran at once on 27 Oct). */
  ref: string;
  /** Rejseplanen's journey id, for its stop list when the timetable doesn't have the train. */
  jid: string | null;
  number: string;
  date: string;
  lat: number;
  lon: number;
  bearing: number | null;
  at: number;
  operatorId: string | null;
  productName: string | null;
  product: Product;
  origin: string | null;
  destination: string | null;
  next: string | null;
  nextEta: number | null;
  delayMin: number | null;
  tripKey: string | null;
  /** In the Danish timetable? Trains that aren't (Öresundståg, SJ, Snälltåget) are Sweden's feed's too. */
  inDanishTimetable: boolean;
}

/** Initial compass bearing from a to b, degrees. Pure. */
export function bearingOf(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const r = Math.PI / 180;
  const y = Math.sin((b.lon - a.lon) * r) * Math.cos(b.lat * r);
  const x = Math.cos(a.lat * r) * Math.sin(b.lat * r) - Math.sin(a.lat * r) * Math.cos(b.lat * r) * Math.cos((b.lon - a.lon) * r);
  return Math.round(((Math.atan2(y, x) / r) + 360) % 360);
}

export class DenmarkFeed {
  private journeys: Journey[] = [];
  private seen = new Map<string, { lat: number; lon: number; bearing: number | null; at: number }>();
  private matcher: TripMatcher;
  private fallback: DenmarkArchiveFallback;
  /** Per hour of the day (Copenhagen): trains seen and how many matched the timetable, for the map health report. */
  readonly matchByHour = new Map<number, { trains: number; matched: number }>();
  /** Drawing from the archive because Rejseplanen isn't answering. */
  usingFallback = false;
  upstreamAt = 0;

  constructor(
    private readonly db: Db,
    private readonly opts: { now?: () => number; client?: RejseplanenClient; fetchImpl?: typeof fetch; graph?: () => RailGraph | null } = {},
  ) {
    this.matcher = new TripMatcher(db);
    this.fallback = new DenmarkArchiveFallback(db, { fetchImpl: opts.fetchImpl, now: opts.now, graph: opts.graph });
  }

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  private name(uic: string | undefined): string | null {
    return uic ? (stationOfUic(this.db, uic)?.name ?? null) : null;
  }

  async poll(): Promise<void> {
    const client = this.opts.client ?? rejseplanen();
    try {
      if (!client.available()) throw new Error('Rejseplanen unavailable');
      this.journeys = withoutStubs((await client.journeyGeoPos()).filter((j) => j.pos && j.category !== 'Togbus'));
      this.upstreamAt = this.now();
      this.usingFallback = false;
    } catch (e) {
      // Rejseplanen resting, blocked or off: the archive's latest delays place the trains instead.
      this.usingFallback = true;
      await this.fallback.refresh();
      if (!this.fallback.upstreamAt) throw e;
    }
  }

  trains(): DenmarkTrain[] {
    if (this.usingFallback) return this.fallback.trains();
    const now = this.now();
    const out: DenmarkTrain[] = [];
    for (const j of this.journeys) {
      const matched = this.matcher.match(j.date, j.ends);
      rememberJourney(j, matched?.tripKey ?? null);
      const number = j.number ?? matched?.trainNumber ?? null;
      if (!number || !j.pos) continue;
      const ref = j.ends ? `${j.ends.firstUic}.${j.ends.firstMin}` : j.jid;
      const key = `${ref}|${j.date}`;
      // Heading from the last position, when it has moved enough to say.
      const prev = this.seen.get(key);
      const moved = prev && Math.hypot((j.pos.lat - prev.lat) * 111_000, (j.pos.lon - prev.lon) * 63_000) > 30;
      const bearing = moved ? bearingOf(prev, j.pos) : (prev?.bearing ?? null);
      this.seen.set(key, { lat: j.pos.lat, lon: j.pos.lon, bearing, at: this.upstreamAt });
      // The next stop: the first whose time is still ahead.
      const next = j.stops.find((s) => (s.arrLive ?? s.arrPlanned ?? s.depLive ?? s.depPlanned ?? 0) > now) ?? null;
      const planned = next ? (next.arrPlanned ?? next.depPlanned) : null;
      const eta = next ? (next.arrLive ?? next.depLive ?? planned) : null;
      out.push({
        ref,
        jid: j.jid,
        number,
        date: j.date,
        lat: j.pos.lat,
        lon: j.pos.lon,
        bearing,
        at: this.upstreamAt,
        operatorId: matched?.operatorId ?? operatorOfJourney(j),
        productName: j.category,
        product: productOfCategory(j.category),
        origin: this.name(j.ends?.firstUic) ?? j.stops[0]?.name ?? null,
        destination: this.name(j.ends?.lastUic) ?? j.direction,
        next: next?.name ?? null,
        nextEta: eta,
        delayMin: planned !== null && eta !== null ? Math.round((eta - planned) / 60_000) : null,
        tripKey: matched?.tripKey ?? null,
        inDanishTimetable: Boolean(matched),
      });
    }
    const hour = Number(new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/Copenhagen', hour: '2-digit', hourCycle: 'h23' }).format(now));
    this.matchByHour.set(hour, { trains: out.length, matched: out.filter((t) => t.tripKey).length });
    for (const [k, v] of this.seen) if (now - v.at > 6 * 3600_000) this.seen.delete(k);
    return this.upstreamAt && now - this.upstreamAt <= MAX_AGE_MS ? out : [];
  }
}

export interface MapHealth {
  at: number;
  countries: Record<string, { trains: number; noOrigin: number; noDestination: number; noNext: number; noOperator: number; noType: number; noTimetableTrip: number }>;
  /** Numbers shown by more than one train at once in a country (allowed, but each should be its own train). */
  sharedNumbers: Record<string, string[]>;
  operators: Record<string, { trains: number; noType: number }>;
  denmarkMatchByHour: Record<string, string>;
}

/** What the live map is missing, per country and operator: the report run before each build. Pure. */
export function mapHealth(trains: Iterable<import('./ingest.js').LiveTrain>, matchByHour: Map<number, { trains: number; matched: number }>, now = Date.now()): MapHealth {
  const countries: MapHealth['countries'] = {};
  const numbers = new Map<string, Map<string, number>>();
  const operators: MapHealth['operators'] = {};
  for (const t of trains) {
    const c = t.id.startsWith('dk:') ? 'DK' : t.id.startsWith('fi:') ? 'FI' : t.id.startsWith('no:') ? 'NO' : 'SE';
    const k = (countries[c] ??= { trains: 0, noOrigin: 0, noDestination: 0, noNext: 0, noOperator: 0, noType: 0, noTimetableTrip: 0 });
    k.trains++;
    if (!t.origin) k.noOrigin++;
    if (!t.destination) k.noDestination++;
    if (!t.next) k.noNext++;
    if (!t.operatorId) k.noOperator++;
    if (!t.trainType) k.noType++;
    if (t.tripKey === null) k.noTimetableTrip++;
    const n = numbers.get(c) ?? numbers.set(c, new Map()).get(c)!;
    n.set(t.number, (n.get(t.number) ?? 0) + 1);
    const o = (operators[t.operatorId ?? '(none)'] ??= { trains: 0, noType: 0 });
    o.trains++;
    if (!t.trainType) o.noType++;
  }
  const sharedNumbers: MapHealth['sharedNumbers'] = {};
  for (const [c, n] of numbers) sharedNumbers[c] = [...n].filter(([, v]) => v > 1).map(([num, v]) => `${num}×${v}`);
  const denmarkMatchByHour: MapHealth['denmarkMatchByHour'] = {};
  for (const [h, v] of [...matchByHour].sort((a, b) => a[0] - b[0])) denmarkMatchByHour[String(h).padStart(2, '0')] = `${v.matched}/${v.trains}`;
  return { at: now, countries, sharedNumbers, operators, denmarkMatchByHour };
}
