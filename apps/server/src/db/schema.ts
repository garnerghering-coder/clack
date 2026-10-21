// Database schema (SQLite now; kept to types that map cleanly to Postgres for later hosting).
// Timestamps are UTC epoch milliseconds. Each station keeps its IANA time zone for display.
// User-owned rows always carry user_id so the app is multi-user ready.
import { sql } from 'drizzle-orm';
import { index, integer, primaryKey, real, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import type { OnboardFacts } from '@clack/shared';

const timestamp = (name: string) => integer(name, { mode: 'timestamp_ms' });
const createdAt = () => timestamp('created_at').notNull().default(sql`(unixepoch() * 1000)`);

// ---------- Reference data (from imports) ----------

/** Keyed by rikshållplats id (national stop id), which Phase 0 found stable from 2012 to today. */
export const stations = sqliteTable('stations', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  country: text('country').notNull(),
  lat: real('lat').notNull(),
  lon: real('lon').notNull(),
  tz: text('tz').notNull(),
  /** Trafikverket LocationSignature, e.g. "Cst". Null for stations Trafikverket doesn't know. */
  trvSignature: text('trv_signature'),
  /** JSON array of GTFS Sweden 3 stop ids (parent station + platforms). */
  gtfsStopIds: text('gtfs_stop_ids', { mode: 'json' }).$type<string[]>().notNull().default(sql`'[]'`),
  /** Where lat/lon came from: gtfs | trafikverket (used when GTFS is off the track) | archive. */
  coordSource: text('coord_source').notNull().default('gtfs'),
  /** Only seen in historical (Sverige 2) timetables, e.g. closed stations. */
  historicalOnly: integer('historical_only', { mode: 'boolean' }).notNull().default(false),
  /** rail_station | bus_stop (a bus stop inside a "rail" trip; such trips are excluded). */
  kind: text('kind').notNull().default('rail_station'),
  /** Average scheduled rail departures per day over the import window; ranks search results. */
  departuresPerDay: real('departures_per_day').notNull().default(0),
  /** Flagged by the import for a human to check (spec §8.4). */
  needsReview: integer('needs_review', { mode: 'boolean' }).notNull().default(false),
});

/** One row per brand (Öresundståg, Pågatåg, SJ …); the operating company is secondary. */
export const operators = sqliteTable('operators', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  shortName: text('short_name').notNull(),
  company: text('company'),
  country: text('country').notNull(),
  brandColor: text('brand_color').notNull(),
  logoPath: text('logo_path'),
});

/**
 * One row per distinct GTFS trip pattern. Keyed by `${source}:${trip_id}:${hash of stops+times}`, so a trip whose
 * timetable changes in a later feed gets a new key and past dates keep the times they actually had.
 */
export const timetableTrips = sqliteTable(
  'timetable_trips',
  {
    key: text('key').primaryKey(),
    source: text('source').notNull(), // gtfs_se3 | gtfs_sv2
    tripId: text('trip_id').notNull(),
    trainNumber: text('train_number'),
    operatorId: text('operator_id').references(() => operators.id),
    /** Operator name as given in GTFS (attributions.txt), kept for reference. */
    gtfsOperator: text('gtfs_operator'),
    routeName: text('route_name'),
    routeType: text('route_type').notNull(),
    category: text('category').notNull(),
    /** Agency time zone the stop times are relative to. */
    tz: text('tz').notNull(),
    feedVersion: text('feed_version'),
  },
  (t) => [index('timetable_trips_number').on(t.trainNumber)],
);

/** The service dates each trip pattern runs on. Past dates are never deleted on import. */
export const timetableTripDates = sqliteTable(
  'timetable_trip_dates',
  {
    tripKey: text('trip_key').notNull().references(() => timetableTrips.key, { onDelete: 'cascade' }),
    serviceDate: text('service_date').notNull(), // YYYY-MM-DD
  },
  (t) => [primaryKey({ columns: [t.tripKey, t.serviceDate] }), index('trip_dates_date').on(t.serviceDate)],
);

