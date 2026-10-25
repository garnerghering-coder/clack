CREATE TABLE `diagnostics` (
	`day` text NOT NULL,
	`build` text NOT NULL,
	`kind` text NOT NULL,
	`signature` text NOT NULL,
	`count` integer DEFAULT 0 NOT NULL,
	PRIMARY KEY(`day`, `build`, `kind`, `signature`)
);
--> statement-breakpoint
CREATE TABLE `usage_counts` (
	`day` text NOT NULL,
	`kind` text NOT NULL,
	`name` text NOT NULL,
	`count` integer DEFAULT 0 NOT NULL,
	PRIMARY KEY(`day`, `kind`, `name`)
);
