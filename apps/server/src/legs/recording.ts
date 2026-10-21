// Did you ride it? (product brief §8.) A saved trip is a plan; it only counts as travelled with evidence. The
// evidence and the thresholds live here, in one pure function, so they can be tested and tuned in one place.
//
// Evidence used: Trafikverket's actual departure at the stop you got on and actual arrival at the stop you got off
// (matched by station, activity and minute, so it is this train), cancellations, and your own answers. A train's
// position never counts as you being on it, and following a train on the map is not a trip at all.
import { and, eq, ne, or } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { legs } from '../db/schema.js';

export const RIDES = ['pending', 'auto', 'confirmed', 'review', 'not_taken'] as const;
export type Ride = (typeof RIDES)[number];
/** The ones that count as travelled (Passport, statistics, milestones). */
export const COUNTED_RIDES: readonly Ride[] = ['auto', 'confirmed'];

export const RECORDING = {
  /** After the (expected) arrival, wait this long for late reports before asking. */
  reviewAfterMs: 2 * 3600_000,
};

export interface RideEvidence {
  current: Ride;
  /** Timetabled arrival where you got off. */
  schedArr: number | null;
  /** Trafikverket's actual times at your boarding / alighting stops. */
  actualDep: number | null;
  actualArr: number | null;
  canceled: boolean;
  /** When the trip was saved: saving it after it arrived is you saying you rode it. */
  createdAt: number;
  /** Trafikverket no longer has the train (older than its ~4-day history): no more reports will come. */
  reportsGone: boolean;
  now: number;
}

export function evaluateRide(e: RideEvidence): { ride: Ride; reason: string } {
  // Your answers stand; new data never overrides them.
  if (e.current === 'confirmed' || e.current === 'not_taken') return { ride: e.current, reason: 'you' };
  if (e.schedArr !== null && e.createdAt > e.schedArr) return { ride: 'confirmed', reason: 'added_after' };
  const arrival = e.actualArr ?? e.schedArr;
  if (arrival === null || e.now < arrival) return { ride: 'pending', reason: 'not_arrived' };
  // Cancelled where you got on or off: maybe you took a replacement bus or another train. Ask.
  if (e.canceled) return { ride: 'review', reason: 'cancelled' };
  if (e.actualDep !== null && e.actualArr !== null) return { ride: 'auto', reason: 'actual_times' };
  if (!e.reportsGone && e.now - arrival < RECORDING.reviewAfterMs) return { ride: 'pending', reason: 'waiting_reports' };
  return { ride: 'review', reason: e.actualDep !== null || e.actualArr !== null ? 'partial_reports' : 'no_reports' };
}

/** Re-evaluates one leg (or all of a user's undecided legs) and stores the result only when it changed. Idempotent. */
export function updateRides(db: Db, opts: { legId?: string; now?: number } = {}): number {
  const now = opts.now ?? Date.now();
  const rows = db
    .select({ id: legs.id, ride: legs.ride, rideReason: legs.rideReason, schedArr: legs.schedArr, actualDep: legs.actualDep, actualArr: legs.actualArr, canceled: legs.canceled, createdAt: legs.createdAt, status: legs.status })
    .from(legs)
    .where(opts.legId ? eq(legs.id, opts.legId) : and(ne(legs.ride, 'confirmed'), ne(legs.ride, 'not_taken')))
    .all();
  let changed = 0;
  for (const r of rows) {
    const next = evaluateRide({
      current: r.ride as Ride,
      schedArr: r.schedArr?.getTime() ?? null,
      actualDep: r.actualDep?.getTime() ?? null,
      actualArr: r.actualArr?.getTime() ?? null,
      canceled: r.canceled,
      createdAt: r.createdAt.getTime(),
      reportsGone: r.status === 'snapshotted',
      now,
    });
    if (next.ride === r.ride && next.reason === r.rideReason) continue;
    db.update(legs).set({ ride: next.ride, rideReason: next.reason }).where(eq(legs.id, r.id)).run();
    changed++;
  }
  return changed;
}

/** Your answer to "Did you take this train?": yes, no, or undo (back to what the evidence says). */
export function answerRide(db: Db, userId: string, legId: string, answer: 'yes' | 'no' | 'undo', now = Date.now()): boolean {
  const owned = db.select({ id: legs.id }).from(legs).where(and(eq(legs.id, legId), eq(legs.userId, userId))).get();
  if (!owned) return false;
  if (answer === 'undo') {
    db.update(legs).set({ ride: 'pending', rideReason: null }).where(eq(legs.id, legId)).run();
    updateRides(db, { legId, now });
  } else db.update(legs).set({ ride: answer === 'yes' ? 'confirmed' : 'not_taken', rideReason: 'you' }).where(eq(legs.id, legId)).run();
  return true;
}

export const countedRide = (ride: string) => (COUNTED_RIDES as readonly string[]).includes(ride);
export const rideFilter = () => or(eq(legs.ride, 'auto'), eq(legs.ride, 'confirmed'));
