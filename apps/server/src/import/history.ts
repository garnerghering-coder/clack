// Sweden's timetable history (DATA_FINDINGS §4): for a date before GTFS Sweden 3's window, the latest GTFS Sverige 2
// snapshot dated on or before it, from Samtrafiken's keyless archive (one snapshot per weekday since 2012-08, every
// date from 2012-08-10 covered). Each snapshot is downloaded once (~50 MB) and only its rail trips for a few weeks
// around the requested date are imported, as source 'gtfs_sv2'. Dates already covered are never imported twice.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import yauzl from 'yauzl';
import { sql } from 'drizzle-orm';
import type { Db } from '../db/client.js';
import { importLog, trvLocations } from '../db/schema.js';
import { loadBrands, loadCategoryRules, loadStationOverrides, type Brand } from '../dataFiles.js';
import { addDays, parseGtfsTime, ymdToIso } from '../lib/time.js';
import { readAll, readCsv, type Row } from '../lib/zip.js';
import { classify, isRailRoute } from './classify.js';
import { brandIndex, refreshStationPopularity, serviceDates } from './gtfs-se3.js';
import { buildStations, type GtfsParent, type TrvLoc } from './stations.js';
import { brandMatcher } from '../boards/board.js';
import { CACHE_DIR } from './downloads.js';
import { loadOfficialMapping } from './official-mapping.js';
import { platformOf, tripDetail, tripDetailArgs, TRIP_DETAIL_COLUMNS, TRIP_DETAIL_VALUES, UPSERT_STOP_SQL } from './detail.js';

export const HISTORY_SOURCE = 'gtfs_sv2';
export const ARCHIVE_URL = 'https://data.samtrafiken.se/trafiklab/gtfs-sverige-2';
/** The archive's first service date. */
export const ARCHIVE_START = '2012-08-10';
const DIR = path.join(CACHE_DIR, 'sverige2');
/** Days either side of the requested date taken from one snapshot. */
const SPAN_DAYS = 14;

export interface Snapshot {
  ymd: string;
  url: string;
  extraUrl: string;
}

const listings = new Map<string, { at: number; list: Snapshot[] }>();
/** For tests. */
export const resetListingCache = () => listings.clear();

/**
 * Snapshot files in one month of the archive, oldest first. Remembered: a past month's listing doesn't change, and
 * the current month's is asked again after an hour (each import used to ask for up to seven months again).
 */
export async function listSnapshots(year: number, month: number, fetchImpl: typeof fetch = fetch, now = Date.now()): Promise<Snapshot[]> {
  const ym = `${year}/${String(month).padStart(2, '0')}`;
  const hit = listings.get(ym);
  const current = ym >= new Date(now).toISOString().slice(0, 7).replace('-', '/');
  if (hit && (!current || now - hit.at < 3600_000)) return hit.list;
  const dir = `${ARCHIVE_URL}/${ym}/`;
  const res = await fetchImpl(dir);
  if (res.status === 404) return [];
  if (!res.ok) throw new Error(`Sverige 2 archive ${res.status}`);
  const list = parseListing(await res.text(), dir);
  listings.set(ym, { at: now, list });
  return list;
}

/** "sweden-20250310.zip" (2017 on) or "trafiklab-20140310.zip" (2012–2016), with its matching extra file. Pure. */
export function parseListing(html: string, dir: string): Snapshot[] {
  const out: Snapshot[] = [];
  for (const m of html.matchAll(/href="((?:sweden|trafiklab)-(\d{8})\.zip)"/g)) out.push({ ymd: m[2]!, url: dir + m[1], extraUrl: `${dir}trafiklab-extra-${m[2]}.zip` });
  return out.sort((a, b) => a.ymd.localeCompare(b.ymd));
}

/** The latest snapshot dated on or before `date`, looking back up to six months (the largest gap is 123 days). */
export async function snapshotFor(date: string, fetchImpl?: typeof fetch): Promise<Snapshot | null> {
  const want = date.replaceAll('-', '');
  let [y, m] = date.split('-').map(Number) as [number, number];
  for (let i = 0; i < 7; i++) {
    const hit = (await listSnapshots(y, m, fetchImpl)).filter((s) => s.ymd <= want).at(-1);
    if (hit) return hit;
    m--;
    if (!m) {
      m = 12;
      y--;
    }
  }
  return null;
}

async function download(url: string, file: string, fetchImpl: typeof fetch = fetch) {
  if (fs.existsSync(file)) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const res = await fetchImpl(url);
  if (!res.ok || !res.body) throw new Error(`Sverige 2 download ${res.status}: ${url}`);
  const tmp = `${file}.part`;
  await pipeline(Readable.fromWeb(res.body as import('node:stream/web').ReadableStream), fs.createWriteStream(tmp));
  fs.renameSync(tmp, file);
}

