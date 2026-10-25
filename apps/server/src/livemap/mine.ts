// Which of your legs still get the ring on the live map (owner, 2026-10-25: "the yellow ring hasn't gone after I got off").
// The tracker keeps a leg for half an hour after it ends (to log the arrival); the ring is for a train you are on or about
// to board, so it goes as soon as the train has reached where you get off.

/** Minutes after the expected arrival that a leg with no arrival recorded keeps its ring. */
export const RING_GRACE_MIN = 2;

export interface RingLeg {
  /** Recorded arrival at your stop, when the tracker has seen it. */
  actualArr: Date | null;
  schedArr: Date | null;
  /** Minutes late at the arrival, as last known. */
  arrDelayMin: number | null;
  /** The live estimate of the arrival, when there is one. */
  arrivalEta: Date | null;
}

export function ringStillOn(leg: RingLeg, now: number): boolean {
  if (leg.actualArr) return false;
  const end = leg.arrivalEta?.getTime() ?? (leg.schedArr ? leg.schedArr.getTime() + (leg.arrDelayMin ?? 0) * 60_000 : null);
  return end === null || now <= end + RING_GRACE_MIN * 60_000;
}
