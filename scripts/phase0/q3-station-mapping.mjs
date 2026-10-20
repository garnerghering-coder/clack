// Q3: draft mapping GTFS Sweden 3 rail stations (parent stations) <-> Trafikverket LocationSignature.
// Three independent methods, then cross-checked:
//   official  — stop_areas.txt (station -> rikshållplats) + Trafiklab's trafikverket_stops.txt (rikshållplats -> signature)
//   geo_name  — nearest Trafikverket station within 300 m with a similar normalised name (the spec's method)
//   timetable — for trains matched by number on a date, the Trafikverket location whose advertised time
//               equals the GTFS stop time (votes; strongest evidence of what Trafikverket calls the stop).
//               Only trusted with >= 3 votes, >= 60% vote share and <= 2 km apart (coincidental votes happen).
//   geo_only  — fallback: nearest Trafikverket location within 100 m whatever its name
//               (catches Danish names in Swedish, e.g. København H = "Köpenhamn H", and x-prefixed halts)
// Writes data/station_mapping.draft.csv and prints a summary.
// Usage: node scripts/phase0/q3-station-mapping.mjs 2026-10-19 2026-10-20
import fs from 'node:fs';
import path from 'node:path';
import { ROOT, CACHE } from './lib.mjs';
import { load, serviceDates, stopTimesByTrip } from './p0data.mjs';
import { gtfsTimeToSec } from './gtfs.mjs';
import { haversine, nameSim } from './geo.mjs';

const dates = process.argv.slice(2);
const RADIUS_M = 300;

// --- GTFS rail stations (parents of the platforms used by rail stop_times)
const stops = load('stops.json');
const stopById = Object.fromEntries(stops.map((s) => [s.stop_id, s]));
const stopTimes = stopTimesByTrip();
const usedParents = new Map(); // parent_id -> number of stop_times
for (const st of stopTimes.values()) for (const s of st) {
  const p = stopById[s[2]].parent_station || s[2];
  usedParents.set(p, (usedParents.get(p) ?? 0) + 1);
}
const areaType = Object.fromEntries(load('areas.json').map((a) => [a.area_id, a.samtrafiken_area_type]));
const riks = {};
for (const sa of load('stop_areas.json')) if (areaType[sa.area_id] === 'rikshallplats') riks[sa.stop_id] = sa.area_id;

// --- Trafikverket stations
const trv = load('trv_stations.json').filter((s) => !s.Deleted);
const trvBySig = {};
for (const s of trv) {
  const m = s.Geometry?.WGS84?.match(/POINT \(([-\d.]+) ([-\d.]+)\)/);
  s.lon = m ? +m[1] : null;
  s.lat = m ? +m[2] : null;
  trvBySig[s.LocationSignature.toLowerCase()] = s;
}

// --- Method 1: official
const officialFile = path.join(CACHE, 'sv2_extra/trafikverket_stops.txt');
const riksToSig = {};
for (const line of fs.readFileSync(officialFile, 'utf8').replace(/^﻿/, '').split('\n').slice(1)) {
  const [id, sig] = line.trim().split(',');
  if (id && sig) (riksToSig[id] ??= []).push(sig.toLowerCase());
}

