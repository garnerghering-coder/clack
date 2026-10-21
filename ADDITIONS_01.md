# Clack — Addition 01: Live Map, Departure Boards, Station Maps with Layover Guide

**Status of the project:** Phase 0 (data verification) and Phase 1 (Sweden demo) are already built. This document does NOT change or re-open them. It describes new features that sit on top of what exists.

**Read first:** `SPEC.md` (data and architecture), `DESIGN.md` (look and UX), `DATA_FINDINGS.md` (what Phase 0 actually proved about the data). Where this file is silent, SPEC.md and DESIGN.md rule. Where this file contradicts the code that exists, inspect the code and tell me before changing anything large. Do not assume module names from SPEC.md; check the repo.

**Why these features:** Clack should not be a Flighty clone with trains painted on. Trains have things planes do not: you can stand on a platform and just need to know what leaves next, stations are places you spend real time in, and connections are tight and stressful. These three features lean into that.

| # | Feature | Buildable now? | Risk |
|---|---------|---------------|------|
| A | Live map of all trains (radar view) | Yes | Low. Depends on how many trains report GPS (check DATA_FINDINGS.md). |
| B | Station departure and arrival boards | Yes | Low |
| C | Station maps with amenities and a Layover Guide | Spike first, then staged | High. Needs hand-curated or OSM indoor data. |
| D | On-board amenities (food, vending, Wi-Fi) | Research spike only | Unknown. May not be possible. |

Build order: **B, then A, then C-spike, then C, with D as a side research task.** B is the cheapest and exposes the station search that C needs.

Principles from SPEC.md still apply: no AI at runtime, keys stay on the server, one shared upstream connection regardless of how many users are looking, `user_id` on user data, i18n for every string, cheap or free infrastructure.

---

## Feature B — Station departure and arrival boards

### What it is
Search any Swedish station, see a live board of departures or arrivals. Not tied to a logged trip. Use case: standing on a platform, or planning to leave in 20 minutes.

### Entry points
1. A **Stations** tab (or a search icon in the Trips header, your call after looking at the nav in DESIGN.md; mobile tab bar currently has Trips, Passport, Settings, so prefer a search icon plus a "Stations" entry rather than a fourth tab unless it fits cleanly).
2. Tapping any stop name in Trip detail, the stop timeline, or the live map.
3. "Nearby" is P2 (needs geolocation permission; skip for now).

### Station search
- Single field. Matches station name, case and diacritic insensitive ("goteborg" finds "Göteborg C"), plus common aliases ("Stockholm Central", "Sthlm C", "Gbg").
- Source: the station list already imported from Trafikverket `TrainStation` plus GTFS `stop_areas`. Reuse the existing station search from the Add-trip flow; do not build a second one.
- Results show name, county or town, and a small chip if a station map exists (Feature C).
- Recent and favourite stations at the top when the field is empty. Favourites stored per user.

### The board (screen)
- Header: station name, small "Live" chip, last-updated time (e.g. "Updated 8 s ago"), star to favourite.
- Segmented control: **Departures | Arrivals**.
- Rows, one per train, sorted by advertised time:
  - Large time (split-flap style digits per DESIGN.md §motion) showing the **estimated** time; if different from scheduled, the scheduled time struck through beside it.
  - Destination (departures) or origin (arrivals), bold.
  - Operator badge (color plus logo, from the existing operator folder), train number, train type.
  - **Platform** in a rounded chip. If the platform changed in the last N minutes, chip turns amber with a small "Changed" label and the old platform struck through.
  - Delay pill using the owner-set bands from DESIGN.md §2.1: green on time, yellow 1-15, amber 16-30, red 31+. Cancelled rows get the red outline and the word "Cancelled"; times shown dimmed.
  - "Via" line (up to 3 notable intermediate stops) in secondary text.
- Filters (sheet or chips): operator, train type, commuter trains on/off (follows the global setting by default), time window (next 1 h, 3 h, rest of day).
- Tap a row: bottom sheet with the full stop list for that train, delay, platform, and a primary button **Add to my trips** which jumps into the existing add-trip confirm step with the train and boarding stop prefilled.
- Pull to refresh on mobile. Auto-refresh while visible.
- Past departures (last 10 minutes) stay visible dimmed so a user who just missed a train sees it. "Show earlier" loads more.
- Empty state: "No departures in this window", with a button to widen the window.

