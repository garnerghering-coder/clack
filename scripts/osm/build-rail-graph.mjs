// Builds the compact rail graph the server routes on: data/osm/rail-graph.json.gz (committed, ODbL).
//
// Input: data/cache/osm/rail.json from scripts/phase0/osm_rail_extract.py (SE + DK + NO extracts).
// Chains of degree-2 nodes are collapsed into edges between junctions, and each edge's geometry is
// simplified (Douglas–Peucker, 2 m) and stored as an encoded polyline (precision 5, ~1 m).
//
// Output: { version, generated, attribution, license, nodes: [lat, lon, …] (junctions),
//           edges: [[u, v, flags, polyline]] }
//   flags bit 0: service track (yard/siding/spur; the router charges 5×)
//         bits 1–2: kind (0 rail, 1 light_rail, 2 narrow_gauge)
//         bit 3: usage is industrial/military/tourism (hidden in the rail-network layer)
//
// Usage: node scripts/osm/build-rail-graph.mjs [path/to/rail.json]
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const ROOT = path.resolve(import.meta.dirname, '../..');
const src = process.argv[2] ?? path.join(ROOT, 'data/cache/osm/rail.json');
const out = path.join(ROOT, 'data/osm/rail-graph.json.gz');

const SERVICE = new Set(['yard', 'siding', 'spur']);
const KIND = { rail: 0, light_rail: 1, narrow_gauge: 2 };
const MINOR_USAGE = new Set(['industrial', 'military', 'tourism']);
const SIMPLIFY_M = 2;

const osm = JSON.parse(fs.readFileSync(src, 'utf8'));
const coord = new Map(Object.entries(osm.nodes).map(([id, c]) => [Number(id), c]));

// Undirected adjacency: node -> Map(neighbour -> flags). Overlapping ways collapse to one edge.
const adj = new Map();
const link = (a, b, f) => {
  if (a === b || !coord.has(a) || !coord.has(b)) return;
  (adj.get(a) ?? adj.set(a, new Map()).get(a)).set(b, f);
  (adj.get(b) ?? adj.set(b, new Map()).get(b)).set(a, f);
};
for (const [, kind, usage, service, nodes] of osm.ways) {
  const f = (SERVICE.has(service) ? 1 : 0) | ((KIND[kind] ?? 0) << 1) | (MINOR_USAGE.has(usage) ? 8 : 0);
  for (let i = 1; i < nodes.length; i++) link(nodes[i - 1], nodes[i], f);
}

// Junctions: anything that isn't a plain pass-through with the same flags on both sides.
const isKey = (n) => {
  const m = adj.get(n);
  if (m.size !== 2) return true;
  const [f1, f2] = [...m.values()];
  return f1 !== f2;
};
const keyIdx = new Map();
const nodesOut = [];
const keyOf = (n) => {
  let i = keyIdx.get(n);
  if (i === undefined) {
    i = keyIdx.size;
    keyIdx.set(n, i);
    const [la, lo] = coord.get(n);
    nodesOut.push(+la.toFixed(6), +lo.toFixed(6));
  }
  return i;
};

const seen = new Set(); // "a,b" directed half-edges already walked
const edgeKey = (a, b) => `${a},${b}`;
const edges = [];
function walk(start, next) {
  if (seen.has(edgeKey(start, next))) return;
  const f = adj.get(start).get(next);
  const chain = [start, next];
  seen.add(edgeKey(start, next));
  seen.add(edgeKey(next, start));
  let prev = start;
  let cur = next;
  while (!isKey(cur) && cur !== start) {
    const nxt = [...adj.get(cur).keys()].find((x) => x !== prev);
    seen.add(edgeKey(cur, nxt));
    seen.add(edgeKey(nxt, cur));
    chain.push(nxt);
    prev = cur;
    cur = nxt;
  }
  edges.push([keyOf(start), keyOf(cur), f, encode(simplify(chain.map((n) => coord.get(n))))]);
}
for (const n of adj.keys()) if (isKey(n)) for (const m of adj.get(n).keys()) walk(n, m);
// Loops with no junction at all (rare: isolated circles).
for (const n of adj.keys()) for (const m of adj.get(n).keys()) if (!seen.has(edgeKey(n, m))) walk(n, m);

function simplify(pts) {
  if (pts.length < 3) return pts;
  const lat0 = (pts[0][0] * Math.PI) / 180;
  const xy = pts.map(([la, lo]) => [lo * 111320 * Math.cos(lat0), la * 110540]);
  const keep = new Uint8Array(pts.length);
  keep[0] = keep[pts.length - 1] = 1;
  const stack = [[0, pts.length - 1]];
  while (stack.length) {
    const [a, b] = stack.pop();
    let best = -1;
    let bd = SIMPLIFY_M;
    for (let i = a + 1; i < b; i++) {
      const d = segDist(xy[i], xy[a], xy[b]);
      if (d > bd) { bd = d; best = i; }
    }
    if (best >= 0) { keep[best] = 1; stack.push([a, best], [best, b]); }
  }
  return pts.filter((_, i) => keep[i]);
}
function segDist([px, py], [ax, ay], [bx, by]) {
  const dx = bx - ax, dy = by - ay;
  const l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) : 0;
  return Math.hypot(px - ax - t * dx, py - ay - t * dy);
}
function encode(pts) {
  let s = '', pla = 0, plo = 0;
  const enc = (v) => {
    v = v < 0 ? ~(v << 1) : v << 1;
    while (v >= 0x20) { s += String.fromCharCode((0x20 | (v & 0x1f)) + 63); v >>= 5; }
    s += String.fromCharCode(v + 63);
  };
  for (const [la, lo] of pts) {
    const a = Math.round(la * 1e5), o = Math.round(lo * 1e5);
    enc(a - pla); enc(o - plo);
    pla = a; plo = o;
  }
  return s;
}

const graph = {
  version: 1,
  generated: new Date().toISOString(),
  source: 'OpenStreetMap extracts (Sweden, Denmark, Norway) via download.openstreetmap.fr',
  attribution: '© OpenStreetMap contributors',
  license: 'ODbL-1.0 (https://opendatacommons.org/licenses/odbl/1-0/)',
  nodes: nodesOut,
  edges,
};
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, zlib.gzipSync(JSON.stringify(graph), { level: 9 }));
const pts = edges.reduce((n, e) => n + e[3].length, 0);
console.log(`${coord.size} OSM nodes -> ${keyIdx.size} junctions, ${edges.length} edges, polyline chars ${pts}`);
console.log(`wrote ${path.relative(ROOT, out)} (${(fs.statSync(out).size / 1e6).toFixed(2)} MB)`);
