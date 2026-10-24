ALTER TABLE `devices` ADD `widget_token` text;--> statement-breakpoint
ALTER TABLE `live_activities` ADD `device_token` text;--> statement-breakpoint
CREATE INDEX `live_activities_device` ON `live_activities` (`device_token`);