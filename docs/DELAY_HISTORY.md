# Delay history: how a train usually runs, and the history-aware change verdict

Built 2026-10-29 (BUILDOUT O4). The observed record (SPEC §5.6: `observed_runs`, `observed_calls`, every passenger
train in Sweden, Norway, Finland and Denmark since the recorder started) now answers two questions in the app, with
nothing predicted: counts and quantiles of what happened on earlier days, always with the number of days behind them.

## What is computed

`apps/server/src/stats/punctuality.ts`, `punctuality(db, { trainNumber, stationId, before, days = 28, event })`:

- The window is the 28 service dates before the leg's date (both ends inclusive, the leg's own day excluded).
- One call per day: the first `observed_calls` row for that train number at that station on that date (a train that
  calls twice counts its first call).
- The delay is `actual − scheduled` in whole minutes, never below 0 (an early train is 0). Arrivals by default; the
  departure when asked (the risk card's boarding station) or when the call has no scheduled arrival (a first stop).
- A cancelled run or call counts as a late day and is left out of the minutes.
- A day without an actual time (not yet reported, or never) is left out entirely.
- Late is 5 minutes or more, the same threshold the risk card's pattern rule has used since 2026-10-22.
- Quantiles are nearest-rank (the value at position ⌈q·n⌉): median, 80th percentile, and the quartiles as the
  "usual" band. Answers are cached for an hour per train, station, date, window and event.

## Where it shows

- **The train leg** (trip detail, Train card): "Usually 15–20 min late at Alvesta, 19 of 28 days" (the quartiles,
  the late days, the days with data) or "Usually on time at X: 24 of 28 days within 5 min" when the third quartile is
  under 5 min. Silent under 4 days. The server sends it as `arrivalHistory` on every leg (the train's arrival at the
  leg's last stop).
- **The change verdict** (`packages/shared/src/changes.ts` `comfortWithHistory`, ClackCore `ChangeRule.comfort(gapMin:minMin:typicalLateMin:)`,
  the same test cases on both sides): the incoming train's usual lateness at the change station, its 80th percentile
  arrival delay over the window, is taken off the gap before the plain rule judges it. Only with 7 or more days of
  record (`HISTORY_MIN_DAYS`); with fewer the plain rule stands. The planner applies it to the journeys left after
  ranking and drops a journey whose change becomes risky; a saved journey's changes and the app's own judge use the
  figure the server sends. The change line says "Allows N min for this train's usual lateness here".
- **The risk card** (`legs/risk.ts`): the past-pattern warning now reads the observed record for every country
  (departures from the boarding station, 28 days; the same rule: 4+ days, most of them late, median 5+ min). The
  Swedish board record (`delay_observations`) remains the fallback when the observed record has under 4 days.

## Sample check (hosted database, read 2026-10-29, window 2026-10-01 … 2026-10-28)

Figures computed from the raw rows by hand with the rules above; the code's tests
(`apps/server/test/punctuality.test.ts`) use the same arithmetic on a made-up record.

| Train, station | Days | Late (≥5) | Cancelled | Median | p80 | Usual band | What the app says |
|---|---|---|---|---|---|---|---|
| VR IC 27 at Tampere (`fi:TPE`), arrival | 28 | 18 | 0 | 8 | 13 | 2–11 | Usually 2–11 min late at Tampere, 18 of 28 days; a change here allows 13 min |
| Vy 234 at Movatn (`NSR:StopPlace:218`), arrival | 28 | 11 | 3 | 4 | 7 | 2–5 | Usually 2–5 min late at Movatn, 11 of 28 days; a change allows 7 min |
| DSB 4283 at København H (`860000626`), arrival | 12 | 2 | 0 | 0 | 3 | 0–1 | Usually on time at København H: 10 of 12 days within 5 min; a change allows 3 min |

Day-by-day minutes behind the first row (X = cancelled): IC 27: 15 2 1 0 11 8 11 13 17 9 9 14 14 2 13 7 1 9 12 3 8 6 7
4 1 1 3 10. Vy 234: 0 7 0 2 3 2 4 10 2 0 0 4 X X X 2 8 9 4 4 4 3 5 3 2 5 10 24 (the three cancelled days carry an
actual arrival in the record too; the run is flagged cancelled, so they count as late and are left out of the minutes).
DSB 4283 has rows for 2026-10-01 … 07 and 22 … 26 only: the Danish archive gap of 2026-10-08 … 21 (DENMARK_DATA_FINDINGS).

Hand check of one raw row: IC 27 at Tampere on 2026-10-09, scheduled arrival 1791550680000, actual 1791551694000:
1 014 000 ms = 16.9 min → 17, as in the list.

## Limits, said plainly

- Sweden's projection into `observed_runs` only starts 2026-10-23 on the hosted server (6 days on 2026-10-29), so
  Swedish legs get no history line and no history-aware verdict until the record is a week old (7 days for the
  verdict, 4 for the line); the risk card falls back to the board record meanwhile. Finland's record runs from
  2023-02, Norway's from 2022-07, Denmark's from 2026-09-30 with the gap above.
- 28 days mixes weekdays and weekends; the figures are "how it has run lately", not a forecast.
- A train renumbered or rerouted keeps its number's history; a new number starts from nothing.
- Shared journeys (`share/shared.ts`) still judge changes with the plain rule.
