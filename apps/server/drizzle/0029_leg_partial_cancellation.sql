ALTER TABLE `leg_stops` ADD `arr_canceled` integer;--> statement-breakpoint
ALTER TABLE `leg_stops` ADD `dep_canceled` integer;--> statement-breakpoint
ALTER TABLE `legs` ADD `cancellation` text;