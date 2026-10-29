// Network status (docs/NETWORK_STATUS.md): where on the network trains are running late right now, from the live map
// alone. A stretch is the track between two stations, as each train's last and next stop name it; it is flagged when
// at least MIN_TRAINS trains are on it and more than half of them are LATE_MIN or more late. Flagged stretches that
// share a station are joined into one corridor ("Hässleholm – Lund – Malmö"), the way a disruption spreads.
import type { DelayCause } from '@clack/shared';
import { countryOfLiveId } from '../lib/countries.js';
import type { LiveTrain } from './ingest.js';

export const LATE_MIN = 10;
export const MIN_TRAINS = 2;

export interface NetworkCause extends DelayCause {
  /** How many of the corridor's late trains give it. */
  trains: number;
}

export interface Corridor {
  /** The stations in order along the corridor, when it is a line; otherwise every station, by name. */
  stations: string[];
  country: string;
  trains: number;
  late: number;
  /** Minutes, over the late trains. */
  medianDelay: number;
  maxDelay: number;
  /** Where to centre the map: the late trains' mean position. */
  lat: number;
  lon: number;
  /** The reasons the feeds give, most-given first. Empty when no feed says why. */
  causes: NetworkCause[];
  /** The late trains' live map ids, for the map to highlight. */
  trainIds: string[];
  /** The track between each pair of neighbouring stations in the corridor, for the map to draw (empty when the
   * stations' ids or the track aren't known). */
  stretches: Stretch[];
  /** The late trains themselves, most late first. */
  lateTrains: CorridorTrain[];
}

export interface Stretch {
  a: string;
  b: string;
  aId: string | null;
  bId: string | null;
  /** Encoded polyline along the track, when both ids are known. */
  polyline: string | null;
}

export interface CorridorTrain {
  id: string;
  number: string;
  operatorId: string | null;
  delayMin: number;
  next: string | null;
  destination: string | null;
  causes: DelayCause[];
}

export interface CountryStatus {
  trains: number;
  /** Trains with a delay known. */
  known: number;
  late: number;
}

/** A train LATE_MIN or more late that isn't part of a corridor: on a calm day, these are the whole story. */
export interface LateTrain {
  id: string;
  number: string;
  operatorId: string | null;
  delayMin: number;
  prev: string | null;
  next: string | null;
  destination: string | null;
  causes: DelayCause[];
}

export interface NetworkStatus {
  at: number;
  lateMin: number;
  countries: Record<string, CountryStatus>;
  corridors: Corridor[];
  /** The most late of the rest, most late first (at most LATE_LIST). */
  late: LateTrain[];
}

export const LATE_LIST = 12;

interface StretchTrains {
  a: string;
  b: string;
  aId: string | null;
  bId: string | null;
  trains: LiveTrain[];
}

const median = (xs: number[]) => {
  const s = [...xs].sort((x, y) => x - y);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m]! : Math.round((s[m - 1]! + s[m]!) / 2);
};

/** Orders a corridor's stations along it when its stretches form one line; else keeps them as met. */
function ordered(stretches: StretchTrains[]): string[] {
  const links = new Map<string, string[]>();
  for (const s of stretches) {
    links.set(s.a, [...(links.get(s.a) ?? []), s.b]);
    links.set(s.b, [...(links.get(s.b) ?? []), s.a]);
  }
  const ends = [...links].filter(([, l]) => l.length === 1).map(([n]) => n);
  const isLine = ends.length === 2 && [...links.values()].every((l) => l.length <= 2);
  if (!isLine) return [...links.keys()];
  const out = [ends[0]!];
  while (out.length < links.size) out.push(links.get(out.at(-1)!)!.find((n) => !out.includes(n))!);
  return out;
}

export type Context = Map<string, { prev: string | null; prevId?: string | null; causes: DelayCause[] }>;

/**
 * `geometry(aId, bId)`: the track between two stations as an encoded polyline, or null; the route passes
 * `segmentBetween`. Without it, corridors carry no stretches.
 */
