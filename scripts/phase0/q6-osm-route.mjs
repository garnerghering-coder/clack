// Q6 (part 3): can we draw legs along real track by routing on the OSM rail graph?
// 1. Routes every consecutive station pair used by rail trips on <date> (snap each station to the
//    nearest rail node within 1 km, Dijkstra by length) and reports success rate + detour ratios.
// 2. Measures how closely GTFS's few detailed shapes (VR Sverige etc.) follow OSM track.
// 3. Writes a GeoJSON sample (data/cache/phase0/route_samples.geojson) for eyeballing.
// Usage: node scripts/phase0/q6-osm-route.mjs 2026-10-20
import fs from 'node:fs';
import path from 'node:path';
import { CACHE } from './lib.mjs';
import { load, serviceDates, stopTimesByTrip, tripOperators, P0 } from './p0data.mjs';

const date = (process.argv[2] ?? '2026-10-20').replaceAll('-', '');
const hav = (a, b, c, d) => {
  const R = 6371008.8, r = Math.PI / 180;
  const x = Math.sin(((c - a) * r) / 2) ** 2 + Math.cos(a * r) * Math.cos(c * r) * Math.sin(((d - b) * r) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
};

// ---- graph
const osm = JSON.parse(fs.readFileSync(path.join(CACHE, 'osm/rail.json'), 'utf8'));
const idx = new Map(); // osm node id -> int
const lat = [], lon = [];
for (const [id, [la, lo]] of Object.entries(osm.nodes)) { idx.set(id, lat.length); lat.push(la); lon.push(lo); }
const adj = Array.from({ length: lat.length }, () => []);
// Service track stays in the graph (it links lines inside stations) but costs 5× so routes prefer running lines.
const SERVICE_PENALTY = { yard: 5, siding: 5, spur: 5, crossover: 1 };
const realLen = new Map(); // "a,b" -> metres, for reporting true length on penalised edges
for (const [, , , service, nodes] of osm.ways) {
  const pen = SERVICE_PENALTY[service] ?? 1;
  for (let i = 1; i < nodes.length; i++) {
    const a = idx.get(String(nodes[i - 1])), b = idx.get(String(nodes[i]));
    if (a === undefined || b === undefined) continue;
    const w = hav(lat[a], lon[a], lat[b], lon[b]) * pen;
    adj[a].push(b, w); adj[b].push(a, w);
  }
}
// grid index ~1 km cells for snapping
const CELL = 0.01;
const grid = new Map();
const key = (la, lo) => `${Math.floor(la / CELL)},${Math.floor(lo / (CELL * 2))}`;
const running = new Set();
for (const [, , , service, nodes] of osm.ways) if (!SERVICE_PENALTY[service] || service === 'crossover') for (const n of nodes) { const i = idx.get(String(n)); if (i !== undefined) running.add(i); }
for (const i of running) { const k = key(lat[i], lon[i]); (grid.get(k) ?? grid.set(k, []).get(k)).push(i); }
function snap(la, lo, maxM = 1000) {
  let best = -1, bd = Infinity;
  const ci = Math.floor(la / CELL), cj = Math.floor(lo / (CELL * 2));
  for (let di = -1; di <= 1; di++) for (let dj = -1; dj <= 1; dj++) {
    for (const i of grid.get(`${ci + di},${cj + dj}`) ?? []) { const d = hav(la, lo, lat[i], lon[i]); if (d < bd) { bd = d; best = i; } }
  }
  return bd <= maxM ? { node: best, d: bd } : null;
}
// binary-heap Dijkstra
function route(s, t, limitM) {
  const dist = new Map([[s, 0]]), prev = new Map();
  const heap = [[0, s]];
  const push = (x) => { heap.push(x); let i = heap.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (heap[p][0] <= heap[i][0]) break; [heap[p], heap[i]] = [heap[i], heap[p]]; i = p; } };
  const pop = () => { const top = heap[0], last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0; for (;;) { const l = 2 * i + 1, r = l + 1; let m = i; if (l < heap.length && heap[l][0] < heap[m][0]) m = l; if (r < heap.length && heap[r][0] < heap[m][0]) m = r; if (m === i) break; [heap[m], heap[i]] = [heap[i], heap[m]]; i = m; } } return top; };
  while (heap.length) {
    const [d, u] = pop();
    if (u === t) break;
    if (d > (dist.get(u) ?? Infinity) || d > limitM) continue;
    const a = adj[u];
    for (let k = 0; k < a.length; k += 2) {
      const v = a[k], nd = d + a[k + 1];
      if (nd < (dist.get(v) ?? Infinity)) { dist.set(v, nd); prev.set(v, u); push([nd, v]); }
    }
  }
  if (!dist.has(t)) return null;
  const pathNodes = [t];
  while (pathNodes[0] !== s) pathNodes.unshift(prev.get(pathNodes[0]));
  let length = 0;
  for (let i = 1; i < pathNodes.length; i++) length += hav(lat[pathNodes[i - 1]], lon[pathNodes[i - 1]], lat[pathNodes[i]], lon[pathNodes[i]]);
  return { length, nodes: pathNodes };
}

