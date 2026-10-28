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
