CREATE TABLE `leg_reports` (
	`id` text PRIMARY KEY NOT NULL,
	`leg_id` text NOT NULL,
	`user_id` text NOT NULL,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	`note` text,
	`shown` text,
	`server_state` text,
	FOREIGN KEY (`leg_id`) REFERENCES `legs`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `leg_reports_leg` ON `leg_reports` (`leg_id`,`created_at`);