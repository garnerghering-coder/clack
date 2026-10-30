# Build 54 buildout (one TestFlight build): accurate positions, network detail, planner, station maps, native look, Ride view, 3D trains, delay history, 3D stations

## Gameplan: one build, many sessions (Garner, 2026-10-28)

Everything below ships together as **build 54**, with no TestFlight in between. The work alternates between two kinds of session, each in its own chat: **engineering phases** (1 and 3: novel, hard-to-verify work where precision decides the result) and **build phases** (2 and 4: well-specified features, careful bulk research, integration). Garner carries this plan from chat to chat, in order: Phase 1 → 2 → 3 → 4.

Every chat starts by reading `docs/buildout/BUILDOUT.md`, which is this plan plus a running log. It ends by updating that log: what's done, what's verified with numbers, what's open, what the next phase needs, and file pointers. Then Garner pushes to GitHub and opens the next chat.

### Step 0 (done 2026-10-28)
- `MAPILLARY_TOKEN` is in `.env` (never commit it); placeholder in `.env.example`. Read it with `process.env.MAPILLARY_TOKEN` or from `.env` in scripts.
- This file was created.

### How to start each chat (Garner pastes this)
> Read `docs/buildout/BUILDOUT.md` and the project's CLAUDE.md files, and follow them. You are running **Phase N**. Do every item of your phase in order, verify each as its "done when" says, commit by path, deploy the server where the phase says, then update the log in BUILDOUT.md and tell Garner what to push and what to check.

**Server changes deploy after each phase.** They stay compatible with build 51 on phones, and measurements gather real data. Phone checks use direct Xcode installs, never TestFlight before Phase 4.

**Station videos (Garner, 2026-10-28): files, tools, rules**
- **Garner has permission to use these walking-tour videos.** There are no licence notes per file.
- **Today they are in `~/Downloads/` (`/Users/garnerghering/Downloads/`):**

  | File | Station | Station id |
  |---|---|---|
  | `Helsinki.mp4` | Helsinki | `fi:HKI` |
  | `Oslo.mp4` | Oslo S | look up in `stations` |
  | `Gothenburg.mp4` | Göteborg C | `740000002` |
  | `Malmo.mp4` | Malmö C | `740000003` |
  | `Stockholm.mp4` | Stockholm C | `740000001`; check in `stations` |
  | `Copenhagen, Denmark  Central Train Station  City Tour  4K  Winter  København, Danmark  2023 - Vision Walking (1080p, h264).mp4` | København H | `860000626` |

- **First step of F2:**
  - Move them into `~/Downloads/station-videos/<station id>/`, keeping their names.
  - Write `~/Downloads/station-videos/INDEX.md`, listing file, station, duration and resolution.
  - More videos Garner adds later go in the same folder, one subfolder per station (or loose in `~/Downloads/station-videos/`, to be sorted by the next chat).
  - These folders are outside the repo, and nothing from them is committed.
- **Tools:** no ffmpeg on this Mac (checked 2026-10-28). Frames are extracted with a small native script, `scripts/stations/frames.swift`, using AVFoundation's `AVAssetImageGenerator`:
  - one frame every 2 s, plus extra frames on scene changes
  - JPEG, 1280 px wide
  - output in `~/Downloads/station-videos/<id>/frames/`, outside the repo
  - Apple's Object Capture (`PhotogrammetrySession`, RealityKit on macOS) is tried for 3D on steady stretches. COLMAP is not installed and isn't needed.
- **What the models do with frames:** they look at them (images can be read directly) to note:
  - entrances, stairs, escalators and lifts, and where they lead
  - platform numbers and sector signs
  - toilets, shops, ticket machines and waiting rooms
  - the order of things along the walk

  Each fact goes into the station file cited as `"source": "video supplied by the owner: <file> @ mm:ss"`.
- **What's kept:** frames and videos are never committed, shipped or shown. Faces are ignored. Videos are used for *what exists and where, roughly*. They are **not** used for exact distances or heights, which come from OSM, operators' plans and Garner's AR walks.

### Phase 1 (engineering). Hard cores, specs and proofs (one chat; if it runs long, log progress and continue in a new engineering chat)
- **F1. Positioning engine, server side (full spec: §A items 1–8 below).**
  - The standing/platform model.
  - GPS snapping and track-direction headings.
  - The run profile.
  - No 95% freeze.
  - Dead reckoning + blend.
  - Parallel tracks.
  - Trains at their first station.
  - Finnish accuracy, Danish timestamps.
  - **GPS-lag instrumentation**, delivery lag and timestamp offset per source, which starts collecting from the first deploy.
  - The `GET /api/live/segment?from&to` endpoint, ready for the app work in F4.
  - The `position-check` CLI, with baseline numbers in `docs/POSITIONING.md`, run before and after.
  - Deploy.
  - **Done when:**
    - unit tests pass for every §A item
    - `position-check` before/after numbers are in POSITIONING.md
    - the lag histograms are collecting on the hosted server
    - `/api/health` stays under 1 s after the deploy
    - build 51 on phones still works (no removed fields)
- **F2. Station data model v2 and the pipeline (full spec: §D below; uses the videos as described above).**
  - **Schema:** 3D-ready, with level heights, platform edges, stairs/escalators/lifts with their ends, and the source of every element.
  - **OSM re-extract** with platform, level, steps and elevator tags.
  - **Drafter and validator.**
  - **Evidence pipeline:**
    - **OSM** geometry.
    - **Operators' published plans**, for facts only.
    - **Mapillary and Wikimedia Commons** photos, plus any other open source found (licences recorded).
    - **Garner's videos:** frames come from `scripts/stations/frames.swift`, and the model reads them for signs, stairs, lifts and platform numbers. Object Capture is tried on steady stretches. Each fact cites its file and timestamp.
    - **Walk logs** with AR.
  - The model reads images directly. Video is turned into frames first.
  - **Reference stations:** builds and verifies 7 as the template:
    - the six with videos: Stockholm C, Göteborg C, Malmö C, København H, Oslo S, Helsinki
    - Jönköping C, which has Garner's AR walk (uploaded walk logs on the hosted server under `data/walklogs/`; fetch with the allowlisted `GET /api/walklogs`)

    The four Swedish ones already have maps, so the existing map is checked against OSM and the video, and extended where they show more.
  - **Handbook:** writes `docs/STATION_MAPPING.md` so a build phase can repeat it for the rest.
  - **The app reads schema v2:** the current station map screen still works with it, and with old files.
  - **Done when:**
    - the 7 reference stations pass the validator, every element sourced
    - positioning places standing trains on their platforms at those stations
    - the existing station-map screens show them correctly in the simulator
- **F3. 3D train kit and the map-camera proof (full spec: Build 53 section, "Simple 3D trains").**
  - The five generic templates.
  - Full composition parsing: Swedish Vagnsordning for all units, Digitraffic wagons.
  - Car counts per type and route, labelled "about N cars".
  - Cars placed along the track.
  - A **proof screen:** MapKit realistic elevation with the RealityKit train overlay synced to `MKMapCamera`, following a replayed trip. It answers whether the sync holds before Phase 2 builds the Ride view on it.
  - The proof screen is Debug-only, reached with a launch argument.
  - **Done when:**
    - every train type maps to a template
    - car counts are tested against real compositions
    - the proof runs in the simulator, with measured frame times
    - the verdict is written in the log

**Phase 1 leaves for Phase 2 (written into the log):**
- **F1:** the new `LiveTrain` fields and endpoints, documented. The first numbers in `docs/POSITIONING.md`. The server deployed.
- **F2:** `docs/STATION_MAPPING.md`, a step-by-step handbook that a build phase can follow without judgement calls. The tools and their commands, including `frames.swift`. 7 reference stations that pass the validator. The list of the remaining stations in order.
- **F3:** the train-kit API (how to place a train with N cars along a polyline) and the proof screen. A plain verdict on whether the MapKit + RealityKit sync holds, with a frame-time measure. If it doesn't hold, the fallback Phase 2 should use instead (MapLibre with a Metal custom layer).

### Phase 2 (build). Features and bulk research on the cores (one chat, continued in new build chats as the log says)
- **O1. Native foundation (§E):**
  - Replace the custom controls with system ones.
  - Both filter sheets become `Form`.
  - DESIGN.md is updated.
  - The design lint flags the old controls.
  - **Done when:** the lint passes with the new rules, and the simulator screenshots of every touched screen are checked.
