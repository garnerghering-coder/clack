# Clack — Product & Build Spec

> **Clack** is the chosen name (pending domain and trademark checks before launch). A Flighty-style app for trains: log every train you ride, see it drawn on the real tracks, and build a "Passport" of your rail history with stats and CO₂ savings.
>
> **For Claude Code:** read this whole file **and `DESIGN.md`** (screens, visual design, live tracking behavior) before writing code. If the two conflict, `DESIGN.md` wins on UI/UX and this file wins on data and architecture; tell the owner about any conflict. Start with **Phase 0** (data verification) — do not build app features until Phase 0's findings are written up. Where this spec and live API documentation disagree, trust the live docs, note the difference in `DATA_FINDINGS.md`, and tell the owner. Ask before making large deviations from this spec.

---

## 1. Product summary

- **What it is:** a train trip logger and stats app, modeled on Flighty (flight tracker + "Passport" history). Trains instead of flights.
- **Who it's for:** launches publicly eventually. During development it runs as a single-user local demo, but the code must be **multi-user ready** (every user-owned row has a `user_id`).
- **Phase 1 goal:** a working demo for **Sweden only**. Other countries (Denmark next, then Germany, UK) are added one at a time later, each as a new data adapter.
- **Core loop:** add a train you rode (or will ride) → it's matched to a real timetabled train → its stops, times, delays and track shape are saved permanently → it appears on the map and in Passport stats.

## 2. Non-negotiable principles

1. **No AI at runtime.** Everything is deterministic code: downloads, database queries, string matching, arithmetic. No LLM calls anywhere in the app or the server.
2. **Cheap.** Free data sources, free map data, no paid tiles or paid APIs. Respect every quota. (The Apple Developer Program and the hosted VM are the only costs; nothing in the code is paid per request.)
3. **Native on iPhone.** The only client is the SwiftUI app in `apps/Clack`. There is no web app, no PWA and no wrapper around a web view.
4. **Keys stay on the server.** The app never calls Trafikverket, Trafiklab, Entur or Digitraffic itself; it only talks to Clack's server. The one key the app holds is its random phone id (§4).
5. **History is permanent.** Once a leg is finished, its data is frozen in our DB and never depends on an external API again.
6. **i18n from day one.** Every user-facing string is a key in the app's String Catalog (`ClackCore/Resources/Localizable.xcstrings`); English and Swedish ship together.
7. **Country = adapter.** Country-specific logic lives behind a common adapter interface (Sweden through Trafikverket and Trafiklab, Norway through Entur, Finland through Digitraffic), so a new country plugs in without touching the core.
8. **Nothing made up.** A train type, livery, line or amenity with no source is not shown (an unpainted train, "Train type not known"), and an estimate is always labelled as one.

## 3. Scope

