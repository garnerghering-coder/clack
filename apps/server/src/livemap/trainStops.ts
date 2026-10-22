// A live-map train's whole route, stop by stop: the timetable's calls with Trafikverket's actual, estimated and
// platform data laid over them, so the train's sheet can list where it has been and where it's going.
import type { Db } from '../db/client.js';
import { eventsFor, fetchAnnouncements, matchAnnouncements, type StopActuals, type StopForMatch } from '../legs/actuals.js';
import { tripStops } from '../search/timetable.js';
import { callsToActuals, serviceJourneyCalls, serviceJourneyFor } from '../entur/calls.js';
import { stations } from '../db/schema.js';
import { inArray } from 'drizzle-orm';

export interface TrainStopView {
  seq: number;
  stationId: string;
  name: string;
  arr: number | null;
  dep: number | null;
  actualArr: number | null;
  actualDep: number | null;
  estimatedArr: number | null;
  estimatedDep: number | null;
  platform: string | null;
  canceled: boolean;
  /** The train has left this stop (or, at the last one, arrived). */
  passed: boolean;
}

type Planned = { seq: number; stationId: string; name: string; arr: number | null; dep: number | null };

/**
 * Lay actuals over the planned calls. A stop with no report counts as passed when a later one has been passed, or
 * (with `now`) when its expected departure is a couple of minutes gone: feeds skip a report now and then. Pure.
 */
export function mergeStops(planned: Planned[], actuals: Map<number, StopActuals>, now?: number): TrainStopView[] {
  const out = planned.map((s, i): TrainStopView => {
    const a = actuals.get(s.seq);
    const last = i === planned.length - 1;
    const view: TrainStopView = {
      ...s,
      actualArr: a?.actualArr ?? null,
      actualDep: a?.actualDep ?? null,
      estimatedArr: a?.estimatedArr ?? null,
      estimatedDep: a?.estimatedDep ?? null,
      platform: a?.platform ?? null,
      canceled: a?.canceled ?? false,
      passed: Boolean(last ? a?.actualArr : a?.actualDep),
    };
    const expected = last ? a?.estimatedArr : a?.estimatedDep;
    if (now !== undefined && !view.passed && expected != null && now - expected > 2 * 60_000) view.passed = true;
    return view;
  });
  let seen = false;
  for (let i = out.length - 1; i >= 0; i--) {
    if (out[i]!.passed) seen = true;
    else if (seen) out[i]!.passed = true;
  }
  return out;
}

const TTL_MS = 30_000;
const cache = new Map<string, { at: number; stops: TrainStopView[] }>();

export async function trainStops(db: Db, trip: { key: string; serviceDate: string }, trainNumber: string, opts: { now?: number; fetchImpl?: typeof fetch } = {}): Promise<TrainStopView[] | null> {
  const now = opts.now ?? Date.now();
  const k = `${trip.key}|${trip.serviceDate}`;
  const hit = cache.get(k);
  if (hit && now - hit.at < TTL_MS) return hit.stops;
  const found = tripStops(db, trip.key, trip.serviceDate);
  if (!found) return null;
  const stops = found.stops;
  const forMatch: StopForMatch[] = stops.map((s, i) => ({ seq: s.seq, role: i === 0 ? 'board' : i === stops.length - 1 ? 'alight' : 'through', sig: s.code, schedArr: s.arr, schedDep: s.dep }));
  const events = eventsFor(forMatch);
  let actuals = new Map<number, StopActuals>();
  try {
    if (events.length) actuals = matchAnnouncements(forMatch, await fetchAnnouncements(events, opts.fetchImpl), trainNumber);
  } catch {
    // Trafikverket down: the plan alone is still worth showing.
  }
  // Norwegian stops from Entur, where Trafikverket has nothing.
  try {
    const id = serviceJourneyFor(db, trip.key, trainNumber, trip.serviceDate);
    if (id) {
      const nsr = new Map(
        db
          .select({ id: stations.id, nsr: stations.nsrId })
          .from(stations)
          .where(inArray(stations.id, stops.map((s) => s.stationId)))
          .all()
          .map((r) => [r.id, r.nsr]),
      );
      const own = trip.key.startsWith('no:');
      const forCalls = stops.map((s) => ({ seq: s.seq, schedArr: s.arr, schedDep: s.dep, nsrId: nsr.get(s.stationId) ?? null })).filter((s) => own || s.nsrId);
      for (const [seq, a] of callsToActuals(forCalls, await serviceJourneyCalls(id, trip.serviceDate, opts))) if (!actuals.has(seq)) actuals.set(seq, a);
    }
  } catch {
    // Entur down or over quota: as above.
  }
  const out = mergeStops(
    stops.map((s) => ({ seq: s.seq, stationId: s.stationId, name: s.name, arr: s.arr, dep: s.dep })),
    actuals,
    now,
  );
  cache.set(k, { at: now, stops: out });
  if (cache.size > 200) cache.delete(cache.keys().next().value!);
  return out;
}
