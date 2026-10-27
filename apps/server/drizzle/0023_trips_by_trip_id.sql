-- Looking a trip up by its GTFS trip id (Denmark's archive days match on it) scanned the whole table, once per trip;
-- on the server that held the event loop for about 2 minutes per day (2026-10-27).
CREATE INDEX `timetable_trips_source_trip` ON `timetable_trips` (`source`,`trip_id`);