// --- Method 3: timetable votes
const routes = Object.fromEntries(load('routes.json').map((r) => [r.route_id, r]));
const sd = serviceDates();
const votes = new Map(); // parent_id -> Map(sig -> count)
for (const date of dates) {
  const ymd = date.replaceAll('-', '');
  const ann = load(`trv_ann_${date}.json`).filter((a) => a.Advertised);
  const byTrain = new Map();
  for (const a of ann) (byTrain.get(a.AdvertisedTrainIdent) ?? byTrain.set(a.AdvertisedTrainIdent, []).get(a.AdvertisedTrainIdent)).push(a);
  for (const t of load('trips.json')) {
    if (!sd.get(t.service_id)?.has(ymd)) continue;
    const anns = byTrain.get(t.samtrafiken_internal_trip_number);
    if (!anns) continue;
    const st = stopTimes.get(t.trip_id) ?? [];
    for (const s of st) {
      const parent = stopById[s[2]].parent_station || s[2];
      for (const [time, act] of [[s[3], 'Ankomst'], [s[4], 'Avgang']]) {
        const sec = gtfsTimeToSec(time) % 86400;
        const hm = `${String(Math.floor(sec / 3600)).padStart(2, '0')}:${String(Math.floor((sec % 3600) / 60)).padStart(2, '0')}`;
        const hits = anns.filter((a) => a.ActivityType === act && a.AdvertisedTimeAtLocation.slice(11, 16) === hm);
        if (hits.length !== 1) continue; // ambiguous or none
        const sig = hits[0].LocationSignature.toLowerCase();
        const v = votes.get(parent) ?? votes.set(parent, new Map()).get(parent);
        v.set(sig, (v.get(sig) ?? 0) + 1);
      }
    }
  }
}

// --- Hand-checked overrides (data/station_overrides.json) win over everything
const overrides = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/station_overrides.json'), 'utf8'));

// --- Combine
const rows = [];
for (const [pid, nStopTimes] of usedParents) {
  const p = stopById[pid];
  const lat = +p.stop_lat, lon = +p.stop_lon;
  const area = riks[pid] ?? '';
  const official = (riksToSig[area] ?? []).filter((s) => trvBySig[s]);
  const officialMissing = (riksToSig[area] ?? []).filter((s) => !trvBySig[s]);

  let geo = null;
  for (const s of trv) {
    if (s.lat == null) continue;
    const d = haversine(lat, lon, s.lat, s.lon);
    if (d > RADIUS_M) continue;
    const sim = Math.max(nameSim(p.stop_name, s.AdvertisedLocationName), nameSim(p.stop_name, s.OfficialLocationName ?? ''));
    const score = sim - d / 3000;
    if (sim >= 0.5 && (!geo || score > geo.score)) geo = { sig: s.LocationSignature.toLowerCase(), d, sim, score };
  }
  let nearest = null;
  for (const s of trv) {
    if (s.lat == null) continue;
    const d = haversine(lat, lon, s.lat, s.lon);
    if (!nearest || d < nearest.d) nearest = { sig: s.LocationSignature.toLowerCase(), d };
  }

  const v = votes.get(pid);
  const vs = v ? [...v].sort((a, b) => b[1] - a[1]) : [];
  const ttShare = vs.length ? vs[0][1] / vs.reduce((s, x) => s + x[1], 0) : 0;
  const ttCand = vs[0]?.[0];
  const ttDist = ttCand && trvBySig[ttCand]?.lat != null ? haversine(lat, lon, trvBySig[ttCand].lat, trvBySig[ttCand].lon) : Infinity;
  const tt = ttCand && vs[0][1] >= 3 && ttShare >= 0.6 && ttDist <= 2000 ? ttCand : null;
  const geoOnly = nearest && nearest.d <= 100 ? nearest.sig : null;
  // Kind: foreign stops Trafikverket doesn't know, and bus stops inside "rail" trips (replacement/connecting buses).
  const country = area.startsWith('74') ? 'SE' : area.startsWith('86') ? 'DK' : area.startsWith('76') ? 'NO' : area.startsWith('80') ? 'DE' : area ? '?' : 'unknown';

  // Decision: timetable evidence wins, then official, then geo_name.
  let chosen = tt ?? official[0] ?? geo?.sig ?? geoOnly ?? null;
  const methods = [];
  if (tt && chosen === tt) methods.push('timetable');
  if (official.includes(chosen)) methods.push('official');
  if (geo?.sig === chosen) methods.push('geo_name');
  if (!methods.length && geoOnly === chosen) methods.push('geo_only');
  const conflict = new Set([tt, official[0], geo?.sig].filter(Boolean)).size > 1;
  const ov = overrides[pid];
  if (ov) {
    chosen = ov.trv_signature ? ov.trv_signature.toLowerCase() : null;
    methods.length = 0;
    methods.push('override');
  }
  const t = chosen ? trvBySig[chosen] : null;
  rows.push({
    gtfs_stop_id: pid, gtfs_name: p.stop_name, lat, lon, stop_area_id: area, stop_times: nStopTimes,
    trv_signature: t ? t.LocationSignature : '', trv_name: t?.AdvertisedLocationName ?? '',
    dist_m: t?.lat != null ? Math.round(haversine(lat, lon, t.lat, t.lon)) : '',
    methods: methods.join('+'), conflict: conflict && !ov ? 'yes' : '',
    official_sig: official.join('|') + (officialMissing.length ? ` (not in TrainStation: ${officialMissing.join('|')})` : ''),
    geo_sig: geo?.sig ?? '', timetable_sig: tt ?? '', timetable_votes: vs.map(([s, n]) => `${s}:${n}`).slice(0, 3).join(' '),
    timetable_share: ttShare ? ttShare.toFixed(2) : '',
    country,
    kind: ov ? ov.kind : chosen ? 'rail_station' : nearest && nearest.d > 1000 ? (country === 'SE' ? 'bus_stop_or_unknown' : 'foreign_not_in_trv') : 'needs_review',
    nearest_trv: nearest ? `${nearest.sig}@${Math.round(nearest.d)}m` : '',
  });
}
rows.sort((a, b) => b.stop_times - a.stop_times);

