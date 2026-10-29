// Station detail for the Explore map at close zoom (plan 2026-10-29, step 2): every track in a box at the rail
// graph's full 2 m detail, service tracks (yards, sidings, spurs) flagged so the app draws them fainter, plus the
// platform outlines of the mapped stations in the box (data/stations, schema 2) with their numbers. The ordinary
// rail-network layer drops service tracks and simplifies to 25 m, which is why tracks never split on screen.
import zlib from 'node:zlib';
import { and, gte, lte } from 'drizzle-orm';
import { fromLocal, type StationMap } from '@clack/shared';
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
      },
      geometry: { type: 'Polygon' as const, coordinates: rings },
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
    return m ? platformFeatures(m, s.id) : [];
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
