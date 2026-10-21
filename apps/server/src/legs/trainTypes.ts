// Train types (rolling stock). No open source says which vehicle ran a train (data/train_types.json explains),
// so a leg starts with the typical type for its operator and product, and the owner can correct it.
import { and, eq, isNull } from 'drizzle-orm';
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

let catalog: { types: TrainType[]; rules: Rule[] } | null = null;
export const trainTypeCatalog = () => (catalog ??= readDataFile<{ types: TrainType[]; rules: Rule[] }>('train_types.json'));

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
