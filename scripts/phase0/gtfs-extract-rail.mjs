// Extract the rail subset of GTFS Sweden 3 into small JSON files under data/cache/phase0/
// so later Phase 0 scripts don't re-scan the 4 GB feed.
// Usage: node scripts/phase0/gtfs-extract-rail.mjs [zipPath]
import fs from 'node:fs';
import path from 'node:path';
import { CACHE } from './lib.mjs';
import { readAll, readGtfs } from './gtfs.mjs';

const zip = process.argv[2] ?? path.join(CACHE, 'gtfs_se3/sweden.zip');
const OUT = path.join(CACHE, 'phase0');
fs.mkdirSync(OUT, { recursive: true });

// Rail = GTFS extended route types 100–199, plus SL's narrow-gauge suburban lines that the
// feed files as route_type 900 (tram): Saltsjöbanan 25/26, Roslagsbanan 27/27S/28/28S/29.
const SL_NARROW_GAUGE = new Set(['25', '26', '27', '27S', '28', '28S', '29']);
const isRail = (r, agencyName) =>
  (Number(r.route_type) >= 100 && Number(r.route_type) < 200) ||
  (r.route_type === '900' && agencyName === 'AB SL Kundtjänst' && SL_NARROW_GAUGE.has(r.route_short_name));

const agencies = Object.fromEntries((await readAll(zip, 'agency.txt')).map((a) => [a.agency_id, a.agency_name]));
const routes = (await readAll(zip, 'routes.txt')).filter((r) => isRail(r, agencies[r.agency_id]));
const routeIds = new Set(routes.map((r) => r.route_id));
const trips = await readAll(zip, 'trips.txt', (t) => routeIds.has(t.route_id));
const tripIds = new Set(trips.map((t) => t.trip_id));
const attributions = await readAll(zip, 'attributions.txt', (a) => tripIds.has(a.trip_id));
console.log(`rail routes ${routes.length}, trips ${trips.length}`);

const stopTimes = [];
const usedStops = new Set();
for await (const st of readGtfs(zip, 'stop_times.txt')) {
  if (!tripIds.has(st.trip_id)) continue;
  stopTimes.push([st.trip_id, +st.stop_sequence, st.stop_id, st.arrival_time, st.departure_time, st.pickup_type, st.drop_off_type, st.shape_dist_traveled]);
  usedStops.add(st.stop_id);
}
console.log(`rail stop_times ${stopTimes.length}, stops used ${usedStops.size}`);

const allStops = await readAll(zip, 'stops.txt');
const stopById = Object.fromEntries(allStops.map((s) => [s.stop_id, s]));
// Keep used stops plus their parent stations.
const keep = new Set(usedStops);
for (const id of usedStops) if (stopById[id]?.parent_station) keep.add(stopById[id].parent_station);
const stops = allStops.filter((s) => keep.has(s.stop_id));
const stopAreas = await readAll(zip, 'stop_areas.txt', (sa) => keep.has(sa.stop_id));
const areaIds = new Set(stopAreas.map((sa) => sa.area_id));
const areas = await readAll(zip, 'areas.txt', (a) => areaIds.has(a.area_id));

const serviceIds = new Set(trips.map((t) => t.service_id));
const calendar = await readAll(zip, 'calendar.txt', (c) => serviceIds.has(c.service_id));
const calendarDates = await readAll(zip, 'calendar_dates.txt', (c) => serviceIds.has(c.service_id));

const shapeIds = new Set(trips.map((t) => t.shape_id).filter(Boolean));
const shapes = {};
for await (const p of readGtfs(zip, 'shapes.txt')) {
  if (!shapeIds.has(p.shape_id)) continue;
  (shapes[p.shape_id] ??= []).push([+p.shape_pt_sequence, +p.shape_pt_lat, +p.shape_pt_lon, p.shape_dist_traveled === '' ? null : +p.shape_dist_traveled]);
}
for (const pts of Object.values(shapes)) pts.sort((a, b) => a[0] - b[0]);
console.log(`rail shapes ${Object.keys(shapes).length}`);

const write = (name, data) => fs.writeFileSync(path.join(OUT, name), JSON.stringify(data));
write('agencies.json', agencies);
write('routes.json', routes);
write('trips.json', trips);
write('attributions.json', attributions);
write('stop_times.json', stopTimes);
write('stops.json', stops);
write('stop_areas.json', stopAreas);
write('areas.json', areas);
write('calendar.json', calendar);
write('calendar_dates.json', calendarDates);
write('shapes.json', shapes);
console.log(`wrote ${OUT}`);
