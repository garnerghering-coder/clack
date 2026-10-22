// Norway's rail timetable (NORWAY_DATA_FINDINGS.md): Entur's per-operator rail GTFS (Vy, Go-Ahead, SJ Nord,
// Flytoget) into the same timetable tables as Sweden, source 'gtfs_no'. Same rules as Sweden: dates from yesterday
// on are replaced, older dates are kept. Stations are NSR stop places; one that's already a station (Oslo S from
// Sweden's cross-border trains, Göteborg C from Vy's) keeps that station's id, so a place is one station.
import crypto from 'node:crypto';
import type { Db } from '../db/client.js';
import { importLog, stations } from '../db/schema.js';
import { loadBrands, type Brand } from '../dataFiles.js';
import { addDays, parseGtfsTime, todayIn, ymdToIso } from '../lib/time.js';
import { readAll, readCsv, type Row } from '../lib/zip.js';
import { haversineM, normName } from '../lib/geo.js';
import { refreshStationPopularity } from './gtfs-se3.js';

export const SOURCE = 'gtfs_no';
const TZ = 'Europe/Oslo';

/** Train number from an Entur trip id: Vy/Go-Ahead/SJ Nord lead with it, Flytoget has it third. */
export function trainNumberFromTripId(tripId: string): string | null {
  const body = tripId.split(':ServiceJourney:')[1];
  if (!body) return null;
  if (tripId.startsWith('FLT:')) return body.split('-')[2] ?? null;
  const m = /^([A-Z]?\d+)/.exec(body);
  // A letter prefix (B705) is a bus or a special; only plain numbers are train numbers.
  return m && /^\d+$/.test(m[1]!) ? m[1]! : null;
}

export const isReplacementBus = (tripId: string) => /:ServiceJourney:B/i.test(tripId);

/**
 * Category from the line: L = local (commuter), R/RE/RX = regional, F = long distance (intercity), FLY = airport
 * express (regional, frequent), and a long-distance trip leaving late and arriving after 05:00 the next day = night.
 */
export function norwegianCategory(line: string, depSec: number | null, arrSec: number | null): string {
  const l = line.toUpperCase();
  if (l.startsWith('FLY')) return 'regional';
  if (/^L\d/.test(l)) return 'commuter';
  if (/^F\d/.test(l)) {
    if (depSec !== null && arrSec !== null && depSec >= 20 * 3600 && arrSec - depSec >= 6 * 3600) return 'night';
    return 'intercity';
  }
  return 'regional';
}

/** "Otta stasjon" → "Otta" (Norwegian stop names carry the word; Swedish ones don't). */
export const cleanStopName = (s: string) => s.replace(/\s+(stasjon|station|holdeplass)$/i, '').trim();

/** The same name in Swedish and Norwegian spelling: "Lilleström" and "Lillestrøm stasjon", "Bjørnfjell" and "Björnfjell". */
export function sameSpelling(a: string, b: string): boolean {
  // normName already folds ö/ø to o; æ becomes ae where Swedish writes ä.
  const fold = (s: string) => normName(cleanStopName(s)).replace(/ae/g, 'a');
  return fold(a) === fold(b);
}

export interface ExistingStation {
  id: string;
  name: string;
  lat: number;
  lon: number;
  country: string;
}

/**
 * The existing station an NSR stop place is, if any: within 400 m whatever the name (one place, two feeds), or
 * within 1.5 km with the same normalised name (station points sit at different ends of big stations).
 */
export function matchStation(p: { name: string; lat: number; lon: number }, existing: ExistingStation[]): ExistingStation | null {
  const name = normName(cleanStopName(p.name));
  let best: { s: ExistingStation; d: number } | null = null;
  for (const s of existing) {
    const d = haversineM(p.lat, p.lon, s.lat, s.lon);
    const same = normName(s.name) === name || normName(s.name).replace(/ [sc]$/, '') === name.replace(/ [sc]$/, '');
    if ((d <= 400 || (same && d <= 1500)) && (!best || d < best.d)) best = { s, d };
  }
  return best?.s ?? null;
}

