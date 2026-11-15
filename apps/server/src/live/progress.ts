// Where a tracked train is and what changed (DESIGN §9). The position rules are shared with the app
// (@clack/shared progress); what changed between two snapshots is the server's.
export {
  BOARDING_MS,
  cumulative,
  DEAD_RECKONING_MS,
  expectedTimes,
  GPS_FRESH_MS,
  liveView,
  locate,
  pointAt,
  type GpsFix,
  type LiveStatus,
  type LiveStop,
  type LiveView,
} from '@clack/shared';
import { cancellationOf, type CallFlag } from '@clack/shared';

export interface LegSummary {
  arrivalDelayMin: number | null;
  depPlatform: string | null;
  arrPlatform: string | null;
  canceled: boolean;
  /** Stations on the ridden part that are cancelled (a short-turn when the train still runs part of the way). */
  canceledStops: string[];
  /** The whole trip's stops in order with their roles and per-role flags: says where a part-way train starts or ends. */
  stops?: (CallFlag & { name: string })[];
  departedAt: number | null;
  arrivedAt: number | null;
}

export interface LegEvent {
  type: 'delayed' | 'platform_set' | 'platform_changed' | 'cancelled' | 'short_turned' | 'departed' | 'arrived';
  payload: Record<string, unknown>;
}

/** Events between two snapshots of a leg (DESIGN §9.3). Small delay wobbles (< 3 min) aren't worth an event. */
export function diffEvents(before: LegSummary, after: LegSummary): LegEvent[] {
  const out: LegEvent[] = [];
  if (!before.canceled && after.canceled) out.push({ type: 'cancelled', payload: {} });
  const newCanceled = after.canceledStops.filter((s) => !before.canceledStops.includes(s));
  if (!after.canceled && newCanceled.length) {
    // Where it now starts or ends on your part, when it doesn't run all of it (build 86: "runs only to X").
    const run = after.stops ? cancellationOf(after.stops) : null;
    const name = (id: string | null) => (id ? (after.stops?.find((s) => s.stationId === id)?.name ?? null) : null);
    const partial =
      run?.kind === 'partial'
        ? { runsFrom: run.runsFrom, runsFromName: name(run.runsFrom), startsThere: run.startsThere, runsTo: run.runsTo, runsToName: name(run.runsTo), endsThere: run.endsThere }
        : {};
    out.push({ type: 'short_turned', payload: { stationIds: newCanceled, ...partial } });
  }
  if (before.departedAt === null && after.departedAt !== null) out.push({ type: 'departed', payload: { at: after.departedAt } });
  if (before.arrivedAt === null && after.arrivedAt !== null) out.push({ type: 'arrived', payload: { at: after.arrivedAt, delayMin: after.arrivalDelayMin } });
  const d0 = before.arrivalDelayMin ?? 0;
  const d1 = after.arrivalDelayMin ?? 0;
  if (after.arrivedAt === null && after.arrivalDelayMin !== null && Math.abs(d1 - d0) >= 3)
    out.push({ type: 'delayed', payload: { delayMin: d1, previousDelayMin: before.arrivalDelayMin } });
  for (const [key, which] of [
    ['depPlatform', 'departure'],
    ['arrPlatform', 'arrival'],
  ] as const)
    if (before[key] && after[key] && before[key] !== after[key]) out.push({ type: 'platform_changed', payload: { which, from: before[key], to: after[key] } });
    else if (!before[key] && after[key]) out.push({ type: 'platform_set', payload: { which, to: after[key] } });
  return out;
}
