-- observed_fetches is WITHOUT ROWID (added by hand; Drizzle's schema can't say it): small rows, so the primary key can
-- be the table. observed_runs and observed_calls stay ordinary tables: their rows are a few hundred bytes, and SQLite
-- advises WITHOUT ROWID only for rows under about 1/20 of a page (measured 2026-10-26: it made a day of Swedish runs 2.4x larger).
CREATE TABLE `observed_calls` (
	`country` text NOT NULL,
	`service_date` text NOT NULL,
	`run_id` text NOT NULL,
	`seq` integer NOT NULL,
	`location` text NOT NULL,
	`station_id` text,
	`sched_arr` integer,
	`sched_dep` integer,
	`est_arr` integer,
	`est_dep` integer,
	`actual_arr` integer,
	`actual_dep` integer,
	`platform` text,
	`canceled_arr` integer DEFAULT false NOT NULL,
	`canceled_dep` integer DEFAULT false NOT NULL,
	`causes` text DEFAULT '[]' NOT NULL,
	`extra` text DEFAULT '{}' NOT NULL,
	PRIMARY KEY(`country`, `service_date`, `run_id`, `seq`)
);
--> statement-breakpoint
CREATE INDEX `observed_calls_station` ON `observed_calls` (`station_id`,`service_date`);--> statement-breakpoint
CREATE TABLE `observed_fetches` (
	`source` text NOT NULL,
	`kind` text NOT NULL,
	`date` text NOT NULL,
	`fetched_at` integer NOT NULL,
	`records` integer NOT NULL,
	`runs` integer DEFAULT 0 NOT NULL,
	`file` text NOT NULL,
	`final` integer DEFAULT false NOT NULL,
	PRIMARY KEY(`source`, `kind`, `date`)
) WITHOUT ROWID;
--> statement-breakpoint
CREATE TABLE `observed_runs` (
	`country` text NOT NULL,
	`service_date` text NOT NULL,
	`run_id` text NOT NULL,
	`train_number` text,
	`source` text NOT NULL,
	`operator` text,
	`product` text,
	`canceled` integer DEFAULT 0 NOT NULL,
	`origin_location` text,
	`dest_location` text,
	`sched_dep` integer,
	`sched_arr` integer,
	`actual_dep` integer,
	`actual_arr` integer,
	`arr_delay_sec` integer,
	`info` text DEFAULT '{}' NOT NULL,
	`passages` text DEFAULT '[]' NOT NULL,
	`fetched_at` integer NOT NULL,
	`final` integer DEFAULT false NOT NULL,
	PRIMARY KEY(`country`, `service_date`, `run_id`)
);
--> statement-breakpoint
CREATE INDEX `observed_runs_number` ON `observed_runs` (`train_number`,`service_date`);