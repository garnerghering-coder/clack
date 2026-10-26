-- Fields the imports used to drop (planned platform, headsigns, line, colour, accessibility), and the two biggest
-- timetable tables rebuilt as WITHOUT ROWID (by hand; Drizzle's schema can't say it). Their rows are small, so the
-- primary key can be the table, and SQLite no longer keeps a second full copy of every row as an index (measured
-- 2026-10-26: the primary-key copies were 51 MB and 34 MB next to tables of 61 MB and 30 MB).
ALTER TABLE `timetable_trips` ADD `headsign` text;--> statement-breakpoint
ALTER TABLE `timetable_trips` ADD `line` text;--> statement-breakpoint
ALTER TABLE `timetable_trips` ADD `route_color` text;--> statement-breakpoint
ALTER TABLE `timetable_trips` ADD `wheelchair` integer;--> statement-breakpoint
ALTER TABLE `timetable_trips` ADD `bikes` integer;--> statement-breakpoint
CREATE TABLE `timetable_stop_times_new` (
	`trip_key` text NOT NULL,
	`seq` integer NOT NULL,
	`station_id` text NOT NULL,
	`arr_sec` integer,
	`dep_sec` integer,
	`no_pickup` integer DEFAULT false NOT NULL,
	`no_dropoff` integer DEFAULT false NOT NULL,
	`platform` text,
	`headsign` text,
	PRIMARY KEY(`trip_key`, `seq`),
	FOREIGN KEY (`trip_key`) REFERENCES `timetable_trips`(`key`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`station_id`) REFERENCES `stations`(`id`) ON UPDATE no action ON DELETE no action
) WITHOUT ROWID;--> statement-breakpoint
INSERT INTO `timetable_stop_times_new` (`trip_key`, `seq`, `station_id`, `arr_sec`, `dep_sec`, `no_pickup`, `no_dropoff`)
	SELECT `trip_key`, `seq`, `station_id`, `arr_sec`, `dep_sec`, `no_pickup`, `no_dropoff` FROM `timetable_stop_times`;--> statement-breakpoint
DROP TABLE `timetable_stop_times`;--> statement-breakpoint
ALTER TABLE `timetable_stop_times_new` RENAME TO `timetable_stop_times`;--> statement-breakpoint
CREATE INDEX `stop_times_station` ON `timetable_stop_times` (`station_id`);--> statement-breakpoint
CREATE TABLE `timetable_trip_dates_new` (
	`trip_key` text NOT NULL,
	`service_date` text NOT NULL,
	PRIMARY KEY(`trip_key`, `service_date`),
	FOREIGN KEY (`trip_key`) REFERENCES `timetable_trips`(`key`) ON UPDATE no action ON DELETE cascade
) WITHOUT ROWID;--> statement-breakpoint
INSERT INTO `timetable_trip_dates_new` SELECT `trip_key`, `service_date` FROM `timetable_trip_dates`;--> statement-breakpoint
DROP TABLE `timetable_trip_dates`;--> statement-breakpoint
ALTER TABLE `timetable_trip_dates_new` RENAME TO `timetable_trip_dates`;--> statement-breakpoint
CREATE INDEX `trip_dates_date` ON `timetable_trip_dates` (`service_date`);