export interface NorwayImportSummary {
  trips: number;
  tripDates: number;
  stations: { matched: number; created: number };
  excluded: number;
  numbersMissing: number;
  window: [string, string];
  ms: number;
}

type StopRow = [seq: number, stopId: string, arr: number | null, dep: number | null, noPickup: boolean, noDropoff: boolean];

export async function importGtfsNorway(db: Db, zips: string[], opts: { today?: string; daysAhead?: number; log?: (m: string) => void } = {}): Promise<NorwayImportSummary> {
  const t0 = Date.now();
  const log = opts.log ?? (() => {});
  const today = opts.today ?? todayIn(TZ);
  const windowStart = addDays(today, -1);
  const windowEnd = addDays(today, opts.daysAhead ?? 90);
  const [from, to] = [windowStart.replaceAll('-', ''), windowEnd.replaceAll('-', '')];
  const brands = loadBrands();
  const brandOf = (agency: string): Brand | undefined => brands.find((b) => b.gtfs_operators.includes(agency));

  // Stations from other sources (Sweden's feed) that a Norwegian stop place might be; our own earlier imports are
  // found by id instead.
  const existing: ExistingStation[] = db
    .select({ id: stations.id, name: stations.name, lat: stations.lat, lon: stations.lon, country: stations.country })
    .from(stations)
    .all()
    .filter((s) => !s.id.startsWith('NSR:'));
  const stationOfPlace = new Map<string, string>();
  const newStations = new Map<string, { id: string; name: string; lat: number; lon: number; stopIds: string[] }>();
  let matched = 0;
  const renamed = new Map<string, string>();
  const merged = new Map<string, string>();
  const nsrOf = new Map<string, string>();
  let excluded = 0;
  let numbersMissing = 0;
  const usedBrands = new Map<string, Brand>();
  const patterns: { key: string; tripId: string; number: string | null; brand?: Brand; agency: string; route: Row; category: string; stops: { station: string; s: StopRow }[]; dates: string[] }[] = [];

  for (const zip of zips) {
    const agencies = new Map((await readAll(zip, 'agency.txt')).map((a) => [a.agency_id!, a]));
    // Rail only (100–117 extended, 2 basic): the feeds also carry replacement buses.
    const routes = new Map((await readAll(zip, 'routes.txt', (r) => r.route_type === '2' || /^1(0\d|1[0-7])$/.test(r.route_type!))).map((r) => [r.route_id!, r]));
    const trips = await readAll(zip, 'trips.txt', (t) => routes.has(t.route_id!));
    const services = new Set(trips.map((t) => t.service_id!));
    const dates = new Map<string, string[]>();
    for (const cd of await readAll(zip, 'calendar_dates.txt', (c) => services.has(c.service_id!) && c.exception_type === '1' && c.date! >= from && c.date! <= to))
      (dates.get(cd.service_id!) ?? dates.set(cd.service_id!, []).get(cd.service_id!)!).push(ymdToIso(cd.date!));
    const kept = trips.filter((t) => dates.has(t.service_id!));
    const tripIds = new Set(kept.map((t) => t.trip_id!));
    const stopsByTrip = new Map<string, StopRow[]>();
    for await (const st of readCsv(zip, 'stop_times.txt')) {
      if (!tripIds.has(st.trip_id!)) continue;
      (stopsByTrip.get(st.trip_id!) ?? stopsByTrip.set(st.trip_id!, []).get(st.trip_id!)!).push([
        Number(st.stop_sequence),
        st.stop_id!,
        parseGtfsTime(st.arrival_time!),
        parseGtfsTime(st.departure_time!),
        st.pickup_type === '1',
        st.drop_off_type === '1',
      ]);
    }
    const stopRows = new Map((await readAll(zip, 'stops.txt')).map((s) => [s.stop_id!, s]));
    const placeOf = (quay: string) => stopRows.get(quay)?.parent_station || quay;
    const stationFor = (quay: string): string | null => {
      const place = placeOf(quay);
      const hit = stationOfPlace.get(place);
      if (hit) return hit;
      const p = stopRows.get(place);
      if (!p) return null;
      const at = { name: p.stop_name!, lat: Number(p.stop_lat), lon: Number(p.stop_lon) };
      const same = matchStation(at, existing);
      let id: string;
      if (same) {
        id = same.id;
        matched++;
        // A Norwegian station from Sweden's feed takes Norway's spelling ("Lilleström" → "Lillestrøm"), but only when
        // it's the same name: a neighbouring place matched by distance ("Oslo S Trelastgata") doesn't rename it.
        if (same.country === 'NO' && sameSpelling(same.name, at.name)) renamed.set(id, cleanStopName(at.name));
        // Its Entur stop place, for boards and live data: the same-named one if several places matched.
        if (!nsrOf.has(id) || sameSpelling(same.name, at.name)) nsrOf.set(id, place);
      } else {
        // NSR sometimes has two places for one station (Oslo lufthavn's airport-train quay sits in its own place):
        // the same name within a kilometre is one station. Different names are never merged.
        const name = cleanStopName(at.name);
        const twin = [...newStations.values()].find((n) => normName(n.name) === normName(name) && haversineM(n.lat, n.lon, at.lat, at.lon) <= 1000);
        id = twin?.id ?? place;
        if (twin) merged.set(place, twin.id);
        else newStations.set(id, { id, name, lat: at.lat, lon: at.lon, stopIds: [] });
      }
      stationOfPlace.set(place, id);
      return id;
    };
    for (const trip of kept) {
      // Replacement buses ride on rail lines with ids like "BUS-1104_…" or "B701-A7_…": not trains.
      if (isReplacementBus(trip.trip_id!)) {
        excluded++;
        continue;
      }
      const raw = (stopsByTrip.get(trip.trip_id!) ?? []).sort((a, b) => a[0] - b[0]);
      if (raw.length < 2) {
        excluded++;
        continue;
      }
      const stops = raw.map((s) => ({ station: stationFor(s[1]), s }));
      if (stops.some((x) => !x.station)) {
        excluded++;
        continue;
      }
      for (const x of stops) newStations.get(x.station!)?.stopIds.push(x.s[1]);
      const route = routes.get(trip.route_id!)!;
      const agency = agencies.get(route.agency_id!)?.agency_name ?? '';
      const brand = brandOf(agency);
      if (brand) usedBrands.set(brand.id, brand);
      const number = trainNumberFromTripId(trip.trip_id!);
      if (!number) numbersMissing++;
      const firstDep = raw[0]![3] ?? raw[0]![2];
      const lastArr = raw.at(-1)![2] ?? raw.at(-1)![3];
      const hash = crypto.createHash('sha1').update(JSON.stringify([number, stops.map((x) => [x.station, x.s[2], x.s[3]])])).digest('hex').slice(0, 10);
      patterns.push({
        key: `no:${trip.trip_id}:${hash}`,
        tripId: trip.trip_id!,
        number,
        brand,
        agency,
        route,
        category: norwegianCategory(route.route_short_name ?? '', firstDep, lastArr),
        stops: stops.map((x) => ({ station: x.station!, s: x.s })),
        dates: dates.get(trip.service_id!)!,
      });
    }
    log(`Entur ${zip.split('/').pop()}: ${kept.length} rail trips running ${windowStart}..${windowEnd}`);
  }

  const sqlite = db.$client;
  let tripDates = 0;
  db.transaction(() => {
    const upsertOperator = sqlite.prepare(
      `insert into operators (id, name, short_name, company, country, brand_color, logo_path) values (?, ?, ?, null, ?, ?, null)
       on conflict(id) do update set name = excluded.name, short_name = excluded.short_name, country = excluded.country, brand_color = excluded.brand_color`,
    );
    for (const b of usedBrands.values()) upsertOperator.run(b.id, b.name, b.short_name, b.country, b.color);
    const insertStation = sqlite.prepare(
      `insert into stations (id, name, country, lat, lon, tz, trv_signature, gtfs_stop_ids, coord_source, historical_only, kind, needs_review, nsr_id)
       values (?, ?, 'NO', ?, ?, ?, null, ?, 'gtfs', 0, 'rail_station', 0, ?)
       on conflict(id) do update set name = excluded.name, lat = excluded.lat, lon = excluded.lon, gtfs_stop_ids = excluded.gtfs_stop_ids, nsr_id = excluded.nsr_id`,
    );
    for (const s of newStations.values()) insertStation.run(s.id, s.name, s.lat, s.lon, TZ, JSON.stringify([s.id, ...new Set(s.stopIds)]), s.id);
    const setNsr = sqlite.prepare(`update stations set nsr_id = ? where id = ?`);
    for (const [id, place] of nsrOf) setNsr.run(place, id);
    const rename = sqlite.prepare(`update stations set name = ?, tz = ? where id = ?`);
    for (const [id, name] of renamed) rename.run(name, TZ, id);
    sqlite.prepare(`delete from timetable_trip_dates where service_date >= ? and trip_key in (select key from timetable_trips where source = ?)`).run(windowStart, SOURCE);
    const insertTrip = sqlite.prepare(
      `insert into timetable_trips (key, source, trip_id, train_number, operator_id, gtfs_operator, route_name, route_type, category, tz, feed_version)
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) on conflict(key) do update set category = excluded.category, operator_id = excluded.operator_id, feed_version = excluded.feed_version`,
    );
    const insertStop = sqlite.prepare(`insert or ignore into timetable_stop_times (trip_key, seq, station_id, arr_sec, dep_sec, no_pickup, no_dropoff) values (?, ?, ?, ?, ?, ?, ?)`);
    const insertDate = sqlite.prepare(`insert or ignore into timetable_trip_dates (trip_key, service_date) values (?, ?)`);
    for (const p of patterns) {
      const routeName = [p.route.route_short_name, p.route.route_long_name].filter(Boolean).join(' ') || null;
      insertTrip.run(p.key, SOURCE, p.tripId, p.number, p.brand?.id ?? null, p.agency, routeName, p.route.route_type, p.category, TZ, today);
      p.stops.forEach((x, i) => insertStop.run(p.key, i + 1, x.station, x.s[2], x.s[3], x.s[4] ? 1 : 0, x.s[5] ? 1 : 0));
      for (const d of p.dates) tripDates += insertDate.run(p.key, d).changes;
    }
    sqlite.prepare(`delete from timetable_trips where source = ? and key not in (select trip_key from timetable_trip_dates)`).run(SOURCE);
    // A place merged into its twin may be a station from an earlier import: point its kept trips at the twin, and
    // drop it unless something of the user's (a leg, a favourite) still refers to it.
    const repoint = sqlite.prepare(`update timetable_stop_times set station_id = ? where station_id = ?`);
    const dropStation = sqlite.prepare(`delete from stations where id = ?`);
    for (const [place, id] of merged) {
      repoint.run(id, place);
      try {
        sqlite.transaction(() => dropStation.run(place))();
      } catch {
        // Still referenced: it stays, harmlessly.
      }
    }
    refreshStationPopularity(db, today);
    db.insert(importLog)
      .values({ source: SOURCE, startedAt: new Date(t0), finishedAt: new Date(), status: 'ok', notes: JSON.stringify({ trips: patterns.length, window: [windowStart, windowEnd] }) })
      .run();
  });
  const summary = { trips: patterns.length, tripDates, stations: { matched, created: newStations.size }, excluded, numbersMissing, window: [windowStart, windowEnd] as [string, string], ms: Date.now() - t0 };
  log(`Norway imported in ${(summary.ms / 1000).toFixed(1)} s: ${summary.trips} trips, ${summary.tripDates} trip-dates, stations ${matched} matched + ${newStations.size} new, ${numbersMissing} without a train number`);
  return summary;
}

export function lastNorwayImport(db: Db): number | null {
  const row = db.$client.prepare(`select started_at from import_log where source = ? and status = 'ok' order by started_at desc limit 1`).get(SOURCE) as { started_at: number } | undefined;
  return row?.started_at ?? null;
}
