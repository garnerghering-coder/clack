// Finland's passenger-train timetable (FINLAND_DATA_FINDINGS.md): Digitraffic's gtfs-passenger.zip (VR long-distance
// and commuter trains, HSL's commuter lines, a few heritage railways) into the same timetable tables as Sweden and
// Norway, source 'gtfs_fi'. Same rules: dates from yesterday on are replaced, older dates are kept. Stations are
// Digitraffic stations, found by their short code (HKI): one that already exists (Haparanda, which the Oulu trains
// serve) keeps its id, so a place is one station.
import crypto from 'node:crypto';
import type { Db } from '../db/client.js';
import { importLog, stations } from '../db/schema.js';
import { loadBrands, type Brand } from '../dataFiles.js';
import { COUNTRIES } from '../lib/countries.js';
import { addDays, parseGtfsTime, todayIn, ymdToIso } from '../lib/time.js';
import { readAll, readCsv, type Row } from '../lib/zip.js';
import { refreshStationPopularity } from './gtfs-se3.js';
import { matchStation, type ExistingStation } from './gtfs-no.js';
import { cleanFiName, fetchFiStations, usableFiStation, type FiStation } from './fi-stations.js';
import { countryOf, TZ_BY_COUNTRY } from './stations.js';

export const SOURCE = 'gtfs_fi';
const TZ = COUNTRIES.FI.tz;

/** GTFS agency_id → our operator brand id (data/operators.json). Heritage railways have no brand: operator null. */
export const FI_AGENCY_BRANDS: Record<string, string> = { '10': 'vr-fi', '9995': 'hsl' };

/**
 * Train type letters as Digitraffic's /metadata/train-types lists them, with the category the API gives each one
 * (Commuter, Long-distance, or something that isn't a passenger train). The API gives ONLY the category: what the
 * letters mean is not in it. Our product per letter:
 *  - Commuter category (HL, HV, HLV) → commuter: from the API.
 *  - S → high_speed: the Pendolino service, from VR's public naming; NOT verified in the API.
 *  - IC, IC2 → intercity; PYO → night (VR's night train); MV, MUS, V → heritage (museum/special): also VR naming,
 *    not verified in the API.
 *  - every other Long-distance letter → regional (a safe default, not a claim about the train).
 * A letter that isn't in this list is regional and gets logged by the importer rather than guessed.
 */
const LONG_DISTANCE_PRODUCT: Record<string, string> = {
  S: 'high_speed',
  IC: 'intercity',
  IC2: 'intercity',
  PYO: 'night',
  MV: 'heritage',
  MUS: 'heritage',
  V: 'heritage',
  H: 'regional',
  P: 'regional',
  HDM: 'regional',
  HSM: 'regional',
  AE: 'regional',
  PVS: 'regional',
  PVV: 'regional',
};
const COMMUTER_TYPES = new Set(['HL', 'HV', 'HLV']);
/** Cargo (T, RJ), locomotive moves (VET), shunting, on-track machines (TYO) and test drives (LIV): not passenger trains. */
const NON_PASSENGER_TYPES = new Set(['T', 'RJ', 'VET', 'PAR', 'VEV', 'VLI', 'W', 'MUV', 'SAA', 'PAI', 'TYO', 'LIV']);

export interface FinnishProduct {
  /** Our product, or null when the type isn't a passenger train (leave the trip out). */
  product: string | null;
  /** False when the letter isn't in /metadata/train-types as we know it: regional, and worth a log line. */
  known: boolean;
}

export function finnishProduct(type: string): FinnishProduct {
  const t = type.toUpperCase();
  if (COMMUTER_TYPES.has(t)) return { product: 'commuter', known: true };
  if (LONG_DISTANCE_PRODUCT[t]) return { product: LONG_DISTANCE_PRODUCT[t]!, known: true };
  if (NON_PASSENGER_TYPES.has(t)) return { product: null, known: true };
  return { product: 'regional', known: false };
}

/** The train type letters from a route id (`TPE_HKI_22_IC_10`, `LPV_HKI_A_HL_10`): <from>_<to>_<number|line>_<TYPE>_<agency>. */
export function trainTypeFromRouteId(routeId: string): string | null {
  const m = /_([A-Z0-9]+)_\d+$/.exec(routeId);
  return m ? m[1]! : null;
}

/**
 * Train number: a trip id is `<number>_<validity date>` (`8192_20261212`, `178_20261106_replacement`); failing that, the
 * number at the end of the short name (`S 13`, `A (HL 8192)`). The commuter line letter is not part of it.
 */