/** Times are seconds after "noon minus 12h" of the service day (GTFS semantics, may exceed 24h). */
export const timetableStopTimes = sqliteTable(
  'timetable_stop_times',
  {
    tripKey: text('trip_key').notNull().references(() => timetableTrips.key, { onDelete: 'cascade' }),
    seq: integer('seq').notNull(),
    stationId: text('station_id').notNull().references(() => stations.id),
    arrSec: integer('arr_sec'),
    depSec: integer('dep_sec'),
    /** GTFS pickup_type/drop_off_type = 1: boarding/alighting not allowed here. */
    noPickup: integer('no_pickup', { mode: 'boolean' }).notNull().default(false),
    noDropoff: integer('no_dropoff', { mode: 'boolean' }).notNull().default(false),
  },
  (t) => [primaryKey({ columns: [t.tripKey, t.seq] }), index('stop_times_station').on(t.stationId)],
);

/** Trafikverket TrainStation locations (refreshed weekly). */
export const trvLocations = sqliteTable('trv_locations', {
  signature: text('signature').primaryKey(),
  name: text('name').notNull(),
  shortName: text('short_name'),
  officialName: text('official_name'),
  country: text('country').notNull(),
  lat: real('lat'),
  lon: real('lon'),
  advertised: integer('advertised', { mode: 'boolean' }).notNull(),
  /** Swedish county (län) number from TrainStation.CountyNo, first listed. */
  countyNo: integer('county_no'),
  /** Distinct base tracks in TrainStation.PlatformLine ("1", "2a", "2b" = 2): the station's size class for walks without a map. */
  baseTracks: integer('base_tracks'),
  modifiedAt: timestamp('modified_at'),
});

/** Routed track geometry per station pair (stored with from < to). */
export const trackSegments = sqliteTable(
  'track_segments',
  {
    fromStationId: text('from_station_id').notNull(),
    toStationId: text('to_station_id').notNull(),
    /** Encoded polyline (precision 5). */
    geometry: text('geometry').notNull(),
    lengthM: real('length_m').notNull(),
    isEstimated: integer('is_estimated', { mode: 'boolean' }).notNull().default(false),
  },
  (t) => [primaryKey({ columns: [t.fromStationId, t.toStationId] })],
);

/** Every download from a quota-limited source, plus each import run. */
export const importLog = sqliteTable('import_log', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  source: text('source').notNull(),
  startedAt: timestamp('started_at').notNull(),
  finishedAt: timestamp('finished_at'),
  status: text('status').notNull(), // ok | failed | skipped
  bytes: integer('bytes'),
  notes: text('notes'),
});

// ---------- User data ----------

export const users = sqliteTable('users', {
  id: text('id').primaryKey(),
  createdAt: createdAt(),
  /** JSON Settings (see @clack/shared). */
  settings: text('settings', { mode: 'json' }).notNull(),
});

export const journeys = sqliteTable('journeys', {
  id: text('id').primaryKey(),
  userId: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  title: text('title'),
  createdAt: createdAt(),
});

export const legs = sqliteTable(
  'legs',
  {
    id: text('id').primaryKey(),
    userId: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
    journeyId: text('journey_id').references(() => journeys.id, { onDelete: 'set null' }),
    status: text('status').notNull().default('planned'),
    dataQuality: text('data_quality').notNull(),
    countryCodes: text('country_codes', { mode: 'json' }).$type<string[]>().notNull().default(sql`'[]'`),
    operatorId: text('operator_id').references(() => operators.id),
    trainNumber: text('train_number'),
    /** Trafikverket train numbers actually matched; numbers can change mid-journey (Phase 0). */
    trvTrainNumbers: text('trv_train_numbers', { mode: 'json' }).$type<string[]>().notNull().default(sql`'[]'`),
    category: text('category'),
    timetableTripKey: text('timetable_trip_key'),
    serviceDate: text('service_date'),
    originStationId: text('origin_station_id').notNull().references(() => stations.id),
    destStationId: text('dest_station_id').notNull().references(() => stations.id),
    schedDep: timestamp('sched_dep'),
    schedArr: timestamp('sched_arr'),
    actualDep: timestamp('actual_dep'),
    actualArr: timestamp('actual_arr'),
    depDelayMin: integer('dep_delay_min'),
    arrDelayMin: integer('arr_delay_min'),
    depPlatform: text('dep_platform'),
    arrPlatform: text('arr_platform'),
    canceled: integer('canceled', { mode: 'boolean' }).notNull().default(false),
    distanceM: real('distance_m'),
    /** Encoded polyline of the whole leg. */
    geometry: text('geometry'),
    isEstimatedGeometry: integer('is_estimated_geometry', { mode: 'boolean' }).notNull().default(false),
    /** Rolling stock id from data/train_types.json. */
    trainType: text('train_type'),
    /** typical (guessed from operator/product) | composition (Trafikverket's planned coach order) | user (the owner's choice) */
    trainTypeSource: text('train_type_source'),
    /** Trafikverket's on-board facts for the departure where you boarded (catering, day-of notices). */
    onboard: text('onboard', { mode: 'json' }).$type<OnboardFacts>(),
    notes: text('notes'),
    createdAt: createdAt(),
  },
  (t) => [index('legs_user_dep').on(t.userId, t.schedDep)],
);

