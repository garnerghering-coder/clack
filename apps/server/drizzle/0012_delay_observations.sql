CREATE TABLE `delay_observations` (
	`train_number` text NOT NULL,
	`signature` text NOT NULL,
	`service_date` text NOT NULL,
	`advertised` integer NOT NULL,
	`delay_min` integer,
	`canceled` integer DEFAULT false NOT NULL,
	PRIMARY KEY(`train_number`, `signature`, `service_date`)
);
