// A day at one station as data for a video (owner, 2026-11-02: an Instagram loop of København H through a weekday).
// Every timetabled train that comes near the station on the date, placed every few seconds on our track by the same
// run model the live map uses (accelerate, cruise, brake between stops; standing at a platform between arrival and
// departure), with its operator colour, type, cars and car length; the station's 3D shapes; the tracks around it; and
// the departures and arrivals at the station by the minute. Timetable only: no delays (the video says so).
//
// Usage: npx tsx apps/server/src/tools/videoDay.ts 860000626 2026-11-10 <out dir> [radius km, default 6]
import fs from 'node:fs';
import path from 'node:path';
import { sql } from 'drizzle-orm';
import { cumulative, platformPoint, pointAt, type LatLon } from '@clack/shared';
import { openDb } from '../db/client.js';
import { config, REPO_ROOT } from '../env.js';
import { railGraph } from '../geo/railGraph.js';
import { platformFeatures, sectorFeatures, structureFeatures, trackFeatures } from '../geo/stationDetail.js';
import { segmentBetween } from '../geo/trackSegments.js';
import { typicalTrainType } from '../legs/trainTypes.js';
import { estimateAlong } from '../live/positioning.js';
import { stationMap } from '../stations/maps.js';

const [stationId = '860000626', date = '2026-11-10', outDir = 'video-kit', radiusArg] = process.argv.slice(2);
const RADIUS_M = Number(radiusArg ?? 6) * 1000;
const STEP_S = 5;

const db = openDb(config.databasePath);
const station = db.all<{ id: string; name: string; lat: number; lon: number; tz: string }>(sql`select id, name, lat, lon, tz from stations where id = ${stationId}`)[0];
if (!station) throw new Error(`no station ${stationId}`);
const map = stationMap(stationId);
const types = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'data/train_types.json'), 'utf8')) as { types: { id: string; name: string; art?: string; cars?: number }[] };
const typeOf = new Map(types.types.map((t) => [t.id, t]));
const operators = new Map(db.all<{ id: string; name: string; brand_color: string | null }>(sql`select id, name, brand_color from operators`).map((o) => [o.id, o]));

const kx = 111_320 * Math.cos((station.lat * Math.PI) / 180), ky = 110_574;
const dist = (lat: number, lon: number) => Math.hypot((lon - station.lon) * kx, (lat - station.lat) * ky);

