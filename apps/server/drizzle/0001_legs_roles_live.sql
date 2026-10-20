CREATE TABLE `leg_events` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`leg_id` text NOT NULL,
	`ts` integer NOT NULL,
	`type` text NOT NULL,
	`payload` text DEFAULT '{}' NOT NULL,
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `leg_events_leg` ON `leg_events` (`leg_id`,`ts`);--> statement-breakpoint
CREATE TABLE `live_state` (
	`leg_id` text PRIMARY KEY NOT NULL,
	`updated_at` integer NOT NULL,
	`status` text NOT NULL,
	`lat` real,
	`lon` real,
	`bearing` real,
	`speed_kmh` real,
	`position_source` text,
	`next_stop_id` text,
	`eta` integer,
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
ALTER TABLE `leg_stops` ADD `role` text DEFAULT 'through' NOT NULL;--> statement-breakpoint
ALTER TABLE `leg_stops` ADD `trv_train_number` text;