// The kind of train a trip was (owner, 2026-11-15: "is it the right way, and are all getting recorded properly?"): one
// answer, worked out from the same facts every time it is read, so the trip's page, the Passport, the medals and CO₂
// agree and a better rule reaches old trips at once. Only the owner's own choice is stored (legs.user_product), and it
// wins.
//
// Night means a service sold as a night train (sleeper or couchette), never a late seated train (owner's rule):
//  - Sweden: GTFS Sverige 3 says so (route_type 105 'Sleeper Rail'), or the train number is one of those it marks so,
//    or that Trafikverket calls 'SJ Nattåg' / 'EuroNight' (the observed record), or data/night_trains.json lists it.
//    Swedish train numbers are national, so a number older feeds carry without the type still says which train it was.
//  - Norway: Entur's own marking (transportSubmode nightRail), by number, in data/night_trains.json.
//  - Finland: VR's night train type (PYO) on a run that goes past midnight; daytime PYO runs (e.g. 904/933
//    Tampere–Turku) are not night trains.
//  - Denmark: no source marks one; only the listed numbers (Snälltåget's Berlin trains) count, wherever they run.
// High speed follows the feed (owner): route_type 101 (Arlanda Express and Flytoget included), Finland's Pendolino
// (S), and for older Swedish feeds without 101 the numbers the current feed marks 101.
import { and, eq, sql } from 'drizzle-orm';
import { legs } from '../db/schema.js';
import type { Db } from '../db/client.js';
import { readDataFile } from '../dataFiles.js';
import type { Product } from '../search/timetable.js';

export const PRODUCTS: readonly Product[] = ['high_speed', 'intercity', 'night', 'regional', 'commuter', 'heritage'];
export const isProduct = (v: unknown): v is Product => typeof v === 'string' && (PRODUCTS as readonly string[]).includes(v);

export interface KindFacts {
  /** The country the trip starts in. */
  country: string | null;
  operatorId: string | null;
  trainNumber: string | null;
  /** What the importer or the owner put on the trip (intercity, regional, commuter, heritage, …). */
  category: string | null;
  /** The timetable trip's GTFS route_type, when the trip has one. */
  routeType: string | null;
  /** The owner's own choice. */
  userProduct: string | null;
}

export interface KindLists {
  /** Night train numbers per country. */
  night: Record<string, Set<string>>;
  /** Swedish numbers the current feed marks high speed (for older feeds without the type). */
  seHighSpeed: Set<string>;
}

export type KindSource = 'user' | 'feed' | 'rule';

export function classifyProduct(f: KindFacts, lists: KindLists): { product: Product; source: KindSource } {
  if (isProduct(f.userProduct)) return { product: f.userProduct, source: 'user' };
  if (f.category === 'heritage') return { product: 'heritage', source: 'feed' };
  const number = f.trainNumber ?? '';
  const country = f.country ?? 'SE';
  if (f.routeType === '105') return { product: 'night', source: 'feed' };
  if (number && (lists.night[country]?.has(number) || (f.operatorId === 'snalltaget' && lists.night.SE?.has(number)))) return { product: 'night', source: 'rule' };
  if (f.routeType === '101') return { product: 'high_speed', source: 'feed' };
  if (f.category === 'high_speed') return { product: 'high_speed', source: 'feed' };
  if (country === 'SE' && number && lists.seHighSpeed.has(number)) return { product: 'high_speed', source: 'rule' };
  // A "night" the old clock rules gave (Norway, Denmark) or a daytime PYO run: a long-distance seated train.
  if (f.category === 'night') return { product: 'intercity', source: 'rule' };
  return { product: isProduct(f.category) ? f.category : 'regional', source: 'feed' };
}

interface NightFile {
  [country: string]: { numbers?: string[] } | string;
}

let cache: { at: number; lists: KindLists } | null = null;

/** The lists, from data/night_trains.json and the timetable and observed record; worked out at most hourly. */
export function kindLists(db: Db, now = Date.now()): KindLists {
  if (cache && now - cache.at < 3600_000) return cache.lists;
  const file = readDataFile<NightFile>('night_trains.json');
  const night: Record<string, Set<string>> = {};
  for (const [country, v] of Object.entries(file)) if (typeof v === 'object' && v.numbers) night[country] = new Set(v.numbers);
  const add = (country: string, rows: { n: string | null }[]) => {
    const set = (night[country] ??= new Set());
    for (const r of rows) if (r.n) set.add(r.n);
  };
  add('SE', db.all<{ n: string | null }>(sql`select distinct train_number n from timetable_trips where source like 'gtfs_se%' and route_type = '105'`));
  add('SE', db.all<{ n: string | null }>(sql`select distinct train_number n from observed_runs where source = 'trafikverket' and (product like '%Nattåg%' or product like '%EuroNight%')`));
  add('FI', db.all<{ n: string | null }>(sql`
    select distinct t.train_number n from timetable_trips t
    where t.source = 'gtfs_fi' and t.category = 'night'
      and exists (select 1 from timetable_stop_times s where s.trip_key = t.key and s.arr_sec >= 86400)`));
  const seHighSpeed = new Set(
    db.all<{ n: string | null }>(sql`select distinct train_number n from timetable_trips where source like 'gtfs_se%' and route_type = '101'`).flatMap((r) => (r.n ? [r.n] : [])),
  );
  cache = { at: now, lists: { night, seHighSpeed } };
  return cache.lists;
}

/** For tests and after an import: the next ask works the lists out again. */
export const resetKindLists = () => (cache = null);

/** Each trip's timetable route_type, by trip key. */
export function routeTypes(db: Db, keys: (string | null)[]): Map<string, string> {
  const ids = [...new Set(keys.filter((k): k is string => !!k))];
  const out = new Map<string, string>();
  for (let i = 0; i < ids.length; i += 500) {
    const chunk = ids.slice(i, i + 500);
    for (const r of db.all<{ key: string; rt: string }>(sql`select key, route_type rt from timetable_trips where key in (${sql.join(chunk.map((k) => sql`${k}`), sql`, `)})`))
      out.set(r.key, r.rt);
  }
  return out;
}

/** The owner's kind for a trip of theirs (null: back to the rules); false when the trip isn't theirs. */
export function setUserProduct(db: Db, userId: string, id: string, product: Product | null): boolean {
  return db.update(legs).set({ userProduct: product }).where(and(eq(legs.userId, userId), eq(legs.id, id))).run().changes > 0;
}