- **O2. Planner and network detail (§B, §C):**
  - Up to 5 changes, pruning, earlier/later and next-day paging.
  - The corridor highlight and CorridorSheet (using F1's station ids).
  - **Done when:** the tests pass, timings stay under 1 s on the hosted data, and the simulator checks are done.
- **O3. Ride view and Explore on Apple Maps:**
  - **Ride view**, on F3's proof: camera presets, speedometer (phone GPS once aboard is confirmed), trip panel, portrait and landscape, Live Activity.
  - **Explore on Apple Maps** behind a switch, with the frame-time readout.
  - Garner checks both on his phone with a direct install.
  - **Done when:** the Ride view runs a replayed trip in the simulator and Garner has tried both on his phone. Explore stays on MapLibre unless he says switch.
- **O4. Delay history:** `stats/punctuality.ts`, the history-aware verdict in TypeScript and Swift, the line on the train leg, `RiskCard` for all four countries, and the written sample check.
  - **Done when:** the sample check is in `docs/` and the shared TypeScript/Swift tests pass.
- **O5a–O5c. Station maps, about 30 per chat:** the remaining hub and mid-tier stations, following `docs/STATION_MAPPING.md` (all evidence sources and Garner's videos as they arrive). Each passes the validator, and each chat reports its review queue to Garner.

### Phase 3 (engineering). Precision and the hardest visuals (one chat, continued as needed)
- **F4. Positioning tuning on a week of measured data:**
  - Lag correction set per source.
  - Run-profile constants checked.
  - App motion along the track with extrapolation, and animated headings.
  - Before/after `position-check`.
- **F5. 3D trains on Explore when zoomed in**, on whichever engine Garner chose after O3, standing on their platforms. Also a polish pass on the Ride view's 3D from his ride feedback.
- **F6. 3D station view:** RealityKit rendering of the station data, with levels at their measured heights and trains pulling in at live platforms and times. It works for every mapped station; stations without a map keep today's view.

### Phase 4 (build). Integrate and ship (1 chat)
- **O6:**
  - full tests and the design lint
  - Release-sim checks of every changed screen
  - health and station-coverage reports
  - build bump to 54, deploy, TestFlight
  - release notes
  - close the log

**Rules that hold in every session:**
- Accuracy first: everything is sourced, and unverified things are said to be unverified.
- Native controls (§E).
- Zero running costs.
- Commit by path with a body that says why.
- Garner pushes.
- No TestFlight before O6.
- Videos as above: facts only, frames never kept in the repo.

## The plan in detail (from the earlier builds 52–55 outline)

## Context

Garner (2026-10-28) wants a much richer map:
- Apple's map look, with 3D buildings and terrain.
- Train positions that are more truthful: a train standing at a station is shown at that station.
- A "Ride view" for a journey you're on: a close third-person camera behind the train, a speedometer (helped by the phone's GPS), and trip information, in portrait or landscape.
- Low-poly 3D trains with several cars that follow the track, also on Explore when zoomed in.
- Later, 3D station maps with trains pulling in and out.

He also folded the planned build 52 (network detail, planner) into this work.

**Decisions (Garner, 2026-10-28):**
- **Map engine: prove it, then switch.**
  - The Ride view is built on Apple Maps (MapKit) first.
  - Explore gets an Apple Maps version behind a switch, tested with ~700 moving trains on his phone.
  - Explore only switches for good if it stays smooth.
  - MapLibre stays for offline maps.
- **Order:**
  - 52: network detail, planner, positioning overhaul.
  - 53: Ride view.
  - 54: 3D trains on Explore, plus delay history.
  - 55: 3D station maps.

**What the code does today, and what's wrong with it (positioning):**
- **GPS:** fixes from Trafikverket, Entur and Digitraffic are shown raw. They are filtered for jumps (`live/sanitize.ts`) but never snapped to the track.
- **Estimates:** each train moves along the routed OSM line between its last and next station by a constant fraction of time, capped at 95% (`ingest.ts:511-516`, `norway.ts:281`, `finland.ts:326`).
- **Standing trains:** they sit at the station centroid. Single station points come from GTFS parent stations (`stations.lat/lon`); platform coordinates are thrown away at import. Platform geometry with track ids exists for 15 Swedish stations (`data/stations/*.json`, `platformForTrack` in `packages/shared/src/station.ts:255`). The live map doesn't fetch `TrackAtLocation` at all.
- **Concrete weaknesses:**
  - **Stuck short of the station:** Swedish trains freeze at 95% when no arrival is reported.
  - **Jumps:** when GPS goes stale after 2 min, a train switches straight to the estimate (no dead reckoning).
  - **Unplaced trains:** Swedish trains at their first station without GPS aren't drawn at all.
  - **Off-track line ends:** routed lines end at station centroids, off the track (`railGraph.ts:251`).
  - **Parallel tracks:** they are chosen by shortest path, not direction of travel.
  - **Rough headings:** Finland and Norway (except Flytoget) point toward the next station. Denmark's lags a poll.
- **App:** markers glide in a straight line for 1.5 s, then freeze until the next update, which can be 10–20 s away (`ExploreLogic.glide`, `ExploreModel.apply`). There's no extrapolation and no animated heading.
- **Composition (for drawing cars later):** Sweden parses "Vagnsordning" into cars of the first unit and the number of units, but doesn't send it to the app. Finland keeps only the lead vehicle type, though Digitraffic has wagons and lengths. Norway and Denmark have nothing.

**Added by Garner (2026-10-28, second note):**
- **3D trains are deliberately simple:** a few generic designs, each adapted per use, with car counts matching what we know or estimate for each route (details in build 53).
- **GPS lag:** measure the delay between a fix and where the train really is, and draw the train forward by it (§A.8).
- **Station maps:** every hub and mid-tier station gets mapped (§D, a program that starts in 52 and runs through 55).
- **Native look:** Apple's own controls everywhere they exist; no hand-made buttons (§E).

## Build 52: positions you can trust, network detail, planner

### A. Positioning overhaul (server: `livemap/ingest.ts`, `norway.ts`, `finland.ts`, `denmark.ts`, `live/progress.ts`, `geo/railGraph.ts`)

1. **One "where is it" model per train:** `state: 'running' | 'standing' | 'waiting'` (`waiting` = before first departure), plus `prevId`/`nextId` (station ids), `platform` and `progress` along the segment.
   - These go on `LiveTrain` as small fields (`atStation`, `platform`, `prevId`, `nextId`).
   - The network-status `context` reuses them.
2. **Standing at a station:**
   - **When it counts as standing:** the feed says the train has arrived and not left (Sweden `lastWasArrival`, Norway/Finland "now between arr and dep"), or GPS speed under 3 km/h within 400 m of the station.
   - Standing trains are drawn at the platform when known, otherwise at the station.
   - **Platform:** Sweden adds `TrackAtLocation` to the announcement fields (`announcements.ts` FIELDS) and keeps the last row's track. Norway and Finland have the platform in their stop data (quay / `commercialTrack`).
   - **Platform → coordinate:** for the 15 mapped stations, `platformForTrack` → platform node → WGS84 (inverse of `toLocal`, `station.ts:310`).
   - **Everywhere else:** the station point snapped onto the nearest running track (`railGraph.snap`), so standing trains sit on rails, not on the station building.
   - The train sheet says it: "At Alvesta · platform 3".
3. **Running between stations:**
   - **Snap GPS onto the track:** project each fix onto the routed prev→next polyline when within 60 m. Heading comes from the track's direction at that point (toward the next station).
   - **Estimates follow a run profile instead of a constant fraction:** a trapezoid (accelerate, cruise, brake) solved from the segment length (`track_segments.lengthM`) and the scheduled or expected run time. Constants are 0.5 m/s² up and 0.6 m/s² down, each with a source note (typical EMU values from Trafikverket/Banverket running-time rules, checked when writing), and are tested.
   - **After the expected arrival time:** with no arrival reported, a train moves to the station's approach (the last 50 m), then to the platform as standing, in every country. This replaces Sweden's freeze at 95%.
   - **Stale GPS (older than 2 min):** dead-reckon along the track from the last fix at its last speed (the shared `liveView` already does this for trips, `progress.ts:257`). Then blend into the estimate over 30 s instead of jumping.
   - **Swedish trains at their first station without GPS:** drawn there as `waiting` until departure.
4. **Line ends on the track:** routed segments start and end at the snapped track points, not the station centroids (`railGraph.ts:251`).
5. **Parallel tracks:** where two running tracks lie within 12 m, pick by the country's running side. Sweden, Norway and Denmark run on the left on double track; Finland on the right. Sources go in the code. If a check against GPS shows this choice is wrong somewhere, it's turned off per country.
6. **Finland:** read Digitraffic's `accuracy` and drop fixes worse than 200 m.
7. **Denmark:** keep the time Rejseplanen's position is for, not the poll time.
8. **GPS lag, measured and corrected:**
   - **Measure it, per source.** Two numbers matter:
     - **Delivery lag:** our receive time minus the fix's own timestamp. Logged per fix, kept as a histogram per source.
     - **Timestamp offset:** whether the fix's timestamp is itself early or late. For Swedish trains, compare the moment the snapped GPS track passes a station's platform point with Trafikverket's reported passage time (`TimeAtLocation`) at that station. The same comparison works for Finland (Digitraffic actual times) and Norway (Entur recorded times).
     - Both are kept per source and train type in `live_quality`-style counters, and written up in `docs/POSITIONING.md` with medians and spread.
   - **Correct it:**
     - Every fix is extrapolated along the track from its own timestamp, by the train's speed × (now − fix time + the measured offset), never past a station where it stops.
     - The app keeps extrapolating until the next fix arrives.
     - If the measured offset turns out negligible (under 2 s median), only the delivery lag is corrected and the docs say so.

**App (`ExploreModel`, `ExploreLogic`, `LiveMapController`):**
- New `GET /api/live/segment?from&to` returns the track polyline for a station pair. It's cached on the phone and is the same data as `segmentBetween`.
- Markers move **along the track**, from the drawn position to the new one, over the expected time until the next update (Sweden ~3 s, others 10–20 s). After that they **extrapolate** at the train's speed (GPS, or the run profile) until the next update, never past a station where the train should stop.
- Heading animates along the track. Standing trains don't creep.
- No movement when far zoomed out, as now.

**Measuring it:** a CLI `position-check` for Swedish trains that have both estimates and later GPS. It reports the distance between our estimate and the GPS fix that arrives later (median and p90, before/after), plus standing-placement checks at the 15 mapped stations. Results are written to `docs/POSITIONING.md`. The overhaul ships only if the numbers are better.

### B. Network status detail (from the previous plan, unchanged)
- **Server:** corridors gain `stretches` (polylines via `segmentBetween`) and `trains` (id, number, operator, delay, next, causes). `context.prev` keeps the station id.
- **App:**
  - an orange `corridor` source and layers in the live style
  - `setCorridor` / `clearCorridor`
  - tapping a corridor fits the map, highlights the stretch and rings its trains
  - a draggable `CorridorSheet` (from `TrainSheet`, with a generic header) lists the stretch, its delays, the reasons with their source, and the affected trains. Tapping a train opens it. It refreshes every 30 s.

### C. Planner: up to 5 changes, sensible results, earlier/later across dates (from the previous plan, unchanged)
- `MAX_TRIPS = 6`. `changes` is 0–5, default 2. A window of `after` + `hours`.
- **Pruning:** drop journeys longer than max(1.5× the fastest, fastest + 3 h), and drop a journey with more changes than a near-equal one. Night journeys are judged against night journeys only.
- **Past midnight:** merge D+1's index.
- **Timing check:** Kolding → Kiruna and Jönköping → Narvik with 5 changes must stay under 1 s.
- **App:**
  - "Show earlier" and "Show later" buttons.
  - A date separator line when results cross into the next day.
  - The Changes control becomes Direct · 1 · 2 · 3 · 4 · 5.
  - One `defaultMaxChanges` constant replaces the fixed 3-entry arrays.

### D. Station maps for every hub and mid-tier station (program: starts in 52, about 20 per build)
- **Scope:** the reviewed tier list (`data/station_tiers.json`): 5 hubs + 94 mid, so about 99 stations. 15 are mapped today, all Swedish.
- **Research per station, recorded with sources:**
  - **OSM:** `railway=platform` with `ref` (track numbers), `level`, `highway=steps`/`elevator`, `building=train_station`, indoor tagging where present. These are fetched with the same extract tooling as `data/osm`.
  - **Operators' published station plans** (Trafikverket, Bane NOR, Banedanmark/DSB, Finnish Transport Infrastructure Agency): used for facts only, never traced.
  - **Garner's walk logs** where he has walked.
- **Tooling:**
  - **Drafter:** a script `scripts/stations/draft.py` builds a `data/stations/<id>.json` draft from OSM (platforms with track ids, levels, stairs and lifts, entrances). Every element carries `_source` (OSM way id), and the file carries ODbL attribution.
  - **Validator:** checks that every platform has its track ids, every level change has stairs or a lift, every platform reaches an exit, and the track ids match the ones in the timetable and boards.
  - **Review queue:** a generated list of what each draft is missing, for Garner or a walk.
- **Order:** busiest first; walked stations first among equals (Jönköping C second level, Nässjö, Malmö C, København H, Fredericia, Kolding, Alvesta).
- **Used by positioning:** every mapped station gives platform-level placement (§A.2). Its platforms also feed the 3D station view in 55.

### E. Native look everywhere (Garner: "iOS native, Apple stuff where possible")
- **Rule from now on:** use the system control wherever one exists:
  - `Picker(.segmented)`, `Toggle`, `Menu`, `Stepper`
  - `Button` with `.glass` / `.glassProminent`
  - system sheets with detents, `List`/`Form` sections
  - SF Symbols for system actions
- Clack's own tokens stay: colours, type, radii.
- **New screens in 52–55** follow it, and DESIGN.md is updated to say so.
- **Audit of the app's own controls:** each is replaced by its system equivalent where one exists (most in 52, the rest as screens are touched), and the audit is written into DESIGN.md:
  - `SegmentedControl` → system segmented `Picker` (Liquid Glass on iOS 26)
  - `ChipButton` → a system bordered/glass button, or a `Picker`/`Menu` where it's a choice
  - `MapButtonFace` → the system glass button
  - `LinkButtonStyle` → system plain buttons
  - custom checkbox rows → `List` selection rows
- The Explore filter sheet and the planner's filter sheet move to `Form` with native rows first.

## Build 53: Ride view on Apple Maps (MapKit)

- **What it is:** opened from a saved trip that's under way, or from a train sheet. Full screen, portrait or landscape.
- **Map:** MapKit `MKMapView` with `MKStandardMapConfiguration(elevationStyle: .realistic)`, which gives 3D buildings and terrain where Apple has them.
  - The train's route is an `MKPolyline` overlay.
  - The camera follows the train with `MKMapCamera`: heading = track tangent, with pitch and distance set per camera preset.
  - **Camera presets:** Behind (third person), Above, Side, Driver's eye (low, ahead). Pinch adjusts the distance; the choice is remembered.
- **Train:**
  - A RealityKit view layered exactly over the map, its perspective camera matched to the `MKMapCamera` each frame (heading, pitch, altitude).
  - Since the camera follows the train, the train stays at a fixed point on screen, and the overlay only needs to bend the cars along the track ahead and behind. The track is projected with `convert(_:toPointTo:)`.
  - It won't be hidden behind buildings; that's a MapKit limit, said plainly.
- **Simple 3D trains, a few generic designs (Garner: "super simple, nothing crazy"):**
  - Five templates, built in RealityKit from boxes and one rounded cab shape:
    - multiple unit (blunt cab)
    - high-speed unit (long nose)
    - double-deck unit
    - locomotive + coaches
    - railcar
  - Each train type in `data/train_types.json` maps to a template. Its art family already says which.
  - **Colouring:** the operator's livery colours are taken from the drawing (main body, window band). An unknown type stays unpainted, which keeps the accuracy rule.
  - **Car counts:**
    - Sweden: full Vagnsordning, all units.
    - Finland: Digitraffic compositions, parsed fully.
    - Elsewhere: an estimate per type and route from the timetable's typical formation, labelled "about N cars".
  - **Cars on the track:** each car is placed along the track polyline by distance behind the lead car, so the train bends through curves.
- **Speedometer and trip panel:**
  - **Speed:** the phone's GPS speed (Core Location, best accuracy) when the phone is confirmed aboard (moving with the train's reported position within ~1 km, and the trip is under way). Otherwise the train's reported or estimated speed, labelled as such.
  - **Panel:** next stop and ETA, delay, distance and time left, current section, line speed where OSM has `maxspeed` (re-extract that tag), altitude from the barometer.
  - **Location:** "While Using" is enough. A Live Activity keeps going in the background, as now.