// ---- station pairs for the date
const stops = Object.fromEntries(load('stops.json').map((s) => [s.stop_id, s]));
const parent = (id) => stops[id].parent_station || id;
const sd = serviceDates();
const st = stopTimesByTrip();
const ops = tripOperators();
const pairs = new Map(); // "a|b" -> {a, b, ops:Set, gtfsDist}
for (const t of load('trips.json')) {
  if (!sd.get(t.service_id)?.has(date)) continue;
  const s = st.get(t.trip_id) ?? [];
  for (let i = 1; i < s.length; i++) {
    const a = parent(s[i - 1][2]), b = parent(s[i][2]);
    if (a === b) continue;
    const k = a < b ? `${a}|${b}` : `${b}|${a}`;
    const e = pairs.get(k) ?? pairs.set(k, { a, b, ops: new Set() }).get(k);
    e.ops.add(ops[t.trip_id]);
  }
}
const res = { ok: 0, snapFail: 0, noPath: 0, detour: 0 };
const ratios = [];
const failures = [];
const segs = new Map();
for (const [k, e] of pairs) {
  const A = stops[e.a], B = stops[e.b];
  const gc = hav(+A.stop_lat, +A.stop_lon, +B.stop_lat, +B.stop_lon);
  const sa = snap(+A.stop_lat, +A.stop_lon), sb = snap(+B.stop_lat, +B.stop_lon);
  if (!sa || !sb) { res.snapFail++; failures.push(`snap: ${A.stop_name} – ${B.stop_name} (${[...e.ops].join('/')})`); continue; }
  const r = route(sa.node, sb.node, Math.max(gc * 3, 20000));
  if (!r) { res.noPath++; failures.push(`no path: ${A.stop_name} – ${B.stop_name} (${[...e.ops].join('/')})`); continue; }
  const ratio = r.length / Math.max(gc, 1);
  ratios.push(ratio);
  if (ratio > 1.6 && gc > 2000) { res.detour++; failures.push(`detour ×${ratio.toFixed(2)}: ${A.stop_name} – ${B.stop_name} (${(r.length / 1000).toFixed(1)} km vs ${(gc / 1000).toFixed(1)} km straight)`); }
  else res.ok++;
  segs.set(k, r);
}
const n = pairs.size;
ratios.sort((a, b) => a - b);
console.log(`station pairs on ${date}: ${n}`);
console.log(`  routed OK: ${res.ok} (${((100 * res.ok) / n).toFixed(1)}%), suspicious detour (>1.6× straight): ${res.detour}, no path: ${res.noPath}, station >1 km from track: ${res.snapFail}`);
console.log(`  track/straight-line ratio: median ${ratios[Math.floor(ratios.length / 2)].toFixed(3)}, p95 ${ratios[Math.floor(ratios.length * 0.95)].toFixed(3)}`);
console.log('  failures/suspicious (first 40):');
for (const f of failures.slice(0, 40)) console.log('   ', f);

// ---- full-trip example lengths
const examples = [];
for (const want of [['423', 'SJ AB'], ['523', 'SJ AB'], ['3933', 'Snälltåget']]) {
  const t = load('trips.json').find((x) => x.samtrafiken_internal_trip_number === want[0] && sd.get(x.service_id)?.has(date));
  if (!t) continue;
  const s = st.get(t.trip_id);
  let total = 0, straight = 0, ok = true;
  const coords = [];
  for (let i = 1; i < s.length; i++) {
    const a = parent(s[i - 1][2]), b = parent(s[i][2]);
    const k = a < b ? `${a}|${b}` : `${b}|${a}`;
    const r = segs.get(k);
    straight += hav(+stops[a].stop_lat, +stops[a].stop_lon, +stops[b].stop_lat, +stops[b].stop_lon);
    if (!r) { ok = false; continue; }
    total += r.length;
    const nodes = a < b ? r.nodes : [...r.nodes].reverse();
    for (const v of nodes) coords.push([lon[v], lat[v]]);
  }
  const gtfsDist = +s.at(-1)[7] || null;
  console.log(`\ntrain ${want[0]} ${stops[parent(s[0][2])].stop_name} → ${stops[parent(s.at(-1)[2])].stop_name}: OSM-routed ${(total / 1000).toFixed(1)} km${ok ? '' : ' (some segments failed)'}, straight stop-to-stop ${(straight / 1000).toFixed(1)} km, GTFS shape_dist_traveled ${gtfsDist ? (gtfsDist / 1000).toFixed(1) + ' km' : 'n/a'}`);
  examples.push({ type: 'Feature', properties: { train: want[0], kind: 'osm_routed', km: +(total / 1000).toFixed(1) }, geometry: { type: 'LineString', coordinates: coords } });
  const shp = load('shapes.json')[t.shape_id];
  if (shp) examples.push({ type: 'Feature', properties: { train: want[0], kind: 'gtfs_shape', points: shp.length }, geometry: { type: 'LineString', coordinates: shp.map((p) => [p[2], p[1]]) } });
}
fs.writeFileSync(path.join(P0, 'route_samples.geojson'), JSON.stringify({ type: 'FeatureCollection', features: examples }));

// ---- how close are GTFS detailed shapes to OSM track?
const shapes = load('shapes.json');
const offs = [];
const perOp = new Map();
const seen = new Set();
for (const t of load('trips.json')) {
  const op = ops[t.trip_id];
  const pts = shapes[t.shape_id];
  if (!pts || seen.has(t.shape_id)) continue;
  seen.add(t.shape_id);
  if (pts.length < 50) continue; // only detailed shapes
  const e = perOp.get(op) ?? perOp.set(op, []).get(op);
  for (let i = 0; i < pts.length; i += 10) {
    const s = snap(pts[i][1], pts[i][2], 5000);
    const d = s ? s.d : 5000;
    e.push(d); offs.push(d);
  }
}
const q = (a, p) => { const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length * p)] ?? NaN; };
console.log('\nDetailed GTFS shapes: distance from shape vertex to nearest OSM rail node');
for (const [op, a] of perOp) console.log(`  ${op}: n=${a.length} median ${q(a, 0.5).toFixed(0)} m, p95 ${q(a, 0.95).toFixed(0)} m, >100 m: ${((100 * a.filter((x) => x > 100).length) / a.length).toFixed(1)}%`);
