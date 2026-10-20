// Database schema (SQLite now; kept to types that map cleanly to Postgres for later hosting).
// Timestamps are UTC epoch milliseconds. Each station keeps its IANA time zone for display.
// User-owned rows always carry user_id so the app is multi-user ready.
import { sql } from 'drizzle-orm';
import { index, integer, primaryKey, real, sqliteTable, text } from 'drizzle-orm/sqlite-core';

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

export const timetableTrips = sqliteTable(
  'timetable_trips',
  {
    /** `${source}:${tripId}:${serviceDate}` */
    id: text('id').primaryKey(),
    source: text('source').notNull(), // gtfs_se3 | gtfs_sv2
    tripId: text('trip_id').notNull(),
    serviceDate: text('service_date').notNull(), // YYYY-MM-DD
    trainNumber: text('train_number'),
    operatorId: text('operator_id').references(() => operators.id),
    routeName: text('route_name'),
    category: text('category').notNull(),
  },
  (t) => [index('timetable_trips_date_number').on(t.serviceDate, t.trainNumber)],
);

export const timetableStopTimes = sqliteTable(
  'timetable_stop_times',
  {
    tripKey: text('trip_key').notNull().references(() => timetableTrips.id, { onDelete: 'cascade' }),
    seq: integer('seq').notNull(),
    stationId: text('station_id').notNull().references(() => stations.id),
    schedArr: timestamp('sched_arr'),
    schedDep: timestamp('sched_dep'),
    /** GTFS pickup_type/drop_off_type = 1: boarding/alighting not allowed here. */
    noPickup: integer('no_pickup', { mode: 'boolean' }).notNull().default(false),
    noDropoff: integer('no_dropoff', { mode: 'boolean' }).notNull().default(false),
  },
  (t) => [primaryKey({ columns: [t.tripKey, t.seq] }), index('stop_times_station').on(t.stationId, t.schedDep)],
);

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
    platform: text('platform'),
    canceled: integer('canceled', { mode: 'boolean' }).notNull().default(false),
    /** Stops between origin and destination. */
    passedThrough: integer('passed_through', { mode: 'boolean' }).notNull().default(false),
    /** JSON array of Trafikverket deviation texts shown as notices / delay reasons. */
    deviations: text('deviations', { mode: 'json' }).$type<string[]>().notNull().default(sql`'[]'`),
  },
  (t) => [primaryKey({ columns: [t.legId, t.seq] })],
);