- Reuses `OnboardView.swift` and `TripProgressView.swift` logic for progress and next stop, `LiveActivities` for the background, and the walk logger's sensor code patterns for GPS and barometer.
- **Explore on Apple Maps, behind a setting (Settings → Map engine: Clack / Apple, Test):**
  - Trains are drawn as one `MKOverlayRenderer` when zoomed out, and as annotation views when close.
  - Garner checks smoothness with ~700 trains on his phone. A frame-time readout is shown in test builds.

## Build 54: 3D trains on Explore when zoomed in, and delay history
- **3D trains:** at close zoom (street level), trains are drawn as the same generated cars along the track, standing at their platform. This works on whichever engine Explore ends up on. On MapLibre that means a custom Metal style layer with real depth; on MapKit, the RealityKit overlay.
- **Delay history:** the change verdict becomes history-aware, as decided earlier. A line on the train leg says how it usually runs ("Usually 15–20 min late at Alvesta, 19 of 28 days"). This uses `observed_runs`/`observed_calls`, with a written sample check before shipping.

## Build 55: 3D station maps with trains
- The station maps (`StationSceneView`, `data/stations/*.json` levels and platforms) are rendered in RealityKit:
  - platforms and levels extruded at their measured heights
  - stairs and lifts as ramps
  - the walk logger's barometer readings give the level heights (Jönköping C measured ~3.5–4 m)
