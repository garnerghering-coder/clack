CREATE TABLE `import_log` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`source` text NOT NULL,
	`started_at` integer NOT NULL,
	`finished_at` integer,
	`status` text NOT NULL,
	`bytes` integer,
	`notes` text
);
--> statement-breakpoint
CREATE TABLE `journeys` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`title` text,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `leg_stops` (
	`leg_id` text NOT NULL,
	`seq` integer NOT NULL,
	`station_id` text NOT NULL,
	`sched_arr` integer,
	`sched_dep` integer,
	`actual_arr` integer,
	`actual_dep` integer,
	`platform` text,
	`canceled` integer DEFAULT false NOT NULL,
	`passed_through` integer DEFAULT false NOT NULL,
	`deviations` text DEFAULT '[]' NOT NULL,
	PRIMARY KEY(`leg_id`, `seq`),
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`station_id`) REFERENCES `stations`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `legs` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`journey_id` text,
	`status` text DEFAULT 'planned' NOT NULL,
	`data_quality` text NOT NULL,
	`country_codes` text DEFAULT '[]' NOT NULL,
	`operator_id` text,
	`train_number` text,
	`trv_train_numbers` text DEFAULT '[]' NOT NULL,
	`category` text,
	`timetable_trip_key` text,
	`service_date` text,
	`origin_station_id` text NOT NULL,
	`dest_station_id` text NOT NULL,
	`sched_dep` integer,
	`sched_arr` integer,
	`actual_dep` integer,
	`actual_arr` integer,
	`dep_delay_min` integer,
	`arr_delay_min` integer,
	`dep_platform` text,
	`arr_platform` text,
	`canceled` integer DEFAULT false NOT NULL,
	`distance_m` real,
	`geometry` text,
	`is_estimated_geometry` integer DEFAULT false NOT NULL,
	`notes` text,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`journey_id`) REFERENCES `journeys`(`id`) ON UPDATE no action ON DELETE set null,
	FOREIGN KEY (`operator_id`) REFERENCES `operators`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`origin_station_id`) REFERENCES `stations`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`dest_station_id`) REFERENCES `stations`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `legs_user_dep` ON `legs` (`user_id`,`sched_dep`);--> statement-breakpoint
CREATE TABLE `operators` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`short_name` text NOT NULL,
	`company` text,
	`country` text NOT NULL,
	`brand_color` text NOT NULL,
	`logo_path` text
);
--> statement-breakpoint
CREATE TABLE `stations` (
	`id` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`country` text NOT NULL,
	`lat` real NOT NULL,
	`lon` real NOT NULL,
	`tz` text NOT NULL,
	`trv_signature` text,
	`gtfs_stop_ids` text DEFAULT '[]' NOT NULL,
	`coord_source` text DEFAULT 'gtfs' NOT NULL,
	`historical_only` integer DEFAULT false NOT NULL,
	`kind` text DEFAULT 'rail_station' NOT NULL,
	`departures_per_day` real DEFAULT 0 NOT NULL,
	`needs_review` integer DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE `timetable_stop_times` (
	`trip_key` text NOT NULL,
	`seq` integer NOT NULL,
	`station_id` text NOT NULL,
	`arr_sec` integer,
	`dep_sec` integer,
	`no_pickup` integer DEFAULT false NOT NULL,
	`no_dropoff` integer DEFAULT false NOT NULL,
	PRIMARY KEY(`trip_key`, `seq`),
	FOREIGN KEY (`trip_key`) REFERENCES `timetable_trips`(`key`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`station_id`) REFERENCES `stations`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `stop_times_station` ON `timetable_stop_times` (`station_id`);--> statement-breakpoint
CREATE TABLE `timetable_trip_dates` (
	`trip_key` text NOT NULL,
	`service_date` text NOT NULL,
	PRIMARY KEY(`trip_key`, `service_date`),
	FOREIGN KEY (`trip_key`) REFERENCES `timetable_trips`(`key`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `trip_dates_date` ON `timetable_trip_dates` (`service_date`);--> statement-breakpoint
CREATE TABLE `timetable_trips` (
	`key` text PRIMARY KEY NOT NULL,
	`source` text NOT NULL,
	`trip_id` text NOT NULL,
	`train_number` text,
	`operator_id` text,
	`gtfs_operator` text,
	`route_name` text,
	`route_type` text NOT NULL,
	`category` text NOT NULL,
	`tz` text NOT NULL,
	`feed_version` text,
	FOREIGN KEY (`operator_id`) REFERENCES `operators`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `timetable_trips_number` ON `timetable_trips` (`train_number`);--> statement-breakpoint
CREATE TABLE `track_segments` (
	`from_station_id` text NOT NULL,
	`to_station_id` text NOT NULL,
	`geometry` text NOT NULL,
	`length_m` real NOT NULL,
	`is_estimated` integer DEFAULT false NOT NULL,
	PRIMARY KEY(`from_station_id`, `to_station_id`)
);
--> statement-breakpoint
CREATE TABLE `trv_locations` (
	`signature` text PRIMARY KEY NOT NULL,
	`name` text NOT NULL,
	`short_name` text,
	`official_name` text,
	`country` text NOT NULL,
	`lat` real,
	`lon` real,
	`advertised` integer NOT NULL,
	`modified_at` integer
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` text PRIMARY KEY NOT NULL,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	`settings` text NOT NULL
);
