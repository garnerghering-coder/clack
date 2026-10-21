CREATE TABLE `followed_trains` (
	`user_id` text NOT NULL,
	`train_number` text NOT NULL,
	`service_date` text NOT NULL,
	`operator_id` text,
	`label` text,
	`created_at` integer DEFAULT (unixepoch() * 1000) NOT NULL,
	PRIMARY KEY(`user_id`, `train_number`, `service_date`),
	FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