- Trains pull in and out at the right platform at their live times (board data: platform, arrival, departure), using the generated 3D cars.
- Stations without a map keep today's view.

## Each phase
- npm test + typecheck, swift test, Xcode RunAllTests
- Simulator check of every changed screen (the Ride view and 3D also checked on Garner's phone with a direct install)
- Garner pushes, deploy the server, watch `/api/health` and `/api/live/health`
- Only Phase 4: bump `CURRENT_PROJECT_VERSION` to 54 on both targets, run the Release-sim checks, and upload to TestFlight (export with `signingStyle automatic`)

## Verification (build 52)
- **Positioning:**
  - Unit tests for:
    - the trapezoid profile (distance at time t, total time = scheduled time)
    - snapping (a fix within 60 m lands on the line, its heading follows the track)
    - standing placement (`lastWasArrival` + track → platform node at Alvesta and Jönköping C)
    - stale GPS → dead reckoning → blend
    - no 95% freeze
  - `position-check` numbers before/after in `docs/POSITIONING.md`.
  - **Simulator:** zoomed in on Stockholm C, standing trains sit on their platforms, and moving trains slide along curves without stopping between updates.
- **Network detail:** a corridor tap highlights track and opens the sheet. Server test: stretches carry polylines.
- **Planner:**
  - Tests for 5 changes, detour pruning and the midnight merge.
  - Timing on the hosted data.
  - Earlier/later and the date separator in the simulator.


## Log

Each session appends an entry: date, phase and item, what's done (with commits), what's verified (with numbers), what's open, and what the next phase needs. Newest last.

- 2026-10-28, Step 0: plan written and approved; Mapillary token in `.env`; this file created. Build 51 is on TestFlight and the hosted server runs commit 701540d. Next: Phase 1, F1.

- **2026-10-28/29, Phase 1, F1 done, F2 tooling done, F3 not started** (session ended on usage; continue in a new engineering chat). Commits `16cdfc9` (positioning) and `26eab4e` (station schema 2). **Hosted server runs `26eab4e`** (deployed 2026-10-29 ~01:30 CET; `/api/health` 0.08–0.12 s; `track_segments` cleared so lines re-route onto the track).
  - **F1, done and verified.** `apps/server/src/live/positioning.ts` (rules, pure), `live/locate.ts` (one locator for all four feeds), `live/placement.ts` (platform points via `platformPoint` in `packages/shared/src/station.ts`, station→track snapping, running-side choice), `live/quality.ts` (histograms, saved to `data/cache/live-quality.json`). Feeds rewritten to use them: `livemap/ingest.ts` (Sweden; `TrackAtLocation` and `TimeAtLocationWithSeconds` added to the announcement fields; waiting at the first stop from 10 min before departure), `norway.ts` (quay platform from `timetable_stop_times.platform`), `finland.ts` (`commercialTrack`; `accuracy > 200 m` dropped; passage offsets incl. non-stopping rows), `denmark.ts` (Rejseplanen's own answer time as `posAt`; positions put on our track). New `LiveTrain` fields `state | prevId | nextId | atStation | platform | progress | fixAt` (all optional; build 51 fine), moved tuple = 9 entries. Endpoints: `GET /api/live/segment?from&to` (polyline, lengthM; ids are ours or `trv:<sig>`), admin `GET /api/live/quality`. CLI `npm run import -- position-check [--minutes=N | --server=URL --admin=TOKEN]`. Routed lines end on the track (`railGraph.route` no longer appends centroids). Running sides from sources: **SE left; NO, DK, FI right** (the plan's "Norway and Denmark left" was wrong); exceptions boxed (Öresund link, Helsinki commuter area). Constants 0.5/0.6 m/s² are the plan's values, unverified against a Trafikverket rule (F4). 599 server tests pass; `test/positioning.test.ts` covers every §A item (profile, no-freeze, snapping+heading, platform placement at Alvesta and Jönköping C, dead reckoning+blend, waiting, side choice, passage times, histograms).
  - **F1 numbers** (docs/POSITIONING.md, 12 min live on the Mac, Sweden): delivery lag median 7.8 s / p90 14.1 s; arrival timestamp offset median +0.6 s (so `TIMESTAMP_OFFSET_S` stays 0); **run profile beats the constant fraction in every product's median** (commuter 452→386 m, regional 1104→995 m, high-speed 3886→2244 m), p90s unchanged (input errors, F4); standing checks: Stockholm C 15 m, Hässleholm/Malmö ~200 m (platform *middle* vs a short train), **Lund C broken (7/12 > 3 km, cause not investigated)**; track-side agreement SE 65% on the Mac run, but **33% (n 40) in the first minute on the server**: treat the Swedish side rule as unverified; F4 decides per line with a week of data. The server has been counting all four sources since the deploy (first minute: DK 65%, NO 74%, FI 100% agreement, small n).
  - **F2, partly done.** Schema 2 in `packages/shared/src/station.ts` (`schema`, `_source` everywhere, `height_m` on levels/platforms/buildings, `PlatformEdge[]` per platform with `track|null`, `ref` on track shapes, `direction` on escalators; `validateStationMap` enforces sources, no walk across levels, every platform reaches an entrance; `stationReview()` = the review queue). `scripts/stations/draft_from_osm.py` writes schema 2, fetches from **Overpass via curl** when no PBF (`data/cache/stations/<id>-osm.json`, 7 reference stations already cached on the Mac), computes platform edges along nearby rails (track from the rail's `railway:track_ref`/`ref`, or the platform's only track, else `null` for review; edits key `platform_edges` sets sides from a plan/video), carries OSM way/node ids as `_source`, reads `levels[].height_m/height_source`, `platform_heights`. `npm run stations:validate -- --review` writes `data/stations/REVIEW.md`. `scripts/stations/frames.swift` (build with `xcrun swiftc -O -module-cache-path /tmp/clack-tools/mc -o /tmp/clack-tools/frames scripts/stations/frames.swift`; plain `swift x.swift` fails on this Mac). Videos moved to `~/Downloads/station-videos/<id>/` with `INDEX.md`; **all six are frame-extracted** (`<id>/frames/`, 567–1 715 JPEGs each + `index.json`); `740000001/FACTS.md` (Stockholm C) exists from a partial read. Swift `StationMap` model reads the new optional fields (ClackKit builds). Server `stationMap()` accepts `fi:HKI` → `fi_HKI.json`. **Jönköping C re-drafted as schema 2 and valid.** Oslo S: `760000100.edits.json` written (multipolygons on, levels -1/0/1/2 named by number); its draft produced 1 connected platform of 15 and was deleted again (not committed) — the relation-ring platforms don't join the footway graph yet (platform access points, level assignment for rings without `level`). **Open:** Oslo S, København H (`860000626`), Helsinki (`fi:HKI`, edits file must be `fi_HKI.edits.json`) drafts; re-draft Stockholm C, Göteborg C, Malmö C with schema 2 (their edits files exist; check `drop_*`/connections still apply to the fresher OSM); `_source` for hand edits in the 15 old edits files (`connections[]._source`, `pois[]._source`); platform `height_m` and level heights (Jönköping C: Garner's AR walk via `GET /api/walklogs`); `docs/STATION_MAPPING.md` (not written); check positioning places standing trains on platforms at the 7 (the Alvesta/Jönköping C test shows the mechanism; `position-check` standing table shows reality); simulator check of station map screens with a schema-2 file.
  - **F3: not started.** No RealityKit/MapKit code exists in the app yet; Sweden's `parseComposition` still keeps only the first unit's cars; Finland's `vehicleOf` only the lead type.
  - **Rules learned this session (Garner):** do not read video frames one by one (it burned most of a session); use OSM, plans and the existing FACTS.md, and at most a handful of frames per station when a specific fact is needed. Keep tool output small.

