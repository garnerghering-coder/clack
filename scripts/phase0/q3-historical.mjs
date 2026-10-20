// Q3 (history): can rail stops in GTFS Sverige 2 archive snapshots be mapped to Trafikverket signatures?
// Sverige 2 stop_ids are rikshållplats IDs (9 digits; 7 digits before 2016: '74xxxxx' -> '7400xxxxx').
// Methods, in order: Trafiklab trafikverket_stops.txt (current) -> the GTFS Sweden 3 draft mapping via
// stop_area_id -> nearest Trafikverket location <= 300 m with a similar name -> nearest <= 100 m.
// Usage: node scripts/phase0/q3-historical.mjs <sverige2 zip>...
import fs from 'node:fs';
import path from 'node:path';
import { ROOT, CACHE } from './lib.mjs';
import { load } from './p0data.mjs';
import { readAll, readGtfs, parseCsvLine } from './gtfs.mjs';
import { haversine, nameSim } from './geo.mjs';

const riksToSig = {};
for (const line of fs.readFileSync(path.join(CACHE, 'sv2_extra/trafikverket_stops.txt'), 'utf8').replace(/^﻿/, '').split('\n').slice(1)) {
  const [id, sig] = line.trim().split(',');
  if (id && sig) riksToSig[id] ??= sig;
}
const csv = fs.readFileSync(path.join(ROOT, 'data/station_mapping.draft.csv'), 'utf8').trim().split('\n');
const head = parseCsvLine(csv[0]);
const areaToSig = {};
for (const line of csv.slice(1)) {
  const r = Object.fromEntries(head.map((h, i) => [h, parseCsvLine(line)[i]]));
  if (r.stop_area_id && r.trv_signature) areaToSig[r.stop_area_id] = r.trv_signature;
}
const trv = load('trv_stations.json').map((s) => {
  const m = s.Geometry?.WGS84?.match(/POINT \(([-\d.]+) ([-\d.]+)\)/);
  return { sig: s.LocationSignature, name: s.AdvertisedLocationName, lat: m ? +m[2] : null, lon: m ? +m[1] : null };
}).filter((s) => s.lat != null);
const trvSigs = new Set(trv.map((s) => s.sig.toLowerCase()));

const norm = (id) => (id.length === 7 && id.startsWith('74') ? '7400' + id.slice(2) : id);

for (const zip of process.argv.slice(2)) {
  const routes = new Map((await readAll(zip, 'routes.txt')).map((r) => [r.route_id, r]));
  const isRail = (t) => t === '2' || (+t >= 100 && +t < 200);
  const railTrips = new Set((await readAll(zip, 'trips.txt', (t) => isRail(routes.get(t.route_id)?.route_type))).map((t) => t.trip_id));
  const used = new Map();
  for await (const s of readGtfs(zip, 'stop_times.txt')) if (railTrips.has(s.trip_id)) used.set(s.stop_id, (used.get(s.stop_id) ?? 0) + 1);
  const stops = Object.fromEntries((await readAll(zip, 'stops.txt', (s) => used.has(s.stop_id))).map((s) => [s.stop_id, s]));

  const by = { official: 0, se3_area: 0, geo_name: 0, geo_only: 0, none: 0 };
  let ev = 0, evMapped = 0;
  const unmapped = [];
  for (const [id, n] of used) {
    const s = stops[id];
    const riks = norm(id);
    let method = 'none';
    if (riksToSig[riks] && trvSigs.has(riksToSig[riks].toLowerCase())) method = 'official';
    else if (areaToSig[riks]) method = 'se3_area';
    else if (s) {
      let best = null;
      for (const t of trv) {
        const d = haversine(+s.stop_lat, +s.stop_lon, t.lat, t.lon);
        if (d <= 300 && nameSim(s.stop_name, t.name) >= 0.5) { method = 'geo_name'; break; }
        if (d <= 100) best = t;
      }
      if (method === 'none' && best) method = 'geo_only';
    }
    by[method]++;
    ev += n;
    if (method !== 'none') evMapped += n;
    else unmapped.push([s?.stop_name ?? id, n, riks]);
  }
  const total = used.size;
  console.log(`\n## ${path.basename(zip)}: ${total} rail stops, ${railTrips.size} rail trips`);
  console.log(`  mapped ${total - by.none}/${total} (${((100 * (total - by.none)) / total).toFixed(1)}%); stop events mapped ${((100 * evMapped) / ev).toFixed(2)}%`);
  console.log(`  by method: ${Object.entries(by).map(([k, v]) => `${k} ${v}`).join(', ')}`);
  unmapped.sort((a, b) => b[1] - a[1]);
  console.log(`  top unmapped: ${unmapped.slice(0, 15).map(([n, c]) => `${n} (${c})`).join('; ')}`);
}
