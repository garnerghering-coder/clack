// GTFS Sweden 3 import (spec §8, adjusted by Phase 0): rail trips only, one row per trip pattern plus its
// service dates, stop times as GTFS offsets. Dates from (today - 1) onward are replaced; older dates are kept,
// because Sweden 3 itself only starts at yesterday and history must stay permanent.
import crypto from 'node:crypto';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, trvLocations } from '../db/schema.js';
import { loadBrands, loadCategoryRules, loadStationOverrides, type Brand } from '../dataFiles.js';
import { parseGtfsTime, todayIn, addDays, ymdToIso } from '../lib/time.js';
import { readAll, readCsv, type Row } from '../lib/zip.js';
import { classify, isRailRoute } from './classify.js';
import { buildStations, type GtfsParent, type TrvLoc } from './stations.js';

export const SOURCE = 'gtfs_se3';

export interface ImportSummary {
  feedVersion: string;
  trips: number;
  tripDates: number;
  stopTimes: number;
  stations: number;
  needsReview: string[];
  excluded: Record<string, number>;
  window: [string, string];
  ms: number;
}

export interface ImportOptions {
  /** Days ahead to import (spec suggested +60; Phase 0 found the feed runs ~14 months ahead). */
  daysAhead?: number;
  today?: string;
  officialSigs: Map<string, string[]>;
  log?: (msg: string) => void;
}

type StopRow = [seq: number, stopId: string, arr: number | null, dep: number | null, noPickup: boolean, noDropoff: boolean];

export function brandIndex(brands: Brand[]): Map<string, Brand> {
  const m = new Map<string, Brand>();
  for (const b of brands) for (const op of b.gtfs_operators) m.set(op, b);
  return m;
}

/** Service dates per service_id from calendar.txt + calendar_dates.txt, limited to [from, to] (YYYYMMDD). */
export function serviceDates(calendar: Row[], calendarDates: Row[], from: string, to: string): Map<string, Set<string>> {
  const map = new Map<string, Set<string>>();
  const add = (sid: string, d: string) => (map.get(sid) ?? map.set(sid, new Set()).get(sid)!).add(d);
  const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  for (const c of calendar) {
    const start = c.start_date! > from ? c.start_date! : from;
    const end = c.end_date! < to ? c.end_date! : to;
    for (let d = new Date(`${ymdToIso(start)}T12:00:00Z`); d <= new Date(`${ymdToIso(end)}T12:00:00Z`); d = new Date(+d + 86400_000)) {
      if (c[days[d.getUTCDay()]!] === '1') add(c.service_id!, d.toISOString().slice(0, 10).replaceAll('-', ''));
    }
  }
  for (const cd of calendarDates) {
    if (cd.date! < from || cd.date! > to) continue;
    if (cd.exception_type === '1') add(cd.service_id!, cd.date!);
    else map.get(cd.service_id!)?.delete(cd.date!);
  }
  return map;
}

