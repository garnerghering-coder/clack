// Train types (rolling stock). No open source says which vehicle ran a train (data/train_types.json explains),
// so a leg starts with the typical type for its operator and product. Once Trafikverket's planned coach order is
// fetched it can pin the type down (SJ: X2000 or SJ 3000), and the owner can always correct it.
import { and, eq, isNull } from 'drizzle-orm';
import type { AmenityEntry } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legs, timetableTrips } from '../db/schema.js';
import { readDataFile } from '../dataFiles.js';
import { productOf } from '../search/timetable.js';

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
  match: { operator?: string; product?: string; number_min?: number; number_max?: number };
  type: string;
}
interface CompositionRule {
  match: { operator?: string; product?: string; locomotive?: boolean; cars?: number; cars_max?: number };
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

/** The type the coach order pins down, if a composition rule covers it. */
export function typeFromComposition(operatorId: string | null, product: string, comp: Composition | null): string | null {
  if (!comp) return null;
  for (const r of trainTypeCatalog().composition_rules ?? []) {
    const m = r.match;
    if (m.operator && m.operator !== operatorId) continue;
    if (m.product && m.product !== product) continue;
    if (m.locomotive !== undefined && m.locomotive !== comp.locomotive) continue;
    if (m.cars !== undefined && m.cars !== comp.cars) continue;
    if (m.cars_max !== undefined && comp.cars > m.cars_max) continue;
    return r.type;
  }
  return null;
}

/** Best type known for a departure: from its coach order when that decides it, else the typical one. */
export function trainTypeFor(operatorId: string | null, product: string, trainNumber: string | null, comp: Composition | null) {
  return typeFromComposition(operatorId, product, comp) ?? typicalTrainType(operatorId, product, trainNumber);
}

export function typicalTrainType(operatorId: string | null, product: string, trainNumber: string | null): string | null {
  const n = trainNumber ? Number(trainNumber) : NaN;
  for (const r of trainTypeCatalog().rules) {
    const m = r.match;
    if (m.operator && m.operator !== operatorId) continue;
    if (m.product && m.product !== product) continue;
    if (m.number_min !== undefined && !(n >= m.number_min)) continue;
    if (m.number_max !== undefined && !(n <= m.number_max)) continue;
    return r.type;
  }
  return null;
}

/** Fills in the typical type for legs saved before train types existed. Never overrides the owner's choice. */
export function backfillTrainTypes(db: Db): number {
  const todo = db
    .select({ id: legs.id, operatorId: legs.operatorId, trainNumber: legs.trainNumber, routeType: timetableTrips.routeType, category: timetableTrips.category })
    .from(legs)
    .leftJoin(timetableTrips, eq(timetableTrips.key, legs.timetableTripKey))
    .where(and(isNull(legs.trainType), isNull(legs.trainTypeSource)))
    .all();
  let n = 0;
  for (const l of todo) {
    const type = typicalTrainType(l.operatorId, productOf(l.routeType ?? '', l.category ?? ''), l.trainNumber);
    if (!type) continue;
    db.update(legs).set({ trainType: type, trainTypeSource: 'typical' }).where(eq(legs.id, l.id)).run();
    n++;
  }
  return n;
}
