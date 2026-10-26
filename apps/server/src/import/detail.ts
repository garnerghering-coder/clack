// The GTFS fields every timetable import keeps besides times and stops (they used to be dropped): the planned
// platform of each stop, headsigns, the line's short name and colour, and wheelchair/bike flags. One place for the
// SQL so the four imports (Sweden 3, Sverige 2, Norway, Finland) write them the same way.
//
// Checked 2026-10-26: Sweden 3 gives platform_code on 119,393 of 179,551 stops (no headsigns, no accessibility);
// Entur gives quay platform codes, trip headsigns and route colours; Digitraffic gives platform codes on 467 of 1,306
// stops, headsigns and bikes_allowed. A field a feed doesn't give stays null: nothing is guessed.
import type { Row } from '../lib/zip.js';

/** GTFS wheelchair_accessible / bikes_allowed: 1 yes, 2 no; 0 or empty is "not stated" (null). */
export const gtfsFlag = (v: string | undefined): 1 | 2 | null => (v === '1' ? 1 : v === '2' ? 2 : null);

export interface TripDetail {
  headsign: string | null;
  line: string | null;
  routeColor: string | null;
  wheelchair: 1 | 2 | null;
  bikes: 1 | 2 | null;
}

export function tripDetail(trip: Row, route: Row, line?: string | null): TripDetail {
  return {
    headsign: trip.trip_headsign || null,
    line: line !== undefined ? line : route.route_short_name || null,
    routeColor: route.route_color || null,
    wheelchair: gtfsFlag(trip.wheelchair_accessible),
    bikes: gtfsFlag(trip.bikes_allowed),
  };
}

/** A stop's planned platform: its own platform_code (a platform or quay under the station), else null. */
export const platformOf = (stop: Row | undefined): string | null => stop?.platform_code || null;

/** Columns and placeholders added to each import's timetable_trips insert; updated on conflict too. */
export const TRIP_DETAIL_COLUMNS = 'headsign, line, route_color, wheelchair, bikes';
export const TRIP_DETAIL_VALUES = '?, ?, ?, ?, ?';
export const TRIP_DETAIL_UPDATE = 'headsign = excluded.headsign, line = excluded.line, route_color = excluded.route_color, wheelchair = excluded.wheelchair, bikes = excluded.bikes';
export const tripDetailArgs = (d: TripDetail) => [d.headsign, d.line, d.routeColor, d.wheelchair, d.bikes] as const;

/**
 * The stop-time insert. A stop already stored for the same trip key gets the newest flags, platform and headsign:
 * the key covers the times, not these, and `insert or ignore` used to keep the first feed's flags for good.
 */
export const UPSERT_STOP_SQL = `insert into timetable_stop_times (trip_key, seq, station_id, arr_sec, dep_sec, no_pickup, no_dropoff, platform, headsign)
  values (?, ?, ?, ?, ?, ?, ?, ?, ?)
  on conflict (trip_key, seq) do update set no_pickup = excluded.no_pickup, no_dropoff = excluded.no_dropoff,
    platform = excluded.platform, headsign = excluded.headsign`;
