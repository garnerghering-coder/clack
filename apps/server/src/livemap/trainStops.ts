// A live-map train's whole route, stop by stop: the timetable's calls with Trafikverket's (Sweden), Entur's (Norway) and
// Digitraffic's (Finland) actual, estimated and platform data laid over them, so the train's sheet can list where it has been and where it's
// going, and which stops nobody reports live (abroad), so those read as timetable times.
import type { Db } from '../db/client.js';
import { eventsFor, fetchAnnouncements, matchAnnouncements, type StopActuals, type StopForMatch } from '../legs/actuals.js';
import { tripStops } from '../search/timetable.js';
import { enturStops } from '../entur/calls.js';
import { stations } from '../db/schema.js';
import { inArray } from 'drizzle-orm';
import { digitrafficFor, fiCodes } from '../digitraffic/trains.js';
import { countryOfKey } from '../lib/countries.js';

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
  /** Who reports this stop live; null: nobody does (Denmark, SJ in Norway), so its times are the timetable's. */
  source: 'trafikverket' | 'entur' | 'digitraffic' | null;
}

type Planned = { seq: number; stationId: string; name: string; arr: number | null; dep: number | null; source?: TrainStopView['source'] };

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
      source: s.source ?? null,
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
  // A Finnish train is Digitraffic's alone: Trafikverket doesn't announce it (not even at Haparanda, where a Swedish
  // train can share its number), and Entur has nothing on it.
  if (countryOfKey(trip.key) === 'FI') {
    let dt = new Map<number, StopActuals>();
    try {
      dt = await digitrafficFor(db, { trainNumber, serviceDate: trip.serviceDate, stops: stops.map((s) => ({ seq: s.seq, role: 'through', sig: null, schedArr: s.arr, schedDep: s.dep, stationId: s.stationId })) }, { fetchImpl: opts.fetchImpl, now });
    } catch {
      // Digitraffic down: the plan alone is still worth showing.
    }
    const codes = fiCodes(db, stops.map((s) => s.stationId));
    const out = mergeStops(
      stops.map((s) => ({ seq: s.seq, stationId: s.stationId, name: s.name, arr: s.arr, dep: s.dep, source: codes.get(s.stationId) ? ('digitraffic' as const) : null })),
      dt,
      now,
    );
    cache.set(k, { at: now, stops: out });
    if (cache.size > 200) cache.delete(cache.keys().next().value!);
    return out;
  }
  const forMatch: StopForMatch[] = stops.map((s, i) => ({ seq: s.seq, role: i === 0 ? 'board' : i === stops.length - 1 ? 'alight' : 'through', sig: s.code, schedArr: s.arr, schedDep: s.dep }));
  const events = eventsFor(forMatch);
  let actuals = new Map<number, StopActuals>();
  try {
    if (events.length) actuals = matchAnnouncements(forMatch, await fetchAnnouncements(events, opts.fetchImpl), trainNumber);
  } catch {
    // Trafikverket down: the plan alone is still worth showing.
  }
  // Norwegian stops from Entur, where Trafikverket has nothing, with Norway's own published times for them.
  let entur = new Map<number, StopActuals>();
  try {
    const nsr = new Map(
      db
        .select({ id: stations.id, nsr: stations.nsrId })
        .from(stations)
        .where(inArray(stations.id, stops.map((s) => s.stationId)))
        .all()
        .map((r) => [r.id, r.nsr]),
    );
    entur = await enturStops(
      db,
      { tripKey: trip.key, trainNumber, serviceDate: trip.serviceDate, stops: stops.map((s) => ({ seq: s.seq, schedArr: s.arr, schedDep: s.dep, nsrId: nsr.get(s.stationId) ?? null, country: s.country })) },
      opts,
    );
    for (const [seq, a] of entur) if (!actuals.has(seq)) actuals.set(seq, a);
  } catch {
    // Entur down or over quota: as above.
  }
  const out = mergeStops(
    stops.map((s) => {
      const e = s.country === 'NO' ? entur.get(s.seq) : undefined;
      return {
        seq: s.seq,
        stationId: s.stationId,
        name: s.name,
        arr: s.arr === null ? null : (e?.advertisedArr ?? s.arr),
        dep: s.dep === null ? null : (e?.advertisedDep ?? s.dep),
        source: s.code && !s.code.includes('.') && s.country === 'SE' ? 'trafikverket' : (e?.source ?? null),
      };
    }),
    actuals,
    now,
  );
  cache.set(k, { at: now, stops: out });
  if (cache.size > 200) cache.delete(cache.keys().next().value!);
  return out;
}