### Data and architecture
- Source: Trafikverket `TrainAnnouncement` filtered by `LocationSignature`, `ActivityType` (`Avgang` for departures, `Ankomst` for arrivals) and an advertised time window.
- **Server-side only.** The client never calls Trafikverket. Add `GET /api/stations/:id/board?type=departures|arrivals&from=&to=` returning a normalized board, and use the existing server-to-client push channel (SSE or whatever Phase 1 uses) for live updates while a board is open.
- **Shared polling:** one upstream query per station per ~15-30 s regardless of how many users are viewing it; refcount viewers, stop polling when nobody is watching, short in-memory cache. This matters for the future public launch and for staying inside Trafikverket's rate limits. Verify the actual limits and how the existing pollers behave before choosing the interval.
- Reuse the existing normalization of announcements into planned versus actual times, platform, deviation text, cancellations. If Phase 1 already has a "train at station" model, extend it; do not duplicate.
- Apply the same "what counts as a train" classification (SPEC.md §11) so metro, trams, buses and ferries never appear.
- Linking: each board row must resolve to the same internal train identity used for trips (date plus operator plus train number or whatever Phase 1 uses), so Add to my trips works and so Feature A can open the same sheet.

### Acceptance criteria
- Search "goteborg" finds Göteborg C; board loads in under 2 s on a warm cache.
- A delayed train shows scheduled time struck through, estimated time, and the correct band color.
- A cancelled train shows red outline and is not counted as departed.
- A platform change updates the row without a manual refresh and shows the Changed label.
- Opening the same board in two browser tabs causes one upstream poll, not two.
- Tapping Add to my trips lands on the confirm step with boarding stop set to this station.

---

## Feature A — Live map of all trains (radar view)

### What it is
A full-screen dark map of Sweden with every tracked train moving along its real route. Think flight-radar, but calmer and prettier, with the same visual language as the single-trip live map.