export function networkStatus(trains: Iterable<LiveTrain>, context: Context, now = Date.now(), geometry?: (aId: string, bId: string) => string | null): NetworkStatus {
  const countries: Record<string, CountryStatus> = {};
  const stretches = new Map<string, StretchTrains>();
  const all = [...trains];
  for (const t of all) {
    const country = countryOfLiveId(t.id);
    const c = (countries[country] ??= { trains: 0, known: 0, late: 0 });
    c.trains++;
    if (t.delayMin !== null) c.known++;
    if ((t.delayMin ?? 0) >= LATE_MIN) c.late++;
    const ctx = context.get(t.id);
    const prev = ctx?.prev;
    if (!prev || !t.next || prev === t.next) continue;
    // Both directions are the same track.
    const flip = prev > t.next;
    const [a, b] = flip ? [t.next, prev] : [prev, t.next];
    const [aId, bId] = flip ? [t.nextId ?? null, ctx?.prevId ?? null] : [ctx?.prevId ?? null, t.nextId ?? null];
    const k = `${a}|${b}`;
    const s = stretches.get(k) ?? stretches.set(k, { a, b, aId, bId, trains: [] }).get(k)!;
    s.aId ??= aId;
    s.bId ??= bId;
    s.trains.push(t);
  }
  const flagged = [...stretches.values()].filter((s) => {
    const late = s.trains.filter((t) => (t.delayMin ?? 0) >= LATE_MIN).length;
    return s.trains.length >= MIN_TRAINS && late * 2 > s.trains.length;
  });
  // Join flagged stretches that share a station (union-find on station names).
  const parent = new Map<string, string>();
  const find = (x: string): string => {
    const p = parent.get(x) ?? x;
    if (p === x) return x;
    const r = find(p);
    parent.set(x, r);
    return r;
  };
  for (const s of flagged) parent.set(find(s.a), find(s.b));
  const groups = new Map<string, StretchTrains[]>();
  for (const s of flagged) {
    const r = find(s.a);
    groups.set(r, [...(groups.get(r) ?? []), s]);
  }
  const corridors: Corridor[] = [...groups.values()].map((group) => {
    const onIt = [...new Map(group.flatMap((s) => s.trains).map((t) => [t.id, t])).values()];
    const late = onIt.filter((t) => (t.delayMin ?? 0) >= LATE_MIN);
    const delays = late.map((t) => t.delayMin!);
    const causes = new Map<string, NetworkCause>();
    for (const t of late)
      for (const c of context.get(t.id)?.causes ?? []) {
        const k = `${c.src}|${c.code ?? c.text}`;
        const had = causes.get(k);
        causes.set(k, had ? { ...had, trains: had.trains + 1 } : { ...c, trains: 1 });
      }
    const byCountry = new Map<string, number>();
    for (const t of late) byCountry.set(countryOfLiveId(t.id), (byCountry.get(countryOfLiveId(t.id)) ?? 0) + 1);
    return {
      stations: ordered(group),
      country: [...byCountry].sort((x, y) => y[1] - x[1])[0]![0],
      trains: onIt.length,
      late: late.length,
      medianDelay: median(delays),
      maxDelay: Math.max(...delays),
      lat: late.reduce((s, t) => s + t.lat, 0) / late.length,
      lon: late.reduce((s, t) => s + t.lon, 0) / late.length,
      causes: [...causes.values()].sort((x, y) => y.trains - x.trains),
      trainIds: late.map((t) => t.id),
      stretches: group.map((s) => ({ a: s.a, b: s.b, aId: s.aId, bId: s.bId, polyline: s.aId && s.bId && geometry ? geometry(s.aId, s.bId) : null })),
      lateTrains: [...late].sort((x, y) => (y.delayMin ?? 0) - (x.delayMin ?? 0)).map((t) => ({ id: t.id, number: t.number, operatorId: t.operatorId, delayMin: t.delayMin ?? 0, next: t.next, destination: t.destination, causes: context.get(t.id)?.causes ?? [] })),
    };
  });
  corridors.sort((x, y) => y.late - x.late || y.medianDelay - x.medianDelay);
  const inCorridor = new Set(corridors.flatMap((c) => c.trainIds));
  const late = all.filter((t) => (t.delayMin ?? 0) >= LATE_MIN && !inCorridor.has(t.id))
    .sort((x, y) => y.delayMin! - x.delayMin!)
    .slice(0, LATE_LIST)
    .map((t) => ({ id: t.id, number: t.number, operatorId: t.operatorId, delayMin: t.delayMin!, prev: context.get(t.id)?.prev ?? null, next: t.next, destination: t.destination, causes: context.get(t.id)?.causes ?? [] }));
  return { at: now, lateMin: LATE_MIN, countries, corridors, late };
}
