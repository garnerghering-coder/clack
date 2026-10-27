// Denmark's rail timetable (DENMARK_DATA_FINDINGS.md): Rejseplanen's open GTFS (rejseplanen.info/labs/GTFS.zip, no
// key, CC BY 4.0, refreshed about every two weeks) into the same timetable tables, source 'gtfs_dk'. Same rules as the
// other countries: dates from yesterday on are replaced, older dates are kept, so Danish history builds up from the
// first import.
//
// What's in (checked 2026-10-27): trains and the S-tog (route_type 2 and 109) of DSB, DSB S-tog, DSB Vores Tog,
// Lokaltog, Midttrafik and NT. Not the Metro (1) or the light rail (0), as in Sweden (SPEC §11). Trains that also call
// in Sweden or Norway (Öresundståg, SJ, Snälltåget, DSB's Swedish runs) are left out: Sweden's feed already has them,
// Danish stops included, with Trafikverket's live times on the Swedish part.
//
// Train numbers are trip_short_name without its zero padding ("000100" is IC 100, "005701" Vores Tog 5701). Stations:
// rail stops carry their UIC number ("000008600626" = 8600626, København H), which is how Clack's Danish stations
// from Sweden's feed are already keyed ("860000626"); others are matched by name and position.
import crypto from 'node:crypto';
import type { Db } from '../db/client.js';
import { importLog, stations } from '../db/schema.js';
import { loadBrands, type Brand } from '../dataFiles.js';
import { addDays, parseGtfsTime, todayIn, ymdToIso } from '../lib/time.js';
import { readAll, readCsv, type Row } from '../lib/zip.js';
import { refreshStationPopularity } from './gtfs-se3.js';
import { calendarRow, serviceDates } from './gtfs-fi.js';
import { matchStation, type ExistingStation } from './gtfs-no.js';
import { countryOf, TZ_BY_COUNTRY } from './stations.js';
import { platformOf, tripDetail, tripDetailArgs, TRIP_DETAIL_COLUMNS, TRIP_DETAIL_UPDATE, TRIP_DETAIL_VALUES, UPSERT_STOP_SQL, type TripDetail } from './detail.js';

export const SOURCE = 'gtfs_dk';
const TZ = 'Europe/Copenhagen';
/** Long-distance products of DSB (InterCity, InterCityLyn, EuroCity Express, RegioJet). */
const INTERCITY_PRODUCTS = new Set(['IC', 'ICL', 'ECE', 'EC', 'RJ']);
/** RegioJet's Prague trains are listed under DSB in Rejseplanen but are not DSB's: no brand for them. */
const NOT_THE_AGENCYS = new Set(['RJ']);

/** "000100" → "100"; empty or not a number → null. Pure. */
export function danishTrainNumber(shortName: string | undefined): string | null {
  const s = (shortName ?? '').trim();
  return /^\d{1,8}$/.test(s) && Number(s) > 0 ? String(Number(s)) : null;
}

/** A stop id's UIC number ("000008600626" → "8600626"), or null for one without. Pure. */
export function uicOf(stopId: string): string | null {
  const m = /^0*(\d{7})$/.exec(stopId);
  return m ? m[1]! : null;
}

/** Clack's id for a Danish UIC station, as Sweden's feed keys them: 8600626 → "860000626". Pure. */
export const danishStationId = (uic: string) => `${uic.slice(0, 2)}00${uic.slice(2)}`;

/** The country of a UIC station number (its first two digits: UIC country codes). Pure. */
export const UIC_COUNTRY: Record<string, string> = { '86': 'DK', '74': 'SE', '76': 'NO', '80': 'DE', '81': 'AT', '54': 'CZ', '51': 'PL', '85': 'CH', '84': 'NL', '87': 'FR', '88': 'BE' };

/** "Odense St." → "Odense" (Rejseplanen adds "St." to station names; Clack's Danish stations don't carry it). */
export const cleanDanishName = (s: string) => s.replace(/\s+St\.?$/i, '').trim();

/**
 * Category from the product: the S-tog is commuter; DSB's IC, ICL, ECE and RJ are intercity (night when it leaves at
 * 20:00 or later and runs six hours or more, as for Norway); everything else (RE, Vores Tog, Lokaltog, Midttrafik, NT)
 * is regional. Pure.
 */