export const legStops = sqliteTable(
  'leg_stops',
  {
    legId: text('leg_id').notNull().references(() => legs.id, { onDelete: 'cascade' }),
    seq: integer('seq').notNull(),
    stationId: text('station_id').notNull().references(() => stations.id),
    schedArr: timestamp('sched_arr'),
    schedDep: timestamp('sched_dep'),
    actualArr: timestamp('actual_arr'),
    actualDep: timestamp('actual_dep'),
    /** Trafikverket's live estimate while the train runs (cleared once an actual time exists). */
    estimatedArr: timestamp('estimated_arr'),
    estimatedDep: timestamp('estimated_dep'),
    platform: text('platform'),
    canceled: integer('canceled', { mode: 'boolean' }).notNull().default(false),
    /** Stops between origin and destination. */
    passedThrough: integer('passed_through', { mode: 'boolean' }).notNull().default(false),
    /** before | board | through | alight | after: the whole trip is kept so the timeline can show the full route. */
    role: text('role').notNull().default('through'),
    /** Trafikverket train number that matched this stop (numbers can change mid-journey). */
    trvTrainNumber: text('trv_train_number'),
    /** JSON array of Trafikverket deviation texts shown as notices / delay reasons. */
    deviations: text('deviations', { mode: 'json' }).$type<string[]>().notNull().default(sql`'[]'`),
  },
  (t) => [primaryKey({ columns: [t.legId, t.seq] })],
);

/** Things that happened to a leg (SPEC §7, DESIGN §9.3). Payload is JSON so push notifications can reuse it later. */
export const legEvents = sqliteTable(
  'leg_events',
  {
    id: integer('id').primaryKey({ autoIncrement: true }),
    legId: text('leg_id').notNull().references(() => legs.id, { onDelete: 'cascade' }),
    ts: timestamp('ts').notNull(),
    // delayed | platform_changed | cancelled | short_turned | departed | arrived
    type: text('type').notNull(),
    payload: text('payload', { mode: 'json' }).$type<Record<string, unknown>>().notNull().default(sql`'{}'`),
  },
  (t) => [index('leg_events_leg').on(t.legId, t.ts)],
);

/** Latest live view of a tracked leg (SPEC §7). */
export const liveState = sqliteTable('live_state', {
  legId: text('leg_id').primaryKey().references(() => legs.id, { onDelete: 'cascade' }),
  updatedAt: timestamp('updated_at').notNull(),
  status: text('status').notNull(),
  lat: real('lat'),
  lon: real('lon'),
  bearing: real('bearing'),
  speedKmh: real('speed_kmh'),
  /** gps | estimated */
  positionSource: text('position_source'),
  /** When the GPS fix was taken (Trafikverket TimeStamp); null for estimates. */
  positionAt: timestamp('position_at'),
  /** Share of the ridden route travelled, 0–1 (splits the map line and fills the progress bar). */
  progress: real('progress'),
  prevStopId: text('prev_stop_id'),
  nextStopId: text('next_stop_id'),
  /** Expected time at the next stop. */
  eta: timestamp('eta'),
  /** Expected arrival where you get off. */
  arrivalEta: timestamp('arrival_eta'),
  arrivalDelayMin: integer('arrival_delay_min'),
});

// ---------- Stations (ADDITIONS_01) ----------

export const stationFavorites = sqliteTable(
  'station_favorites',
  {
    userId: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
    stationId: text('station_id').notNull().references(() => stations.id),
    createdAt: createdAt(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.stationId] })],
);

export const stationRecent = sqliteTable(
  'station_recent',
  {
    userId: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
    stationId: text('station_id').notNull().references(() => stations.id),
    lastViewed: timestamp('last_viewed').notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.stationId] })],
);

/** "I'd like a map of this station" — counts demand for station maps (ADDITIONS_01 C). */
export const stationRequests = sqliteTable('station_requests', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  userId: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  stationId: text('station_id').notNull().references(() => stations.id),
  createdAt: createdAt(),
});
