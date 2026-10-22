# Backend reliability and accuracy: where we stand and what's next

Owner, 2026-10-22: Clack is only as strong as its backend. Someone should be able to make a whole train journey
with only the app, and nothing shown may be made up. This notes the honest state of things and the agreed order of
work. See **Status** for what's built.

## Confidence today

| Area | Confidence | Why |
|---|---|---|
| Swedish timetable and search | High | Official GTFS (Sweden 3) and the Sverige 2 archive. The past-date bug (fixed 2026-10-22) shows it needs regression tests on real days. |
| Swedish live times, delays, cancellations, tracks | High at source, ours unmeasured | Trafikverket is the authority behind the station boards. We poll every 20 s (~7–17 s behind). Known feed bug (wrong offsets on actual times) is corrected in `actualTime()`. |
| Live position, Sweden | Medium-high | ~86% of trains send GPS, every ~30 s. The rest are drawn as labelled estimates. No filter yet for impossible jumps. |
| Norway, Norwegian operators | Medium-high | Entur GPS and delays; actual times only on the day. |
| Cross-border | Medium-low | No live data for SJ, Snälltåget or Vy Tåg on the Norwegian side, and none at any Danish station (CROSS_BORDER.md). Shown as timetable plus last known delay, labelled expected. |
| Track geometry | High | OSM routing: 99.1% of pairs clean, median 1.01× the straight line (DATA_FINDINGS §6). |
| Station maps | Low outside Stockholm C, Göteborg C, Malmö C | Shop lists from OSM or one dated plan; they go stale. |
| Delay warnings, reasons | High | Observations and Trafikverket's own codes only. |
| Running for days unattended | Unknown | One Node process, no supervision, no feed-health monitoring, never soak-tested. Biggest gap. |

## Order of work

1. **Accuracy audit, run daily.** Record what the app showed during each tracked trip (times, delays, tracks,
   positions), then compare it the next day with Trafikverket's and Entur's final records. Report: share of live
   times within 1 min of the final one, track changes after we showed a track, GPS jumps and stale spells. This gives
   real numbers to judge everything else by.
