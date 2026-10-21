// The faint "Show rail network" layer (SPEC §12, DESIGN §2.4): running lines from the rail graph, simplified
// for drawing, plus rail stations as points. Built once per process and served gzipped.
import zlib from 'node:zlib';
import { eq } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { stations } from '../db/schema.js';
import { FLAG_MINOR_USAGE, FLAG_SERVICE, type RailGraph } from './railGraph.js';

const SIMPLIFY_M = 25;

function simplify(pts: [number, number][], tol: number): [number, number][] {
  if (pts.length < 3) return pts;
  const k = 111320 * Math.cos((pts[0]![1] * Math.PI) / 180);
  const xy = pts.map(([lon, lat]) => [lon * k, lat * 110540] as const);
  const keep = new Uint8Array(pts.length);
  keep[0] = keep[pts.length - 1] = 1;
  const stack: [number, number][] = [[0, pts.length - 1]];
  while (stack.length) {
    const [a, b] = stack.pop()!;
    const [ax, ay] = xy[a]!;
    const [bx, by] = xy[b]!;
    const dx = bx - ax;
    const dy = by - ay;
    const l2 = dx * dx + dy * dy;
    let best = -1;
    let bd = tol;
    for (let i = a + 1; i < b; i++) {
      const [px, py] = xy[i]!;
      const t = l2 ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) : 0;
      const d = Math.hypot(px - ax - t * dx, py - ay - t * dy);
      if (d > bd) {
        bd = d;
        best = i;
      }
    }
    if (best >= 0) {
      keep[best] = 1;
      stack.push([a, best], [best, b]);
    }
  }
  return pts.filter((_, i) => keep[i]);
}

export function railNetworkGeoJson(db: Db, graph: RailGraph) {
  const r5 = (v: number) => Math.round(v * 1e5) / 1e5;
  const lines: [number, number][][] = [];
  for (const e of graph.edges) {
    if (e.flags & (FLAG_SERVICE | FLAG_MINOR_USAGE)) continue;
    const pts: [number, number][] = [];
    for (let i = 0; i < e.pts.length; i += 2) pts.push([r5(e.pts[i + 1]!), r5(e.pts[i]!)]);
    lines.push(simplify(pts, SIMPLIFY_M));
  }
  const st = db
    .select({ id: stations.id, name: stations.name, lat: stations.lat, lon: stations.lon, dpd: stations.departuresPerDay })
    .from(stations)
    .where(eq(stations.kind, 'rail_station'))
    .all();
  return {
    type: 'FeatureCollection',
    features: [
      { type: 'Feature', properties: { kind: 'rail' }, geometry: { type: 'MultiLineString', coordinates: lines } },
      // id for tapping through to the station; dpd (weighted departures a day) decides from which zoom it shows.
      ...st.map((s) => ({ type: 'Feature', properties: { kind: 'station', id: s.id, name: s.name, dpd: Math.round(s.dpd) }, geometry: { type: 'Point', coordinates: [r5(s.lon), r5(s.lat)] } })),
    ],
  };
}

let cached: Buffer | null = null;
export function railNetworkGz(db: Db, graph: RailGraph): Buffer {
  cached ??= zlib.gzipSync(JSON.stringify(railNetworkGeoJson(db, graph)));
  return cached;
}
