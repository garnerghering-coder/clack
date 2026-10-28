// The journey planner (Build 44 in the plan): routes between any two stations with up to two changes, over the
// timetables of all four countries, each change meeting the change rule (packages/shared/src/changes.ts). It is a
// round-based search (RAPTOR): round k finds the earliest arrival everywhere with k trains, and it is run once per
// departure from the origin, latest first, keeping the labels (rRAPTOR), so the whole day costs about one search.
//
// The day's timetable is held in memory (`dayIndex`), built in chunks with pauses so the server keeps answering (the
// lesson of 27 Oct), cached per date and warmed for today and tomorrow. A planner search itself takes milliseconds.
import fs from 'node:fs';
import path from 'node:path';
import { sql } from 'drizzle-orm';
import { comfortOf, countryOfStops, minChangeMin, type Comfort, type Tier } from '@clack/shared';
import type { Db } from '../db/client.js';
import { REPO_ROOT } from '../env.js';
import { addDays } from '../lib/time.js';
import { candidateTrips, loadStops, toResult, utc, type StopRow, type TripResult, type TripRow } from './timetable.js';

const MAX_TRIPS = 3; // up to two changes
const MAX_WAIT_MS = 3 * 3600_000;
const breathe = () => new Promise<void>((r) => setImmediate(r));

/**
 * The day as flat number arrays (stations interned): about 15 MB for three days of all four countries, where objects
 * per stop took 317 MB. Full stop details (names, codes) are fetched only for the trains in the results.
 */
interface Trip { row: TripRow; country: string | null; number: string | null; start: number; len: number }
export interface DayIndex {
  date: string;
  trips: Trip[];
  stations: string[];
  stationIdx: Map<string, number>;
  stopStation: Int32Array;
  stopArr: Float64Array;
  stopDep: Float64Array;
  stopSeq: Int32Array;
  /** bit 1: pickup, bit 2: drop-off */
  stopFlags: Uint8Array;
  stopTrip: Int32Array;
  /** station index → its departures (global stop indexes), sorted by time */
  deps: Map<number, Int32Array>;
  builtAt: number;
}

// ---- Tiers ------------------------------------------------------------------------------------------------------

let tiers: Map<string, Tier> | null = null;
export function tierOf(stationId: string): Tier {
  if (!tiers) {
    const file = path.join(REPO_ROOT, 'data/station_tiers.json');
    const data = fs.existsSync(file) ? (JSON.parse(fs.readFileSync(file, 'utf8')) as { stations: Record<string, { tier: Tier }> }) : { stations: {} };
    tiers = new Map(Object.entries(data.stations).map(([id, s]) => [id, s.tier]));
  }
  return tiers.get(stationId) ?? 'default';
}

// ---- The day in memory ------------------------------------------------------------------------------------------

const days = new Map<string, Promise<DayIndex>>();
const INDEX_TTL_MS = 6 * 3600_000;

/** Every trip running on `date` (with the day before's after-midnight runs and the next day's, for late changes). */
export function dayIndex(db: Db, date: string, now = Date.now()): Promise<DayIndex> {
  const hit = days.get(date);
  if (hit) return hit;
  const p = build(db, date, now);
  days.set(date, p);
  p.then((d) => setTimeout(() => days.get(date) === p && days.delete(date), Math.max(0, d.builtAt + INDEX_TTL_MS - Date.now())).unref?.()).catch(() => days.delete(date));
  for (const d of days.keys()) if (days.size > 3 && d !== date) days.delete(d);
  return p;
}

