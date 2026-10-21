# Norway — data findings (Entur)

Checked 2026-10-21 (evening, so live counts are low-traffic numbers) before building Norway support. Every
Entur request sends `ET-Client-Name: garner-clack`. All data is under NLOD, so the Sources page and map
attribution credit Entur.

## TL;DR

| Question | Finding | What we do |
| --- | --- | --- |
| Rail timetable | Entur publishes per-operator rail GTFS: Vy `rb_vyg` (64 MB), Go-Ahead `rb_goa` (17 MB), SJ Nord `rb_sjn` (21 MB), Flytoget `rb_flt` (0.7 MB) at `storage.googleapis.com/marduk-production/outbound/gtfs/rb_<code>-aggregated-gtfs.zip`. All `route_type` 100/101. | Import these four, at most once per 24 h, cached. The whole-Norway file (532 MB) isn't needed. |
| Date range | Feeds start yesterday or today and run to Feb–Mar 2027. | Same rule as Sweden: never delete past dates on import. |
| History older than the feed | Journey Planner returns nothing for past days, and I know of no public archive like Sweden's. | Norwegian trips older than yesterday can't come from a timetable. They can be added as manual trips (stations and times), with geometry from the rail graph. |
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
