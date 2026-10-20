// Q3 (history): is the rikshållplats ID a stable station key across years?
// Compares rail stops of each older Sverige 2 snapshot with the newest one: same normalised ID,
// similar name, and distance between the two coordinates.
// Usage: node scripts/phase0/q3-riks-stability.mjs <newest zip> <older zip>...
import path from 'node:path';
import { readAll, readGtfs } from './gtfs.mjs';
import { haversine, nameSim } from './geo.mjs';

const norm = (id) => (id.length === 7 && id.startsWith('74') ? '7400' + id.slice(2) : id);
async function railStops(zip) {
  const routes = new Map((await readAll(zip, 'routes.txt')).map((r) => [r.route_id, r]));
  const isRail = (t) => t === '2' || (+t >= 100 && +t < 200);
  const trips = new Set((await readAll(zip, 'trips.txt', (t) => isRail(routes.get(t.route_id)?.route_type))).map((t) => t.trip_id));
  const used = new Set();
  for await (const s of readGtfs(zip, 'stop_times.txt')) if (trips.has(s.trip_id)) used.add(s.stop_id);
  return Object.fromEntries((await readAll(zip, 'stops.txt', (s) => used.has(s.stop_id))).map((s) => [norm(s.stop_id), s]));
}
const [newest, ...older] = process.argv.slice(2);
const now = await railStops(newest);
const allNow = Object.fromEntries((await readAll(newest, 'stops.txt')).map((s) => [s.stop_id, s]));
for (const zip of older) {
  const old = await railStops(zip);
  let same = 0, sameName = 0, near = 0, gone = 0;
  const odd = [];
  for (const [id, s] of Object.entries(old)) {
    const n = allNow[id];
    if (!n) { gone++; continue; }
    same++;
    const d = haversine(+s.stop_lat, +s.stop_lon, +n.stop_lat, +n.stop_lon);
    if (nameSim(s.stop_name, n.stop_name) >= 0.5) sameName++;
    else if (odd.length < 8) odd.push(`${s.stop_name} → ${n.stop_name}`);
    if (d <= 500) near++;
  }
  const t = Object.keys(old).length;
  console.log(`${path.basename(zip)}: ${t} rail stops; ID still exists in ${path.basename(newest)}: ${same} (${((100 * same) / t).toFixed(1)}%), of which similar name ${sameName}, within 500 m ${near}; ID gone ${gone}`);
  if (odd.length) console.log(`  renamed examples: ${odd.join('; ')}`);
  console.log(`  still a rail stop today: ${Object.keys(old).filter((id) => now[id]).length}`);
}