const cols = Object.keys(rows[0]);
const esc = (v) => (/[",\n]/.test(String(v)) ? `"${String(v).replaceAll('"', '""')}"` : String(v));
const out = path.join(ROOT, 'data/station_mapping.draft.csv');
fs.writeFileSync(out, [cols.join(','), ...rows.map((r) => cols.map((c) => esc(r[c])).join(','))].join('\n') + '\n');

const n = rows.length;
const cnt = (f) => rows.filter(f).length;
const pct = (x) => `${x} (${((100 * x) / n).toFixed(1)}%)`;
console.log(`GTFS rail stations (parent stops used by rail trips): ${n}`);
console.log(`mapped (any method):            ${pct(cnt((r) => r.trv_signature))}`);
console.log(`  via timetable evidence:       ${pct(cnt((r) => r.timetable_sig))}`);
console.log(`  via official file:            ${pct(cnt((r) => r.official_sig && !r.official_sig.startsWith(' (')))}`);
console.log(`  via geo+name (≤${RADIUS_M} m):       ${pct(cnt((r) => r.geo_sig))}`);
console.log(`  via override:                 ${pct(cnt((r) => r.methods === 'override' && r.trv_signature))}`);
console.log(`  via geo_only (≤100 m):        ${pct(cnt((r) => r.methods === 'geo_only'))}`);
console.log(`all available methods agree:    ${pct(cnt((r) => r.trv_signature && !r.conflict))}`);
console.log(`conflicts between methods:      ${cnt((r) => r.conflict)}`);
console.log(`unmatched:                      ${cnt((r) => !r.trv_signature)}`);
for (const k of ['bus_stop', 'bus_stop_or_unknown', 'foreign_not_in_trv', 'needs_review']) console.log(`  ${k}: ${cnt((r) => r.kind === k)}`);
const w = (f) => rows.filter(f).reduce((s, r) => s + r.stop_times, 0);
console.log(`stop_times-weighted match rate: ${((100 * w((r) => r.trv_signature)) / w(() => true)).toFixed(2)}%`);
console.log(`\nConflicts:`);
for (const r of rows.filter((r) => r.conflict)) console.log(`  ${r.gtfs_name} [${r.gtfs_stop_id}] tt=${r.timetable_sig}(${r.timetable_votes}) official=${r.official_sig} geo=${r.geo_sig} -> ${r.trv_signature}`);
console.log(`\nUnmatched:`);
for (const r of rows.filter((r) => !r.trv_signature)) console.log(`  [${r.kind}/${r.country}] ${r.gtfs_name} [${r.gtfs_stop_id}] area=${r.stop_area_id} stop_times=${r.stop_times} nearest=${r.nearest_trv}`);
console.log(`\nwrote ${out}`);