- **2026-10-29, Phase 1 finished: F2 and F3 done** (continued in a build chat after the engineering chat ran out of usage). Commits `9885bd7` (seven reference stations, schema 2), `9a2d417` (handbook), and the 3D kit + proof commit after it. **Not yet deployed: Garner pushes, then deploy** (`git pull`, `npm ci`, `systemctl restart clack`); the hosted server still runs `54ba23e`.
  - **F2 done.** All seven reference stations pass the validator in schema 2: Stockholm C (17 platforms), Göteborg C (16), Malmö C (11), Jönköping C (2, now with its upper level), Oslo S (13 of 18 connected), København H (7), Helsinki (20). Drafter gained `default_level` (Norway numbers the ground floor 1), hand-placed `entrances`, and manual sources that cite the edits file and entry. Jönköping C's upper level is +3.3 m from the owner's AR walk (barometer +3.5, ARKit +3.1), with the two escalators and the Juneporten entrance placed from the walk's marks (GPS ±10–13 m). `docs/STATION_MAPPING.md` is the handbook. The station map screen shows a schema-2 file in the simulator (Jönköping C against the hosted server).
  - **F2 open (for Phase 2's station batches and Phase 3):** Oslo S platforms 5–6, 7–8, 11–12, B11, B12 unconnected (OSM footways don't reach them; Bane NOR's plan or the video decides); København H has only 7 of its 12 platforms as refs (the rest are relation rings without `ref` in OSM; DSB's plan gives the numbers); level names at Oslo S, København H and Helsinki are still "Level N"; no platform heights anywhere; the standing-placement check at the 7 is still to be read off `/api/live/quality` after the deploy (the server's `data/cache/live-quality.json` wasn't there on 2026-10-29 01:30, so the counter file may not be written on the hosted server: check `quality.ts` and the service's working directory). Videos: only Stockholm's FACTS.md exists; the handbook says how the others are used (a handful of frames, facts only).
  - **F3 done.** `TrainKit` (ClackCore, pure, tested): five designs mapped from the type's art family, car count = feed → type's stated count → default, cars placed along a polyline bending with it. `TrainScene` (app, RealityKit): box-built cars coloured from the operator's brand colour, grey when unknown. Compositions: Sweden's `parseComposition` now returns `totalCars`/`unitCars` over all units; Finland's `fetchDayVehicles` returns `{vehicle, cars, lengthM}` from the wagons (verified 2026-10-28 on /compositions/2026-10-28/27: Sr2 + 6 Ed, 178 m); `LiveTrain.cars` carries it (Sweden, Finland). `data/train_types.json` has `cars` on 17 types whose text states the count.
  - **F3 verdict: the MapKit + RealityKit sync holds.** Proof screen `-open rideproof` (debug): `MKMapView` realistic elevation following a replayed 120 km/h run Stockholm C → Uppsala C (`/api/live/segment`), RealityKit `ARView(.nonAR)` over it, its camera set from the map's *actual* camera each frame (MapKit clamps the requested pitch), FOV read off two projected points. Simulator, iPhone 17 Pro: frame work 1.0 ms median / 1.5 ms p90; projection of the front car differs by 11 px steadily (about 1 m at 320 m) — a constant offset, so a one-time calibration term will remove it. Phase 2 can build the Ride view on this; no Metal fallback needed. Known limits: trains aren't hidden behind buildings; the map's 3D buildings exist where Apple has them.
  - **Next:** Phase 2 (build chat): O1 native foundation, O2 planner + network detail, O3 Ride view on this proof + Explore on Apple Maps behind a switch, O4 delay history, O5 station batches per `docs/STATION_MAPPING.md`.

- **2026-10-29, Phase 2, O1 and O2 done** (build chat). Commits `71717ad` (O1), `36d04ba` (O2 server), `00ab380` (O2 app).
  - **O1 done.** `SegmentedControl` wraps the system segmented `Picker`; `LinkButtonStyle` is the system borderless style; the Explore filter sheet and the planner's filter sheet are `Form`s. `scripts/ios/lint_design.py` flags hand-made checkmarks and non-segmented picker styles (passes). DESIGN.md has the native-controls paragraph. Screens checked in the simulator.
  - **O2 done, server.** `search/planner.ts`: `MAX_TRIPS = 6`, exported `rank()` (dedupe; detours over max(1.5× fastest, fastest + 3 h) dropped; a near-equal with more changes dropped; night journeys ranked among night journeys). `routes/search.ts`: `changes` 0–5 (default 2), `after` + `hours` (1–24, default 6) window, planned on the day the window falls in plus the next day's index when it runs past midnight, `window: {start, end}` in the answer. `livemap/network.ts`: corridors carry `stretches` (`a, b, aId, bId, polyline` via `segmentBetween`) and `lateTrains`. Tests: `test/planner.test.ts` (ranking), `test/network.test.ts` (stretches + late trains), 604 server tests pass.
  - **O2 done, app.** `AddTrainModel`: `defaultMaxChanges = 2`, `maxChangesLimit = 5`, asks with `changes=5` and filters locally; today's first page is now−10 min + 6 h, another day whole; `showEarlierJourneys`/`showLaterJourneys` add six hours a side, merged by departure without repeats; `daySeparator` writes the date where the list crosses midnight; "No more journeys found later" when a page is empty. `JourneyFilterSheet`: Direct · 1 · 2 · 3 · 4 · 5. Explore: `corridor` source + `corridor-glow/body` layers and a `train-corridor` ring layer (`MapStyle`), `setCorridor/clearCorridor` (`LiveMapController`), `ExploreModel.showCorridor/closeCorridor/watchCorridor` (30 s), `CorridorSheet` (stretch, delays, reasons with their source, late trains → tap opens). Strings in EN/SV; `add.upTo1/2`, `add.changesOne/Two` removed. Tests: `ClackTests/AddTrainPagingTests` (2), ClackKit 387.
  - **Timings (local DB, 2026-10-29, after the day index is built):** Kolding → Kiruna 5 changes 318 ms (1 journey, 4 changes, 1437 min), 2 changes 52 ms (none); Kolding → Helsinki 5 changes 316 ms (none); Jönköping → Narvik and Jönköping → Kolding 0 ms, 0 journeys locally (unexpected for Jönköping → Kolding; the local DB may lack those services; check on the hosted data after the deploy). Stockholm → Göteborg today: 8.0 s on the first ask of the day (the index build; the app shows the direct trains and asks again), 120 ms after. **The under-1 s check on the hosted data is still to do after Garner pushes and the server is deployed** (the planner code path is the same, so the first-ask index build is the only risk, and it was there before).
  - **Simulator checks done:** corridor sheet and highlight (`-tab explore -exploreNetwork -networkSample -exploreCorridor`), the planner list with Show earlier / Show later and the "no more" line (`-add -addQuery "Kiruna → Narvik" -addLater 3`), Stockholm → Göteborg and Göteborg → Oslo lists. **Not looked at on screen:** the day line (unit-tested in `AddTrainPagingTests`, needs a scroll to reach) and the six-step Changes picker (lint passes; it is the same system `Picker` as O1's). A pre-existing failure in `test/actuals.test.ts` (composition fields from F3) was fixed in `36d04ba`.
  - **Not deployed yet:** the hosted server still runs `42ca12a`; deploy after Garner's next push (phones on build 51 keep working: new fields are optional, `changes` defaults to 2).
  - **Next:** O3 (Ride view on the F3 proof, Explore on Apple Maps behind a setting), O4, O5.

- **2026-10-29, Phase 2, O3 done (simulator side); Garner's phone check pending.** Commit `11875ba`.
  - **Ride view.** `ClackCore/Logic/RideLogic.swift` (track from trip geometry with stops at segment ends, snap a report to metres along, extrapolate at speed with the next stop as the limit, speed source choice, camera presets; 5 tests), `Map/RideMapView.swift` (the F3 proof's MapKit + RealityKit sync, generalised: route polyline, pinch, layout margins so Apple's attribution stays clear), `Features/Ride/RideModel.swift` (polls `GET /api/live/trains/:id` every 5 s, stops every 30 s, phone GPS via `LocationModel`, `CMAltimeter`; `-open ride:replay`), `Features/Ride/RideScreen.swift` (portrait: panel under the map; landscape: beside). Entry points: Explore's train sheet ("Ride view") and the trip detail while the stage is `during`. Strings EN/SV. The Live Activity is unchanged (the plan: "keeps going as now").
  - **Explore on Apple Maps.** `Map/AppleLiveMapView.swift` (`LiveMapSurface` protocol, `AppleLiveMapSurface`, dot overlay below zoom 7, annotation views above, route/corridor polylines, frame-interval readout), `LiveMapController.surface` forwarding, Settings → Map engine (`MapEngine`, `@AppStorage("clack.mapEngine")`). Not on the Apple engine: station taps, the rail-network layer, station names from Clack's data (Apple's own show), offline tiles. Documented in `docs/IOS.md`.
  - **Verified:** replay runs in the simulator (train green in SJ's colour, 6 cars, camera presets, 120 km/h, next stop and ETA, "64 km · 32 min left"); Explore on Apple Maps zoomed out with 605 live trains as dots (readout: frame 16.7 ms median and p90 in the simulator, which says little about the phone) and zoomed in on the sample corridor with markers and the orange stretch. 83 app tests, 392 package tests, design lint clean.
  - **Not verified:** landscape layout on screen (no rotation from the shell here; the layout branch is a plain `HStack`), the phone's GPS speedometer and altitude (need a real ride), frame times with ~700 trains on a phone. **Garner:** install from Xcode, open Explore → a train → Ride view, and switch Settings → Map engine to Apple Maps (test) to judge smoothness; the readout sits bottom left. Explore stays on the Clack map unless you say switch.
  - **Next:** O4 delay history, then O5 station batches.

- **2026-10-29, Phase 2, O4 done.** Delay history from the observed record. `apps/server/src/stats/punctuality.ts` (28-day window, first call per day, late ≥ 5 min, cancellations late, nearest-rank quantiles, hour cache; tests), `packages/shared/src/changes.ts` `typicalLateMin`/`comfortWithHistory` (7+ days of record; tests mirrored in ClackCore `ChangeRuleTests`), applied in the planner (`withHistory` after ranking, risky dropped), saved journeys (`journeyChanges`, `arrivalHistory` on every leg) and the risk card (`patternFromHistory`, all countries, board record as fallback). App: `Punctuality` model, `Leg.arrivalHistory`, `PlannedChange.typicalLateMin/historyDays`, `ConnectionResult.typicalLateMin`, the line on the Train card, the note under change verdicts (planned and saved). Strings EN/SV. `docs/DELAY_HISTORY.md` has the method, the limits and the sample check on the hosted record (IC 27 at Tampere, Vy 234 at Movatn, DSB 4283 at København H, with a hand-checked row). Server 569 tests, package 393, app build and lint clean. Open: Sweden's observed projection is only 6 days old on the hosted server, so Swedish legs show nothing until it reaches 4 (line) and 7 (verdict) days; shared journeys keep the plain rule; the Train card line was not screenshotted (no local leg with 4+ days of record). Next: O5 station batches.


- **2026-10-29, Phase 2, O5 batch 1: 24 stations drafted (Sweden, Norway, Finland), 43 maps in all, every one passing the validator.** Method per `docs/STATION_MAPPING.md` with a minimal edits file each (OSM only so far; level names are placeholders, "Draft from OpenStreetMap" in the app). Drafter changes: platform tracks lose their sector letter (the validator and the app match "2a" as track 2; this had failed Norrköping C, Västerås C, Hallsberg, Örebro C); when OSM tags no entrance, footway ends away from the platforms stand in as exits, sourced as such (fixed Norrköping C, Trollhättan, Kil, Nationaltheatret, Asker, Falköping C, Öxnered, Moss, Örebro S, Kumla). New maps: Asker, Drammen, Eskilstuna C, Flemingsberg, Hyllie, Kil, Lillestrøm, Linköping C, Moss, Nationaltheatret, Norrköping C, Nässjö C, Pasila, Sandvika, Skövde C, Skøyen, Tampere, Tikkurila, Triangeln, Trollhättan, Varberg C, Västerås C, Örebro C, Öxnered.
  - **Withheld (edits file kept with the reason, no map shipped):** Södertälje Syd, Lysaker, Hallsberg, Kumla, Örebro S: OSM joins no footway to the platforms and tags no entrance, so the platforms reach no exit; they need the operator's plan or a walk.
  - **No map possible yet (OSM has no numbered platforms; `platform_refs` from a plan needed):** Herrljunga C, Falköping C, Arlanda C, Ski, Oslo lufthavn.
  - **Review queue for the new maps:** 107 items over 24 stations (`data/stations/REVIEW.md`): mostly platforms not connected to the walking graph, platform heights and placeholder level names. Nothing was checked against videos or photos in this batch (none for these stations), and no simulator look yet.
  - **Still to draft:** 51 Danish hub/mid stations (batch 2), then the withheld and unnumbered ones with sources.

- **2026-10-29, owner's notes from a ride on build 50, and the Nässjö walks.** Done in this chat:
  - Trip map: the train marker is now Explore's disc with the heading cone (`TrainMarkerView` in `Map/MapLibreSupport.swift`), pulsing halo while live, fainter when estimated.
  - Stops list: the train's dot is drawn last and a little larger than a stop's, so it sits over a stop dot when the two meet (`ClackDesign/Components/StopTimeline.swift`).
  - "Change at X" alert: no longer a fixed 15 min before arriving; it goes once the live state's next stop is the change station (the stop before it is behind you), never earlier than 15 min out, and at 5 min out in any case; without a live state at 15 min as before (`push/rules.ts` `changeDue`; the get-off alert was already stop-relative, within 10 min of the ETA).
  - Train type picker: the types drawn in this operator's livery come first, the "X or Y" groups for uncertain automatic types are left out, two types with the same drawing are offered once, and the picture is larger with the name as a caption (`TrainCard.pickable`).
  - Nässjö C (`740000140`): the owner's two walks (AR walk DC1B3590, 28 marks; lift walk 0CA1F029) gave the footbridge level (+6.2 m, barometer), four entrances, toilets, lockers, Pressbyrån, Espresso House, and the escalator/stairs/lift links from the footbridge to platforms 2a/2b and 9–10 and into the building, and the doors to 1a/1b. 8 platforms connected now; 5–8 still have no OSM outline. Walk files deleted from the Mac after use.
  - Not done on screen: none of these four changes was screenshotted (time); the owner sees them on the next install.
  - **Owner's notes still to do (2026-10-29, from the same ride):** in a leg's departure and arrival boxes, put the "+X" delay beside the struck-out planned time instead of in its own line; give the platform in the corner a defined shape of its own (a small box in the accent yellow with a rail or platform mark), so it reads as a platform and not a stray number. Both in the trip detail's time boxes (DESIGN wins on the look: written status, radius tokens, no pills).

- **2026-10-29, owner's phone test of the O3 build (build chat).** Findings: the phone ran hot; in the Ride view the train stood still and sat apart from both the red route line and Apple's rail; on the Apple-engine Explore the trains jumped between points, were hard to see and floated with no rail lines. Done: `RideTarget` moved out of the main-actor model (the 20 Xcode warnings); the Ride view's panel no longer overlaps the map (the layout margins had shifted MapKit's camera centre against the RealityKit camera, which put the train beside the line) and the map runs at 30 fps; a train without a reported speed gets one from its last two reports and an estimated position counts as "now", so it keeps moving; drag orbits the camera round the train and tilts it, pinch zooms, the presets are starting points (the owner's "ring over the train"). Apple-engine Explore: flat muted map, no Apple POIs, Clack's rail network as an overlay under the trains, a gliding train is no longer jumped to its target before the glide (the jitter), frame stats every 120 frames. Still: the red line (our OSM-routed track) and Apple's drawn railway can sit tens of metres apart by their sources; the train follows ours. Not screenshotted; owner to rebuild and look. Heat on the Explore Apple engine is still to be judged on the phone.
  - **Second phone pass (same day):** still hot; the train levitated above the ground, the red line and Apple's railway still apart, Snälltåget 307 still still. Done: the preset tabs are gone (drag orbits, pinch zooms); the AR view is now shifted each frame by the difference between where MapKit draws the look-at point and where RealityKit projects the scene origin, so the train stands on the ground whatever MapKit does with its centre; RealityKit renders at 2x with the camera-feed effects off and the display link at 24 fps; the route line is thin and translucent (it is our OSM-routed track, Apple's drawn railway can sit some metres off, and the train follows ours). On the hosted record Snälltåget 307 reports a fresh position every poll with no speed (`speedKmh: null`, `estimated: false`), so the derived speed from two reports is the path that should move it; to confirm on the next install. Apple-engine Explore: rails as a solid transit-blue 2 pt line and station dots with names from zoom 9 (tap opens the station), like Apple's own transit view the owner pointed to.
  - **Owner's idea to do later:** the journey view (several legs) should carry the same live experience as a single leg while the journey is under way or about to start, or become the leg view adapted to a journey.

- **2026-10-29, regroup: Ride view and Apple Maps engine scrapped** (owner's call after two phone tests: hot phone, train not on the ground, Apple map jumping and bare). Removed `Features/Ride/*`, `Map/RideMapView.swift`, `Map/RideProofScreen.swift`, `Map/TrainScene.swift`, `Map/AppleLiveMapView.swift`, `ClackCore/Logic/RideLogic.swift` and its tests, the `LiveMapSurface` indirection in `LiveMapController`, the Map engine setting, the Ride buttons, 20 strings. Kept: `TrainKit` (pure car placement, reused next), `LiveTrain.cars`, `TrainType.cars`, the composition parsing. The plan from here (all in this chat): station detail on our own map at close zoom with trains as cars at their platforms → the leg time boxes and the journey view's live experience → Danish batch and withheld stations → positioning tuning → 3D station view opened from a station → ship build 54.

- **2026-10-29, owner's items from the Malmö layover:** long stands in the stops lists (done: arrival in the time column, "Departs 09:04 · 45 min stop" under the name, from five minutes; the owner picked it from three looks in the design gallery). **Battery:** 50 minutes of Clack open on an iPhone 17 cost over 20 % (a Debug build from Xcode, which is unoptimised, but still too much). To do as its own pass right after the station detail: measure with Instruments' energy log on the phone, then cut the idle work: the Explore render loop (only run frames while something glides), the one-second `Ticking` views (stop when nothing on screen changes by the second), the trip map's follow mode (ease only on a new position), the live stream's full re-render per update (diff what changed), and the walk logger's sensors when not recording. Report before/after.
  - **Order from here (owner, same evening):** finish the station-detail drawing on Explore → the leg time boxes and the journey view's live experience → positioning tuning on the measured week → the 3D station view as a demo of one station (Jönköping C) for feedback before the rest. The battery pass and the Danish station batch wait (the batch job is paused mid-retry, 68 maps on disk, nothing committed).

- **2026-10-29 evening, station detail on Explore: tracks and trains-as-cars working, platforms not yet drawn.** App side committed: `station-detail` and `station-platforms` sources and layers from zoom 13 (`MapStyle.stationDetailLayers`), the fetch per view box with debounce and cache (`ExploreModel.viewChangedForDetail`), trains as their cars from zoom 14 (`StationDetailLogic`, tested; `MapStyle.trainCarLayers`; cars tappable), `-exploreAt lat,lon,zoom` for checks, DESIGN §2.6. Verified in the simulator at Stockholm C and Jönköping C: every track at full detail with sidings fainter, trains standing as cars on their tracks. **Found and fixed on the way:** a MapLibre shape collection that mixes lines and polygons draws nothing on iOS, so platforms went to their own source. **Still open:** the platform polygons (17 at Stockholm C, parsed by MapLibre into a collection) do not show; next check is whether the fill layer renders at all (a loud test colour) versus the polygons being wrong; Debug log lines for this are still in `LiveMapController.setStationDetail` and `ExploreModel.show` and come out once it works. The ordinary `rail-network` line fades out above zoom 13.6 as designed.
  - Session ended here on usage. Order for the next session (owner): finish the platforms → leg time boxes and the journey view's live experience → positioning tuning → the 3D station view demo at Jönköping C → battery pass and the Danish batch when asked (the drafting job is paused mid-retry: 68 maps on disk, none of the Danish ones committed).


- **2026-10-29, journey view and Trips toggle (owner's notes):** journey leg rows no longer show the delay line (only distance; the delay sits beside the times). Timeline dots now count a train as left or arrived only on evidence (`TripsLogic.reached`: actual times, live state, or with no tracking the expected time plus 10 min); the fill still follows the clock. The Trips Upcoming/Past toggle is `TripsSegmentedControl`, build 50's look, the one exception to native controls (DESIGN §native controls). The journey page has a "Now" section (`JourneyNow.swift`, `TripsLogic.nowLegIndex`): the running leg's status, live module and next change, with its followed route map replacing the whole-journey map while under way. Verified in the simulator: past journey (no delay line, filled dots), the toggle. **Not verified on screen:** the "Now" section (no journey within the hour in the local data); logic is unit-tested only.
- **2026-10-29, positioning in the app (docs/POSITIONING.md, app side).** `LiveTrain` now reads `state`, `prevId`, `nextId`, `progress`, `platform`, `atStation` (all optional; the moved tuple's entries 8 and 9 too); `APIClient.liveSegment(from:to:)` fetches the track between two stops. `ExploreModel.apply` glides a running train along that track (cached per station pair, fetched the first time a pair is seen; the first update on a new pair is still a straight glide), easing to the new fix and then carrying on at `speedKmh` for at most 4 s and never past the next station; the heading follows the track (`ExploreLogic.TrackPath`, `Glide`, `makeGlide`, tested in `TrackGlideTests`). Standing and waiting trains, trains off the track by 100 m or more and trains without a segment glide straight, as before. Marker heading updates on full renders, not on the lightweight glide frames. Checked in the simulator against the local server (train 598 near Duved moved along its track between two screenshots). Hosted-data tuning skipped: the server with the build 54 fields is not deployed yet. No build bump.

- **2026-10-29, positioning tuning on the hosted counters (4.8 h of data, not days).** Read `data/cache/live-quality.json` from the server at b6e4ac4 through a new `position-check --file=` (the admin route also needs a user id the CLI lacks); table and decisions in docs/POSITIONING.md. All `TIMESTAMP_OFFSET_S` stay 0 (Trafikverket arrivals +2 to +3 s with a 30 s p90 are not distinguishable from 0; Digitraffic passes read 0); ACCEL/DECEL unchanged (not measurable from these counters). Standing check: only a fix at or after the arrival report and under 3 km/h counts (`countsAsStanding`; the 9 km at Lund C was approach fixes and trains that had left, not the station id). Denmark's track-side rule switched off (42% agreement, n 4 473). Not deployed. Next: a week of data, a Trafikverket pass measure, Entur and Rejseplanen offsets.

- **2026-10-29, planner speed (`GET /api/search`, changes=5).** Hosted warm answers took 1.1-1.7 s by curl (`/api/health` 0.11-0.16 s, so network is about 0.13 s; the rest is the server; first ask 4 s is the day index build, unchanged). Measured locally with a CPU profile on the real database: the time is in `plan`'s loop, not SQL. Two causes: (1) for every marked label the loop walked the station's whole day of departures from the first one (a hub has thousands) instead of starting at the arrival time; (2) the same train was boarded again and again, in every departure run and round, from stops where an earlier boarding had already given every later stop its label (Malmö → Köpenhamn: 1.4 M rides and 19.7 M stop visits for 506 departure runs; now 0.19 M and 2.4 M). Also the change minimum (tier lookup, cross-border) was worked out for 2.7 M candidates; it is now a tier check per label and the cross-border check only between countries. Fixes in `search/planner.ts`: binary search into the sorted departures, a per-round "already ridden from here or earlier" set kept across runs (exact, labels only improve), the cheaper minimum check, and `planCached` (ten minutes per built index, used by the route) for repeated asks. Results unchanged: old and new `plan` compared on seven routes (Stockholm → Malmö, Oslo, Köpenhamn → Malmö, Kolding → Kiruna, Göteborg → Narvik, Oslo → Bergen, Stockholm → Helsingfors), identical JSON. Local `plan` before → after (ms, warm index, changes=5): Stockholm → Malmö 260 → 120, Stockholm → Oslo 250 → 100, Kolding → Kiruna 195 → 59, Göteborg → Narvik 150 → 56, Malmö → Köpenhamn 520 → 200; repeats now come from memory. **Unverified:** the hosted effect (that box is slower and has Jönköping services the local database lacks; expected roughly 2.5x less plan time, so about 0.5 s, and near 0.15 s for a repeated pair) shows only after deploy; the remaining server costs (`smartSearch` station lookup, `reconstruct` stop queries, history queries on the large observed record) were not measured on the hosted box.

- **2026-10-30, 3D station view demo at Jönköping C, with measured heights** (build chat; not on TestFlight). Debug builds on iOS 18+, Jönköping C only, from the station map's side column ("3D view"; `-station3D` opens it, `-fakeBoard3D` a made-up board, `-camera3D bearing,pitch,distance[,x,z]` another angle).
  - **ClackCore:** `Logic/StationScene3D.swift` (scene values and meshes, no RealityKit: platforms, tracks, buildings from lowest ground to measured top, roofs as sheets under measured tops, terrain mesh, ramps, lift columns; train states arriving/standing/leaving over 60 s from the boards, cars placed with `TrainKit.carPoses`), `StationRouting.toWGS84` (inverse of `toLocal`), `StationMap.terrain`, `StationShape.topM/baseM`, `ShapeKind.roof`. 11 tests in `StationScene3DTests`.
  - **App:** `Features/Stations/StationScene3DView.swift` (`RealityView` with a virtual camera of its own: one finger turns and tilts, two move, pinch zooms; unlit colours; the clock runs per frame only while a train slides, else sleeps to the next change; board loaded once then followed by `boardStream`). Panel: the notes that apply, the trains, unknown platforms, and the credits (OSM, Lantmäteriet, Trafikverket). Lucide `box` icon added. DESIGN §2.7.
  - **Data (the owner's research pass, `docs/STATION_3D_RESEARCH.md`, files in `data/stations/research/740000090/`):** platform height 0.58 m from Trafikverket's register (BIS object 1705, class "mellan"; replaces the 0.55 m standard); station building +8.4 m, waiting hall +5.3 m with its roof over 2b at +6.1 m, canopy over 2a +3.4 m, footbridge roof +9.1 m, Juneporten block +13.1 m, hotel +63.2 m and nine neighbours, all laser roof medians above the 91.67 m platform surface (Lantmäteriet, scanned March 2022, CC BY 4.0); the ground as a 5 m grid from the laser's ground model (the town side up to +5 m, Vättern −2.9 m). New edits keys `structures_file`/`structures` and `terrain` in the drafter; `scripts/stations/terrain_preview.py` makes an 8-bit preview of a float GeoTIFF (the research's showed blank). Format: `roof` kind, `top_m`, `base_m`, `terrain`, source type `lantmateriet`; the validator checks them.
  - **Owner's correction:** the first version drew the upper level as a yellow hull round the walkway points; it isn't there (the upper level is the town's ground, +3.6 m at Juneporten's entrance by the laser, +3.3 m by the walk). Floors are now drawn only from an outline. Stairs and escalators whose walk-mark ends are too far apart (one came out 52 m) are drawn at 30° from their upper end, and the panel says so.
  - **Frame rate (simulator, iPhone 17 Pro):** about 54 fps while a train slides in, 60 fps with nothing moving: RealityKit draws every frame even when idle, and `RealityView` has no frame-rate setting. Camera effects (motion blur, depth of field, grain, HDR) are off. Heat on the phone is the thing to judge.
  - **Unverified:** what sits under the roofs (canopy undersides, the footbridge deck), the upper level's floor inside Juneporten and whether the footbridge is that level, which way each train runs along its track (drawn one way), the escalators' real positions (walk marks ±10 m; the 30° ramps are drawn, not measured), car sizes (typical values). The ground under the platforms is drawn 5 cm low so it doesn't flicker against them.
  - **Next:** Garner tries it on his phone (a Release build from Xcode); no other station gets the 3D view until he has. Then: the national Trafikverket platform-height script (playbook Part 1), and a walk for the footbridge deck and the escalators.
- **2026-10-30, the station in 3D on Explore** (owner: "when a user zooms in close enough to the station, it switches into the 3d view"). Built into the MapLibre map rather than swapping in RealityKit, so trains, labels, taps and sheets stay, and nothing renders while idle: `fill-extrusion` layers `model-platforms`/`model-buildings`/`model-roofs`/`model-cars` (`MapStyle.stationModelLayers`, from zoom 15), native polygon features with height attributes (`LiveMapController.setPolygons`; GeoJSON polygons with attributes don't draw on iOS), car footprints from the car lines (`carFootprint`, 3 m wide, height per design), tilt to 55° at zoom 16 where the detail has measured structures and back below 15.5 (`ExploreModel.updateTilt`). Server: `structureFeatures` and platform `height`/`measured` in `/api/map/station-detail` (heights above the rails; test in `stationDetail.test.ts`). Checked in the simulator at Jönköping C (dark, light) and Stockholm C (car boxes, no tilt). Ground flat on Explore (no terrain in MapLibre iOS). **Needs the hosted server deployed** for phones: until then the hosted answer has no structures and Explore stays flat. App test run not repeated for this change (lint, typecheck, server tests pass; 3 known Danish-draft failures).
- **2026-10-30, owner's notes on the 3D and the planner (after trying it on his phone).**
  - **Kolding → Jönköping C overnight (his DSB + SJ tickets):** the planner finds exactly that journey (Re 50974, IC 70176, Öresundståg 1180, SJ 520, Krösatåg 17600) on the hosted server, first in the list from 21:30, but it has 4 changes and the list's default filter is 2, so it was hidden without a word while other journeys showed. "Include more changes" now also sits under the list whenever the filter hides any journey.
  - **Planner:** no separate date line; a picked day is the Pick date button's own label. While a search is out, the station suggestions come from the quick station search for the part being typed (`AddTrainLogic.typedTerm`, tested), so they show before the journeys.
  - **Explore 3D:** labels over the 3D (layer order: flat detail, 3D, then every symbol); the tilted view keeps one tile zoom (`tileLodPitchThreshold` 60°) against the lake flickering between two tile versions (steady in the simulator; to confirm on the phone); the selected train as cars gets a yellow outline on the ground instead of the ring, the camera centres it above the sheet with a content inset (right when tilted or turned) and follows it until the map is dragged (`keepInView`, `onUserGesture`; `-exploreSelect <id>` in Debug). Not confirmed on a moving train in the simulator (the only fast train's last report was 41 s old).
  - **Station detail:** the traced waiting-hall roof is smoothed (`simplify_m` 2 m: 87 → 15 corners); the footbridge is a `bridge` from 5.9 m above the rails (the minimum clear height over electrified track, TRVR Bro 11; a lower bound, said in the panel) to its measured roof, so it is a closed span, not a floating sheet. Platform 2's sectors 2a and 2b are edges from Trafikverket's BanInfo track lines (`sector_edges`); a train announced at "2a" stands in that part, in the full-screen view (`platformMiddle(sector:)`) and on Explore (`platformPoint` in shared, tested on the real map).
  - **Open:** the footbridge deck's real height, and how the lift (OSM levels 0;1 at its north end) meets it: a barometer reading on the next walk (±0.5 m is enough here); the escalators' positions.
- **2026-10-30, planner: a late journey dropped as a "detour" over the whole day.** Kolding 22:05 → Jönköping C 07:17 (4 changes, via København) showed when searched from 21:30 but not for the whole of 1 November, with any change filter: `rank` measured every journey against the day's fastest (a ~6 h midday one), so 9 h 12 min overnight counted as a detour although nothing faster left near 22:05. The detour rule now compares with journeys leaving within 2 h (`rank`, test in `planner.test.ts`). Needs the hosted server deployed.
