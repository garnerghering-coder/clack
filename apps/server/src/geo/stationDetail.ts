// Station detail for the Explore map at close zoom (plan 2026-10-29, step 2): every track in a box at the rail
// graph's full 2 m detail, service tracks (yards, sidings, spurs) flagged so the app draws them fainter, plus the
// platform outlines of the mapped stations in the box (data/stations, schema 2) with their numbers. The ordinary
// rail-network layer drops service tracks and simplifies to 25 m, which is why tracks never split on screen.
// Where a map has measured heights (docs/STATION_3D_RESEARCH.md) it also gives the buildings and roofs and each
// platform's height, for the map's 3D at the closest zooms.
import zlib from 'node:zlib';
import { and, gte, lte } from 'drizzle-orm';
import { fromLocal, LASER_SOURCES, type StationMap } from '@clack/shared';
import type { Db } from '../db/client.js';
import { stations } from '../db/schema.js';
import { stationMap } from '../stations/maps.js';
import { FLAG_MINOR_USAGE, FLAG_SERVICE, type RailGraph } from './railGraph.js';

export interface Bbox {
  w: number;
  s: number;
  e: number;
  n: number;
}

/** The widest box answered (about 3 × 3 km at 59°N), so a zoomed-out ask can't pull the whole network. */
export const MAX_SPAN_DEG = { lat: 0.03, lon: 0.06 };
/** Tracks are read this far outside the box, so a platform's track doesn't end at the screen edge. */
const PAD_DEG = 0.003;

export function parseBbox(raw: string | undefined): Bbox | null {
  const p = (raw ?? '').split(',').map(Number);
  if (p.length !== 4 || p.some((v) => !Number.isFinite(v))) return null;
  const [w, s, e, n] = p as [number, number, number, number];
  if (e <= w || n <= s || e - w > MAX_SPAN_DEG.lon || n - s > MAX_SPAN_DEG.lat) return null;
  return { w, s, e, n };
}

/** The box rounded to about 100 m, so neighbouring asks share one answer. */
export function cacheKey(b: Bbox): string {
  const r = (v: number) => (Math.round(v / 0.001) * 0.001).toFixed(3);
  return `${r(b.w)},${r(b.s)},${r(b.e)},${r(b.n)}`;
}

/** The platform polygons of one map, each ring in WGS84 (lon, lat), with the platform's number and tracks. */
export function platformFeatures(m: StationMap, stationId: string) {
  const r6 = (v: number) => Math.round(v * 1e6) / 1e6;
  return m.platforms.map((p) => {
    const rings = (p.geometry ?? []).map((ring) => ring.map(([x, y]) => {
      const [lat, lon] = fromLocal(m, x, y);
      return [r6(lon), r6(lat)];
    }));
    const nodeXY = m.nodes.find((n) => n.id === p.node);
    const node = nodeXY ? fromLocal(m, nodeXY.x, nodeXY.y) : null;
    return {
      type: 'Feature' as const,
      properties: {
        kind: 'platform',
        cls: 'platform',
        stationId,
        ref: p.ref,
        tracks: p.tracks,
        level: p.level,
        node: node ? [r6(node[1]), r6(node[0])] : null,
        draft: m.quality === 'osm_draft',
        // Above the rails, the map's flat ground; the standard when the map has none. `measured` (what the 3D raises)
        // also needs the platform on the main level: a tunnel platform (Malmö C's City Tunnel) isn't on the surface.
        height: p.height_m ?? STANDARD_PLATFORM_HEIGHT_M,
        measured: p.height_m !== undefined && (m.levels.find((l) => l.id === p.level)?.order ?? 0) === 0,
      },
      geometry: { type: 'Polygon' as const, coordinates: rings },
    };
  });
}

/** Platform surface above the rail head when the map has none: the TSI's nominal low platform (as the app's 3D view). */
export const STANDARD_PLATFORM_HEIGHT_M = 0.55;
/** How thick a roof is drawn under its measured top (its underside isn't measured); as the app's 3D view. */
const ROOF_SHEET_M = 0.4;

/** The map's platform height for the 3D: the median of the measured ones, else the standard. */
export function railToPlatformM(m: StationMap): number {
  const known = m.platforms.map((p) => p.height_m).filter((h): h is number => h !== undefined).sort((a, b) => a - b);
  return known.length ? known[Math.floor(known.length / 2)]! : STANDARD_PLATFORM_HEIGHT_M;
}

/**
 * The buildings and roofs with a measured top (`top_m`, metres above the platform surface), as polygons in lon/lat.
 * The Explore map's ground is flat at rail level, so `base` and `height` are metres above the rails: a building from
 * the ground to its top, a roof as a sheet under its top. `lantmateriet` says the heights need that credit.
 */
