// Journeys (SPEC §13): consecutive legs become one journey when the next train leaves from the station the previous
// one arrived at, on the same day, within 4 hours. Regrouped whenever legs change; manual split/merge comes later.
import { and, eq, inArray, notInArray } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { journeys, legs } from '../db/schema.js';

export const MAX_TRANSFER_MS = 4 * 3600_000;

export interface GroupableLeg {
  id: string;
  originStationId: string;
  destStationId: string;
  dep: number;
  arr: number;
}

const localDay = (ms: number) => new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Stockholm' }).format(ms);

/** Legs in departure order, split into journeys. Pure, for tests. */
export function groupLegs(list: GroupableLeg[]): GroupableLeg[][] {
  const sorted = [...list].sort((a, b) => a.dep - b.dep);
  const out: GroupableLeg[][] = [];
  for (const l of sorted) {
    const cur = out.at(-1);
    const prev = cur?.at(-1);
    const gap = prev ? l.dep - prev.arr : Infinity;
    if (cur && prev && prev.destStationId === l.originStationId && gap >= 0 && gap <= MAX_TRANSFER_MS && localDay(prev.arr) === localDay(l.dep)) cur.push(l);
    else out.push([l]);
  }
  return out;
}

/** Recomputes the user's journeys and stores legs.journey_id. A journey's id is its first leg's id. */
export function regroupJourneys(db: Db, userId: string) {
  const rows = db
    .select({ id: legs.id, originStationId: legs.originStationId, destStationId: legs.destStationId, schedDep: legs.schedDep, schedArr: legs.schedArr })
    .from(legs)
    .where(eq(legs.userId, userId))
    .all();
  // Scheduled times decide the plan; a delay doesn't break a journey you actually made.
  const groups = groupLegs(
    rows.map((r) => ({
      id: r.id,
      originStationId: r.originStationId,
      destStationId: r.destStationId,
      dep: r.schedDep?.getTime() ?? 0,
      arr: r.schedArr?.getTime() ?? 0,
    })),
  );
  db.transaction((tx) => {
    const ids: string[] = [];
    for (const g of groups) {
      const jid = `j-${g[0]!.id}`;
      ids.push(jid);
      tx.insert(journeys).values({ id: jid, userId }).onConflictDoNothing().run();
      tx.update(legs)
        .set({ journeyId: jid })
        .where(
          inArray(
            legs.id,
            g.map((l) => l.id),
          ),
        )
        .run();
    }
    if (ids.length)
      tx.delete(journeys)
        .where(and(eq(journeys.userId, userId), notInArray(journeys.id, ids)))
        .run();
    else tx.delete(journeys).where(eq(journeys.userId, userId)).run();
  });
}
