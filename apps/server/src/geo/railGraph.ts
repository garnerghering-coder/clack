// Routing along the OSM rail network (SPEC §12, DATA_FINDINGS §6).
//
// The graph is data/osm/rail-graph.json.gz, built by scripts/osm/build-rail-graph.mjs: junction nodes plus
// edges whose geometry is an encoded polyline. Stations snap onto the track by projecting onto edge segments
// (several candidates within 400 m, because stations often sit between parallel or freight lines), then one
// multi-source/multi-target Dijkstra runs with the snap distance added to the cost. Service track costs 5×.
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { decodePolyline, type LatLon } from '@clack/shared';
import { REPO_ROOT } from '../env.js';

export const RAIL_GRAPH_PATH = path.join(REPO_ROOT, 'data/osm/rail-graph.json.gz');

export interface RailGraphFile {
  version: number;
  generated: string;
  attribution: string;
  nodes: number[];
  edges: [number, number, number, string][];
}

export const FLAG_SERVICE = 1;
export const FLAG_MINOR_USAGE = 8;
const SERVICE_PENALTY = 5;
const SNAP_RADIUS_M = 400;
const SNAP_FALLBACK_M = 1500;
const SNAP_CAP = 40;
const CELL = 0.01; // degrees latitude (~1.1 km); longitude cells are twice as wide

interface Edge {
  u: number;
  v: number;
  flags: number;
  cost: number;
  length: number;
  /** Flat [lat, lon, lat, lon, …]. */
  pts: Float64Array;
  /** Cumulative length at each point, metres. */
  cum: Float64Array;
}

interface Candidate {
  edge: number;
  /** Distance along the edge to the snapped point, metres. */
  offset: number;
  /** Distance from the station to the track, metres. */
  d: number;
  point: LatLon;
}

export interface RouteResult {
  points: LatLon[];
  lengthM: number;
}

