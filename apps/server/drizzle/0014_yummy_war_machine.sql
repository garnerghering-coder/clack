CREATE TABLE `devices` (
	`token` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`environment` text NOT NULL,
	`start_token` text,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	`last_seen_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `devices_user` ON `devices` (`user_id`);--> statement-breakpoint
CREATE TABLE `live_activities` (
	`token` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`leg_id` text NOT NULL,
	`environment` text NOT NULL,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `live_activities_leg` ON `live_activities` (`leg_id`);--> statement-breakpoint
CREATE TABLE `push_log` (
	`leg_id` text NOT NULL,
	`kind` text NOT NULL,
	`key` text DEFAULT '' NOT NULL,
	`sent_at` integer NOT NULL,
	PRIMARY KEY(`leg_id`, `kind`, `key`),
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade
);
