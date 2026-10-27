// Denmark's trains for the live map, from Rejseplanen (rejseplanen/client.ts): one position answer for the whole
// country every DENMARK_POLL_MS while someone is looking at the map. Rejseplanen works the positions out from live
// delays (not GPS), so every Danish train is drawn as estimated. Trains are linked to the Danish timetable by their
// journey's ends (rejseplanen/match.ts); trains Sweden's feed also has are left to the ingest to draw once.
import { eq } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { stations } from '../db/schema.js';
import { danishStationId } from '../import/gtfs-dk.js';
import { productOfCategory } from '../boards/denmark.js';
import { rejseplanen, type Journey, type RejseplanenClient } from '../rejseplanen/client.js';
import { TripMatcher } from '../rejseplanen/match.js';
import type { Product } from '../search/timetable.js';

export const DENMARK_POLL_MS = 20_000;
/** A train whose last position is older than this is dropped (Rejseplanen stopped listing it). */
const MAX_AGE_MS = 2 * 60_000;

export interface DenmarkTrain {
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
  private names = new Map<string, string | null>();
  upstreamAt = 0;

  constructor(
    private readonly db: Db,
    private readonly opts: { now?: () => number; client?: RejseplanenClient } = {},
  ) {
    this.matcher = new TripMatcher(db);
  }

  private now() {
    return (this.opts.now ?? Date.now)();
  }

  private name(uic: string | undefined): string | null {
    if (!uic) return null;
    if (!this.names.has(uic)) {
      const id = uic.startsWith('86') ? danishStationId(uic) : `uic:${uic}`;
      this.names.set(uic, this.db.select({ n: stations.name }).from(stations).where(eq(stations.id, id)).get()?.n ?? null);
    }
    return this.names.get(uic)!;
  }

  async poll(): Promise<void> {
    const client = this.opts.client ?? rejseplanen();
    if (!client.available()) return;
    this.journeys = (await client.journeyGeoPos()).filter((j) => j.pos && j.category !== 'Togbus');
    this.upstreamAt = this.now();
  }

  trains(): DenmarkTrain[] {
    const now = this.now();
    const out: DenmarkTrain[] = [];
    for (const j of this.journeys) {
      const matched = this.matcher.match(j.date, j.ends);
      const number = j.number ?? matched?.trainNumber ?? null;
      if (!number || !j.pos) continue;
      const key = `${number}|${j.date}`;
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
        number,
        date: j.date,
        lat: j.pos.lat,
        lon: j.pos.lon,
        bearing,
        at: this.upstreamAt,
        operatorId: matched?.operatorId ?? null,
        productName: j.category,
        product: productOfCategory(j.category),
        origin: this.name(j.ends?.firstUic),
        destination: this.name(j.ends?.lastUic) ?? j.direction,
        next: next?.name ?? null,
        nextEta: eta,
        delayMin: planned !== null && eta !== null ? Math.round((eta - planned) / 60_000) : null,
        tripKey: matched?.tripKey ?? null,
        inDanishTimetable: Boolean(matched),
      });
    }
    for (const [k, v] of this.seen) if (now - v.at > 6 * 3600_000) this.seen.delete(k);
    return this.upstreamAt && now - this.upstreamAt <= MAX_AGE_MS ? out : [];
  }
}