export function danishCategory(routeType: string, product: string, depSec: number | null, arrSec: number | null): string {
  if (routeType === '109') return 'commuter';
  if (INTERCITY_PRODUCTS.has(product.toUpperCase())) {
    if (depSec !== null && arrSec !== null && depSec >= 20 * 3600 && arrSec - depSec >= 6 * 3600) return 'night';
    return 'intercity';
  }
  return 'regional';
}

export interface DenmarkImportSummary {
  trips: number;
  tripDates: number;
  stations: { matched: number; created: number };
  excluded: { abroad: number; unmatched: number; short: number };
  numbersMissing: number;
  window: [string, string];
  ms: number;
}

type StopRow = [seq: number, stopId: string, arr: number | null, dep: number | null, noPickup: boolean, noDropoff: boolean, headsign: string | null];

export async function importGtfsDenmark(db: Db, zip: string, opts: { today?: string; daysAhead?: number; fillGaps?: boolean; log?: (m: string) => void } = {}): Promise<DenmarkImportSummary> {
  const t0 = Date.now();
  const log = opts.log ?? (() => {});
  const today = opts.today ?? todayIn(TZ);
  const windowStart = addDays(today, -1);
  const windowEnd = addDays(today, opts.daysAhead ?? 90);
  const [from, to] = [windowStart.replaceAll('-', ''), windowEnd.replaceAll('-', '')];
  const brands = loadBrands();
  const brandOf = (agency: string): Brand | undefined => brands.find((b) => b.gtfs_operators.includes(agency));

  const agencies = new Map((await readAll(zip, 'agency.txt')).map((a) => [a.agency_id!, a]));
  const routes = new Map((await readAll(zip, 'routes.txt', (r) => r.route_type === '2' || r.route_type === '109' || /^1(0\d|1[0-7])$/.test(r.route_type!))).map((r) => [r.route_id!, r]));
  const trips = await readAll(zip, 'trips.txt', (t) => routes.has(t.route_id!));
  const services = new Set(trips.map((t) => t.service_id!));
  const calendar = new Map((await readAll(zip, 'calendar.txt', (c) => services.has(c.service_id!))).map((c) => [c.service_id!, calendarRow(c)]));
  const added = new Map<string, string[]>();
  const removed = new Map<string, Set<string>>();
  for (const cd of await readAll(zip, 'calendar_dates.txt', (c) => services.has(c.service_id!))) {
    if (cd.exception_type === '1') (added.get(cd.service_id!) ?? added.set(cd.service_id!, []).get(cd.service_id!)!).push(cd.date!);
    else if (cd.exception_type === '2') (removed.get(cd.service_id!) ?? removed.set(cd.service_id!, new Set()).get(cd.service_id!)!).add(cd.date!);
  }
  // fillGaps (old copies, imported newest first): only dates no import has covered yet, and nothing is deleted.
  const covered = new Set<string>(opts.fillGaps ? (db.$client.prepare(`select distinct d.service_date from timetable_trip_dates d join timetable_trips t on t.key = d.trip_key where t.source = ?`).all(SOURCE) as { service_date: string }[]).map((r) => r.service_date) : []);
  const dates = new Map<string, string[]>();
  for (const sid of services) {
    const ds = serviceDates(calendar.get(sid), added.get(sid) ?? [], removed.get(sid) ?? new Set(), from, to).map(ymdToIso).filter((d) => !covered.has(d));
    if (ds.length) dates.set(sid, ds);
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
      st.stop_headsign || null,
    ]);
  }
  log(`Rejseplanen: ${kept.length} rail trips running ${windowStart}..${windowEnd}`);

  const usedStops = new Set([...stopsByTrip.values()].flatMap((l) => l.map((s) => s[1])));
  const stopRows = new Map<string, Row>();
  for await (const s of readCsv(zip, 'stops.txt')) if (usedStops.has(s.stop_id!)) stopRows.set(s.stop_id!, s);

  const existing: ExistingStation[] = db.select({ id: stations.id, name: stations.name, lat: stations.lat, lon: stations.lon, country: stations.country }).from(stations).all();
  const existingIds = new Set(existing.map((s) => s.id));
  const stationOfStop = new Map<string, string | null>();
  const newStations = new Map<string, { id: string; name: string; lat: number; lon: number; country: string; stopIds: string[] }>();
  let matched = 0;
  /** Our station for a Rejseplanen stop; null when it has no position. */
  const stationFor = (stopId: string): string | null => {
    if (stationOfStop.has(stopId)) return stationOfStop.get(stopId)!;
    const s = stopRows.get(stopId);
    const uic = uicOf(stopId);
    let id: string | null = null;
    if (s) {
      const at = { name: s.stop_name!, lat: Number(s.stop_lat), lon: Number(s.stop_lon) };
      const byUic = uic?.startsWith('86') ? danishStationId(uic) : null;
      if (byUic && existingIds.has(byUic)) {
        id = byUic;
        matched++;
      } else {
        const same = Number.isFinite(at.lat) ? matchStation({ ...at, name: cleanDanishName(at.name) }, existing) : null;
        if (same) {
          id = same.id;
          matched++;
        } else if (Number.isFinite(at.lat)) {
          id = byUic ?? (uic ? `uic:${uic}` : `dk:${stopId}`);
          if (!newStations.has(id)) {
            const country = (uic && UIC_COUNTRY[uic.slice(0, 2)]) || countryOf(null, undefined, at.lat, at.lon);
            newStations.set(id, { id, name: cleanDanishName(at.name), lat: at.lat, lon: at.lon, country, stopIds: [stopId] });
          }
        }
      }
    }
    stationOfStop.set(stopId, id);
    return id;
  };
  /** A stop in Sweden or Norway: the train is in that country's feed already. */
  const abroadNorth = (stopId: string) => {
    const uic = uicOf(stopId);
    if (uic && (uic.startsWith('74') || uic.startsWith('76'))) return true;
    const id = stationFor(stopId);
    const c = id ? (existing.find((e) => e.id === id)?.country ?? newStations.get(id)?.country) : undefined;
    return c === 'SE' || c === 'NO';
  };

  const excluded = { abroad: 0, unmatched: 0, short: 0 };
  let numbersMissing = 0;
  const usedBrands = new Map<string, Brand>();
  const patterns: { key: string; tripId: string; number: string | null; brand?: Brand; agency: string; route: Row; category: string; stops: { station: string; s: StopRow; platform: string | null }[]; dates: string[]; detail: TripDetail }[] = [];
  for (const trip of kept) {
    const raw = (stopsByTrip.get(trip.trip_id!) ?? []).sort((a, b) => a[0] - b[0]);
    if (raw.length < 2) {
      excluded.short++;
      continue;
    }
    if (raw.some((s) => abroadNorth(s[1]))) {
      excluded.abroad++;
      continue;
    }
    const stops = raw.map((s) => ({ station: stationFor(s[1]), s }));
    if (stops.some((x) => !x.station)) {
      excluded.unmatched++;
      continue;
    }
    for (const x of stops) newStations.get(x.station!)?.stopIds.push(x.s[1]);
    const route = routes.get(trip.route_id!)!;
    const agency = agencies.get(route.agency_id!)?.agency_name ?? '';
    const product = route.route_short_name ?? '';
    // The agency, or the route's description: Öresundståg's Danish runs are listed under Skånetrafiken, described "Öresundståg".
    const brand = NOT_THE_AGENCYS.has(product.toUpperCase()) ? undefined : (brandOf(agency) ?? (route.route_desc ? brandOf(route.route_desc) : undefined));
    if (brand) usedBrands.set(brand.id, brand);
    const number = danishTrainNumber(trip.trip_short_name);
    if (!number) numbersMissing++;
    const firstDep = raw[0]![3] ?? raw[0]![2];
    const lastArr = raw.at(-1)![2] ?? raw.at(-1)![3];
    const hash = crypto
      .createHash('sha1')
      .update(JSON.stringify([number, route.route_type, stops.map((x) => [x.station, x.s[2], x.s[3], x.s[4], x.s[5]])]))
      .digest('hex')
      .slice(0, 10);
    patterns.push({
      key: `dk:${trip.trip_id}:${hash}`,
      tripId: trip.trip_id!,
      number,
      brand,
      agency,
      route,
      category: danishCategory(route.route_type!, product, firstDep, lastArr),
      stops: stops.map((x) => ({ station: x.station!, s: x.s, platform: platformOf(stopRows.get(x.s[1])) })),
      dates: dates.get(trip.service_id!)!,
      detail: tripDetail(trip, route),
    });
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
      `insert into stations (id, name, country, lat, lon, tz, trv_signature, gtfs_stop_ids, coord_source, historical_only, kind, needs_review)
       values (?, ?, ?, ?, ?, ?, null, ?, 'gtfs', 0, 'rail_station', 0)
       on conflict(id) do update set gtfs_stop_ids = excluded.gtfs_stop_ids`,
    );
    for (const s of newStations.values()) insertStation.run(s.id, s.name, s.country, s.lat, s.lon, TZ_BY_COUNTRY[s.country] ?? TZ, JSON.stringify([...new Set(s.stopIds)]));
    if (!opts.fillGaps) sqlite.prepare(`delete from timetable_trip_dates where service_date >= ? and trip_key in (select key from timetable_trips where source = ?)`).run(windowStart, SOURCE);
    const insertTrip = sqlite.prepare(
      `insert into timetable_trips (key, source, trip_id, train_number, operator_id, gtfs_operator, route_name, route_type, category, tz, feed_version, ${TRIP_DETAIL_COLUMNS})
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ${TRIP_DETAIL_VALUES}) on conflict(key) do update set category = excluded.category, operator_id = excluded.operator_id, feed_version = excluded.feed_version, ${TRIP_DETAIL_UPDATE}`,
    );
    const insertStop = sqlite.prepare(UPSERT_STOP_SQL);
    const insertDate = sqlite.prepare(`insert or ignore into timetable_trip_dates (trip_key, service_date) values (?, ?)`);
    for (const p of patterns) {
      // "IC Odense St." style: the product and where it's going (Rejseplanen has no long route names).
      const routeName = [p.route.route_short_name, p.detail.headsign && cleanDanishName(p.detail.headsign)].filter(Boolean).join(' ') || null;
      insertTrip.run(p.key, SOURCE, p.tripId, p.number, p.brand?.id ?? null, p.agency, routeName, p.route.route_type, p.category, TZ, today, ...tripDetailArgs(p.detail));
      p.stops.forEach((x, i) => insertStop.run(p.key, i + 1, x.station, x.s[2], x.s[3], x.s[4] ? 1 : 0, x.s[5] ? 1 : 0, x.platform, x.s[6]));
      for (const d of p.dates) tripDates += insertDate.run(p.key, d).changes;
    }
    sqlite.prepare(`delete from timetable_trips where source = ? and key not in (select trip_key from timetable_trip_dates)`).run(SOURCE);
    refreshStationPopularity(db, opts.fillGaps ? todayIn(TZ) : today);
    db.insert(importLog)
      .values({ source: SOURCE, startedAt: new Date(t0), finishedAt: new Date(), status: 'ok', notes: JSON.stringify({ trips: patterns.length, window: [windowStart, windowEnd], excluded }) })
      .run();
  });
  const summary = { trips: patterns.length, tripDates, stations: { matched, created: newStations.size }, excluded, numbersMissing, window: [windowStart, windowEnd] as [string, string], ms: Date.now() - t0 };
  log(
    `Denmark imported in ${(summary.ms / 1000).toFixed(1)} s: ${summary.trips} trips, ${summary.tripDates} trip-dates, stations ${matched} matched + ${newStations.size} new; left out ${excluded.abroad} also in Sweden's or Norway's feed, ${excluded.unmatched} with an unplaced stop; ${numbersMissing} without a train number`,
  );
  return summary;
}

export function lastDenmarkImport(db: Db): number | null {
  const row = db.$client.prepare(`select started_at from import_log where source = ? and status = 'ok' order by started_at desc limit 1`).get(SOURCE) as { started_at: number } | undefined;
  return row?.started_at ?? null;
}
