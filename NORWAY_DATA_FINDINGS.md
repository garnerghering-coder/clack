# Norway — data findings (Entur)

Checked 2026-10-21 (evening, so live counts are low-traffic numbers) before building Norway support. Every
Entur request sends `ET-Client-Name: garner-clack`. All data is under NLOD, so the Sources page and map
attribution credit Entur.

## TL;DR

| Question | Finding | What we do |
| --- | --- | --- |
| Rail timetable | Entur publishes per-operator rail GTFS: Vy `rb_vyg` (64 MB), Go-Ahead `rb_goa` (17 MB), SJ Nord `rb_sjn` (21 MB), Flytoget `rb_flt` (0.7 MB) at `storage.googleapis.com/marduk-production/outbound/gtfs/rb_<code>-aggregated-gtfs.zip`. All `route_type` 100/101. | Import these four, at most once per 24 h, cached. The whole-Norway file (532 MB) isn't needed. |
| Date range | Feeds start yesterday or today and run to Feb–Mar 2027. | Same rule as Sweden: never delete past dates on import. |
| History older than the feed | Journey Planner returns nothing for past days. **Corrected 2026-10-26:** Entur's public BigQuery table has every journey's planned and actual times back to early 2020 (see below), and the Mobility Database keeps copies of the national GTFS (from at least May 2025). | Older days come from the observed record: searchable back to 2020-01-01; before that, manual trips. |
| Train numbers | No `trip_short_name`. Journey Planner's `privateCode` is the train number. It's also in the trip id: Vy/Go-Ahead/SJ Nord `…:ServiceJourney:<number>[-suffix]_<id>-R`; Flytoget `…:ServiceJourney:1-<route>-<number>-<date>`. Vy's live vehicle id is `<number>-<date>`. | Parse the number from the trip id. The import checks a sample against `privateCode`. |
| Geometry | `shapes.txt` is present for every operator (Sweden's data has none). | Use the shapes for Norwegian legs. The OSM rail graph already includes Norway (built from SE + DK + NO extracts), as a fallback and for the map's rail lines. |
| Stations | Stops are NSR quays (`NSR:Quay:…`) with parent stop places (`NSR:StopPlace:…`, `location_type` 1). Swedish stations served by Vy/SJ Nord have NSR ids too. | One station per place. An NSR stop place within ~500 m of an existing station with a matching name reuses that station's id, so Oslo S stays `760000100`. Otherwise the NSR id becomes the station id (country NO). |
| Cross-border overlap | Sweden's data already has 26 Norwegian stations and Oslo trips by SJ (157), Vy (84) and Snälltåget (16). Vy's RE20 Oslo–Göteborg is in both feeds. | Search shows a train once: same number, date, boarding station and departure minute → one result. The boarding station's country's feed wins. |
| Live positions | GTFS-RT `vehicle-positions?datasource=VYG/GOA/FLT/SJN`, every 15 s. At 00:20: Vy 43 trains, Go-Ahead 4, Flytoget 6, SJ Nord 0. Every position has its trip id and start date. Median age 26 s, p90 up to 446 s. Only Flytoget sends a bearing; nobody sends speed. | Poll every 20 s. Bearing comes from movement or the shape. A position older than 2 min isn't shown as live (same rule as Sweden). SJ Nord positions need a daytime recheck. |
| Delays and cancellations | GTFS-RT `trip-updates`: per-stop delay, schedule relationship and cancellations, keyed by the same trip ids. | Live map delay and next stop. |
| Actual times | Journey Planner `serviceJourney(id).estimatedCalls(date)` gives `actualDepartureTime`/`actualArrivalTime`, `cancellation` and the quay's public code (the track), but only for the current day. | Norwegian legs get actuals while they run and shortly after. The tracker already refreshes due legs every 5 min. A leg first seen after its day stays scheduled-only. |
| Boards | Journey Planner `stopPlace.estimatedCalls` (departures; arrivals via `arrivalDeparture`) with aimed, expected and actual times, tracks and cancellations. | Departure and arrival boards for Norwegian stations. |
| Night trains | Journey Planner `transportSubmode: nightRail` (for example Go-Ahead 725, F5). GTFS doesn't say. | The category comes from line rules (L = commuter, R/RE/RX = regional, F = long distance, FLY = airport) plus an overnight check. |
| Rate limits | With the client header: 500 trip searches/min and 1,000 other requests/min. GTFS downloads at most once per 24 h. | Respect the reset headers and don't retry inside a minute. |

## History and the observed record (checked 2026-10-26/27)

- **Journey Planner keeps actual times only briefly.** At 21:00, trains that finished an hour earlier still had
  `actualDepartureTime` to the second; that morning's trains had none (only `realtimeState: scheduled`). The observed
  record fetches each journey ~15 min after its last scheduled arrival, again later if it ran late
  (`apps/server/src/observed/norway.ts`).
- **Entur's BigQuery archive:** `ent-data-sharing-ext-prd.realtime_siri_et.realtime_siri_et_last_recorded`
  (documented in the public bucket `storage.googleapis.com/sidecar_files_data-entur-no/`). One row per stop per
  journey per day, Q1 2020 on, refreshed ~04:00 UTC, 3.1 billion rows, partitioned by `operatingDate`, NLOD 2.0.
  - Queried from our free sandbox project (`clack-data`, service account with BigQuery Job User). A day of rail is
    ~14,000–20,000 rows and scans **0.07–0.17 GB** (2020 to now ≈ 170 GB, under the free 1 TiB a month).
  - Rail sources by year (one sample day each): 2020 NSB, GOA, FLT, GJB; 2022 and 2024 all BNR (Bane NOR); 2026 VYG,
    GOA, FLT, BNR. `vehicleMode = 'rail'` leaves out Vy's buses.
  - **Two id styles:** older rows are `"<number>:<date>"` (`471:2022-03-08`) with the operator in `operatorRef`
    (VY, SJN); newer ones are codespace ids (`VYG:ServiceJourney:61-LOD_617015-R`). Both are read
    (`journeyIdentity`); VY is Vy's codespace VYG.
  - No platform text: the platform is the quay's `publicCode`. Older days call at quays since retired, so
    `quays_all_versions` (newest version per quay) is used, not `quays_last_version`.
  - A station can have several stop places (Lillestrøm's platforms are under `NSR:StopPlace:451`, our station knows
    `60694`); places are matched to stations as the import does (400 m, or 1.5 km with the same name). 56 of 566 rail
    places are stations no longer served (Skoppum, Kjose, Kornsjø …); they become historical-only stations. On
    2024-03-12 all 1,470 rail journeys then map to our stations.
  - Some operators copy the planned time into a missing actual one; the `estimated` flag is kept and an estimated
    time is never stored as an actual. Lines are missing in older rows (`SJN:Line:-`).
- **Disruption messages (SIRI-SX)** `https://api.entur.io/realtime/v1/rest/sx`: all ~480 current situations, all
  modes, 0.7 MB per call. Not archived anywhere by Entur; the record keeps each new or changed one (every 10 min).
- **Mobility Database** (`mdb-1078`) has daily copies of the national GTFS (530 MB each; copies found from May 2025);
  not used, since the BigQuery archive goes further back (docs/MOBILITY_DATABASE.md).