/** The extra file wraps another zip (extra.zip); unpack that one inner file next to it. */
async function unpackInner(zipPath: string, name: string, out: string) {
  if (fs.existsSync(out)) return;
  const zip = await yauzl.openPromise(zipPath);
  for await (const entry of zip.eachEntry()) {
    if (entry.fileName !== name && !entry.fileName.endsWith(`/${name}`)) continue;
    await pipeline(await zip.openReadStreamPromise(entry), fs.createWriteStream(`${out}.part`));
    fs.renameSync(`${out}.part`, out);
    return;
  }
}

/** Dates already imported from the archive, from the import log. */
function coveredDates(db: Db): Set<string> {
  const out = new Set<string>();
  for (const r of db.$client.prepare(`select notes from import_log where source = ? and status = 'ok'`).all(HISTORY_SOURCE) as { notes: string }[])
    for (const d of trustedDates(JSON.parse(r.notes) as ImportNotes)) out.add(d);
  return out;
}

interface ImportNotes {
  snapshot?: string;
  dates?: string[];
}
/**
 * The dates an import really filled. A snapshot only holds its own day and later in full (one from 28 Sept has a
 * third of the 25th's trains), so earlier imports that also took the days before their snapshot don't count for
 * those days: they're imported again from the right snapshot. Pure.
 */
export function trustedDates(notes: ImportNotes): string[] {
  const from = notes.snapshot ? ymdToIso(notes.snapshot) : null;
  return (notes.dates ?? []).filter((d) => !from || d >= from);
}

/** The days to import around `date` from a snapshot of `snapshotDate`: from the snapshot's day on, up to two weeks
 * either side of the asked-for date (or the `span` given, for the backfill's blocks), not yet covered and before the
 * current feed's first day. Pure. */
export function datesToFill(date: string, snapshotDate: string, firstCurrent: string, covered: Set<string>, span?: { from: string; to: string }): string[] {
  const out: string[] = [];
  const [first, last] = span ? [span.from, span.to] : [addDays(date, -SPAN_DAYS), addDays(date, SPAN_DAYS)];
  for (let d = first; d <= last; d = addDays(d, 1)) {
    if (d >= ARCHIVE_START && d >= snapshotDate && d < firstCurrent && !covered.has(d)) out.push(d);
  }
  return out;
}

/** The first day of the current Swedish feed (GTFS Sweden 3): the archive is only for days before it. */
export function firstCurrentDay(db: Db): string {
  return (
    db.all<{ d: string | null }>(sql`select min(d.service_date) as d from timetable_trip_dates d join timetable_trips t on t.key = d.trip_key where t.source = 'gtfs_se3'`)[0]?.d ??
    '9999-12-31'
  );
}

/** Is there any Swedish timetable for this date (today's feed kept from earlier days, or the archive)? */
export function hasSwedishTimetable(db: Db, date: string): boolean {
  if (coveredDates(db).has(date)) return true;
  return Boolean(
    // Only the current feed here: archive trips on a date can be a partial day (see trustedDates).
    db.all(sql`select 1 from timetable_trip_dates d join timetable_trips t on t.key = d.trip_key where d.service_date = ${date} and t.source = 'gtfs_se3' limit 1`).length,
  );
}

/** The 7-digit rikshållplats ids of 2012–2016 (74xxxxx) became 9 digits (7400xxxxx). */
export const riksId = (id: string) => (/^\d{7}$/.test(id) ? `${id.slice(0, 2)}00${id.slice(2)}` : id);

type StopRow = [seq: number, stopId: string, arr: number | null, dep: number | null, noPickup: boolean, noDropoff: boolean, headsign: string | null];

/**
 * An archive trip's key: a fingerprint of everything stored about it (number, operator, route type, category, route
 * name, headsign, and per stop the station, times, boarding flags, platform and headsign). The same train in the next
 * snapshot gets the same key and only adds its dates, so an unchanged train is stored once, not once per snapshot;
 * a train that differs in anything stored gets its own. Earlier `sv2:<snapshot>:<trip>:<hash>` keys stay as they are.
 */
export function historyKey(t: { number: string | null; operator: string; routeType: string; category: string; routeName: string | null; headsign: string | null; stops: unknown[][] }): string {
  return `sv2:${crypto.createHash('sha1').update(JSON.stringify([t.number, t.operator, t.routeType, t.category, t.routeName, t.headsign, t.stops])).digest('hex').slice(0, 14)}`;
}

