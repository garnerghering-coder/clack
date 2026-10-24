ALTER TABLE `leg_stops` ADD `causes` text;--> statement-breakpoint
ALTER TABLE `stations` ADD `fi_id` text;--> statement-breakpoint
ALTER TABLE `stations` ADD `fi_uic` integer;--> statement-breakpoint
CREATE UNIQUE INDEX `stations_fi_id` ON `stations` (`fi_id`) WHERE "stations"."fi_id" is not null;