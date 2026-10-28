// Journeys (SPEC §13): consecutive legs become one journey when the next train leaves from the station the previous
// one arrived at within 4 hours, also past midnight (owner, 2026-10-22: SJ 547 into Malmö C at 23:53 and the 00:35
// to the airport are one journey; an overnight stay is longer than 4 hours anyway). Regrouped whenever legs change.
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
  /** Saved together from one planned journey (legs.planned_group). */
  group?: string | null;
}

/** Legs in departure order, split into journeys. Pure, for tests. */
export function groupLegs(list: GroupableLeg[]): GroupableLeg[][] {
  const sorted = [...list].sort((a, b) => a.dep - b.dep);
  const out: GroupableLeg[][] = [];
  for (const l of sorted) {
    const cur = out.at(-1);
    const prev = cur?.at(-1);
    const gap = prev ? l.dep - prev.arr : Infinity;
    // A planned journey stays whole whatever the wait; other legs join when they meet within MAX_TRANSFER_MS.
    const planned = !!l.group && prev?.group === l.group;
    if (cur && prev && (planned || (prev.destStationId === l.originStationId && gap >= 0 && gap <= MAX_TRANSFER_MS))) cur.push(l);
    else out.push([l]);
  }
  return out;
}

/** Recomputes the user's journeys and stores legs.journey_id. A journey's id is its first leg's id. */
export function regroupJourneys(db: Db, userId: string) {
  const rows = db
    .select({ id: legs.id, originStationId: legs.originStationId, destStationId: legs.destStationId, schedDep: legs.schedDep, schedArr: legs.schedArr, group: legs.plannedGroup })
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
      group: r.group,
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