export interface HistorySummary {
  snapshot: string;
  dates: string[];
  trips: number;
  stationsAdded: number;
  ms: number;
}

/**
 * Import the archive's timetable around `date`: from the snapshot for that date, its rail trips on the days within
 * SPAN_DAYS, from the snapshot's own day on, that have no Swedish timetable yet (and are before GTFS Sweden 3's first day).
 */
export async function importHistory(
  db: Db,
  date: string,
  opts: { fetchImpl?: typeof fetch; log?: (m: string) => void; span?: { from: string; to: string }; keepDownload?: boolean } = {},
): Promise<HistorySummary | null> {
  const t0 = Date.now();
  const log = opts.log ?? (() => {});
  const snap = await snapshotFor(date, opts.fetchImpl);
  if (!snap) return null;
  const zip = path.join(DIR, `sweden-${snap.ymd}.zip`);
  log(`Sverige 2: snapshot ${snap.ymd} for ${date}`);
  // Train numbers: trip_short_name until 2019, then the extra file's trips_technical.txt (DATA_FINDINGS §4).
  const extra = path.join(DIR, `extra-${snap.ymd}.zip`);
  const inner = path.join(DIR, `extra-${snap.ymd}-inner.zip`);
  // Both files at once (the extra one used to wait for the 33–63 MB main one); the extra one may be missing.
  const extraDownload = download(snap.extraUrl, extra, opts.fetchImpl).then(
    () => null,
    (e: Error) => e,
  );
  await download(snap.url, zip, opts.fetchImpl);
  const technical = new Map<string, string>();
  try {
    const failed = await extraDownload;
    if (failed) throw failed;
    await unpackInner(extra, 'extra.zip', inner);
    for await (const r of readCsv(inner, 'trips_technical.txt')) if (r.technical_trip_number) technical.set(r.trip_id!, r.technical_trip_number);
  } catch (e) {
    log(`Sverige 2: no extra file for ${snap.ymd} (${(e as Error).message}); numbers from trip_short_name only`);
  }

  // The dates to fill: around the requested one, not yet covered, before the current feed's first day.
  const wanted = datesToFill(date, ymdToIso(snap.ymd), firstCurrentDay(db), coveredDates(db), opts.span);
  if (!wanted.length) return { snapshot: snap.ymd, dates: [], trips: 0, stationsAdded: 0, ms: Date.now() - t0 };
  const [from, to] = [wanted[0]!.replaceAll('-', ''), wanted.at(-1)!.replaceAll('-', '')];
  const wantedSet = new Set(wanted);

  const agencies = new Map((await readAll(zip, 'agency.txt')).map((a) => [a.agency_id!, a]));
  const routes = new Map((await readAll(zip, 'routes.txt', (r) => isRailRoute(r.route_type!, r.route_short_name!, agencies.get(r.agency_id!)?.agency_name ?? ''))).map((r) => [r.route_id!, r]));
  let trips = await readAll(zip, 'trips.txt', (t) => routes.has(t.route_id!));
  const sids = new Set(trips.map((t) => t.service_id!));
  const dates = serviceDates(await readAll(zip, 'calendar.txt', (c) => sids.has(c.service_id!)), await readAll(zip, 'calendar_dates.txt', (c) => sids.has(c.service_id!)), from, to);
  trips = trips.filter((t) => [...(dates.get(t.service_id!) ?? [])].some((d) => wantedSet.has(ymdToIso(d))));
  const tripIds = new Set(trips.map((t) => t.trip_id!));
  const stopsByTrip = new Map<string, StopRow[]>();
  const used = new Set<string>();
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
    used.add(st.stop_id!);
  }
  log(`Sverige 2 ${snap.ymd}: ${trips.length} rail trips on ${wanted[0]}..${wanted.at(-1)}`);

  // Stations: archive stop ids are rikshållplats ids, which our Swedish stations are keyed by. Unknown ones (closed
  // or renamed stations) are built like the current import's and kept as historical-only.
  const stopRows = new Map<string, Row>();
  for await (const s of readCsv(zip, 'stops.txt')) if (used.has(s.stop_id!) || s.location_type === '1') stopRows.set(s.stop_id!, s);
  const parentOf = (id: string) => stopRows.get(id)?.parent_station || id;
  const existing = new Map(db.all<{ id: string; sig: string | null; kind: string }>(sql`select id, trv_signature as sig, kind from stations`).map((s) => [s.id, s]));
  const bySig = new Map([...existing.values()].filter((s) => s.sig).map((s) => [s.sig!.toLowerCase(), s.id]));
  const stationOf = new Map<string, string>();
  const missing: GtfsParent[] = [];
  for (const id of used) {
    const pid = parentOf(id);
    const riks = riksId(pid);
    if (existing.has(riks)) stationOf.set(id, riks);
    else {
      const p = stopRows.get(pid);
      if (p && !missing.some((m) => m.stopId === pid)) missing.push({ stopId: pid, name: p.stop_name!, lat: Number(p.stop_lat), lon: Number(p.stop_lon), childIds: [], riks });
    }
  }
  const trv: TrvLoc[] = db.select().from(trvLocations).all().map((t) => ({ signature: t.signature, name: t.name, lat: t.lat, lon: t.lon, country: t.country }));
  const built = buildStations(missing, trv, await loadOfficialMapping(opts.fetchImpl), loadStationOverrides());
  const added = built.stations.filter((s) => !(s.trvSignature && bySig.has(s.trvSignature.toLowerCase())));
  const kindOf = new Map([...existing.values()].map((s) => [s.id, s.kind]));
  for (const s of built.stations) kindOf.set(s.id, s.kind);
  for (const m of missing) {
    const sid = built.stationOfParent.get(m.stopId);
    const row = built.stations.find((s) => s.id === sid);
    // Same Trafikverket signature as a current station: it's that station under an older id.
    const id = row?.trvSignature ? (bySig.get(row.trvSignature.toLowerCase()) ?? sid) : sid;
    if (id) for (const u of used) if (parentOf(u) === m.stopId) stationOf.set(u, id);
  }

  const rules = loadCategoryRules();
  const brands = brandIndex(loadBrands());
  // Older feeds name the regional authority as the agency (Skånetrafiken) and the product as the route (Pågatågen).
  const matchBrand = brandMatcher(loadBrands());
  const brandById = new Map(loadBrands().map((b) => [b.id, b]));
  const usedBrands = new Map<string, Brand>();
  const patterns: { key: string; trip: Row; route: Row; number: string | null; brand?: Brand; agency: string; category: string; stops: { station: string; s: StopRow }[]; dates: string[] }[] = [];
  for (const trip of trips) {
    const raw = (stopsByTrip.get(trip.trip_id!) ?? []).sort((a, b) => a[0] - b[0]);
    if (raw.length < 2) continue;
    const stops = raw.map((s) => ({ station: stationOf.get(s[1])!, s }));
    if (stops.some((x) => !x.station)) continue;
    const route = routes.get(trip.route_id!)!;
    const agency = agencies.get(route.agency_id!)?.agency_name ?? '';
    const result = classify(rules, {
      gtfs_route_type: route.route_type!,
      gtfs_operator: agency,
      gtfs_route_short_name: route.route_short_name,
      train_number: trip.trip_short_name || technical.get(trip.trip_id!) || trip.samtrafiken_internal_trip_number || null,
      has_non_rail_stop: stops.some((x) => kindOf.get(x.station) === 'bus_stop'),
      stop_sigs: [],
    });
    if (result.excluded) continue;
    const named = matchBrand(route.route_long_name ?? '') ?? matchBrand(agency);
    const brand = brands.get(agency) ?? (named ? brandById.get(named) : undefined);
    if (brand) usedBrands.set(brand.id, brand);
    const number = trip.trip_short_name || technical.get(trip.trip_id!) || trip.samtrafiken_internal_trip_number || null;
    patterns.push({
      key: historyKey({ number, operator: brand?.id ?? agency, routeType: route.route_type!, category: result.category, routeName: route.route_long_name || route.route_short_name || null, headsign: trip.trip_headsign || null, stops: stops.map((x) => [x.station, x.s[2], x.s[3], x.s[4], x.s[5], platformOf(stopRows.get(x.s[1])), x.s[6]]) }),
      trip,
      route,
      number,
      brand,
      agency,
      category: result.category,
      stops,
      dates: [...dates.get(trip.service_id!)!].map(ymdToIso).filter((d) => wantedSet.has(d)),
    });
  }

  const sqlite = db.$client;
  db.transaction(() => {
    const upsertOperator = sqlite.prepare(
      `insert into operators (id, name, short_name, company, country, brand_color, logo_path) values (?, ?, ?, null, ?, ?, null) on conflict(id) do nothing`,
    );
    for (const b of usedBrands.values()) upsertOperator.run(b.id, b.name, b.short_name, b.country, b.color);
    const insertStation = sqlite.prepare(
      `insert into stations (id, name, country, lat, lon, tz, trv_signature, gtfs_stop_ids, coord_source, historical_only, kind, needs_review)
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, 0) on conflict(id) do nothing`,
    );
    for (const s of added) insertStation.run(s.id, s.name, s.country, s.lat, s.lon, s.tz, s.trvSignature, JSON.stringify(s.gtfsStopIds), s.coordSource, s.kind);
    const insertTrip = sqlite.prepare(
      `insert or ignore into timetable_trips (key, source, trip_id, train_number, operator_id, gtfs_operator, route_name, route_type, category, tz, feed_version, ${TRIP_DETAIL_COLUMNS})
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Europe/Stockholm', ?, ${TRIP_DETAIL_VALUES})`,
    );
    const insertStop = sqlite.prepare(UPSERT_STOP_SQL);
    const insertDate = sqlite.prepare(`insert or ignore into timetable_trip_dates (trip_key, service_date) values (?, ?)`);
    // A partial day left by an earlier import from a later snapshot: its trips come off these dates (the trips stay,
    // for trips already saved against them) before this snapshot's full day goes in.
    const clearDay = sqlite.prepare(`delete from timetable_trip_dates where service_date = ? and trip_key in (select key from timetable_trips where source = ?)`);
    for (const d of wanted) clearDay.run(d, HISTORY_SOURCE);
    for (const p of patterns) {
      insertTrip.run(p.key, HISTORY_SOURCE, p.trip.trip_id, p.number, p.brand?.id ?? null, p.agency, p.route.route_long_name || p.route.route_short_name || null, p.route.route_type, p.category, snap.ymd, ...tripDetailArgs(tripDetail(p.trip, p.route)));
      p.stops.forEach((x, i) => insertStop.run(p.key, i + 1, x.station, x.s[2], x.s[3], x.s[4] ? 1 : 0, x.s[5] ? 1 : 0, platformOf(stopRows.get(x.s[1])), x.s[6]));
      for (const d of p.dates) insertDate.run(p.key, d);
    }
    db.insert(importLog)
      .values({ source: HISTORY_SOURCE, startedAt: new Date(t0), finishedAt: new Date(), status: 'ok', notes: JSON.stringify({ snapshot: snap.ymd, dates: wanted, trips: patterns.length }) })
      .run();
  });
  if (added.length) refreshStationPopularity(db);
  // The backfill keeps disk use down: a snapshot is only needed again for another block from the same snapshot.
  if (opts.keepDownload === false) for (const f of [zip, extra, inner]) fs.rmSync(f, { force: true });
  const summary = { snapshot: snap.ymd, dates: wanted, trips: patterns.length, stationsAdded: added.length, ms: Date.now() - t0 };
  log(`Sverige 2 ${snap.ymd}: ${summary.trips} trips for ${wanted.length} days in ${(summary.ms / 1000).toFixed(1)} s, ${added.length} historical stations added`);
  return summary;
}