2. **Sanitization layer and feed health** (owner's item 5).
   - Drop GPS points that need impossible speeds (seen: 1% of consecutive fixes disagree with the reported speed by
     ~150 km/h, i.e. jumps).
   - An actual time never goes back to expected; odd jumps (20 min late → departed) are held until a second report.
   - Per-source staleness; a "live data is delayed" notice when a feed goes quiet instead of showing old data as live.
3. **Process reliability.** Supervisor and restart, catch-up after downtime, a 48-hour soak run, tests that replay
   recorded real feeds.
4. **Offline mode** (owner's item 4). PWA service worker caching saved trips' stops, times and geometry; when the
   connection drops, an estimated position from the last fix and recent speed, labelled as an estimate.
5. **Better estimates** (owner's item 1). Dead reckoning from recent segment speeds (the delay observations are
   already recorded). Crowdsourced GPS: not now (needs a native app, many users, a privacy story).
6. **Inbound train sets** (owner's item 2). First check whether the data exists: GTFS `block_id`, vehicle ids in
   TrainComposition. If it doesn't, an inferred link is a guess and either doesn't ship or is labelled.
7. **Congestion** (owner's item 3). Only as observations ("3 trains ahead on this single-track section are late"),
   never as probabilities we can't back.

**Owner decisions pending:** a Rejseplanen key for Danish live data (may be paid). There's no public source for
Swedish operators' live data in Norway today.

## Status (2026-10-22)

1. **Accuracy audit: built.** What each tracked trip showed (expected times, tracks) is recorded on every change;
   an hour after a trip ends it's scored at 60/30/15/5 min before each event against the final record, the stored
   actual times are checked against Trafikverket asked by train number, and GPS coverage, feed failures and dropped
   fixes are counted. Hourly report in `data/audit/latest.md`, numbers at `/api/audit`. A hidden user follows two
   real trains an hour (05–22, rotating long-distance, regional, commuter, Norway) so there are numbers from day one.
2. **Sanitization and feed health: built.** GPS jump filter (two agreeing fixes win over a stale one) on the trip
   tracker, the live map and Norway; reported speed kept only if it fits the movement (allowing ±250 m per fix);
   actual times never go back to "not yet"; a future "actual" is an estimate; an estimate jump of 15+ min waits for
   the next answer. `/api/health` reports each feed (ok / degraded / down) and the last dropped fixes; a trip's
   freshness goes by when the feeds last answered for it.
3. **Process reliability: built, being tested.** `scripts/supervise.mjs` restarts the server after a crash or five
   minutes without a health answer (tested with a crashing and a frozen server), restarts on code changes in
   development, and shuts down cleanly. Catch-up after downtime was already there (actual times for the last 4 days,
   the live map's full query after reconnecting, imports on start). Soak and replay: see below.
4. **Offline: built.** Trips, stops, track, operators and station maps are kept on the phone; with no live update
   for a minute the phone moves the train itself (shared position code, same rules as the server), marked as an
   estimate; a "No connection" strip; on https/localhost the app shell is kept too, so it opens offline (tested in
   Chromium: a page reload offline still shows the trip).
5. **Better estimates: built.** After GPS goes quiet the train is carried on at its last speed for up to 5 min,
   never past the next stop and never back behind its last fix. Segment speeds from history: not yet.
6. **Inbound train sets: not buildable on real data; not shipped.** Checked 2026-10-22: no public source says in
   advance which trip a physical train set runs next.
   - GTFS Sweden 3 and every cached Sverige 2 feed (2019–2026) have no `block_id`; the 2012/2016 feeds have the
     column but it's empty.
   - Trafikverket has no vehicle, set or circulation object among its 74 object types. TrainComposition is coach
     order only (2,259 rows, 308 trains). Every other id is per train (2,458 checked).
   - Entur's GTFS and NeTEx have no blocks. Journey Planner's `aimedVehicleId` was empty on all 1,708 rail
     journeys, and `expectedVehicleId` is just the train number.
   - Only Go-Ahead's and Flytoget's GPS carry real unit ids (e.g. unit 71-03: train 3943 to Oslo lufthavn, then
     3768 back after a 21-minute turnaround). But a unit shows up on its next trip only once the previous one has
     ended (4 min before to 3 min after departure), too late to warn about anything.
   - Guessing the next trip from earlier days would be made-up data. Not tested: Oxyfi's Trainpos (unit ids for
     five Swedish regional fleets, needs its own key) and GTFS Sweden 3 realtime (our key gets a 403).
7. **Congestion: built as an observation.** Within two hours of leaving, the trains that left your station your
   way in the last hour and how late they are now; a warning when at least two, and half, are 10+ min late. No
   single-track or platform-capacity rules: we have no reliable data on track counts, and the owner's rule is no
   probabilities we can't back.

**Found on the way:** SJ 441 and SJ Nord's 441 share a number and a brand on the same day, and the train sheet
could show one's header with the other's stops. Map trains are now paired only with a trip that runs where they are.

**Speedometer: built.** A small gauge with km/h on the train sheet and the trip's live panel, only from a fresh
(under a minute) fix whose reported speed passed the check. Sweden only (Norway sends no speeds).

## Speedometer on a live train (checked 2026-10-22)

Sample: every Swedish train's GPS, six polls 30 s apart, 13:58 UTC on a Thursday: 305 trains, 1,554 fixes.

- **69% of fixes carry a speed.** Of fixes where the train was clearly moving (> 20 km/h between fixes), 30% had
  none. Trafikverket's own note: speed is often absent when slow.
- **The reported speed agrees with movement:** against the speed worked out from consecutive fixes, median
  difference 4.4 km/h, p90 24 km/h (the straight line between fixes cuts curves and averages over 30 s).
  p99 146 km/h: GPS jumps, which the sanitization layer must drop.
- **Fixes come every ~31 s (p90 44 s),** so a speed is a reading from up to half a minute ago, not a live needle.
- **Norway:** no operator sends speed (NORWAY_DATA_FINDINGS). Only a speed worked out along the track between fixes
  (~every 15–20 s) is possible, and it's an average.

**Rule if built:** show the reported speed only from a fresh fix (under ~60 s) of an active train, with its age
("from the train's GPS, 20 s ago"). With no reported speed: either nothing, or an along-track average between two
fresh fixes, labelled as an average. Stopped only when two fixes are at the same place. The needle may glide to a new
reading, but never shows values between readings as if they were measured.
