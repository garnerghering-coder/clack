// Q4: inspect GTFS Sverige 2 archive snapshots: files, service-date window, rail route types,
// where the train number lives, and whether a known train can be found.
// Usage: node scripts/phase0/q4-sverige2-inspect.mjs <zip>... [--train 523]
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { readAll, readGtfs } from './gtfs.mjs';

const args = process.argv.slice(2);
const ti = args.indexOf('--train');
const train = ti >= 0 ? args.splice(ti, 2)[1] : '523';

for (const zip of args) {
  console.log(`\n## ${path.basename(zip)}`);
  const list = execFileSync('unzip', ['-l', zip], { encoding: 'utf8' })
    .split('\n').filter((l) => /\.txt$/.test(l)).map((l) => l.trim().split(/\s+/)).map((p) => `${p[3]} (${(p[0] / 1e6).toFixed(1)} MB)`);
  console.log('files:', list.filter((l) => !/agency_stops_\d+/.test(l)).map((l) => l.replace(/^.*\//, '')).join(', '));
  const has = (f) => list.some((l) => l.startsWith(f + ' ') || l.includes('/gtfs-sweden/' + f + ' ') || l.includes('/' + f + ' '));
  if (has('feed_info.txt')) console.log('feed_info:', JSON.stringify((await readAll(zip, 'feed_info.txt'))[0]));

  let min = '99999999', max = '0';
  if (has('calendar.txt')) for (const c of await readAll(zip, 'calendar.txt')) { if (c.start_date < min) min = c.start_date; if (c.end_date > max) max = c.end_date; }
  if (has('calendar_dates.txt')) for await (const c of readGtfs(zip, 'calendar_dates.txt')) { if (c.exception_type !== '1') continue; if (c.date < min) min = c.date; if (c.date > max) max = c.date; }
  console.log(`service dates: ${min} .. ${max}`);

  const agencies = Object.fromEntries((await readAll(zip, 'agency.txt')).map((a) => [a.agency_id, a.agency_name]));
  const routes = await readAll(zip, 'routes.txt');
  const types = {};
  for (const r of routes) types[r.route_type] = (types[r.route_type] ?? 0) + 1;
  console.log('route_type counts:', JSON.stringify(types));
  // Older snapshots use basic route_type 2 (rail); newer use extended 100–199.
  const isRail = (t) => (+t >= 100 && +t < 200) || t === '2';
  const railRoutes = new Map(routes.filter((r) => isRail(r.route_type)).map((r) => [r.route_id, r]));
  const trips = await readAll(zip, 'trips.txt', (t) => railRoutes.has(t.route_id));
  console.log(`rail routes ${railRoutes.size}, rail trips ${trips.length}; trips.txt columns: ${Object.keys(trips[0] ?? {}).join(',')}`);
  const filled = (f) => trips.filter((t) => t[f]).length;
  for (const f of ['trip_short_name', 'trip_headsign']) if (f in (trips[0] ?? {})) console.log(`  ${f} filled ${filled(f)}/${trips.length}`);
  console.log('  sample rail routes/trips:');
  for (const t of trips.filter((_, i) => i % Math.max(1, Math.floor(trips.length / 6)) === 0).slice(0, 6)) {
    const r = railRoutes.get(t.route_id);
    console.log(`    agency=${agencies[r.agency_id]} type=${r.route_type} route_short=${r.route_short_name} route_long=${r.route_long_name} trip_short=${t.trip_short_name ?? ''} headsign=${t.trip_headsign ?? ''}`);
  }
  // Find the known train: route_short_name or trip_short_name == train
  const hits = trips.filter((t) => t.trip_short_name === train || railRoutes.get(t.route_id).route_short_name === train);
  console.log(`train ${train}: ${hits.length} matching trips` + (hits[0] ? ` e.g. trip_id ${hits[0].trip_id} (${agencies[railRoutes.get(hits[0].route_id).agency_id]})` : ''));
  if (hits[0]) {
    const st = await readAll(zip, 'stop_times.txt', (s) => s.trip_id === hits[0].trip_id);
    const stops = Object.fromEntries((await readAll(zip, 'stops.txt')).map((s) => [s.stop_id, s.stop_name]));
    st.sort((a, b) => a.stop_sequence - b.stop_sequence);
    console.log('  stops: ' + st.map((s) => `${stops[s.stop_id]} ${s.departure_time.slice(0, 5)}`).join(' → '));
  }
  console.log(`shapes.txt present: ${has('shapes.txt')}`);
}
