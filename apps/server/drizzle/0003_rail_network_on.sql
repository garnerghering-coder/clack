-- Owner asked (2026-10-21) for every map to show the rail network dimmed under the route by default.
UPDATE `users` SET `settings` = json_set(`settings`, '$.showRailNetwork', json('true'));