export function trainNumberOf(tripId: string, shortName = ''): string | null {
  const fromId = /^(\d+)_/.exec(tripId);
  if (fromId) return fromId[1]!;
  const fromName = /(\d+)\)?\s*$/.exec(shortName);
  return fromName ? fromName[1]! : null;
}

/** The commuter line letter from `A (HL 8192)` → 'A'; null for long-distance short names. */
export const commuterLineOf = (shortName: string): string | null => /^([A-Z])\s+\([A-Z]+\s+\d+\)$/.exec(shortName)?.[1] ?? null;

interface CalendarRow {
  days: boolean[];
  start: string;
  end: string;
}

const WEEKDAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
export const calendarRow = (r: Row): CalendarRow => ({ days: WEEKDAYS.map((d) => r[d] === '1'), start: r.start_date!, end: r.end_date! });

/**
 * The dates (YYYYMMDD) a service runs inside from..to: its weekly pattern between start and end, plus the dates
 * calendar_dates adds (exception 1), minus the ones it removes (exception 2).
 */
export function serviceDates(cal: CalendarRow | undefined, added: string[], removed: Set<string>, from: string, to: string): string[] {
  const out = new Set<string>();
  if (cal) {
    const lo = cal.start > from ? cal.start : from;
    const hi = cal.end < to ? cal.end : to;
    for (let d = lo; d <= hi; d = addDays(ymdToIso(d), 1).replaceAll('-', '')) {
      const dow = new Date(Date.UTC(Number(d.slice(0, 4)), Number(d.slice(4, 6)) - 1, Number(d.slice(6, 8)))).getUTCDay();
      if (cal.days[dow]) out.add(d);
    }
  }
  for (const d of added) if (d >= from && d <= to) out.add(d);
  for (const d of removed) out.delete(d);
  return [...out].sort();
}

export interface ExistingFiStation extends ExistingStation {
  fiId: string | null;
}

/**
 * The station a Digitraffic station is. Order: the one already carrying its short code (fi_id); else, among stations
 * no Finnish code has claimed, the one within 400 m (or 1.5 km with the same name) — this is how HPA finds Haparanda.
 */
export function findFiStation(st: { code: string; name: string; lat: number; lon: number }, existing: ExistingFiStation[], claimed: ReadonlySet<string> = new Set()): ExistingFiStation | null {
  const own = existing.find((s) => s.fiId === st.code);
  if (own) return own;
  const free = existing.filter((s) => !s.fiId && !claimed.has(s.id));
  return (matchStation(st, free) as ExistingFiStation | null) ?? null;
}

export interface FinlandImportSummary {
  trips: number;
  tripDates: number;
  stations: { matched: number; created: number };
  excluded: number;
  numbersMissing: number;
  unknownTypes: string[];
  window: [string, string];
  ms: number;
}

type StopRow = [seq: number, stopId: string, arr: number | null, dep: number | null, noPickup: boolean, noDropoff: boolean];