**Built:**
1. Add a train (smart search by number or by stations, with a manual fallback), or import it from a ticket shared to Clack as a PDF or email (SJ tickets and receipts so far).
2. Trip detail: map, stop timeline, times and delays, platforms, the train's drawing, change risk, what is on board, activity log.
3. Trips: upcoming and past legs grouped into journeys, with the next one featured.
4. Explore: the live map of every running passenger train in Sweden, Norway and Finland, station search, station maps and live departure and arrival boards.
5. Passport: stats, year filter, commuter toggle, CO₂ comparisons, map of everything, share cards.
6. Settings: theme, language (English, Swedish), distance units, clock, CO₂ comparison, commuter filter, rail-network toggle, walking pace and step-free routing, display name, alert lead time, offline maps, privacy, about and sources, delete my data.
7. **Live tracking:** live delays, platforms, cancellations and short-turns, train position (GPS or labelled estimate), activity log (`DESIGN.md` §9).
8. **Alerts and Live Activities:** the server sends push alerts for saved trips and updates a Live Activity (Lock Screen and Dynamic Island) for the train you are on (docs/IOS.md).
9. **Working offline:** trips, stations and maps are kept on the phone; status and progress are estimated, and labelled, when there is no connection.
10. **Home Screen and Lock Screen widgets:** next journey, passport, departures, year in rail, stats.
11. **Sharing a journey by link:** a link shows one journey (trains, times, platforms, position, never the traveller's id, seat or other trips) in the app as a followed journey, or on a web page with a demo of the app; followers get alerts about it. No accounts and no friend list: whoever has the link can follow it, and the traveller can stop it (docs/IOS.md).

**Not built yet** (planned as later workstreams, see docs/SWIFT_PORT.md): more deep links, an Apple Watch app, and export of your data. Out of scope: accounts and login, friends, other countries until each has an adapter, booking and ticket sales.

## 4. Tech stack

| Layer | Choice | Why |
|---|---|---|
| App | SwiftUI, iPhone only (`apps/Clack`), with the Swift package `ClackKit` (ClackCore, ClackDesign) | Native feel, widgets, Live Activities, share sheet |
| Map | MapLibre Native | Free, open source, vector maps, offline tile cache |
| Basemap tiles | A Protomaps PMTiles extract of the Nordics on the server, served as `z/x/y` vector tiles (`/api/map/tiles`), with label glyphs from `apps/server/assets/map-fonts` | No API key, no per-request cost |
| Backend | Node.js 22 + TypeScript, Fastify, run with tsx | One language across server, shared package and scripts |
| Database | SQLite via Drizzle ORM (`data/app.db`); schema kept Postgres-compatible | Zero cost, one file |
| Push | Apple Push Notification service, from the server (`apps/server/src/push`) | Alerts and Live Activity updates |
| Strings | The String Catalog `ClackCore/Resources/Localizable.xcstrings`; the server reads it too | One source for both languages |
| Jobs | In-process scheduler (daily timetable import, post-trip snapshots, audit, push watcher) | No extra service |
| Hosting | One VM behind Caddy with https (docs/SERVER.md) | Cheap, simple |

**Identity.** There are no accounts. On first launch the app makes a random UUID, keeps it in the Keychain (it is being made to sync through the iCloud Keychain, so a new iPhone gets the same trips back; the app does not set that yet, and the privacy text already says it) and sends it with every request in `X-Clack-User`. Every user-owned row has a `user_id`. A shared server run with `CLACK_REQUIRE_USER=1` refuses `/api` requests without one. Delete my data removes the rows and the push addresses.

**Layout.** `apps/Clack` (app), `apps/server` (API, importers, push), `packages/shared` (types, constants, strings), `assets/trains` (train drawings), `data/` (hand-made data), `scripts/` (imports and tools).

## 5. Data sources (Sweden)

All keys go in `.env` (never committed). Provide a `.env.example`:

```
TRAFIKVERKET_API_KEY=
TRAFIKLAB_GTFS_SWEDEN3_KEY=
TRAFIKLAB_GTFS_SVERIGE2_KEY=
```

### 5.1 Trafikverket Open API — "what actually happened"
- **Use:** actual/estimated times, delays, platforms (tracks), cancellations, operator, product info for every Swedish passenger train. Also the station list (codes + coordinates).
- **Endpoint:** `POST https://api.trafikinfo.trafikverket.se/v2/data.json` with an XML request body containing the key, object type, schema version and filters.
- **Object types we need:** `TrainAnnouncement` (one row per train per station per activity — arrival/departure), `TrainStation` (station signature codes like `Cst`, names, WGS84 coordinates). Possibly `ReasonCode` for delay reasons.
- **Fields to look for (verify names and schema versions in Phase 0):** `AdvertisedTrainIdent`, `LocationSignature`, `ActivityType`, `AdvertisedTimeAtLocation`, `EstimatedTimeAtLocation`, `TimeAtLocation`, `TrackAtLocation`, `Canceled`, `Operator`, `ProductInformation`, `FromLocation`, `ToLocation`, `ScheduledDepartureDateTime`.
- **Note:** SJ and Snälltåget publish only planned timetables to GTFS Sweden 3, not realtime. Trafikverket is our only source of actual times for long-distance trains.
- **Data uses SWEREF 99 TM, but WGS84 is also published** — use WGS84.

### 5.2 GTFS Sweden 3 (static) — "what trains exist"
- **Use:** master catalogue of stations, routes, trips (trains) and stop times. Powers search.
- **Download:** `https://opendata.samtrafiken.se/gtfs-sweden/sweden.zip?key={key}` (updated daily ~05:00–06:00).
- **Quota (Bronze):** 10 calls/minute, **50 calls/month.** This is tight:
  - The server downloads at most **once per day** (after 06:30).
  - Cache the zip on disk; **never re-download in development** if the cached file is < 24h old. Add a guard that refuses to download if the last download was < 20h ago unless forced with a flag.
  - Log every download with a timestamp so quota use is visible.
- **License:** CC0. Free for commercial use.
- **Also available:** `stop_areas.txt` / `areas.txt` (maps stops to national "rikshållplatser") — useful for grouping platforms into one station.

### 5.3 GTFS Sverige 2 — "what trains existed in the past"
- **Use:** historical timetables (Trafiklab says back to 2012) so users can find and add old trips properly.
- **Unknown:** how history is packaged (per date? per week? archive files?). Phase 0 must find out from the docs page `https://www.trafiklab.se/api/gtfs-datasets/gtfs-sverige-2` and a test call.
- **Rule:** only fetch historical data **on demand** when a user searches a date outside the current GTFS Sweden 3 window, and cache what is fetched.

### 5.4 OpenStreetMap rail network — map lines and distance
- **Use:** draw each leg along the real tracks; compute accurate distance; optional "rail network" background layer.
- **Source:** Sweden extract from Geofabrik (`.osm.pbf`), filtered to `railway=rail` (and `light_rail`/`narrow_gauge` where passenger lines need it), excluding `service=yard/siding/spur` where practical.
- **License:** ODbL. **Attribution required** ("© OpenStreetMap contributors") on the map.
- **First check GTFS `shapes.txt`:** if GTFS Sweden 3 provides good shapes for rail trips, prefer those (simpler). OSM routing is the fallback/upgrade path. Phase 0 decides.

### 5.5 Live tracking data (Trafikverket, same key as 5.1)
- **Delays, platforms, cancellations:** `TrainAnnouncement`, via query + streaming (server-sent events) if it works well, otherwise polling every 20–30 s for tracked legs only.
- **Position:** `TrainPosition` (v1.1 appears in the API's object list). Not every train reports a position; handle absence. When absent, estimate position by interpolating along the leg geometry between the last confirmed stop passage and the next estimated stop time, and label it "Estimated".
- **One poller per train per date**, shared across users; the backend pushes updates to clients over SSE/WebSocket. Clients never call Trafikverket directly.
- Phase 0 must confirm schema versions, streaming vs polling behavior, connection/rate limits, and which operators actually report positions.

### 5.6 Not used in Phase 1 (possibly later)
KoDa (regional historical realtime since Feb 2020), Oxyfi realtime positioning (limited to a few regional operators, one websocket per key, server must relay), GTFS Sweden 3 Realtime / GTFS Regional realtime, ResRobot, NeTEx, SIRI.

## 6. Phase 0 — Data verification spike (do this first)

Build small scripts in `scripts/phase0/` and write results to **`DATA_FINDINGS.md`**. Answer:

1. **Trafikverket history window:** query `TrainAnnouncement` for a known train (e.g. an SJ X2000 Stockholm–Göteborg) for yesterday, 7 days ago, 30 days ago, 90 days ago, 1 year ago. How far back are *actual* times (`TimeAtLocation`) available? This sets where "full delay data" ends and "unknown" begins.
2. **Train number in GTFS:** confirm where the public train number lives in GTFS Sweden 3 (`trip_short_name`? something in the extra files?) and that it matches Trafikverket's `AdvertisedTrainIdent`.
3. **Station ID matching:** build a draft mapping table between GTFS stops/stop areas and Trafikverket `LocationSignature` codes, matching on name + coordinates (within ~300 m). Report match rate and list unmatched stations.
4. **GTFS Sverige 2 packaging:** how to fetch a past date; file sizes; how far back it truly goes; whether train numbers are present.
5. **Rail filtering:** list the `route_type` values used for trains in GTFS Sweden 3 (many may be the generic `100`) and identify how to tell intercity / regional / commuter / heritage apart (route_type, agency, route names).
6. **Shapes:** do rail trips in GTFS Sweden 3 have `shapes.txt` geometry? Is it track-accurate?
7. **Quota sanity:** confirm the Bronze limits and that caching works.
8. **Live position availability:** query `TrainPosition` while trains are running. Which trains and operators report positions (SJ, regional, commuter)? How fresh are they? Document the fields and update interval.
9. **Streaming vs polling:** test Trafikverket's SSE streaming for `TrainAnnouncement` against plain polling. Report reliability, reconnect behavior, any connection or rate limits, and recommend one approach for tracking several trains at once.

Deliverable: `DATA_FINDINGS.md` + the draft station mapping file. Then stop and summarise for the owner before Phase 1 features.

## 7. Data model (initial)

Use UTC timestamps everywhere; store each station's IANA time zone and render in the station's local time.

**Reference data (from imports):**
- `stations` — id, name, country, lat, lon, tz, gtfs_stop_ids[], trv_signature, stop_area_id
- `operators` — id, name, short_name, country, brand_color, logo_path
- `timetable_trips` — trip_id, service_date, train_number, operator_id, route_name, category (intercity/regional/commuter/heritage), source (`gtfs_se3` | `gtfs_sv2`)
- `timetable_stop_times` — trip_id, seq, station_id, sched_arr, sched_dep
- `track_segments` — from_station_id, to_station_id, geometry (encoded polyline/GeoJSON), length_m (cache for routed station pairs)

**User data:**
- `users` — id, created_at, settings (JSON). Phase 1: one seeded user.
- `legs` — id, user_id, journey_id, status (`planned` | `completed` | `snapshotted`), data_quality (`full` | `scheduled_only` | `manual`), country codes[], operator_id, train_number, category, origin_station_id, dest_station_id, sched_dep, sched_arr, actual_dep, actual_arr, dep_delay_min, arr_delay_min, dep_platform, arr_platform, canceled, distance_m, geometry, is_estimated_geometry, notes, created_at
- `leg_stops` — leg_id, seq, station_id, sched_arr, sched_dep, actual_arr, actual_dep, platform, canceled, passed_through (bool, for stops between origin and destination)
- `journeys` — id, user_id, title (auto, editable), created_at
- `leg_events` — id, leg_id, ts, type (`delayed` | `platform_changed` | `cancelled` | `short_turned` | `departed` | `arrived`), payload (JSON)
- `live_state` — leg_id, updated_at, status, lat, lon, bearing, speed_kmh, position_source (`gps` | `estimated`), next_stop_id, eta

## 8. Daily import pipeline

1. After 06:30 Swedish time, if the cached GTFS Sweden 3 zip is ≥ 20h old, download it.
2. Parse into staging tables; keep only rail trips (see §11); upsert stations/operators/trips/stop times for a rolling window (e.g. −7 to +60 days, tune after Phase 0).
3. Swap staging → live atomically.
4. Refresh the station mapping (new stations flagged for review, not silently dropped).
5. Fetch `TrainStation` from Trafikverket weekly (it rarely changes).

## 9. Add-trip flow (Flighty-style)

**Step 1 — date.** Default today. Any past or future date allowed.

**Step 2 — one smart search field.** Parse input with plain rules (no AI):
- `<operator> <number>` e.g. `SJ 523`, `sj523`, `Snälltåget 3943` → operator + train number. Match operator via a list of names/aliases.
- Digits only, e.g. `523` → train number, any operator.
- `<station> → <station>`, `<station> - <station>`, `<station> to <station>` → route.
- `<operator> <station> <station>` → operator + route.
- As the user types station names, show autocomplete from `stations` (accent-insensitive fuzzy match: "Goteborg" finds "Göteborg C"; common aliases like "Stockholm" → "Stockholm C").

**Step 3 — results list.** Query the timetable for that date:
- Route search: trips calling at origin then destination, in order. Show departure/arrival time, duration, operator (color + logo), train number, category.
- Train number search: the matching trip(s); user then picks boarding and alighting stations from its stop list (default: first and last).

**Step 4 — confirm & save.** Create the leg with all intermediate stops, then (async) attach actual times (§10) and geometry (§12).

**Historical dates:** if the date is outside the live timetable window, search GTFS Sverige 2 (fetched on demand per §5.3).

**Manual fallback** (nothing found, or the user prefers): origin station, destination station, date, optional operator, train number and times. Everything else is "unknown". Geometry is still drawn along the rail network between the two stations and marked as estimated. Data quality = `manual`. Manual legs count in the map and stats.

**Duplicates:** warn if the user already has the same train number on the same date.

## 10. Actual times & permanent snapshots

- When a leg is created for a train that has already run, immediately query Trafikverket for `AdvertisedTrainIdent = train_number` on that date and fill actual times, delays, platforms, cancellations for every stop.
- For future legs, store schedule only. When the app is opened (Phase 1 has no background tracking) and a leg's scheduled arrival has passed, fetch actuals and **snapshot**: freeze the leg and set status `snapshotted`.
- If actuals are unavailable (older than Trafikverket's window — see Phase 0), keep scheduled times and set data_quality = `scheduled_only`. Delay stats exclude these legs (shown as "unknown").
- Delay = actual − advertised, in whole minutes. Arrival delay at the user's destination is the headline number.

## 11. What counts as a train

- **Included:** intercity/long-distance, high speed, regional, cross-border (e.g. Öresundståg), night trains, **commuter rail** (Pendeltåg, Pågatåg, etc.), Arlanda Express, narrow-gauge suburban lines (Roslagsbanan, Saltsjöbanan), heritage railways (tag as `heritage`).
- **Excluded:** metro/tunnelbana, trams, light rail/city trams, replacement buses, ferries, buses.
- Classification uses GTFS `route_type`, agency and route names, plus a hand-maintained **overrides file** (`data/category_overrides.json`) for edge cases found in Phase 0.
- **Commuter filter:** commuter legs count by default; a Passport toggle hides them from stats.

## 12. Map

**Look (Flighty-inspired):** dark minimal basemap; the user's route drawn as a glowing line in the operator's brand color; stops as small dots, labeled with times on the trip page; origin/destination emphasised.

**Toggle:** "Show rail network" faintly renders all rail lines (from our OSM extract as a vector layer) beneath the user's routes.

**Geometry per leg:**
1. Prefer GTFS shape for the trip if Phase 0 shows it is track-accurate.
2. Otherwise route on the OSM rail graph between each pair of consecutive stops (snap stations to nearest rail node; shortest path). Cache each station pair in `track_segments`.
3. If routing fails, fall back to straight segments between stops and mark `is_estimated_geometry`.

**Distance** = length of the leg's geometry (fall back to summed stop-to-stop great-circle distance).

**Attribution:** OpenStreetMap contributors (ODbL) and basemap attribution shown on every map.

## 13. Journeys (grouping legs)

- Each train is a **leg**. Legs are auto-grouped into a **journey** when the next leg departs from the same station (or same stop area) as the previous leg arrived, on the same day, within **4 hours**.
- Users can manually split or merge journeys.
- Journey view shows legs in order with transfer times between them.

## 14. Passport (stats)

All stats are plain SQL aggregations over the user's legs, filterable by **year / all time** and the **commuter toggle**:

- Total distance (km/mi), total time on trains, number of trains (legs), number of journeys
- Stations visited (count + list), countries visited, border crossings (counted when a leg's stops span two countries)
- Operators ridden (with counts), train categories / products (X2000, Regional, InterCity…)
- Longest leg (distance and duration), most-ridden route, most-used station
- Delay stats (only legs with `full` data): total minutes delayed, on-time % (on time = arriving ≤ 5 min late by default; constant `ON_TIME_MAX_DELAY_MIN`; delay color bands are defined in `DESIGN.md` §2.1: green ≤0, yellow 1–15, amber 16–30, red 31+), average delay, worst delay, cancellations
- CO₂ (see §15)
- Map of all legs ever ridden

## 15. CO₂ comparisons

**Method:** for each leg, `saved_kg = distance_km × (comparison_factor − train_factor) / 1000` (factors in g CO₂e per passenger-km). Show "train emissions", "would have emitted by X", and "saved". One setting switches the comparison everywhere.

**Comparison options (Sweden factors):** source is IVL Swedish Environmental Research Institute, *"Typvärden för klimatpåverkande utsläpp från långväga personresor i Sverige"*, report U11173, May 2026 (commissioned by SJ AB). Values are well-to-wheel, g CO₂e/pkm:

| Mode | g CO₂e / pkm | Note |
|---|---|---|
| Domestic flight | 170 | Includes high-altitude effect |
| Car, 1 person | 190 | Average Swedish car, rural driving (default car option) |
| Car, 2 people | 95 | |
| Car, 3 people | 63 | |
| Car, average occupancy (1.45) | 130 | |
| Electric car, 1 person | 10 | Trafikverket rural WTW value; excludes vehicle manufacturing (see note) |
| Long-distance coach | 15 | |

**Train factor (Sweden):** 0.27 g CO₂e/pkm (IVL value for an average SJ train; SJ high-speed is 0.19). Phase 1 simplification: use 0.27 for all electric Swedish trains. Flag non-electrified (diesel) lines for a higher factor later.

**Implementation rules:**
- Factors live in a versioned config file (`data/co2_factors.json`) with source, year and unit for every value, keyed by country, so other countries get their own factors later.
- Show a short "How we calculate this" page listing sources.
- Note for later: the electric car figure excludes battery/vehicle manufacturing, which IVL notes is significant; consider an optional "include vehicle manufacturing" mode. Also note the source was commissioned by SJ; when adding other countries consider UK DESNZ/DEFRA conversion factors as a cross-check.

## 16. Settings

Language (English first), distance units (km/mi), clock (24h/12h), CO₂ comparison mode, commuter filter default, map rail-network toggle default. Settings are stored per user.

## 17. Screens

Three tabs (`DESIGN.md` §3): **Trips**, **Explore**, **Passport**. Settings opens from a gear in the Trips and Passport headers.

1. **Trips:** upcoming and past legs grouped by journey, the next one as a featured card; "+" to add.
2. **Add a train:** date, smart search (number or stations), results, confirm; manual entry; or a shared ticket ("From your ticket").
3. **Trip detail:** map; header with operator, train number, date; stop timeline with scheduled vs actual times, platforms, delays; progress, change risk, disruption and alert cards, what is on board, activity log; distance, duration, CO₂ saved; data-quality note.
4. **Journey:** the legs of one journey with connections between them.
5. **Explore:** the live map; station search; a station's map and its departure and arrival boards.
6. **Arrival:** shown when you reach the end of a journey.
7. **Passport:** headline stats, year filter, commuter toggle, map of all legs, breakdown lists, share cards.
8. **Settings:** the list in §3, with About (sources and the CO₂ method) and Privacy.

Portrait iPhone only; iPads run it in iPhone mode. Dark and light themes.

## 18. Operator branding

- Each operator has a brand colour in `data/operators.json`. The server downloads each operator's logo (its website's app icon) into `data/cache/logos/` and serves it at `GET /api/operators/:id/logo`; the app shows it in the operator badge (`Config.showOperatorLogos`).
- Garner has the operators' approval to show their logos (2026-10-23, kept for App Review, docs/APP_STORE.md). If that ever changes, switching `Config.showOperatorLogos` off shows the fallback: a coloured badge with the operator's short name.

## 19. Build order & acceptance criteria

The server was built in this order; each step was done when its acceptance sentence held.

1. **Phase 0, data verification** (§6): `DATA_FINDINGS.md` answers all nine questions.
2. **Skeleton:** server, SQLite, `.env` handling, strings. Done when the server starts with one command (`npm run dev`).
3. **Import:** GTFS Sweden 3 import with quota guard; station mapping; Trafikverket `TrainStation` import. Done when stations are searchable.
4. **Search & add:** smart search, results, save a leg with its stops. Done when "SJ 523" and "Stockholm → Göteborg" both find real trains on a chosen date.
5. **Actuals & snapshot:** Trafikverket integration. Done when a past train shows real delays and platforms per stop.
6. **Map & geometry:** basemap, routed track lines, rail-network layer. Done when a leg draws along the real tracks.
7. **Live tracking:** server-side poller or stream per tracked train, `leg_events` and `live_state`, SSE to the app. Done when a train that is running shows live delays and a moving marker.
8. **Trips, trip detail, journeys; Passport and CO₂; historical search** (`DESIGN.md` §4, §6, §7, §8).
9. **Norway** through Entur: timetables, live positions, boards. **Finland** through Digitraffic (Fintraffic, CC BY 4.0), the same scope; the Finnish data is described in `FINLAND_DATA_FINDINGS.md`.
10. **Native app:** all of the above in SwiftUI (docs/SWIFT_PORT.md, done), then alerts, Live Activities, ticket import, offline mode and widgets (docs/IOS.md, done).
11. **Later work** is tracked as workstreams A to J ("Clack: from ported to stellar"; docs/SWIFT_PORT.md, last section).

Tests (vitest for the server and shared package; Swift Testing for the app) cover: search input parsing, station fuzzy matching, delay calculation, journey grouping, distance calculation, CO₂ calculation, stat aggregations, the push rules and the strings (`ClackCoreTests/L10nTests.swift` checks every key has both languages with the same placeholders).

## 20. Launch checklist

What App Review needs, and what is done and open, is in `docs/APP_STORE.md`. In short:
- Operator logos: approval is held; keep the written approvals.
- Rejseplanen (Denmark) and any other free tiers marked non-commercial: confirm commercial terms before charging money.
- Privacy policy at `https://clack-garner.duckdns.org/privacy`, data deletion in Settings; a backup of `data/app.db` (docs/SERVER.md, none automatic yet).
- Map and data attributions in the app and the App Store listing.
- Apple Developer Program (the paid team is active), TestFlight, then the App Store.

## 21. Future phases

- **Denmark** via Rejseplanen API 2.0 (access id requested separately; the free non-commercial tier is ~50,000 calls a month). New adapter, Danish station data, Danish rail CO₂ factor, Öresund border-crossing logic.
- **Then:** Germany, UK.
- **In the app:** more deep links, an Apple Watch app, export of your data, booking-email import and CSV import.

## 22. Open questions (resolved by Phase 0)

- Trafikverket actual-times history window
- GTFS Sverige 2 packaging and coverage
- Train-number field in GTFS and match rate to Trafikverket
- Whether GTFS shapes are good enough or OSM routing is needed
- Rail category classification rules and overrides
- Which trains report live GPS positions, and whether Trafikverket streaming or polling is the better live-tracking approach