export async function importGtfsSweden3(db: Db, zipPath: string, opts: ImportOptions): Promise<ImportSummary> {
  const t0 = Date.now();
  const log = opts.log ?? (() => {});
  const today = opts.today ?? todayIn('Europe/Stockholm');
  const windowStart = addDays(today, -1);
  const windowEnd = addDays(today, opts.daysAhead ?? 90);
  const from = windowStart.replaceAll('-', '');
  const to = windowEnd.replaceAll('-', '');

  const feedVersion = (await readAll(zipPath, 'feed_info.txt'))[0]?.feed_version ?? 'unknown';
  const agencies = new Map((await readAll(zipPath, 'agency.txt')).map((a) => [a.agency_id!, a]));
  const routes = new Map(
    (await readAll(zipPath, 'routes.txt', (r) => isRailRoute(r.route_type!, r.route_short_name!, agencies.get(r.agency_id!)?.agency_name ?? ''))).map((r) => [r.route_id!, r]),
  );
  let trips = await readAll(zipPath, 'trips.txt', (t) => routes.has(t.route_id!));
  const serviceIds = new Set(trips.map((t) => t.service_id!));
  const dates = serviceDates(
    await readAll(zipPath, 'calendar.txt', (c) => serviceIds.has(c.service_id!)),
    await readAll(zipPath, 'calendar_dates.txt', (c) => serviceIds.has(c.service_id!)),
    from,
    to,
  );
  trips = trips.filter((t) => (dates.get(t.service_id!)?.size ?? 0) > 0);
  const tripIds = new Set(trips.map((t) => t.trip_id!));
  log(`feed ${feedVersion}: ${routes.size} rail routes, ${trips.length} rail trips running ${windowStart}..${windowEnd}`);

  const operatorOf = new Map<string, string>();
  for (const a of await readAll(zipPath, 'attributions.txt', (a) => tripIds.has(a.trip_id!) && a.is_operator !== '0')) operatorOf.set(a.trip_id!, a.organization_name!);

  const stopsByTrip = new Map<string, StopRow[]>();
  const usedStops = new Set<string>();
  for await (const st of readCsv(zipPath, 'stop_times.txt')) {
    if (!tripIds.has(st.trip_id!)) continue;
    const list = stopsByTrip.get(st.trip_id!) ?? stopsByTrip.set(st.trip_id!, []).get(st.trip_id!)!;
    list.push([Number(st.stop_sequence), st.stop_id!, parseGtfsTime(st.arrival_time!), parseGtfsTime(st.departure_time!), st.pickup_type === '1', st.drop_off_type === '1']);
    usedStops.add(st.stop_id!);
  }
  for (const list of stopsByTrip.values()) list.sort((a, b) => a[0] - b[0]);
  log(`stop_times: ${[...stopsByTrip.values()].reduce((n, l) => n + l.length, 0)} rail rows`);

  // Parent stations of the used platforms, with their rikshållplats.
  const stopRows = new Map<string, Row>();
  for await (const s of readCsv(zipPath, 'stops.txt')) stopRows.set(s.stop_id!, s);
  const parentOf = (id: string) => stopRows.get(id)?.parent_station || id;
  const areaType = new Map((await readAll(zipPath, 'areas.txt')).map((a) => [a.area_id!, a.samtrafiken_area_type]));
  const riksOf = new Map<string, string>();
  for (const sa of await readAll(zipPath, 'stop_areas.txt')) if (areaType.get(sa.area_id!) === 'rikshallplats') riksOf.set(sa.stop_id!, sa.area_id!);
  const parents = new Map<string, GtfsParent>();
  for (const id of usedStops) {
    const pid = parentOf(id);
    const p = stopRows.get(pid);
    if (!p) continue;
    const entry =
      parents.get(pid) ??
      parents.set(pid, { stopId: pid, name: p.stop_name!, lat: Number(p.stop_lat), lon: Number(p.stop_lon), childIds: [], riks: riksOf.get(pid) }).get(pid)!;
    if (id !== pid) entry.childIds.push(id);
  }

  const trv: TrvLoc[] = db.select().from(trvLocations).all().map((t) => ({ signature: t.signature, name: t.name, lat: t.lat, lon: t.lon, country: t.country }));
  if (!trv.length) throw new Error('Trafikverket stations are not imported yet; run the trv-stations import first');
  const built = buildStations([...parents.values()], trv, opts.officialSigs, loadStationOverrides());
  const stationById = new Map(built.stations.map((s) => [s.id, s]));

  // Classify, build trip patterns.
  const rules = loadCategoryRules();
  const brands = brandIndex(loadBrands());
  const usedBrands = new Map<string, Brand>();
  const excluded: Record<string, number> = {};
  const patterns: {
    key: string;
    trip: Row;
    route: Row;
    operator?: string;
    brand?: Brand;
    category: string;
    tz: string;
    stops: (StopRow & { station: string })[];
    dates: string[];
  }[] = [];
  for (const trip of trips) {
    const route = routes.get(trip.route_id!)!;
    const raw = stopsByTrip.get(trip.trip_id!) ?? [];
    if (raw.length < 2) continue;
    const stops = raw.map((s) => Object.assign([...s] as StopRow, { station: built.stationOfParent.get(parentOf(s[1]))! }));
    if (stops.some((s) => !s.station)) continue;
    const agency = agencies.get(route.agency_id!);
    const operator = operatorOf.get(trip.trip_id!) ?? agency?.agency_name;
    const result = classify(rules, {
      gtfs_route_type: route.route_type!,
      gtfs_operator: operator,
      gtfs_route_short_name: route.route_short_name,
      train_number: trip.samtrafiken_internal_trip_number || trip.trip_short_name || null,
      has_non_rail_stop: stops.some((s) => stationById.get(s.station)?.kind === 'bus_stop'),
      stop_sigs: stops.map((s) => stationById.get(s.station)?.trvSignature ?? undefined),
    });
    if (result.excluded) {
      excluded[result.reason] = (excluded[result.reason] ?? 0) + 1;
      continue;
    }
    const brand = operator ? brands.get(operator) : undefined;
    if (brand) usedBrands.set(brand.id, brand);
    const number = trip.samtrafiken_internal_trip_number || trip.trip_short_name || null;
    const hash = crypto
      .createHash('sha1')
      .update(JSON.stringify([number, route.route_type, stops.map((s) => [s.station, s[2], s[3], s[4], s[5]])]))
      .digest('hex')
      .slice(0, 10);
    patterns.push({
      key: `se3:${trip.trip_id}:${hash}`,
      trip,
      route,
      operator,
      brand,
      category: result.category,
      tz: agency?.agency_timezone || 'Europe/Stockholm',
      stops,
      dates: [...dates.get(trip.service_id!)!].map(ymdToIso),
    });
  }
  log(`${patterns.length} rail trip patterns kept; excluded: ${JSON.stringify(excluded)}`);

  // Write everything in one transaction: readers keep seeing the old data until it commits.
  const sqlite = db.$client;
  let tripDates = 0;
  let stopTimes = 0;
  db.transaction(() => {
    const upsertOperator = sqlite.prepare(
      `insert into operators (id, name, short_name, company, country, brand_color, logo_path) values (?, ?, ?, null, ?, ?, null)
       on conflict(id) do update set name = excluded.name, short_name = excluded.short_name, country = excluded.country, brand_color = excluded.brand_color`,
    );
    for (const b of usedBrands.values()) upsertOperator.run(b.id, b.name, b.short_name, b.country, b.color);

    const upsertStation = sqlite.prepare(
      `insert into stations (id, name, country, lat, lon, tz, trv_signature, gtfs_stop_ids, coord_source, historical_only, kind, needs_review)
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
       on conflict(id) do update set name = case when stations.country = 'NO' then stations.name else excluded.name end, country = excluded.country, lat = excluded.lat, lon = excluded.lon, tz = excluded.tz,
         trv_signature = excluded.trv_signature, gtfs_stop_ids = excluded.gtfs_stop_ids, coord_source = excluded.coord_source,
         historical_only = 0, kind = excluded.kind, needs_review = excluded.needs_review`,
    );
    for (const s of built.stations)
      upsertStation.run(s.id, s.name, s.country, s.lat, s.lon, s.tz, s.trvSignature, JSON.stringify(s.gtfsStopIds), s.coordSource, s.kind, s.needsReview ? 1 : 0);

    // Replace this source's dates from windowStart on; older dates stay as they were.
    sqlite.prepare(`delete from timetable_trip_dates where service_date >= ? and trip_key in (select key from timetable_trips where source = ?)`).run(windowStart, SOURCE);

    const insertTrip = sqlite.prepare(
      `insert into timetable_trips (key, source, trip_id, train_number, operator_id, gtfs_operator, route_name, route_type, category, tz, feed_version)
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) on conflict(key) do update set feed_version = excluded.feed_version, category = excluded.category, operator_id = excluded.operator_id`,
    );
    const insertStop = sqlite.prepare(
      `insert or ignore into timetable_stop_times (trip_key, seq, station_id, arr_sec, dep_sec, no_pickup, no_dropoff) values (?, ?, ?, ?, ?, ?, ?)`,
    );
    const insertDate = sqlite.prepare(`insert or ignore into timetable_trip_dates (trip_key, service_date) values (?, ?)`);
    for (const p of patterns) {
      const routeName = p.route.route_long_name || p.route.route_short_name || null;
      insertTrip.run(p.key, SOURCE, p.trip.trip_id, p.trip.samtrafiken_internal_trip_number || p.trip.trip_short_name || null, p.brand?.id ?? null, p.operator ?? null, routeName, p.route.route_type, p.category, p.tz, feedVersion);
      p.stops.forEach((s, i) => {
        if (insertStop.run(p.key, i + 1, s.station, s[2], s[3], s[4] ? 1 : 0, s[5] ? 1 : 0).changes) stopTimes++;
      });
      for (const d of p.dates) tripDates += insertDate.run(p.key, d).changes;
    }
    // Patterns with no dates left (replaced by a changed timetable before they ever ran) can go.
    sqlite.prepare(`delete from timetable_trips where source = ? and key not in (select trip_key from timetable_trip_dates)`).run(SOURCE);

    // Stations nothing uses any more (merged duplicates, stops dropped from the feed), unless a saved leg needs them.
    sqlite
      .prepare(
        `delete from stations where historical_only = 0
           and id not in (select station_id from timetable_stop_times)
           and id not in (select origin_station_id from legs) and id not in (select dest_station_id from legs)
           and id not in (select station_id from leg_stops)`,
      )
      .run();

    refreshStationPopularity(db, today);

    db.insert(importLog)
      .values({ source: SOURCE, startedAt: new Date(t0), finishedAt: new Date(), status: 'ok', notes: JSON.stringify({ feedVersion, trips: patterns.length, window: [windowStart, windowEnd] }) })
      .run();
  });

  const summary: ImportSummary = {
    feedVersion,
    trips: patterns.length,
    tripDates,
    stopTimes,
    stations: built.stations.length,
    needsReview: built.stations.filter((s) => s.needsReview).map((s) => `${s.name} (${s.id})`),
    excluded,
    window: [windowStart, windowEnd],
    ms: Date.now() - t0,
  };
  log(`imported in ${(summary.ms / 1000).toFixed(1)} s: ${summary.trips} trips, ${summary.tripDates} trip-dates, ${summary.stopTimes} new stop times, ${summary.stations} stations`);
  return summary;
}