async function build(db: Db, date: string, now: number): Promise<DayIndex> {
  const rows = new Map<string, TripRow>();
  for (const r of [...candidateTrips(db, date, sql`1 = 1`), ...candidateTrips(db, addDays(date, 1), sql`1 = 1`)]) rows.set(`${r.key}|${r.service_date}`, r);
  await breathe();
  const byKey = new Map<string, TripRow[]>();
  for (const r of rows.values()) (byKey.get(r.key) ?? byKey.set(r.key, []).get(r.key)!).push(r);
  const keys = [...byKey.keys()];
  const stations: string[] = [], stationIdx = new Map<string, number>();
  const intern = (id: string) => stationIdx.get(id) ?? (stationIdx.set(id, stations.length), stations.push(id), stations.length - 1);
  const st: number[] = [], arr: number[] = [], dep: number[] = [], seq: number[] = [], flags: number[] = [], tripOf: number[] = [];
  const trips: Trip[] = [];
  for (let i = 0; i < keys.length; i += 400) {
    const chunk = keys.slice(i, i + 400);
    const stopRows = db.all<{ k: string; seq: number; s: string; a: number | null; d: number | null; np: number; nd: number; c: string }>(sql`
      select st.trip_key k, st.seq, st.station_id s, st.arr_sec a, st.dep_sec d, st.no_pickup np, st.no_dropoff nd, s.country c
      from timetable_stop_times st join stations s on s.id = st.station_id
      where st.trip_key in (${sql.join(chunk.map((k) => sql`${k}`), sql`, `)})
      order by st.trip_key, st.seq`);
    const grouped = new Map<string, typeof stopRows>();
    for (const r of stopRows) (grouped.get(r.k) ?? grouped.set(r.k, []).get(r.k)!).push(r);
    for (const [k, ss] of grouped) {
      if (ss.length < 2) continue;
      const country = countryOfStops(ss.map((x) => x.c));
      for (const row of byKey.get(k)!) {
        const ti = trips.length;
        trips.push({ row, country, number: row.train_number, start: st.length, len: ss.length });
        for (const x of ss) {
          st.push(intern(x.s));
          arr.push(utc(row, x.a ?? x.d) ?? NaN);
          dep.push(utc(row, x.d ?? x.a) ?? NaN);
          seq.push(x.seq);
          flags.push((x.np ? 0 : 1) | (x.nd ? 0 : 2));
          tripOf.push(ti);
        }
      }
    }
    await breathe();
  }
  const ix: DayIndex = {
    date, trips, stations, stationIdx,
    stopStation: Int32Array.from(st), stopArr: Float64Array.from(arr), stopDep: Float64Array.from(dep), stopSeq: Int32Array.from(seq),
    stopFlags: Uint8Array.from(flags), stopTrip: Int32Array.from(tripOf), deps: new Map(), builtAt: now,
  };
  const lists = new Map<number, number[]>();
  for (const t of trips)
    for (let g = t.start; g < t.start + t.len - 1; g++) {
      if (!(ix.stopFlags[g]! & 1) || Number.isNaN(ix.stopDep[g]!)) continue;
      const sIdx = ix.stopStation[g]!;
      (lists.get(sIdx) ?? lists.set(sIdx, []).get(sIdx)!).push(g);
    }
  for (const [sIdx, l] of lists) ix.deps.set(sIdx, Int32Array.from(l.sort((a, b) => ix.stopDep[a]! - ix.stopDep[b]!)));
  return ix;
}

/** Build today's and tomorrow's indexes in the background (after startup and timetable imports). */
export function warmPlanner(db: Db, today: string, log?: (m: string) => void) {
  for (const d of [today, addDays(today, 1)]) {
    const t = Date.now();
    dayIndex(db, d)
      .then((ix) => log?.(`planner: ${d} ready, ${ix.trips.length} trips in ${Date.now() - t} ms`))
      .catch((e) => log?.(`planner: ${d} failed: ${(e as Error).message}`));
  }
}

// ---- The search -------------------------------------------------------------------------------------------------

export interface PlannedChange {
  stationId: string;
  name: string;
  /** The real wait: the next train's departure minus this one's arrival. */
  gapMin: number;
  /** What the change rule asks for here. */
  minMin: number;
  comfort: Comfort;
}

export interface PlannedJourney {
  legs: TripResult[];
  changes: PlannedChange[];
  dep: number;
  arr: number;
  durationMin: number;
  fastest?: boolean;
}

interface Label { arr: number; trip: number; board: number; alight: number; prev: number | null }

/** Minutes a change at `station` from trip a to trip b needs. */
const changeMs = (station: string, a: Trip, b: Trip) => minChangeMin(tierOf(station), a.country, b.country) * 60_000;

/**
 * Journeys from `fromId` to `toId` leaving in [from, until), with up to `maxChanges` changes, by departure. One list:
 * direct trains and journeys with changes together. A journey is dropped when another leaves no earlier, arrives no
 * later and has no more changes. `board`/`alight` in labels are global stop indexes.
 */
