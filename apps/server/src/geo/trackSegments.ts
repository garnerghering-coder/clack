// Track geometry for station pairs, cached in track_segments (SPEC §12), and whole legs built from them.
import { and, asc, eq, isNull, ne, or } from 'drizzle-orm';
import { decodePolyline, encodePolyline, type LatLon } from '@clack/shared';
import type { Db } from '../db/client.js';
import { legStops, legs, stations, trackSegments } from '../db/schema.js';
import { haversineM } from '../lib/geo.js';
import { railGraph, type RailGraph } from './railGraph.js';

export interface StationPoint {
  id: string;
  lat: number;
  lon: number;
}

export interface Segment {
  points: LatLon[];
  lengthM: number;
  /** Straight line because the stations couldn't be routed on the rail network. */
  estimated: boolean;
}

/** Track between two consecutive stops, from the cache or routed now. Ordered a → b. */
export function segmentBetween(db: Db, a: StationPoint, b: StationPoint, graph: RailGraph | null = railGraph()): Segment {
  if (a.id === b.id) return { points: [[a.lat, a.lon]], lengthM: 0, estimated: false };
  const [lo, hi] = a.id < b.id ? [a, b] : [b, a];
  const orient = (points: LatLon[]) => (lo === a ? points : [...points].reverse());
  const hit = db
    .select()
    .from(trackSegments)
    .where(and(eq(trackSegments.fromStationId, lo.id), eq(trackSegments.toStationId, hi.id)))
    .get();
  if (hit) return { points: orient(decodePolyline(hit.geometry)), lengthM: hit.lengthM, estimated: hit.isEstimated };

  // Segments are stored lo → hi and flipped on use.
  const straight: Segment = {
    points: [
      [lo.lat, lo.lon],
      [hi.lat, hi.lon],
    ],
    lengthM: haversineM(lo.lat, lo.lon, hi.lat, hi.lon),
    estimated: true,
  };
  // Without the graph file nothing is cached, so the pair gets routed once the graph exists.
  if (!graph) return { ...straight, points: orient(straight.points) };
  const r = graph.route([lo.lat, lo.lon], [hi.lat, hi.lon]);
  const seg = r ? { points: r.points, lengthM: r.lengthM, estimated: false } : straight;
  db.insert(trackSegments)
    .values({ fromStationId: lo.id, toStationId: hi.id, geometry: encodePolyline(seg.points), lengthM: seg.lengthM, isEstimated: seg.estimated })
    .onConflictDoNothing()
    .run();
  return { ...seg, points: orient(seg.points) };
}

/** Track along a sequence of stops: one segment per consecutive pair, plus the joined line. */
export function pathThrough(db: Db, stops: StationPoint[], graph: RailGraph | null = railGraph()) {
  const segments: Segment[] = [];
  for (let i = 1; i < stops.length; i++) segments.push(segmentBetween(db, stops[i - 1]!, stops[i]!, graph));
  const points: LatLon[] = segments.flatMap((s, i) => (i ? s.points.slice(1) : s.points));
  return {
    segments,
    points,
    lengthM: segments.reduce((n, s) => n + s.lengthM, 0),
    estimated: segments.some((s) => s.estimated),
  };
}

/** Routes the ridden part of a leg and stores its geometry and distance. */
export function attachLegGeometry(db: Db, legId: string, graph: RailGraph | null = railGraph()): boolean {
  const ridden = db
    .select({ id: stations.id, lat: stations.lat, lon: stations.lon, role: legStops.role })
    .from(legStops)
    .innerJoin(stations, eq(stations.id, legStops.stationId))
    .where(eq(legStops.legId, legId))
    .orderBy(asc(legStops.seq))
    .all()
    .filter((s) => s.role === 'board' || s.role === 'through' || s.role === 'alight');
  if (ridden.length < 2) return false;
  const p = pathThrough(db, ridden, graph);
  // A straight-line result without a graph is a placeholder: leave geometry empty so it's routed later.
  db.update(legs)
    .set({ geometry: graph ? encodePolyline(p.points) : null, distanceM: p.lengthM, isEstimatedGeometry: p.estimated })
    .where(eq(legs.id, legId))
    .run();
  return true;
}

/**
 * Legs without track geometry (saved before routing existed or while the graph was missing), and legs drawn as
 * straight lines whose stations may route now. Straight-line cache entries are retried too; they're few and cheap.
 */
export function backfillLegGeometry(db: Db, log: (m: string) => void = () => {}): number {
  const graph = railGraph();
  if (!graph) {
    log('Rail network file missing (data/osm/rail-graph.json.gz): trips are drawn as straight lines');
    return 0;
  }
  db.delete(trackSegments).where(eq(trackSegments.isEstimated, true)).run();
  const todo = db
    .select({ id: legs.id })
    .from(legs)
    .where(or(isNull(legs.geometry), and(eq(legs.isEstimatedGeometry, true), ne(legs.dataQuality, 'manual'))))
    .all();
  let fixed = 0;
  for (const { id } of todo) {
    attachLegGeometry(db, id, graph);
    if (!db.select({ e: legs.isEstimatedGeometry }).from(legs).where(eq(legs.id, id)).get()?.e) fixed++;
  }
  if (todo.length) log(`Rail network: routed ${fixed} of ${todo.length} trip(s) along the tracks`);
  return fixed;
}
