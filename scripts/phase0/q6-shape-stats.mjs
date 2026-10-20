// Q6 (part 1): are GTFS Sweden 3 rail shapes detailed geometry or just stop-to-stop lines?
// Per operator: points per km, share of shapes whose points ≈ stop count, max gap between points,
// and how far stops sit from their shape.
import fs from 'node:fs';
import path from 'node:path';
import { load, tripOperators, stopTimesByTrip, P0 } from './p0data.mjs';

const hav = (a, b, c, d) => {
  const R = 6371008.8, r = Math.PI / 180;
  const x = Math.sin(((c - a) * r) / 2) ** 2 + Math.cos(a * r) * Math.cos(c * r) * Math.sin(((d - b) * r) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
};
const shapes = load('shapes.json');
const trips = load('trips.json');
const ops = tripOperators();
const st = stopTimesByTrip();
const stops = Object.fromEntries(load('stops.json').map((s) => [s.stop_id, s]));

const per = new Map();
const samples = {};
const seen = new Set();
for (const t of trips) {
  if (!t.shape_id || seen.has(t.shape_id) || !shapes[t.shape_id]) continue;
  seen.add(t.shape_id);
  const pts = shapes[t.shape_id];
  let len = 0, maxGap = 0;
  for (let i = 1; i < pts.length; i++) {
    const g = hav(pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2]);
    len += g;
    if (g > maxGap) maxGap = g;
  }
  const sts = st.get(t.trip_id) ?? [];
  // stop -> nearest shape vertex distance (sampled)
  let maxStopOff = 0;
  for (const s of sts) {
    const p = stops[s[2]];
    let best = Infinity;
    for (const q of pts) { const d = hav(+p.stop_lat, +p.stop_lon, q[1], q[2]); if (d < best) best = d; }
    if (best > maxStopOff) maxStopOff = best;
  }
  const op = ops[t.trip_id] ?? '?';
  const e = per.get(op) ?? per.set(op, { n: 0, km: 0, pts: 0, stopOnly: 0, gaps: [], off: [] }).get(op);
  e.n++;
  e.km += len / 1000;
  e.pts += pts.length;
  if (pts.length <= sts.length * 1.5) e.stopOnly++;
  e.gaps.push(maxGap);
  e.off.push(maxStopOff);
  if (!samples[op] && len > 20000) samples[op] = { trip_id: t.trip_id, shape_id: t.shape_id, number: t.samtrafiken_internal_trip_number };
}
const med = (a) => { const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length / 2)] ?? 0; };
const p95 = (a) => { const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length * 0.95)] ?? 0; };
console.log('operator | unique shapes | pts/km | shapes with ~only stop points | median max gap (m) | p95 max gap (m) | median max stop→shape (m)');
for (const [op, e] of [...per].sort((a, b) => b[1].n - a[1].n)) {
  console.log(`${op} | ${e.n} | ${(e.pts / e.km).toFixed(1)} | ${e.stopOnly} | ${med(e.gaps).toFixed(0)} | ${p95(e.gaps).toFixed(0)} | ${med(e.off).toFixed(0)}`);
}
fs.writeFileSync(path.join(P0, 'shape_samples.json'), JSON.stringify(samples, null, 1));
console.log('\nsample shapes per operator written to shape_samples.json');