export async function importGtfsFinland(
  db: Db,
  zip: string,
  opts: { today?: string; daysAhead?: number; log?: (m: string) => void; stations?: FiStation[]; brands?: Brand[] } = {},
): Promise<FinlandImportSummary> {
  const t0 = Date.now();
  const log = opts.log ?? (() => {});
  const today = opts.today ?? todayIn(TZ);
  const windowStart = addDays(today, -1);
  const windowEnd = addDays(today, opts.daysAhead ?? 90);
  const [from, to] = [windowStart.replaceAll('-', ''), windowEnd.replaceAll('-', '')];
  const brands = opts.brands ?? loadBrands();
  const brandOf = (agencyId: string): Brand | undefined => {
    const id = FI_AGENCY_BRANDS[agencyId];
    return id ? brands.find((b) => b.id === id) : undefined;
  };

  const meta = new Map<string, FiStation>();
  for (const s of opts.stations ?? (await fetchFiStations().catch((e) => (log(`Digitraffic stations unavailable (${(e as Error).message}); using the timetable's own stop list`), [])))) {
    if (usableFiStation(s)) meta.set(s.code, s);
  }

  const agencies = new Map((await readAll(zip, 'agency.txt')).map((a) => [a.agency_id!, a]));
  // Rail only (100–117 extended, 2 basic). Digitraffic's feed has 102 (long distance) and 109 (commuter).
  const routes = new Map((await readAll(zip, 'routes.txt', (r) => r.route_type === '2' || /^1(0\d|1[0-7])$/.test(r.route_type!))).map((r) => [r.route_id!, r]));
  const trips = await readAll(zip, 'trips.txt', (t) => routes.has(t.route_id!));
  const services = new Set(trips.map((t) => t.service_id!));
  const calendar = new Map((await readAll(zip, 'calendar.txt', (c) => services.has(c.service_id!))).map((c) => [c.service_id!, calendarRow(c)]));
  const added = new Map<string, string[]>();
  const removed = new Map<string, Set<string>>();
  for (const cd of await readAll(zip, 'calendar_dates.txt', (c) => services.has(c.service_id!))) {
    if (cd.exception_type === '1') (added.get(cd.service_id!) ?? added.set(cd.service_id!, []).get(cd.service_id!)!).push(cd.date!);
    else if (cd.exception_type === '2') (removed.get(cd.service_id!) ?? removed.set(cd.service_id!, new Set()).get(cd.service_id!)!).add(cd.date!);
  }
  const dates = new Map<string, string[]>();
  for (const sid of services) {
    const ds = serviceDates(calendar.get(sid), added.get(sid) ?? [], removed.get(sid) ?? new Set(), from, to);
    if (ds.length) dates.set(sid, ds.map(ymdToIso));
  }
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
  log(`Digitraffic GTFS: ${kept.length} rail trips running ${windowStart}..${windowEnd}`);

  // Stations: a platform stop (JRI_0) belongs to its parent (JRI), whose id is the Digitraffic short code.
  const stopRows = new Map((await readAll(zip, 'stops.txt')).map((s) => [s.stop_id!, s]));
  const parentOf = (stopId: string) => stopRows.get(stopId)?.parent_station || stopId;
  const existing: ExistingFiStation[] = db
    .select({ id: stations.id, name: stations.name, lat: stations.lat, lon: stations.lon, country: stations.country, fiId: stations.fiId })
    .from(stations)
    .all();
  const claimed = new Set<string>();
  const stationOfCode = new Map<string, string>();
  const newStations = new Map<string, { id: string; code: string; uic: number | null; name: string; lat: number; lon: number; country: string; stopIds: Set<string> }>();
  let matched = 0;
  const matchedCodes = new Map<string, { id: string; uic: number | null }>();
  const stationFor = (stopId: string): string | null => {
    const code = parentOf(stopId);
    const hit = stationOfCode.get(code);
    if (hit) return hit;
    const m = meta.get(code);
    const p = stopRows.get(code);
    // Digitraffic's station list first (names, country, UIC code); the timetable's own stop row if it lacks one.
    const at = m ?? (p ? { code, uic: null, name: cleanFiName(p.stop_name!), lat: Number(p.stop_lat), lon: Number(p.stop_lon), country: 'FI', passengerTraffic: true } : null);
    if (!at || !Number.isFinite(at.lat) || !Number.isFinite(at.lon)) return null;
    const same = findFiStation(at, existing, claimed);
    let id: string;
    if (same) {
      id = same.id;
      claimed.add(id);
      matched++;
      if (!same.fiId) matchedCodes.set(code, { id, uic: at.uic });
    } else {
      id = `fi:${code}`;
      newStations.set(id, { id, code, uic: at.uic, name: at.name, lat: at.lat, lon: at.lon, country: countryOf(null, undefined, at.lat, at.lon, at.country), stopIds: new Set([code]) });
    }
    stationOfCode.set(code, id);
    return id;
  };

  let excluded = 0;
  let numbersMissing = 0;
  const unknownTypes = new Set<string>();
  const usedBrands = new Map<string, Brand>();
  const patterns: { key: string; tripId: string; number: string | null; brand?: Brand; agency: string; route: Row; category: string; stops: { station: string; s: StopRow }[]; dates: string[] }[] = [];
  for (const trip of kept) {
    const route = routes.get(trip.route_id!)!;
    const type = trainTypeFromRouteId(route.route_id!);
    const kind = type ? finnishProduct(type) : { product: 'regional', known: false };
    if (!kind.product) {
      excluded++;
      continue;
    }
    if (!kind.known) unknownTypes.add(type ?? route.route_id!);
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
    for (const x of stops) newStations.get(x.station!)?.stopIds.add(x.s[1]);
    const brand = brandOf(route.agency_id!);
    if (brand) usedBrands.set(brand.id, brand);
    const number = trainNumberOf(trip.trip_id!, trip.trip_short_name ?? route.route_short_name ?? '');
    if (!number) numbersMissing++;
    const hash = crypto.createHash('sha1').update(JSON.stringify([number, stops.map((x) => [x.station, x.s[2], x.s[3]])])).digest('hex').slice(0, 10);
    patterns.push({
      key: `fi:${trip.trip_id}:${hash}`,
      tripId: trip.trip_id!,
      number,
      brand,
      agency: agencies.get(route.agency_id!)?.agency_name ?? '',
      route,
      category: kind.product,
      stops: stops.map((x) => ({ station: x.station!, s: x.s })),
      dates: dates.get(trip.service_id!)!,
    });
  }
  if (unknownTypes.size) log(`Digitraffic GTFS: train types not in /metadata/train-types, treated as regional: ${[...unknownTypes].join(', ')}`);

  const sqlite = db.$client;
  let tripDates = 0;
  db.transaction(() => {
    const upsertOperator = sqlite.prepare(
      `insert into operators (id, name, short_name, company, country, brand_color, logo_path) values (?, ?, ?, null, ?, ?, null)
       on conflict(id) do update set name = excluded.name, short_name = excluded.short_name, country = excluded.country, brand_color = excluded.brand_color`,
    );
    for (const b of usedBrands.values()) upsertOperator.run(b.id, b.name, b.short_name, b.country, b.color);
    const insertStation = sqlite.prepare(
      `insert into stations (id, name, country, lat, lon, tz, trv_signature, gtfs_stop_ids, coord_source, historical_only, kind, needs_review, fi_id, fi_uic)
       values (?, ?, ?, ?, ?, ?, null, ?, 'gtfs', 0, 'rail_station', 0, ?, ?)
       on conflict(id) do update set name = excluded.name, lat = excluded.lat, lon = excluded.lon, gtfs_stop_ids = excluded.gtfs_stop_ids, fi_id = excluded.fi_id, fi_uic = excluded.fi_uic`,
    );
    for (const s of newStations.values()) insertStation.run(s.id, s.name, s.country, s.lat, s.lon, TZ_BY_COUNTRY[s.country] ?? TZ, JSON.stringify([...s.stopIds]), s.code, s.uic);
    // An existing station (Haparanda) keeps its name, country and time zone; it only learns its Finnish code.
    const setFi = sqlite.prepare(`update stations set fi_id = ?, fi_uic = ? where id = ? and fi_id is null`);
    for (const [code, m] of matchedCodes) setFi.run(code, m.uic, m.id);
    sqlite.prepare(`delete from timetable_trip_dates where service_date >= ? and trip_key in (select key from timetable_trips where source = ?)`).run(windowStart, SOURCE);
    const insertTrip = sqlite.prepare(
      `insert into timetable_trips (key, source, trip_id, train_number, operator_id, gtfs_operator, route_name, route_type, category, tz, feed_version)
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) on conflict(key) do update set category = excluded.category, operator_id = excluded.operator_id, feed_version = excluded.feed_version`,
    );
    const insertStop = sqlite.prepare(`insert or ignore into timetable_stop_times (trip_key, seq, station_id, arr_sec, dep_sec, no_pickup, no_dropoff) values (?, ?, ?, ?, ?, ?, ?)`);
    const insertDate = sqlite.prepare(`insert or ignore into timetable_trip_dates (trip_key, service_date) values (?, ?)`);
    for (const p of patterns) {
      // "IC 27 Helsinki - Oulu", or for a commuter line "A Helsinki - Leppävaara": the line letter stays in the name.
      const routeName = [p.route.route_short_name, p.route.route_long_name].filter(Boolean).join(' ') || null;
      insertTrip.run(p.key, SOURCE, p.tripId, p.number, p.brand?.id ?? null, p.agency, routeName, p.route.route_type, p.category, TZ, today);
      p.stops.forEach((x, i) => insertStop.run(p.key, i + 1, x.station, x.s[2], x.s[3], x.s[4] ? 1 : 0, x.s[5] ? 1 : 0));
      for (const d of p.dates) tripDates += insertDate.run(p.key, d).changes;
    }
    sqlite.prepare(`delete from timetable_trips where source = ? and key not in (select trip_key from timetable_trip_dates)`).run(SOURCE);
    refreshStationPopularity(db, today);
    db.insert(importLog)
      .values({ source: SOURCE, startedAt: new Date(t0), finishedAt: new Date(), status: 'ok', notes: JSON.stringify({ trips: patterns.length, window: [windowStart, windowEnd] }) })
      .run();
  });
  const summary = {
    trips: patterns.length,
    tripDates,
    stations: { matched, created: newStations.size },
    excluded,
    numbersMissing,
    unknownTypes: [...unknownTypes],
    window: [windowStart, windowEnd] as [string, string],
    ms: Date.now() - t0,
  };
  log(`Finland imported in ${(summary.ms / 1000).toFixed(1)} s: ${summary.trips} trips, ${summary.tripDates} trip-dates, stations ${summary.stations.matched} matched + ${newStations.size} new, ${numbersMissing} without a train number, ${excluded} left out`);
  return summary;
}

export function lastFinlandImport(db: Db): number | null {
  const row = db.$client.prepare(`select started_at from import_log where source = ? and status = 'ok' order by started_at desc limit 1`).get(SOURCE) as { started_at: number } | undefined;
  return row?.started_at ?? null;
}