// Local midnight of the service date, as the timetable's seconds count from it (GTFS: noon minus 12 h).
const noon = Date.parse(`${date}T12:00:00Z`);
const offsetMin = (() => {
  const f = new Intl.DateTimeFormat('en-GB', { timeZone: station.tz, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(new Date(noon));
  const [h, m] = f.split(':').map(Number) as [number, number];
  return (h - 12) * 60 + m;
})();
const midnight = noon - 12 * 3600_000 - offsetMin * 60_000;

// The trips calling here that day; a train both feeds carry (Öresundståg in the Danish and the Swedish timetables)
// once, by number and minute here.
const trips = db.all<{ key: string; source: string; train_number: string | null; operator_id: string | null; category: string; route_color: string | null; line: string | null; headsign: string | null }>(sql`
  select distinct t.key, t.source, t.train_number, t.operator_id, t.category, t.route_color, t.line, t.headsign
  from timetable_stop_times s join timetable_trips t on t.key = s.trip_key
  join timetable_trip_dates d on d.trip_key = t.key and d.service_date = ${date}
  where s.station_id = ${stationId}`);
const stopsOf = (key: string) =>
  db.all<{ seq: number; station_id: string; arr_sec: number | null; dep_sec: number | null; no_pickup: number; no_dropoff: number; platform: string | null; lat: number; lon: number }>(sql`
    select s.seq, s.station_id, s.arr_sec, s.dep_sec, s.no_pickup, s.no_dropoff, s.platform, st.lat, st.lon
    from timetable_stop_times s join stations st on st.id = s.station_id where s.trip_key = ${key} order by s.seq`);

const seen = new Map<string, string>();
const graph = railGraph();
const segCache = new Map<string, { points: LatLon[]; cum: number[]; L: number }>();
const seg = (a: { station_id: string; lat: number; lon: number }, b: { station_id: string; lat: number; lon: number }) => {
  const k = `${a.station_id}>${b.station_id}`;
  if (!segCache.has(k)) {
    const s = segmentBetween(db, { id: a.station_id, lat: a.lat, lon: a.lon }, { id: b.station_id, lat: b.lat, lon: b.lon }, graph);
    const pts = s.points.length > 1 ? s.points : ([[a.lat, a.lon], [b.lat, b.lon]] as LatLon[]);
    const cum = cumulative(pts);
    segCache.set(k, { points: pts, cum, L: cum.at(-1) ?? 0 });
  }
  return segCache.get(k)!;
};

// Car counts and lengths as the app draws them (TrainKit), except the S-tog: an SA set is 8 short articulated cars,
// about 84 m (da.wikipedia.org/wiki/S-tog, read 2026-11-01; the app's 8 × 24 m was flagged as too long, review A11).
const TEMPLATE: Record<string, { cars: number; carM: number }> = { highSpeed: { cars: 6, carM: 24 }, multipleUnit: { cars: 4, carM: 24 }, doubleDeck: { cars: 3, carM: 26.4 }, locoCoaches: { cars: 5, carM: 26.4 }, railcar: { cars: 2, carM: 20 } };
const templateOf = (art?: string) =>
  ['x2000', 'x3'].includes(art ?? '') ? 'highSpeed' : ['double_deck'].includes(art ?? '') ? 'doubleDeck' : ['loco', 'loco_coaches'].includes(art ?? '') ? 'locoCoaches' : ['railcar', 'dk_railcar'].includes(art ?? '') ? 'railcar' : 'multipleUnit';

const out: object[] = [];
const departures: number[] = [], arrivals: number[] = [];
for (const t of trips) {
  const stops = stopsOf(t.key);
  const here = stops.findIndex((s) => s.station_id === stationId);
  const atHere = stops[here]!;
  const k = `${t.train_number ?? t.key}|${Math.round((atHere.dep_sec ?? atHere.arr_sec ?? 0) / 60)}`;
  if (seen.has(k) && seen.get(k) !== t.source) continue;
  seen.set(k, t.source);
  if (here < stops.length - 1 && atHere.dep_sec !== null && !atHere.no_pickup) departures.push(atHere.dep_sec);
  if (here > 0 && atHere.arr_sec !== null && !atHere.no_dropoff) arrivals.push(atHere.arr_sec);

  const typeId = typicalTrainType(t.operator_id, t.category, t.train_number);
  const type = typeId ? typeOf.get(typeId) : undefined;
  const tpl = TEMPLATE[templateOf(type?.art)]!;
  let cars = type?.cars ?? tpl.cars, carM = tpl.carM, carsNote = type?.cars ? 'the type\'s usual cars' : 'the drawing\'s default';
  if (typeId === 'dk_stog') { cars = 8; carM = 84 / 8; carsNote = 'one SA set, 84 m (da.wikipedia.org/wiki/S-tog)'; }
  if (typeId === 'x31') { cars = 3; carsNote = 'one X31 unit (3 cars); how many units run is not known per train'; }
  const op = t.operator_id ? operators.get(t.operator_id) : undefined;
  const color = (t.route_color && /^[0-9a-f]{6}$/i.test(t.route_color) ? `#${t.route_color}` : null) ?? op?.brand_color ?? '#f8d64a';

  // Positions every STEP_S seconds while within the radius: standing between arrival and departure, else running.
  const samples: [number, number, number, number][] = [];
  const push = (sec: number, lat: number, lon: number, bearing: number) => {
    if (dist(lat, lon) <= RADIUS_M) samples.push([sec, Math.round(lon * 1e6) / 1e6, Math.round(lat * 1e6) / 1e6, Math.round(bearing)]);
  };
  const platformAt = (s: (typeof stops)[number]) => {
    if (s.station_id === stationId && map) {
      const p = platformPoint(map, s.platform);
      if (p) return { lat: p[0], lon: p[1] };
    }
    return { lat: s.lat, lon: s.lon };
  };
  for (let i = 0; i < stops.length; i++) {
    const s = stops[i]!;
    const near = dist(s.lat, s.lon) <= RADIUS_M + 15_000;
    // Standing at the stop.
    if (near && s.arr_sec !== null && s.dep_sec !== null && s.dep_sec > s.arr_sec) {
      const p = platformAt(s);
      for (let sec = s.arr_sec; sec < s.dep_sec; sec += STEP_S) push(sec, p.lat, p.lon, -1);
    }
    const n = stops[i + 1];
    if (!n || s.dep_sec === null || n.arr_sec === null && n.dep_sec === null) continue;
    if (!near && dist(n.lat, n.lon) > RADIUS_M + 15_000) continue;
    const g = seg(s, n);
    const depMs = s.dep_sec * 1000, arrMs = (n.arr_sec ?? n.dep_sec!) * 1000;
    for (let sec = Math.ceil(s.dep_sec / STEP_S) * STEP_S; sec * 1000 < arrMs; sec += STEP_S) {
      const e = estimateAlong(g.L, depMs, arrMs, sec * 1000);
      const p = pointAt(g.points, g.cum, Math.min(g.L, Math.max(0, e.m)));
      push(sec, p.lat, p.lon, p.bearing);
    }
  }
  if (!samples.length) continue;
  out.push({
    id: t.key, number: t.train_number, operator: op?.name ?? t.operator_id, operatorId: t.operator_id, category: t.category, line: t.line, headsign: t.headsign,
    color, type: type?.name ?? null, cars, carLengthM: Math.round(carM * 10) / 10, carsNote,
    here: { arr: atHere.arr_sec, dep: atHere.dep_sec, platform: atHere.platform },
    samples,
  });
}

// The station's shapes (platforms with their heights, buildings and roofs from the laser) and the tracks around it.
const r = RADIUS_M * 1.2;
const box = { w: station.lon - r / kx, e: station.lon + r / kx, s: station.lat - r / ky, n: station.lat + r / ky };
const stationShapes = map ? [...platformFeatures(map, stationId), ...sectorFeatures(map, stationId), ...structureFeatures(map, stationId)] : [];
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'trains.json'), JSON.stringify({ date, stationId, station: station.name, tz: station.tz, stepSeconds: STEP_S, midnightUtcMs: midnight, trains: out }));
fs.writeFileSync(path.join(outDir, 'station.geojson'), JSON.stringify({ type: 'FeatureCollection', features: stationShapes }));
fs.writeFileSync(path.join(outDir, 'tracks.geojson'), JSON.stringify({ type: 'FeatureCollection', features: graph ? trackFeatures(graph, box) : [] }));
const perMinute = (list: number[]) => {
  const a = Array(26 * 60).fill(0);
  for (const s of list) a[Math.floor(s / 60)]++;
  return a;
};
fs.writeFileSync(
  path.join(outDir, 'counts.json'),
  JSON.stringify({ note: 'Calls at the station by minute of the service day (index = minutes after local midnight; past 1440 is after midnight).', departures: perMinute(departures), arrivals: perMinute(arrivals), totalDepartures: departures.length, totalArrivals: arrivals.length }),
);
fs.writeFileSync(
  path.join(outDir, 'meta.json'),
  JSON.stringify(
    {
      station: station.name, stationId, date, centre: { lat: station.lat, lon: station.lon }, radiusM: RADIUS_M, box,
      trains: out.length, departures: departures.length, arrivals: arrivals.length,
      source: 'Timetable (Rejseplanen GTFS for Denmark, Trafiklab GTFS Sverige for Öresundståg), placed on our track by the live map\'s run model; no delays.',
      credits: ['© OpenStreetMap contributors (tracks, station shapes)', 'Protomaps (basemap)', 'Rejseplanen / Banedanmark (timetable, platform heights)', 'Danmarks Højdemodel, © Klimadatastyrelsen, CC BY 4.0 (building and roof heights)', 'Trafiklab (Swedish timetable)'],
    },
    null,
    2,
  ),
);
console.log(`${station.name} ${date}: ${out.length} trains near, ${departures.length} departures, ${arrivals.length} arrivals → ${outDir}`);
