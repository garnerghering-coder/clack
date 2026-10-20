ALTER TABLE `leg_stops` ADD `estimated_arr` integer;--> statement-breakpoint
ALTER TABLE `leg_stops` ADD `estimated_dep` integer;--> statement-breakpoint
ALTER TABLE `live_state` ADD `position_at` integer;--> statement-breakpoint
ALTER TABLE `live_state` ADD `progress` real;--> statement-breakpoint
ALTER TABLE `live_state` ADD `prev_stop_id` text;--> statement-breakpoint
ALTER TABLE `live_state` ADD `arrival_eta` integer;--> statement-breakpoint
ALTER TABLE `live_state` ADD `arrival_delay_min` integer;