/** One archive import at a time; asking again for a date being imported joins that import. */
const inflight = new Map<string, Promise<HistorySummary | null>>();
let queue: Promise<unknown> = Promise.resolve();

export type HistoryState = { state: 'ready' } | { state: 'loading' } | { state: 'failed'; error: string } | { state: 'unavailable' };
const failures = new Map<string, { at: number; error: string }>();

/**
 * Make sure there's a Swedish timetable for `date`, starting an archive import in the background if needed. Returns
 * at once: 'ready', 'loading' (ask again shortly), 'failed' (retried after a minute) or 'unavailable' (before 2012).
 */
export function ensureHistory(db: Db, date: string, opts: { fetchImpl?: typeof fetch; log?: (m: string) => void; now?: number } = {}): HistoryState {
  if (date < ARCHIVE_START) return { state: 'unavailable' };
  if (hasSwedishTimetable(db, date)) return { state: 'ready' };
  // From the current feed's first day on, the archive has nothing to add: a day the current feed lacks (the server
  // was off when it was current) can't be filled, and saying "loading" would ask again for ever.
  if (date >= firstCurrentDay(db)) return { state: 'unavailable' };
  if (inflight.has(date)) return { state: 'loading' };
  const failed = failures.get(date);
  if (failed && (opts.now ?? Date.now()) - failed.at < 60_000) return { state: 'failed', error: failed.error };
  const run = queue.then(() => (hasSwedishTimetable(db, date) ? null : importHistory(db, date, opts)));
  queue = run.catch(() => undefined);
  inflight.set(date, run);
  run
    .then(
      () => failures.delete(date),
      (e) => {
        failures.set(date, { at: Date.now(), error: (e as Error).message });
        opts.log?.(`Sverige 2 for ${date} failed: ${(e as Error).message}`);
      },
    )
    .finally(() => inflight.delete(date));
  return { state: 'loading' };
}