export function structureFeatures(m: StationMap, stationId: string) {
  const r6 = (v: number) => Math.round(v * 1e6) / 1e6;
  const rail = railToPlatformM(m);
  const lantmateriet = m.sources.some((s) => s.type === 'lantmateriet');
  // Which laser the heights come from, for the map's credit line ("lantmateriet", "kartverket", "nls", …).
  const credit = m.sources.find((s) => LASER_SOURCES.includes(s.type))?.type ?? '';
  const r2 = (v: number) => Math.round(v * 100) / 100;
  return m.shapes
    .filter((s) => (s.kind === 'building' || s.kind === 'roof' || s.kind === 'bridge') && s.top_m !== undefined && s.points.length >= 3)
    .map((s) => {
      const top = s.top_m! + rail;
      // A building stands on the flat ground; a roof is a sheet under its top; a bridge spans from its underside.
      const base = s.kind === 'roof' ? Math.max(0, top - ROOF_SHEET_M) : s.kind === 'bridge' ? Math.max(0, (s.base_m ?? 0) + rail) : 0;
      const ring = s.points.map(([x, y]) => {
        const [lat, lon] = fromLocal(m, x, y);
        return [r6(lon), r6(lat)];
      });
      ring.push(ring[0]!);
      return {
        type: 'Feature' as const,
        properties: { kind: 'structure', cls: s.kind === 'bridge' ? 'building' : s.kind, stationId, name: s.name ?? '', base: r2(base), height: r2(top), lantmateriet, credit },
        geometry: { type: 'Polygon' as const, coordinates: [ring] },
      };
    });
}

/** Every graph edge that touches the padded box, at full detail, as one feature per edge. */
export function trackFeatures(graph: RailGraph, b: Bbox) {
  const r6 = (v: number) => Math.round(v * 1e6) / 1e6;
  const w = b.w - PAD_DEG * 2, e = b.e + PAD_DEG * 2, s = b.s - PAD_DEG, n = b.n + PAD_DEG;
  const out: object[] = [];
  for (const edge of graph.edges) {
    let inside = false;
    for (let i = 0; i < edge.pts.length && !inside; i += 2) {
      const lat = edge.pts[i]!, lon = edge.pts[i + 1]!;
      if (lat >= s && lat <= n && lon >= w && lon <= e) inside = true;
    }
    if (!inside) continue;
    const coords: [number, number][] = [];
    for (let i = 0; i < edge.pts.length; i += 2) coords.push([r6(edge.pts[i + 1]!), r6(edge.pts[i]!)]);
    out.push({
      type: 'Feature',
      // `cls` is what the map's layers filter on: "track" for running and platform tracks, "siding" for yards,
      // sidings, spurs and minor-usage lines (drawn fainter).
      properties: { kind: 'track', cls: edge.flags & (FLAG_SERVICE | FLAG_MINOR_USAGE) ? 'siding' : 'track', service: !!(edge.flags & FLAG_SERVICE), minor: !!(edge.flags & FLAG_MINOR_USAGE) },
      geometry: { type: 'LineString', coordinates: coords },
    });
  }
  return out;
}

export function stationDetailGeoJson(db: Db, graph: RailGraph, b: Bbox) {
  const inBox = db
    .select({ id: stations.id })
    .from(stations)
    .where(and(gte(stations.lat, b.s - PAD_DEG), lte(stations.lat, b.n + PAD_DEG), gte(stations.lon, b.w - PAD_DEG * 2), lte(stations.lon, b.e + PAD_DEG * 2)))
    .all();
  const platforms = inBox.flatMap((s) => {
    const m = stationMap(s.id);
    return m ? [...platformFeatures(m, s.id), ...structureFeatures(m, s.id)] : [];
  });
  return { type: 'FeatureCollection', features: [...trackFeatures(graph, b), ...platforms] };
}

const gzCache = new Map<string, { at: number; gz: Buffer }>();
const CACHE_MS = 3600_000;

/** The answer gzipped, kept an hour per rounded box. */
export function stationDetailGz(db: Db, graph: RailGraph, b: Bbox, now = Date.now()): Buffer {
  const key = cacheKey(b);
  const hit = gzCache.get(key);
  if (hit && now - hit.at < CACHE_MS) return hit.gz;
  const gz = zlib.gzipSync(JSON.stringify(stationDetailGeoJson(db, graph, b)));
  gzCache.set(key, { at: now, gz });
  if (gzCache.size > 500) gzCache.delete(gzCache.keys().next().value!);
  return gz;
}