export function plan(db: Db, ix: DayIndex, fromId: string, toId: string, from: number, until: number, maxChanges = 2): PlannedJourney[] {
  const origin = ix.stationIdx.get(fromId), target = ix.stationIdx.get(toId);
  if (origin === undefined || target === undefined || origin === target) return [];
  const rounds = Math.min(MAX_TRIPS, maxChanges + 1);
  // best[k][station]: earliest arrival with k+1 trains, kept across runs (rRAPTOR: later departures first).
  const best: Map<number, Label>[] = Array.from({ length: rounds }, () => new Map());
  const originDeps = [...(ix.deps.get(origin) ?? [])].filter((g) => ix.stopDep[g]! >= from && ix.stopDep[g]! < until);
  const times = [...new Set(originDeps.map((g) => ix.stopDep[g]!))].sort((a, b) => b - a);
  const found: PlannedJourney[] = [];
  const seen = new Set<string>();
  const stopsCache = new Map<string, StopRow[]>();

  const ride = (g0: number, prev: number | null, round: Map<number, Label>, marked: Map<number, Label>) => {
    const ti = ix.stopTrip[g0]!;
    const t = ix.trips[ti]!;
    for (let g = g0 + 1; g < t.start + t.len; g++) {
      const s = ix.stopStation[g]!, a = ix.stopArr[g]!;
      if (!(ix.stopFlags[g]! & 2) || Number.isNaN(a) || s === origin) continue;
      const have = round.get(s);
      if (have && have.arr <= a) continue;
      const lab = { arr: a, trip: ti, board: g0, alight: g, prev };
      round.set(s, lab);
      marked.set(s, lab);
    }
  };

  for (const t0 of times) {
    let marked = new Map<number, Label>();
    for (const g of originDeps) if (ix.stopDep[g] === t0) ride(g, null, best[0]!, marked);
    for (let k = 1; k < rounds && marked.size; k++) {
      const next = new Map<number, Label>();
      for (const [station, lab] of marked) {
        if (station === target) continue;
        const arriving = ix.trips[lab.trip]!;
        const sid = ix.stations[station]!;
        for (const g of ix.deps.get(station) ?? []) {
          const d = ix.stopDep[g]!;
          if (d < lab.arr) continue;
          if (d - lab.arr > MAX_WAIT_MS) break;
          const ti = ix.stopTrip[g]!;
          const trip = ix.trips[ti]!;
          if (ti === lab.trip || (trip.number && trip.number === arriving.number)) continue; // the same train
          if (d - lab.arr < changeMs(sid, arriving, trip)) continue;
          ride(g, station, best[k]!, next);
        }
      }
      marked = next;
    }
    for (let k = 0; k < rounds; k++) {
      if (!best[k]!.has(target)) continue;
      const j = reconstruct(db, ix, best, k, target, stopsCache);
      if (!j || j.dep !== t0) continue;
      // One physical train in two feeds (Vy's Oslo–Göteborg trains are in Norway's and Sweden's) is one journey:
      // the same numbers at the same times count once.
      const id = `${j.dep}|${j.arr}|` + j.legs.map((l) => `${l.trainNumber ?? l.key}@${l.from.time}`).join('>');
      if (seen.has(id)) continue;
      seen.add(id);
      found.push(j);
    }
  }
  const kept = found.filter(
    (c) => !found.some((d) => d !== c && d.dep >= c.dep && d.arr <= c.arr && d.changes.length <= c.changes.length && (d.dep > c.dep || d.arr < c.arr || d.changes.length < c.changes.length)),
  );
  kept.sort((a, b) => a.dep - b.dep || a.arr - b.arr);
  if (kept.length > 1) {
    const quickest = Math.min(...kept.map((j) => j.durationMin));
    kept.find((j) => j.durationMin === quickest)!.fastest = true;
  }
  return kept;
}

function reconstruct(db: Db, ix: DayIndex, best: Map<number, Label>[], k: number, target: number, cache: Map<string, StopRow[]>): PlannedJourney | null {
  const parts: Label[] = [];
  let station = target;
  for (let r = k; r >= 0; r--) {
    const lab = best[r]!.get(station);
    if (!lab) return null;
    parts.unshift(lab);
    if (r > 0) {
      if (lab.prev === null) return null;
      station = lab.prev;
    }
  }
  const legs: TripResult[] = [];
  for (const p of parts) {
    const t = ix.trips[p.trip]!;
    let ss = cache.get(t.row.key);
    if (!ss) {
      ss = loadStops(db, [t.row.key]).get(t.row.key) ?? [];
      cache.set(t.row.key, ss);
    }
    const a = ss.find((s) => s.seq === ix.stopSeq[p.board]), b = ss.find((s) => s.seq === ix.stopSeq[p.alight]);
    if (!a || !b) return null;
    legs.push(toResult(t.row, ss, a, b));
  }
  // Labels from different departure runs can fail to chain in time; such a journey isn't real.
  for (let i = 1; i < legs.length; i++) if (legs[i]!.from.time < legs[i - 1]!.to.time) return null;
  const changes = legs.slice(1).map((leg, i) => {
    const a = ix.trips[parts[i]!.trip]!, b = ix.trips[parts[i + 1]!.trip]!;
    const gapMin = Math.round((leg.from.time - legs[i]!.to.time) / 60_000);
    const minMin = changeMs(leg.from.stationId, a, b) / 60_000;
    return { stationId: leg.from.stationId, name: leg.from.name, gapMin, minMin, comfort: comfortOf(gapMin, minMin) };
  });
  if (changes.some((c) => c.comfort === 'risky')) return null;
  const dep = legs[0]!.from.time, arr = legs.at(-1)!.to.time;
  return { legs, changes, dep, arr, durationMin: Math.round((arr - dep) / 60_000) };
}
