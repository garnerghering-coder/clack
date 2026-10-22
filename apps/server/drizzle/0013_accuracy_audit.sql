CREATE TABLE `leg_audits` (
	`leg_id` text PRIMARY KEY NOT NULL,
	`audited_at` integer NOT NULL,
	`result` text NOT NULL,
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `live_quality` (
	`leg_id` text PRIMARY KEY NOT NULL,
	`ticks` integer DEFAULT 0 NOT NULL,
	`gps_ticks` integer DEFAULT 0 NOT NULL,
	`estimated_ticks` integer DEFAULT 0 NOT NULL,
	`failed_ticks` integer DEFAULT 0 NOT NULL,
	`rejected_fixes` integer DEFAULT 0 NOT NULL,
	`first_at` integer,
	`last_at` integer,
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `shown_values` (
	`leg_id` text NOT NULL,
	`seq` integer NOT NULL,
	`field` text NOT NULL,
	`value` text,
	`shown_at` integer NOT NULL,
	PRIMARY KEY(`leg_id`, `seq`, `field`, `shown_at`),
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
ALTER TABLE `live_state` ADD `reported_at` integer;