### Entry points
- New map icon/tab "Live" (mobile: replace nothing in the tab bar; place it as a button in the Trips header or as a Stations/Live combined tab, decide with DESIGN.md's nav in view).
- From any trip's map: "Show all trains" toggle.
- From a station board: "Show on map" for a row.

### Screen
- Same basemap as the trip map (self-hosted PMTiles, dark). Rail network layer ON by default here, faint.
- **Train markers:** small rounded glyphs (not tiny icons that disappear: 10-14 px dot with a short heading tick) in the operator color, soft glow like the live marker in DESIGN.md §6 but dimmer. Hollow if the position is estimated rather than GPS (same rule as the trip view).
- Delay is shown by a thin ring around the marker using the delay bands; on time = no ring. Cancelled trains are not shown on the map.
- **Zoom-dependent detail:**
  - Zoomed out (country view): dots only, clustered when overlapping (cluster shows a count), no labels.
  - Region view: dots plus train number label on hover/tap, no clustering.
  - Close view: train number and destination label next to the marker; station dots appear.
- **Selecting a train** (tap): the marker enlarges; its full route draws on along the tracks using the existing 3-stroke glowing route (past part solid, future part dashed); a bottom sheet appears with operator, train number, type, origin to destination, next stop and ETA, delay, speed if known. Button **Add to my trips** and **Open full detail**.
- **Filters** (top chip row): operator multi-select, train type (high-speed, regional, commuter, night, freight is NOT included), "only delayed", "only my trains".
- Your own tracked trains are always drawn on top and slightly larger, with the Clack accent halo.
- A small legend (collapsible) explaining solid versus hollow markers and the ring colors.
- Counters in a corner chip: "412 trains live". If the feed is stale (> 60 s since last update), show "Delayed data" in grey with the age.

### Data and architecture (important)
- Source: Trafikverket `TrainPosition` (and TrainAnnouncement for delay, next stop). DATA_FINDINGS.md from Phase 0 says what fraction of trains actually report GPS and how fresh positions are; **read it and adapt**. Where a train has no GPS, use the same estimated-position logic as the single-trip view (interpolate along the route shape between last confirmed stop and next stop using schedule and delay). Estimated trains are hollow markers. Make this switchable on the server (`LIVE_MAP_INCLUDE_ESTIMATED`) in case it looks cluttered.
- **One server-side ingest, fan-out to clients.** Do not open an upstream stream per user. Run one `TrainPosition` stream (SSE if Phase 0 verified it works, polling otherwise) and keep an in-memory table `liveTrains` keyed by train identity. Serve:
  - `GET /api/live/trains?bbox=&zoom=` initial snapshot, filtered to the viewport.
  - A push channel with deltas (changed trains only), filtered by the client's subscribed bounding box so a user looking at Skåne does not receive Norrland.
- **Smooth motion:** clients interpolate between position updates along the route polyline (dead-reckon with speed and bearing, snapped to the shape when available) so markers glide instead of jumping. Cap interpolation to avoid trains running past the next stop.
- **Route geometry:** reuse the shapes from Phase 1 (GTFS shapes or OSM-routed). Do not send a full polyline for every train. Send shape ids; the client fetches and caches shapes on demand, only for selected trains. The rail layer can be a single vector tile source.
- **Scale target for the demo:** a few hundred to roughly a thousand simultaneous trains in Sweden at peak. Render with MapLibre symbol/circle layers from a GeoJSON source updated in place (not DOM markers). Test with 1,000 simulated trains and keep 60 fps panning on a mid-range phone.
- Cost: no paid services. Nothing here needs more than the existing key and server.
- Retention: live positions are ephemeral. Do not write every position to the database. Only the tracked legs of real users keep their `live_state`/`leg_events` as in SPEC.md.

### Acceptance criteria
- Opening Live shows moving trains within 3 s on a warm server, and the number matches reality roughly (compare with Trafikverket's own Tågtrafik info).
- Panning to another region switches the subscription and loads trains there without a page reload.
- 1,000 simulated markers pan and zoom smoothly.
- Selecting a train draws its route and opens the sheet; Add to my trips works.
- Killing the upstream connection shows the "Delayed data" state, and recovery clears it automatically.
- No per-user upstream calls (verify in server logs with two clients open).

---

## Feature C — Station maps with amenities and the Layover Guide

This is the signature feature and the heaviest. It is staged so that value ships early and nothing is promised that the data cannot support.

### What it is
For major stations, a clean, dark, schematic **map of the station** that shows:
1. **Platforms/tracks** with their numbers, and the main halls, entrances, stairs, escalators and lifts that connect them.
2. **Amenities** as tappable pins: toilets (free or paid), cafés and restaurants, convenience stores/kiosks, ticket office and machines, luggage lockers, waiting rooms, information, pharmacy, ATM, taxi/bus links. Each pin shows name, category, hours, and whether it is open **now** (or at a chosen time).
3. The **Layover Guide**: when the user has a connection in a journey (arriving leg plus next leg at the same station), the map highlights the arriving platform, the departing platform, and draws a **dotted animated path** between them along the fastest walkable route, with walking time, a "will I make it" indicator, and which amenities are actually open during the layover window.

It is a station map first and a layover tool second. The same map is reachable from any station (via the Stations search, a station board, a trip stop) even with no connection.

### Staging (important)
| Stage | What | Gate |
|-------|------|------|
| C0 | **Data spike** (see below). Report findings. | Do first. Nothing else in C starts until it reports. |
| C1 | Station data format, loader, validator, and the map renderer, shown for **one** pilot station (suggest Stockholm C or Göteborg C, whichever has better OSM indoor data). | C0 done |
| C2 | Amenities layer with hours and open/closed logic. | C1 |
| C3 | Routing and the Layover Guide on the pilot station. | C1 (amenity dimming also needs C2) |
| C4 | Roll out to 5-10 major interchanges. | C3 stable |

If C0 shows the data is much worse than hoped, STOP and report. Fallbacks are defined below; do not silently invent geometry.

### C0 — Data feasibility spike (do this first, timebox it)
Write findings to `STATION_DATA_FINDINGS.md`, same spirit as `DATA_FINDINGS.md`. Make real requests and inspect real responses. Timebox it; do not let it sprawl. Check, in order of likely payoff:

1. **OpenStreetMap indoor and platform data** for the biggest stations (Stockholm C, Göteborg C, Malmö C, Uppsala C, Hässleholm, Linköping C, Örebro C, Norrköping C, Lund C, Västerås C). Query via Overpass or a Geofabrik extract for: `railway=platform`, `public_transport=platform`, `ref` on platforms, `indoor=*` features, `level`/`repeat_on`, `highway=footway` with `indoor=yes`, `highway=steps`, `highway=elevator`, `conveying=*`, `amenity=toilets` (with `fee=*`), `shop=*`, `amenity=cafe|restaurant|fast_food`, `opening_hours=*`. Report per station: how many platforms have a `ref`, whether indoor footways connect platforms to halls, how many POIs have `opening_hours`. OSM license is ODbL: attribution is required and must appear on the Sources page and on the map.
2. **GTFS `pathways.txt` and `levels.txt`** in the GTFS Sweden 3 feed we already download: does Samtrafiken's feed include them? If yes, that is a ready-made station graph. Likely no, but it is free to check.
3. **Trafikverket `TrainStation`** fields and any station-level objects (geometry, platform lists). Does it expose platform geometry or just the station point?
4. **Station owners/operators:** Jernhusen (owns and operates many major stations; verify which), Trafikverket (platforms), SJ station pages, and each station's own website. Look for a structured source: JSON endpoints behind their site, opening-hours markup (schema.org JSON-LD), downloadable floor plans. **Respect robots.txt and terms of service.** Do not scrape anything the terms forbid. If a page is useful but not machine-usable, note it as a manual-curation source and move on. Do not copy copyrighted floor-plan images.
5. **Commercial/licensing check:** anything we plan to use must be allowed for a public app. Report license per source.

C0 must end with a table: per pilot station, per data type (platform numbers, walking graph, toilets, shops, opening hours), the best available source and its quality (good / partial / none), plus a recommended pilot station and a time estimate for authoring one station.

### Station data format (committed to the repo, versioned)
One JSON file per station in `data/stations/<station_id>.json`, validated by a schema in `packages/shared`. Authored by a script that drafts from OSM, then hand-edited. Fields:

```
{
  "station_id": "...",            // matches the internal station id
  "name": "Stockholm C",
  "updated": "2026-10-xx",
  "sources": [{"type":"osm","license":"ODbL","retrieved":"..."}, {"type":"manual"}],
  "levels": [{"id":"L0","name":"Street","order":0}, {"id":"L1","name":"Hall","order":1}],
  "coord_system": "schematic",     // or "wgs84"
  "outline": [...],                // simplified polygons per level (building footprint, halls)
  "platforms": [{"id":"p12","ref":"12","tracks":["12a","12b"],"level":"L0","geometry":[...]}],
  "nodes": [{"id":"n1","type":"platform_access|hall|entrance|stairs|escalator|lift|gate","level":"L0","x":..,"y":..}],
  "edges": [{"from":"n1","to":"n2","seconds":40,"step_free":true,"kind":"walk|stairs|escalator|lift"}],
  "pois": [{
    "id":"poi1","category":"toilet|cafe|restaurant|kiosk|shop|ticket|locker|waiting|info|pharmacy|atm|taxi|bus|other",
    "name":"...","level":"L1","x":..,"y":..,"node":"n9",
    "fee": null | {"amount":10,"currency":"SEK"} | "free",
    "opening_hours":"Mo-Fr 06:00-22:00; Sa,Su 07:00-21:00",   // OSM opening_hours syntax
    "hours_source":"osm|manual|website","hours_verified":"2026-10-xx"
  }]
}
```
Rules: every platform has at least one edge to the main graph; every POI attaches to a node; the validator fails the build if a platform is unreachable or an edge has no seconds. Edge `seconds` are **walking seconds at normal pace, no luggage**; speed multipliers apply at runtime. Keep the data format independent of the renderer so a nicer map can replace the first one later.

### Renderer (C1)
- **Do not use MapLibre with a fake world coordinate system.** Render the station as an **SVG scene** (pan, pinch-zoom, level switcher), styled with the DESIGN.md tokens. A schematic look (clean, simplified shapes) is intended: we are a designed map, not a CAD plan.
- Visual style: dark `surface` background; building outline in `surface-raised` with a hairline stroke; platforms as elongated rounded bars with the platform number in a clear chip, in a muted tone; halls as soft filled areas; stairs/escalators/lifts as small glyphs; amenity pins as circular badges with a category icon (inline stroke SVG, no emoji), grouped by category color but desaturated so the layover path stays the star.
- **Open/closed state on pins:** open = full brightness with a small green dot; closes soon (within 30 min of the reference time) = amber dot; closed = dimmed to ~35 % opacity with a grey dot; unknown hours = normal brightness with a "?" and "Hours unverified" in the sheet. The "reference time" is **now** by default, or **the layover window** when the Layover Guide is active (see below), or a user-chosen time via a small time chip ("Now" / pick time).
- Level switcher (chips L0, L1, ...) when a station has more than one level; auto-select the level of the highlighted platform in Layover mode and show small "up/down" connectors.
- Tapping a pin opens a bottom sheet: name, category, fee, today's hours, open-now status, "closes in 25 min", source and "verified on" date.
- Category filter row: Toilets, Food, Shops, Tickets, Lockers, Info. Toggles dim others rather than hiding, so orientation is kept.
- Station header: name, "Departures" button (to Feature B), "Show on live map", a "Data quality" label (e.g. "Hand-curated, verified Oct 2026") so users know how much to trust it.
- Accessibility: all pins and the path have text equivalents in a list view ("List" toggle shows amenities as a sorted list with open status). Path respects reduced-motion (no marching ants, static dots).

### Amenities and hours logic (C2)
- Parse hours with an `opening_hours` library (e.g. the `opening_hours` npm package, or equivalent) and evaluate in `Europe/Stockholm` including public holidays (Swedish holiday set). Unit-test: overnight spans, holidays, "closes in" computation, unknown hours.
- Hours are **static data**, not live. State this honestly in the UI ("Opening hours as listed; may differ on holidays").
- A "Report a problem" link per pin is P2, but store a `reports` table now if cheap; do not build a moderation UI yet.
- Stale data: if `hours_verified` is older than 12 months, show a subtle "May be out of date".

### Routing and walking times (C3)
- Build a graph from `nodes` and `edges`; Dijkstra or A* over `seconds`. Graphs are tiny; compute on the client or server, whichever fits existing code, but the same module in `packages/shared` should be usable by both.
- Walking profile in Settings: **Pace** (relaxed / normal / brisk, multipliers 1.25 / 1.0 / 0.8), **Step-free only** (excludes stairs and escalators), **Heavy luggage** (adds time on stairs/escalators and prefers lifts). Default: normal.
- Path output: ordered list of nodes with level changes, total seconds, total meters (if geometry available), and a list of human instructions generated deterministically from node types ("Take the stairs up to the main hall", "Follow signs to track 7", "Take the lift down"). No AI, templates only, i18n keys.

### Layover Guide (C3)
**Trigger:** a journey (SPEC.md §13) with two consecutive legs where leg A alights at station S and leg B boards at station S. It also works for a single leg selected manually through "Plan a change" on the station map (P2).

**Inputs, all live:**
- Arrival platform and estimated arrival time of leg A.
- Departure platform and estimated departure time of leg B.
- Walking profile from Settings.
- Station map for S, if one exists.

**Computed:**
- `layover = est_departure_B - est_arrival_A`
- `walk = shortest path seconds (platform A to platform B)` plus a small fixed `deboard` buffer (default 60 s, configurable) and `board` buffer (default 30 s).
- `slack = layover - walk - buffers`

**Status chip (reuse delay band colors so users learn one language):**
- Green "Easy connection": slack ≥ 5 min.
- Yellow "Tight": 0 ≤ slack < 5 min.
- Red "Likely to miss": slack < 0.
- Grey "Unknown": a platform is not yet assigned, or no station map exists. Show the plain layover duration only, and the platform if known.
- If leg B is cancelled or leg A is cancelled, show a red outlined banner "Connection broken" and keep the map for reference. Do not suggest alternatives in this version (that needs a journey planner, which we do not have).

**Map presentation when active:**
1. The station map opens zoomed to fit both platforms and the path.
2. Arriving platform highlighted with a chip in the **operator color of leg A** labeled "Arrive · Track 2 · 14:32 (+6)". Departing platform highlighted with a chip in the operator color of leg B labeled "Depart · Track 7 · 14:55".
3. A **dotted path** between them in the Clack accent color (`#4C8DFF`), 3 px round dots, marching toward the destination (paused with reduced motion), with a soft glow like the route line. Level changes show a small step/lift glyph on the path and the level chip switches as the user scrubs or taps "Next step".
4. A floating card at the bottom: big walking time ("5 min walk"), the slack chip ("Easy connection · 12 min to spare"), and the layover window ("Layover 14:32 – 14:55 · 23 min").
5. **Amenity filter by layover:** pins are evaluated against the *layover window* not "now". Open for the whole window = full brightness; opens/closes during the window = amber with "Closes 14:45"; closed during the whole window = dimmed. Optional "Along my path" toggle shows only POIs within ~40 seconds of the path, sorted by detour time, with "+1 min detour" labels. This is the feature the user cares most about: find a coffee that is open, on the way, and still make the train.
6. **Live updates:** if the platform, delay or cancellation changes (the existing live pipeline already emits these), recompute path and slack immediately, flash the changed chip, and add a line to the activity log ("Platform changed to 9, +3 min walk"). Push notifications are still out of scope but the recompute should be a pure function so they can be added later.
7. A "Start walking" mode (P2) is not needed now.

**Where it appears in the product:**
- Journey view (DESIGN.md Journey section): each connection shows a compact connection card (platforms, walk time, status chip) and a button "Open station map".
- Trip detail: when a trip is part of a journey with a connection, a "Connection" row above the stop timeline.
- Live hero card on the Trips tab: when the next event is a connection, show "Change at Hässleholm · Track 2 to 5 · 6 min walk · Tight" instead of the generic next-stop line.

**Fallback when no station map exists (do this from day one so the feature degrades gracefully):**
- Show platforms, layover duration and the status chip using an **estimated** walk time derived from station size class (small 2 min, medium 4 min, large 7 min, configurable table) and a clear label "Estimated, no station map". Colors: never green when the estimate is the only basis; cap at yellow ("Tight") or show grey "Check signs" unless slack is ≥ 15 min.
- Same station-size table is used if a map exists but the two platforms are not connected in the graph (log an error for the data team).

### Authoring and maintenance (C1/C4)
- Provide `scripts/stations/draft-from-osm.ts`: given a station id, fetch OSM data, produce a draft JSON and a simple preview HTML. Provide `scripts/stations/validate.ts` (also runs in CI).
- Provide a dev-only preview page `/dev/station/:id` that renders a station and lets me click two platforms to see the path and time. This is how we QA hand edits. It does not need to ship to production.
- Keep a `CHANGELOG` per station (who/when/what) inside the JSON `sources` or a sibling file.
- Honest data labels in the UI: "Hand-curated", "From OpenStreetMap", "Estimated".
- Realistic expectation: authoring one major station properly takes real hours. Prioritize by passenger volume and by stations that appear in the user's own trips (a "request a station map" count in a table is enough for now).

### Acceptance criteria (C)
- C0: `STATION_DATA_FINDINGS.md` exists with the per-station table and a recommendation.
- C1: the pilot station renders on desktop and phone, pans/zooms, level switcher works, platforms are labeled, tap-through to the Departures board works.
- C2: tap on any pin shows hours and open/closed; at 23:30 on a Sunday the kiosk with Mo-Su 06-22 hours shows closed; unit tests cover the hours logic including holidays.
- C3: choosing Track 2 → Track 7 on the pilot station gives a path whose time matches a manually walked estimate within about ±1 minute; step-free mode avoids stairs; a platform change updates the path within one live refresh.
- Layover chip logic is covered by unit tests: easy, tight, miss, unknown, cancelled leg, no-map fallback.
- With no map for a station, the connection card still shows platforms, layover and an estimated walk, labeled as an estimate.

---

## Feature D — On-board amenities (research spike only, not a build commitment)

**Goal:** find out whether we can honestly show per-train facts such as bistro/café car, vending, Wi-Fi, power outlets, quiet car, bike space, step-free access.

**Spike (`ONBOARD_DATA_FINDINGS.md`, timebox, same rules as C0):**
1. Does any open feed carry this? Check Trafikverket `TrainAnnouncement` fields (e.g. `ProductInformation`, `TrainComposition`, `Deviation`, anything about service), GTFS Sweden 3 (`trips.txt` extensions, `attributions`, `bikes_allowed`, `wheelchair_accessible` are standard GTFS and likely present), and the other Trafiklab APIs.
2. Operator public info: SJ and others publish what train types offer on their sites. Is it structured, or only prose? Which terms allow reuse?
3. Rolling-stock identity: can we know *which* unit or type operates a specific departure (X2000, Snabbtåg, Regina, Itino, etc.)? If not, per-train facts are impossible and only per-type "typically" claims remain.

**Possible outcomes (decide after the spike, not before):**
- A: real per-train data exists → show icons in the trip detail and board rows.
- B: only per-train-type data → show "Typically: café car, Wi-Fi" labeled as typical, from a small hand-maintained table (`data/train-types.json`) with a verified date, never as a promise.
- C: nothing usable → drop it. Do not fake it.

Use standard GTFS `bikes_allowed` and `wheelchair_accessible` where present, since they are free and factual.

---

## Cross-cutting changes

### Data model additions (adapt to existing schema; check for what Phase 1 already has)
- `station_favorites(user_id, station_id, created_at)`
- `station_recent(user_id, station_id, last_viewed)` (may be local storage only)
- `station_requests(user_id, station_id, created_at)` (counts demand for station maps)
- `user_settings`: add `walk_pace` (relaxed|normal|brisk), `step_free_only` (bool), `heavy_luggage` (bool), `deboard_buffer_s`, `board_buffer_s`
- Station map JSON files live in the repo, not the DB; a small `station_maps` table holds `station_id`, `version`, `quality` (curated|osm|estimated), `updated_at` for the UI.
- No table for live positions. Keep them in memory.

### API additions (names are suggestions; match existing conventions)
- `GET /api/stations/search?q=`
- `GET /api/stations/:id`
- `GET /api/stations/:id/board?type=&from=&to=`
- `GET /api/stations/:id/map` (returns the station JSON or 404)
- `GET /api/live/trains?bbox=&zoom=` plus push channel for deltas
- `GET /api/journeys/:id/connections` returning connection objects with platforms, times, walk estimate and status, for the Journey view and hero card

### Navigation and design
- Follow DESIGN.md tokens, type, spacing, motion. New screens to add to DESIGN.md as a short appendix (or as `DESIGN_ADDITIONS_01.md`): Station search, Board, Live map, Station map, Layover Guide card. Keep the split-flap digits on board times and walk-time numbers.
- New colors are not needed. Reuse delay bands for connection status and board rows. The dotted layover path uses the accent color.
- Add the new data sources to the in-app Sources page: OSM (ODbL attribution required), any station owner data, with licenses.
- All new strings through i18n (en, sv at minimum).

### Performance and cost
- Free or cheap: no new paid services. Station maps are static JSON, the live map and boards reuse one upstream connection each.
- Document the expected request rates to Trafikverket in `README` and make polling intervals env-configurable.

### Testing
- Unit tests: board normalization, platform-change detection, hours evaluation, routing (including step-free), layover status thresholds, no-map fallback.
- A recorded-fixtures mode so the live map, boards and layover guide can be demoed and tested without live data (replay a captured day).
- Manual QA script: pick a real connection, compare the app's platforms and walk estimate against the station signs.

---

## Suggested execution order for Claude Code

1. Read SPEC.md, DESIGN.md, DATA_FINDINGS.md and the current code. Write a short note on what already exists that these features can reuse (station search, announcement normalization, live pipeline, operator branding, route shapes). Share it before building.
2. **Feature B** (boards): station page, board endpoint, shared polling with refcount, Add to my trips handoff.
3. **Feature A** (live map): ingest and fan-out, viewport subscription, markers with interpolation, select-a-train sheet, filters, stale-data state.
4. **C0 spike** and `STATION_DATA_FINDINGS.md`. **Stop and report** with the recommendation before C1.
5. **D spike** can run in parallel with step 4, same report-and-stop rule.
6. C1 → C2 → C3 on the pilot station, then fallback mode for stations with no map, then C4 rollout.
7. Update DESIGN.md/SPEC.md references and the Sources page.

Report after each numbered step with: what works, what is mocked, anything that deviated from this document and why.

## Open questions for the owner (do not block on these)
- Which station should be the pilot? Default to whichever has the best OSM indoor data after C0.
- Navigation placement of Stations and Live (tab versus header icons).
- How much walking-profile customization is worth exposing at launch.
- Whether we want a user-facing "Report a problem" on map data before public launch (recommended).