const R = 6371008.8;
const RAD = Math.PI / 180;
function hav(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const a = Math.sin(((lat2 - lat1) * RAD) / 2) ** 2 + Math.cos(lat1 * RAD) * Math.cos(lat2 * RAD) * Math.sin(((lon2 - lon1) * RAD) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export class RailGraph {
  readonly attribution: string;
  readonly generated: string;
  readonly edges: Edge[];
  private readonly adj: number[][]; // node -> [edge, edge, …]
  private readonly grid = new Map<string, number[]>(); // cell -> [edge, segIdx, edge, segIdx, …]
  private readonly nodeCount: number;

  constructor(file: RailGraphFile) {
    this.attribution = file.attribution;
    this.generated = file.generated;
    this.nodeCount = file.nodes.length / 2;
    this.adj = Array.from({ length: this.nodeCount }, () => []);
    this.edges = file.edges.map(([u, v, flags, poly], ei) => {
      const p = decodePolyline(poly);
      const pts = new Float64Array(p.length * 2);
      const cum = new Float64Array(p.length);
      for (let i = 0; i < p.length; i++) {
        pts[2 * i] = p[i]![0];
        pts[2 * i + 1] = p[i]![1];
        if (i) cum[i] = cum[i - 1]! + hav(p[i - 1]![0], p[i - 1]![1], p[i]![0], p[i]![1]);
      }
      const length = cum[p.length - 1] ?? 0;
      this.adj[u]!.push(ei);
      if (v !== u) this.adj[v]!.push(ei);
      for (let i = 1; i < p.length; i++) this.index(ei, i - 1, p[i - 1]!, p[i]!);
      return { u, v, flags, length, cost: length * (flags & FLAG_SERVICE ? SERVICE_PENALTY : 1), pts, cum };
    });
  }

  static load(file = RAIL_GRAPH_PATH): RailGraph | null {
    if (!fs.existsSync(file)) return null;
    return new RailGraph(JSON.parse(zlib.gunzipSync(fs.readFileSync(file)).toString('utf8')) as RailGraphFile);
  }

  private index(edge: number, seg: number, a: LatLon, b: LatLon) {
    const i0 = Math.floor(Math.min(a[0], b[0]) / CELL);
    const i1 = Math.floor(Math.max(a[0], b[0]) / CELL);
    const j0 = Math.floor(Math.min(a[1], b[1]) / (2 * CELL));
    const j1 = Math.floor(Math.max(a[1], b[1]) / (2 * CELL));
    for (let i = i0; i <= i1; i++)
      for (let j = j0; j <= j1; j++) {
        const k = `${i},${j}`;
        const list = this.grid.get(k);
        if (list) list.push(edge, seg);
        else this.grid.set(k, [edge, seg]);
      }
  }

  /** Track positions near a station: the nearest point on each nearby running-line edge, nearest first. */
  snap(lat: number, lon: number): Candidate[] {
    const best = new Map<number, Candidate>();
    const ci = Math.floor(lat / CELL);
    const cj = Math.floor(lon / (2 * CELL));
    const kx = 111320 * Math.cos(lat * RAD);
    const ky = 110540;
    for (let di = -1; di <= 1; di++)
      for (let dj = -1; dj <= 1; dj++) {
        const list = this.grid.get(`${ci + di},${cj + dj}`);
        if (!list) continue;
        for (let n = 0; n < list.length; n += 2) {
          const ei = list[n]!;
          const si = list[n + 1]!;
          const e = this.edges[ei]!;
          const ax = (e.pts[2 * si + 1]! - lon) * kx;
          const ay = (e.pts[2 * si]! - lat) * ky;
          const bx = (e.pts[2 * si + 3]! - lon) * kx;
          const by = (e.pts[2 * si + 2]! - lat) * ky;
          const dx = bx - ax;
          const dy = by - ay;
          const l2 = dx * dx + dy * dy;
          const t = l2 ? Math.max(0, Math.min(1, -(ax * dx + ay * dy) / l2)) : 0;
          const d = Math.hypot(ax + t * dx, ay + t * dy);
          const prev = best.get(ei);
          if (prev && prev.d <= d) continue;
          const plat = e.pts[2 * si]! + t * (e.pts[2 * si + 2]! - e.pts[2 * si]!);
          const plon = e.pts[2 * si + 1]! + t * (e.pts[2 * si + 3]! - e.pts[2 * si + 1]!);
          best.set(ei, { edge: ei, d, offset: e.cum[si]! + t * (e.cum[si + 1]! - e.cum[si]!), point: [plat, plon] });
        }
      }
    const all = [...best.values()].sort((a, b) => a.d - b.d);
    const running = all.filter((c) => c.d <= SNAP_RADIUS_M && !(this.edges[c.edge]!.flags & FLAG_SERVICE));
    if (running.length) return running.slice(0, SNAP_CAP);
    const near = all.find((c) => c.d <= SNAP_FALLBACK_M);
    return near ? [near] : [];
  }

  /** Shortest track path between two stations, or null when either is off the network or no path exists. */
  route(from: LatLon, to: LatLon): RouteResult | null {
    const src = this.snap(from[0], from[1]);
    const dst = this.snap(to[0], to[1]);
    if (!src.length || !dst.length) return null;
    const straight = hav(from[0], from[1], to[0], to[1]);
    const limit = Math.max(straight * 3, 20000);

    const pen = (c: Candidate) => (this.edges[c.edge]!.flags & FLAG_SERVICE ? SERVICE_PENALTY : 1);
    let best = Infinity;
    let bestEnd: { kind: 'direct'; s: Candidate; t: Candidate } | { kind: 'node'; node: number; t: Candidate } | null = null;

    // Both ends on the same edge: ride along it directly.
    for (const s of src)
      for (const t of dst)
        if (s.edge === t.edge) {
          const c = s.d + t.d + Math.abs(s.offset - t.offset) * pen(s);
          if (c < best) {
            best = c;
            bestEnd = { kind: 'direct', s, t };
          }
        }

    const dist = new Float64Array(this.nodeCount).fill(Infinity);
    const prevEdge = new Int32Array(this.nodeCount).fill(-1);
    const srcOf = new Int32Array(this.nodeCount).fill(-1); // index into src when the node was reached from a snap point
    const heap = new MinHeap();
    src.forEach((c, i) => {
      const e = this.edges[c.edge]!;
      const p = pen(c);
      for (const [node, cost] of [
        [e.u, c.d + c.offset * p],
        [e.v, c.d + (e.length - c.offset) * p],
      ] as const) {
        if (cost < dist[node]!) {
          dist[node] = cost;
          srcOf[node] = i;
          prevEdge[node] = -1;
          heap.push(cost, node);
        }
      }
    });
    // Target entry costs per node.
    const entry = new Map<number, { cost: number; t: Candidate }[]>();
    for (const t of dst) {
      const e = this.edges[t.edge]!;
      const p = pen(t);
      for (const [node, cost] of [
        [e.u, t.d + t.offset * p],
        [e.v, t.d + (e.length - t.offset) * p],
      ] as const) {
        const list = entry.get(node);
        if (list) list.push({ cost, t });
        else entry.set(node, [{ cost, t }]);
      }
    }

    while (heap.size) {
      const [d, u] = heap.pop();
      if (d >= best) break;
      if (d > dist[u]! || d > limit) continue;
      for (const en of entry.get(u) ?? [])
        if (d + en.cost < best) {
          best = d + en.cost;
          bestEnd = { kind: 'node', node: u, t: en.t };
        }
      for (const ei of this.adj[u]!) {
        const e = this.edges[ei]!;
        const v = e.u === u ? e.v : e.u;
        const nd = d + e.cost;
        if (nd < dist[v]!) {
          dist[v] = nd;
          prevEdge[v] = ei;
          srcOf[v] = -1;
          heap.push(nd, v);
        }
      }
    }
    if (!bestEnd) return null;

    let points: LatLon[];
    if (bestEnd.kind === 'direct') {
      points = this.slice(bestEnd.s.edge, bestEnd.s.offset, bestEnd.t.offset);
    } else {
      // Walk back from the node where we left the network towards the target.
      const chain: LatLon[][] = [];
      let node = bestEnd.node;
      while (prevEdge[node]! >= 0) {
        const e = this.edges[prevEdge[node]!]!;
        const from = e.u === node ? e.v : e.u;
        chain.unshift(this.slice(prevEdge[node]!, from === e.u ? 0 : e.length, from === e.u ? e.length : 0));
        node = from;
      }
      const s = src[srcOf[node]!]!;
      const se = this.edges[s.edge]!;
      chain.unshift(this.slice(s.edge, s.offset, node === se.u ? 0 : se.length));
      const te = this.edges[bestEnd.t.edge]!;
      chain.push(this.slice(bestEnd.t.edge, bestEnd.node === te.u ? 0 : te.length, bestEnd.t.offset));
      points = chain.flatMap((part, i) => (i ? part.slice(1) : part));
    }
    points = [from, ...points, to];
    let lengthM = 0;
    for (let i = 1; i < points.length; i++) lengthM += hav(points[i - 1]![0], points[i - 1]![1], points[i]![0], points[i]![1]);
    return { points: dedupe(points), lengthM };
  }

  /** Points along an edge between two offsets (either direction). */
  private slice(ei: number, a: number, b: number): LatLon[] {
    const e = this.edges[ei]!;
    const n = e.cum.length;
    const at = (off: number): LatLon => {
      let i = 1;
      while (i < n - 1 && e.cum[i]! < off) i++;
      const s0 = e.cum[i - 1]!;
      const s1 = e.cum[i]!;
      const t = s1 > s0 ? (off - s0) / (s1 - s0) : 0;
      return [e.pts[2 * (i - 1)]! + t * (e.pts[2 * i]! - e.pts[2 * (i - 1)]!), e.pts[2 * (i - 1) + 1]! + t * (e.pts[2 * i + 1]! - e.pts[2 * (i - 1) + 1]!)];
    };
    const lo = Math.min(a, b);
    const hi = Math.max(a, b);
    const out: LatLon[] = [at(lo)];
    for (let i = 0; i < n; i++) if (e.cum[i]! > lo && e.cum[i]! < hi) out.push([e.pts[2 * i]!, e.pts[2 * i + 1]!]);
    out.push(at(hi));
    return a <= b ? out : out.reverse();
  }
}

function dedupe(pts: LatLon[]): LatLon[] {
  return pts.filter((p, i) => i === 0 || p[0] !== pts[i - 1]![0] || p[1] !== pts[i - 1]![1]);
}

class MinHeap {
  private k: number[] = [];
  private v: number[] = [];
  get size() {
    return this.k.length;
  }
  push(key: number, val: number) {
    const k = this.k;
    const v = this.v;
    k.push(key);
    v.push(val);
    let i = k.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (k[p]! <= key) break;
      k[i] = k[p]!;
      v[i] = v[p]!;
      i = p;
    }
    k[i] = key;
    v[i] = val;
  }
  pop(): [number, number] {
    const k = this.k;
    const v = this.v;
    const top: [number, number] = [k[0]!, v[0]!];
    const lk = k.pop()!;
    const lv = v.pop()!;
    if (k.length) {
      let i = 0;
      for (;;) {
        const l = 2 * i + 1;
        const r = l + 1;
        let m = -1;
        let mk = lk;
        if (l < k.length && k[l]! < mk) {
          m = l;
          mk = k[l]!;
        }
        if (r < k.length && k[r]! < mk) m = r;
        if (m < 0) break;
        k[i] = k[m]!;
        v[i] = v[m]!;
        i = m;
      }
      k[i] = lk;
      v[i] = lv;
    }
    return top;
  }
}

let cached: RailGraph | null | undefined;
/** The shared graph, loaded on first use (~0.5 s). Null when the graph file is missing. */
export function railGraph(): RailGraph | null {
  if (cached === undefined) cached = RailGraph.load();
  return cached;
}
