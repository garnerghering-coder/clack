// Train types (rolling stock). No open source says which vehicle ran a train (data/train_types.json explains),
// so a leg starts with the typical type for its operator and product. Once Trafikverket's planned coach order is
// fetched it can pin the type down (SJ: X2000 or SJ 3000), and the owner can always correct it.
import { and, eq, isNull, or } from 'drizzle-orm';
import type { AmenityEntry } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legs, timetableTrips } from '../db/schema.js';
import { readDataFile } from '../dataFiles.js';
import { productOf } from '../search/timetable.js';
import { normName } from '../lib/geo.js';

export interface TrainType {
  id: string;
  name: string;
  builder: string | null;
  max_kmh: number | null;
  since: number | null;
  art: string;
  about: string;
}
interface Rule {
  /**
   * `ends`: the trip starts or ends at one of these stations; `both_ends`: it starts and ends at them (a line's
   * stations, so a trip that leaves the line doesn't match). For lines an operator runs with a different type.
   */
  match: { operator?: string; product?: string; number_min?: number; number_max?: number; ends?: string[]; both_ends?: string[]; vehicle_prefix?: string };
  type: string;
}
interface CompositionRule {
  match: { operator?: string; product?: string; locomotive?: boolean; cars?: number; cars_max?: number; both_ends?: string[] };
  type: string;
}
interface Catalog {
  types: TrainType[];
  rules: Rule[];
  composition_rules?: CompositionRule[];
  amenities?: AmenityEntry[];
}

let catalog: Catalog | null = null;
export const trainTypeCatalog = () => (catalog ??= readDataFile<Catalog>('train_types.json'));

export interface Composition {
  locomotive: boolean;
  /** Numbered cars in the first unit (doubled sets list each unit). */
  cars: number;
  units: number;
}

/**
 * Trafikverket's planned coach order, e.g. "Vagnsordning 1-3-4-5-6-7, 8-10-11-12-13-14" (two X2000 sets) or
 * "Vagnsordning Lok-[-6]-5-4-3-2". Other lines in the field ("Långt tåg.", "Café i vagn B") are ignored.
 */
export function parseComposition(texts: (string | { Description?: string })[] | undefined | null): Composition | null {
  for (const t of texts ?? []) {
    const s = typeof t === 'string' ? t : (t.Description ?? '');
    const m = s.match(/^\s*Vagnsordning\s+(.+)$/i);
    if (!m) continue;
    // Snälltåget lists cars with commas ("9,10,11"): only ", " (with a space) separates units.
    const units = m[1]!.split(/,\s+/).map((u) => u.split(/[-,]/).map((c) => c.replace(/[[\]]/g, '').trim()).filter(Boolean));
    const first = units[0] ?? [];
    const locomotive = first.some((c) => /^lok$/i.test(c));
    const cars = first.filter((c) => !/^lok$/i.test(c)).length;
    if (!cars) continue;
    return { locomotive, cars, units: units.length };
  }
  return null;
}

/** A station name for matching ends: feeds differ on the "C" ("Hässleholm" / "Hässleholm C"). */
const endKey = (name: string) => normName(name).replace(/ c$/, '');

/** The type the coach order pins down, if a composition rule covers it. `ends`: as for typicalTrainType. */
export function typeFromComposition(operatorId: string | null, product: string, comp: Composition | null, ends?: (string | null | undefined)[]): string | null {
  if (!comp) return null;
  const endNames = new Set((ends ?? []).filter((e): e is string => !!e).map(endKey));
  for (const r of trainTypeCatalog().composition_rules ?? []) {
    const m = r.match;
    if (m.both_ends && !(endNames.size && [...endNames].every((e) => m.both_ends!.some((b) => endKey(b) === e)))) continue;
    if (m.operator && m.operator !== operatorId) continue;
    if (m.product && m.product !== product) continue;
    if (m.locomotive !== undefined && m.locomotive !== comp.locomotive) continue;
    if (m.cars !== undefined && m.cars !== comp.cars) continue;
    if (m.cars_max !== undefined && comp.cars > m.cars_max) continue;
    return r.type;
  }
  return null;
}

/** SJ's Storlien–Trondheim trains come through Trafikverket as "SJ", but SJ Nord runs them (jernbane.net 2026; Norske tog). */
export function brandOnLine(operatorId: string | null, ends: (string | null | undefined)[]): string | null {
  if (operatorId === 'sj' && ends.some((e) => e && normName(e).startsWith('trondheim'))) return 'sj-nord';
  return operatorId;
}

/** Best type known for a departure: from its coach order when that decides it, else the typical one. */
export function trainTypeFor(operatorId: string | null, product: string, trainNumber: string | null, comp: Composition | null, ends?: (string | null | undefined)[], vehicle?: string | null) {
  return typeFromComposition(operatorId, product, comp, ends) ?? typicalTrainType(operatorId, product, trainNumber, ends, vehicle);
}

/**
 * `ends`: the trip's first and last stations, where known (a rule with `ends` is skipped without them). `vehicle`: the
 * set running it, where the live feed names it (a `vehicle_prefix` rule is skipped without it).
 */
export function typicalTrainType(operatorId: string | null, product: string, trainNumber: string | null, ends?: (string | null | undefined)[], vehicle?: string | null): string | null {
  const n = trainNumber ? Number(trainNumber) : NaN;
  const endNames = new Set((ends ?? []).filter((e): e is string => !!e).map(endKey));
  for (const r of trainTypeCatalog().rules) {
    const m = r.match;
    if (m.operator && m.operator !== operatorId) continue;
    if (m.product && m.product !== product) continue;
    if (m.number_min !== undefined && !(n >= m.number_min)) continue;
    if (m.number_max !== undefined && !(n <= m.number_max)) continue;
    if (m.ends && !m.ends.some((e) => endNames.has(endKey(e)))) continue;
    if (m.vehicle_prefix && !vehicle?.startsWith(m.vehicle_prefix)) continue;
    if (m.both_ends && !(endNames.size && [...endNames].every((e) => m.both_ends!.some((b) => endKey(b) === e)))) continue;
    return r.type;
  }
  return null;
}

/**
 * Fills in the typical type for legs saved before train types existed, and re-derives the ones that are only
 * typical, so a corrected rule reaches trips already saved. Never overrides the owner's choice or a coach order.
 */
export function backfillTrainTypes(db: Db): number {
  const todo = db
    .select({ id: legs.id, trainType: legs.trainType, operatorId: legs.operatorId, trainNumber: legs.trainNumber, routeType: timetableTrips.routeType, category: timetableTrips.category })
    .from(legs)
    .leftJoin(timetableTrips, eq(timetableTrips.key, legs.timetableTripKey))
    .where(or(and(isNull(legs.trainType), isNull(legs.trainTypeSource)), eq(legs.trainTypeSource, 'typical')))
    .all();
  let n = 0;
  for (const l of todo) {
    const type = typicalTrainType(l.operatorId, productOf(l.routeType ?? '', l.category ?? ''), l.trainNumber);
    if (type === l.trainType) continue;
    if (!type) {
      db.update(legs).set({ trainType: null, trainTypeSource: null }).where(eq(legs.id, l.id)).run();
      n++;
      continue;
    }
    db.update(legs).set({ trainType: type, trainTypeSource: 'typical' }).where(eq(legs.id, l.id)).run();
    n++;
  }
  return n;
}