export function lastImportedFeed(db: Db): string | null {
  const row = db.all<{ notes: string }>(sql`select notes from import_log where source = ${SOURCE} and status = 'ok' order by started_at desc limit 1`)[0];
  return row ? (JSON.parse(row.notes).feedVersion as string) : null;
}

/**
 * Popularity for search ranking: boardable departures per day over the next week, with a commuter train counting a
 * third, so "stoc" puts Stockholm C (308 departures, mostly long-distance and regional) above Stockholm City (460,
 * all pendeltåg). One grouped query; also run at start-up so older databases get the weighting.
 */
export function refreshStationPopularity(db: Db, today = new Date().toISOString().slice(0, 10)) {
  const sqlite = db.$client;
  sqlite.exec('drop table if exists temp.station_pop');
  sqlite
    .prepare(
      `create temp table station_pop as
       select st.station_id, sum(case when t.category = 'commuter' then 0.33 else 1.0 end) / 8.0 as w
       from timetable_stop_times st
       join timetable_trip_dates d on d.trip_key = st.trip_key
       join timetable_trips t on t.key = st.trip_key
       where st.dep_sec is not null and st.no_pickup = 0 and d.service_date between ? and ?
       group by st.station_id`,
    )
    .run(today, addDays(today, 7));
  sqlite.exec(`update stations set departures_per_day = coalesce((select w from temp.station_pop p where p.station_id = stations.id), 0)`);
  sqlite.exec('drop table temp.station_pop');
}

