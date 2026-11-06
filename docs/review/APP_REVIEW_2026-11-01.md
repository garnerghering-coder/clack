# Clack app review, 2026-11-01

## 1. What was tested and how

- **Date:** Sunday 2026-11-01.
- **Build:** Release build 54 ("Version 1.0 (build 54)"), installed on the iPhone 17 Pro simulator, first launch with an
  empty keychain, against the hosted server https://getclack.app. The hosted server ran `34e35fbd`
  (`/api/health`), one commit behind local `main` (`efc35d75`, "Sectors named all along the platform").
- **How:** hands-on in the simulator (English and Swedish, light and dark, text sizes up to AX-XXXL, the accessibility
  hierarchy, cold launches, rotation); code reading of the app, ClackKit and the server; and comparisons with outside
  sources (Trafikverket, Digitraffic, Entur, Rejseplanen, OpenStreetMap, Jernhusen, dsb.dk, Wikipedia, the IVL report).
  The outside comparisons were made at 07:35–07:51 UTC on a Sunday morning, so delays and cancellations were barely
  exercised. **Repeat the board, delay and cancellation checks on a weekday rush hour.**
- **All times in this report are UTC** unless marked "local". (Local time was CET, UTC+1.)
- **Not tested:**
  - real flight mode (offline behaviour is from code only);
  - a real VoiceOver run (labels were read from the UI hierarchy, not heard);
  - a physical phone or a battery measurement (performance is from code only);
  - the Live Activity on the lock screen, and alerts (left off);
  - "Help place trains for everyone" switched on (privacy checked in code);
  - ticket import;
  - the 3D station view (Debug-only, Jönköping C).

## 2. Overall verdict

Clack's core is strong. Swedish, Norwegian and Danish boards matched their sources row for row (91/91 in Sweden, 93/93
in Norway, 86/86 in Denmark), Swedish GPS positions sit within metres of Trafikverket's, Finnish GPS trains within
280 m, and the live trip card is the best thing in the app. What stands between this build and the App Store is mostly
around that core: a test tool that every user can see and that uploads precise location with the user id, privacy text
that says "never your position" while the app sends a precise along-track position, and a privacy manifest that
doesn't declare either. The next most important things: battery use during a trip, a few live-data errors that show
wrong things as fact (Helsinki's ring trains missing, stale positions after the server idles, Finnish compositions),
large text and VoiceOver on the main screens, and the planner hiding or misdescribing the train you are actually on.

### Five things to fix first

1. **Station walks tool and privacy wording (App Store blocker).** The "Station walks (test tool)" entry is shown to
   every user (`alwaysShowTestTools = true`). It records precise location, motion, barometer and camera, uploads it
   with the user id, and none of this is in the privacy text or removed by Delete my data (P1). Fix it together with
   the location wording: "Not your position" / "Never your position" / "Your exact position stays on your phone"
   contradicts what rider reports send and what the App Store label plan says (P2), and `PrivacyInfo.xcprivacy` lacks
   Precise Location (P3) and the required-reason APIs (P4).
2. **Battery on a trip.** Explore's live stream and its ~30 fps glide loop keep running in the background while a Live
   Activity keeps the app alive (E1, E4). GPS runs at best accuracy with no distance filter (E3). Background location
   runs for the whole trip even with "Help place trains" off (E2).
3. **Live data shown wrong.** The Helsinki board drops the I and P ring trains, 22 of 59 departures (A1). The live map
   can serve positions 13 hours old as live after the server idles (A2). Finnish compositions use only the first
   section, so IC 909 is drawn with 7 cars instead of 4 and night train 269 as an electric IC instead of a diesel with
   sleepers (A3).
4. **Large text and VoiceOver.** At the largest size the Plan a journey sheet runs off both sides of the screen (D1);
   the board, Settings and the flip-tile times break (D2–D5). The live trip card is one button that reads only "View
   journey: Stockholm C to Malmö C" (D8), and delays read as a bare "+3" (D9).
5. **Planner and finding your own train.** Searching "523" while SJ 523 is running hides it behind "Show earlier"
   (W1). Göteborg → Oslo suggests an overnight detour via Stockholm and Helsingborg (A7); Copenhagen → Hamburg resolves
   to Hamburg Bergedorf and gives nothing, with no "not covered" note (A8); SJ's Oslo departure times differ from
   Entur's by 5–11 min (A4); and Stockholm → Narvik is shown as a tight change at Boden for coaches that probably run
   through (A6).

## 3. Findings

Severity: **blocker** (stops a release or a user), **major**, **minor**, **polish**. File paths are from the repository
root. Screenshots are in [2026-11-01/](2026-11-01/). Where an outside source and Clack disagree, both values are
given; neither is assumed right unless a source says so.

### Privacy and trust

**P1. Station walks test tool is visible to every user and uploads precise data with the user id**
- Where: Settings > bottom > "Station walks (test tool)", in this Release build and, while the flag is true, in App
  Store builds too.
- Expected: an owner-only tool, hidden in App Store builds (docs/APP_STORE.md item 11), with the privacy text covering
  anything it sends.
- Actual: any user can record a walk (precise location, motion at 50 Hz, barometer, AR camera). When it ends, the app
  PUTs the whole file (up to 50 MB) with `X-Clack-User`. The server reads the body, then answers 404 to anyone not in
  `WALKLOG_USERS`; the app treats that as a failure and retries every minute while the list is shown. The privacy text
  doesn't mention walk recordings or the upload. Walk files on the phone (Documents/walks) and on the server
  (data/walklogs, not keyed to the user) survive Delete my data. The tool's strings are hard-coded English (about 45
  literals). The Camera and Motion purpose strings and the `systemUptime` call (P4) exist only for this tool.
- Evidence: seen in Settings during walkthrough 1; code.
- File: apps/Clack/Clack/Features/Settings/WalkLogger/WalkStore.swift:126 (`alwaysShowTestTools = true`), :96-115;
  apps/Clack/Clack/Features/Settings/SettingsScreen.swift:562-578; apps/Clack/Clack/Features/Settings/WalkLogger/WalkScreens.swift;
  apps/server/src/routes/walkLogs.ts:16-28.
- Severity: blocker. Confidence: high.

**P2. Location wording says "never your position" while a precise along-track position is sent**
- Where: catalog keys `riders.ask.body` ("Not your position"), `riders.settingNote` ("Never your position"), the same
  in Swedish; the location purpose string ("… Your exact position stays on your phone." / "Din exakta position stannar
  i telefonen.").
- Expected: wording that matches what is sent, and matches docs/APP_STORE.md, which itself calls the progress along a
  known train's track "a position" and plans to label it Precise Location.
- Actual: a rider report carries train id, stretch, progress to 1e-4 (about 2 m on a 20 km stretch), speed and a
  second-accurate time: the phone's position along a known line. The purpose string never mentions placing trains or
  background use during a Live Activity. A reviewer reading "stays on your phone" next to a background location mode
  will ask.
- File: apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings; apps/Clack/Clack.xcodeproj/project.pbxproj:560, :605
  (`INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`); apps/Clack/Clack/sv.lproj/InfoPlist.strings;
  apps/Clack/ClackKit/Sources/ClackCore/Logic/RiderLogic.swift:39-59.
- Severity: major (App Review 5.1.1(i), 5.1.2). Confidence: high.

**P3. Privacy manifest lacks Precise Location**
- Where: apps/Clack/Clack/PrivacyInfo.xcprivacy, collected data types.
- Expected: "Precise Location, not linked, App Functionality" (docs/APP_STORE.md:35).
- Actual: only Coarse Location ("Near you") is declared.
- Severity: major. Confidence: high.

**P4. Required-reason APIs not declared**
- Where: `NSPrivacyAccessedAPITypes` in apps/Clack/Clack/PrivacyInfo.xcprivacy (only UserDefaults CA92.1).
- Actual: `ProcessInfo.processInfo.systemUptime` (WalkRecorder.swift:40) is System Boot Time and needs a reason (e.g.
  35F9.1); it is compiled into Release even when the tool is hidden. App Group UserDefaults
  (`UserDefaults(suiteName: WidgetSnapshot.groupId)`, ClackCore/LiveActivity/SharedSettings.swift:16, Identity.swift) are
  shared with the widget extension, so CA92.1 doesn't cover them; 1C8F.1 does. The manifest's comment ("all read only by
  this app") is no longer true. ClackWidgets has no PrivacyInfo.xcprivacy of its own.
- Expected: every required-reason API declared, or App Store Connect flags ITMS-91053 and can block a submission.
- Severity: major. Confidence: medium (rules certain; whether past TestFlight uploads already got the warning is not
  visible here).

**P5. "What our server keeps" leaves out several stored items**
- Where: `privacy.storedBody` (EN/SV) and https://getclack.app/privacy (read 07:38, identical to the repo copy).
- Expected: "This is everything it keeps and why" (`privacy.intro`) to be literally true.
- Actual: the server also keeps, per user id: coach and seat (also filled from tickets), your own platform corrections,
  whether you rode the trip (`ride`), favourite stations, recently viewed stations with timestamps (browsing history),
  station-map requests, share links and followed links, Live Activity push tokens linked to a trip and device,
  widget/push-to-start tokens with `last_seen_at`, and what was shown per trip (`shown_values`).
- File: apps/server/src/db/schema.ts; the catalog.
- Severity: major (5.1.1(i), GDPR Art. 13). Confidence: high.

**P6. Usage data is on by default and the privacy page contradicts itself**
- Where: Settings > Usage data; Settings > Privacy.
- Expected: opt-in (or at least wording that matches), consistent statements.
- Actual: usage sharing is on by default while the page opens with "no tracking". The page says the server keeps "the
  optional name shown on your Passport" and later "No name … collected".
- Severity: minor (GDPR / App Review risk). Confidence: high.

**P7. Usage counts and crash summaries are sent with the user id**
- Where: apps/Clack/Clack/App/Usage.swift:94, :105 (`client.perform`, which adds `X-Clack-User`,
  apps/Clack/ClackKit/Sources/ClackCore/API/APIClient.swift:76).
- Expected: `privacy.usageBody` "… with no code, device or anything that says who you are"; manifest says not linked.
- Actual: the server does not store the id (apps/server/src/routes/usage.ts), but the request carries it. The rider
  report path already shows the fix (its own ephemeral session with no id).
- Severity: minor. Confidence: high.

**P8. "Near you" position sent without a tap, with the user id**
- Where: first screen; apps/Clack/Clack/Features/Trips/WelcomeView.swift:104-109;
  apps/Clack/ClackKit/Sources/ClackCore/API/Endpoints.swift:99-103.
- Expected: `privacy.locationBody` "When you tap 'Near you' … sent once"; manifest Coarse Location not linked.
- Actual: when location is already allowed, `load()` sends lat/lon (2 decimals, about 1.1 km × 0.5 km at 60° N) on
  appear, e.g. after Start over or Delete my data with permission kept. The GET carries `X-Clack-User`; the server
  doesn't log or store it (apps/server/src/routes/stations.ts:52-57).
- Severity: minor. Confidence: high.

**P9. Location copy says "Only when you ask for it"**
- Where: `privacy.locationBody` (EN/SV).
- Actual: location starts on its own whenever the app is open and a logged train is running, and in the background
  while the trip's Live Activity runs, whether or not sharing is on (see E2, E3).
- Severity: minor (text). Confidence: high.

**P10. Rider reports are unlinkable by policy only**
- Where: apps/Clack/Clack/App/RiderReporter.swift:87, :105; apps/server/src/app.ts:63-75.
- Actual: each 20 s loop first calls `GET /api/live/mine` (and per new stretch `/api/live/segment`) with `X-Clack-User`,
  from the same IP, seconds before the anonymous report; the server also knows from `legs` who logged that train. With
  few riders a session could be matched to an id. Nothing does this and nothing is logged, so the claims hold today.
- Expected: one honest sentence in docs (POSITIONING.md); optionally jitter the report or poll `/live/mine` less.
- Severity: minor. Confidence: high.

**P11. Delete my data can be partly undone by the rider loop**
- Where: apps/Clack/Clack/App/RiderReporter.swift:59-65; apps/Clack/Clack/App/AppModel.swift:179-203; apps/server/src/app.ts:63-74.
- Actual: `deleteMyData` swaps `app.client` to a new id, but a running rider loop keeps the old client and calls
  `/api/live/mine` every 60 s with the deleted id; the server's onRequest hook re-creates a user row for any unknown
  valid id. Result: an empty `users` row under the deleted id until the app is closed.
- Severity: minor. Confidence: medium (code path clear; not run).

**P12. Hosted privacy page lacks contact, controller and date**
- Where: apps/server/public/privacy/index.html and sv/index.html (served live, read 07:38).
- Actual: every `privacy.*` body matches the catalog word for word, but `privacy.contactTitle/Body` and
  `privacy.updated` are missing (the in-app screen has them, SettingsScreen.swift:549-554). No "who runs Clack", no
  rights (access, export, complaint to IMY). Section order differs from the app.
- Severity: minor (GDPR Art. 13). Confidence: high.

**P13. The server logs client IPs for pages and API errors**
- Where: apps/server/src/index.ts:39, apps/server/src/app.ts:55 (trustProxy); privacy and share routes registered without
  `logLevel: 'warn'`.
- Actual: `/privacy` and share pages (`/s/…`, token in the URL) log "incoming request" with the real client IP to the
  systemd journal; 5xx on `/api` log too. The privacy text says nothing about IPs or logs.
- Severity: minor. Confidence: medium (journald persistence on the VM not checked).

**P14. The first-trip ask can override a choice made in Settings**
- Where: apps/Clack/Clack/App/RiderReporter.swift:114-117; SettingsScreen.swift:175-183.
- Actual: turning sharing on in Settings doesn't set `riders.asked`, so the first-trip alert still appears and "Not
  now" turns sharing off again. Delete my data keeps `riders.sharing`/`riders.asked` (no `clack.` prefix); Start over
  clears them.
- Severity: polish. Confidence: high.

**P15. Info.plist leftovers a reviewer may ask about**
- Actual: `NSLocalNetworkUsageDescription` ("… the Clack server on your Mac while the app is being built") and
  `NSAllowsLocalNetworking` ship in Release (project.pbxproj:559, :604). Camera and Motion purpose strings exist only for
  the walk tool (P1).
- Severity: polish. Confidence: high.

Checked and fine: rider reports carry no coordinates, go on an ephemeral session with no cookies and no user id, use a
per-train session code, are kept in memory for 3 min and never written to disk or logged. Push tokens are registered
only with alerts on and deleted with the user. Ticket files are read on the phone. MetricKit sends only kind, a short
signature and the build. No third-party hosts at runtime besides Apple. EN and SV privacy texts say the same things.

### Performance and battery

All from code reading; nothing was measured on a phone.

**E1. Explore keeps streaming and animating in the background during a trip**
- Where: Explore tab left open, phone locked, trip with a Live Activity running.
- Expected: streams, render loops and tickers stop when the app leaves the foreground.
- Actual: the stream task is keyed on the tab, bbox and `ready`, never on `scenePhase`; the render loop stops only when
  the tab changes. While a Live Activity runs, the `CLBackgroundActivitySession` and continuous location keep the
  process alive, so the SSE stream (a delta every 2 s), the 33 ms glide loop, MapLibre source updates, `LiveHub`
  listeners (Trips, and TripDetail refetching `/legs/:id` on every update) and the 5 s `now` ticker all keep running.
  Probably the largest drain in the app.
- File: apps/Clack/Clack/Features/Explore/ExploreScreen.swift:79-82, :111-116; ExploreModel.swift:68-76, :308-321;
  apps/Clack/Clack/App/RiderReporter.swift:94, :128-139; TripDetailScreen.swift:130-134; apps/server/src/livemap/ingest.ts:120.
- Fix idea: gate on `scenePhase == .active` too; close `LiveHub` in the background.
- Severity: major. Confidence: high.

**E2. Background location runs for the whole trip even with "Help place trains" off**
- Where: apps/Clack/Clack/App/RiderReporter.swift:81-99, :128-140.
- Expected: background location (UIBackgroundModes `location`, `CLBackgroundActivitySession`) only for the feature
  APP_STORE.md justifies it with (riders' reports).
- Actual: `run()` calls `startFollowing(keepInBackground: liveActivityRunning)` for any running logged train;
  `guard sharing else { return }` comes only at line 118, after the background session started (lines 94, 135). With
  sharing off the only consumer is the on-screen map (ExploreModel.swift:356), which isn't visible in the background.
- Severity: major (battery; App Review 2.5.4 and 5.1.1; contradicts "Only when you ask for it"). Confidence: high.

**E3. GPS at best accuracy, no distance filter, for the whole trip**
- Where: apps/Clack/Clack/App/LocationModel.swift:31-32, :43, :98-103; RiderReporter.swift:84-99.
- Actual: `kCLLocationAccuracyBest`, no `distanceFilter` (about 1 fix a second), used only every 20 s. Each fix hops to
  the main actor and writes an `@Observable` property (about 3,600 wakeups an hour). `/live/mine` is polled every
  20 s during a trip, and every 60 s while the app is open with nothing running.
- Fix idea: `kCLLocationAccuracyNearestTenMeters` or HundredMeters, a ~50 m filter, or `CLLocationUpdate.liveUpdates`
  throttled to 20 s.
- Severity: major. Confidence: high.

**E4. At zoom 7 and closer the glide loop never stops, and every frame resets the whole train source**
- Where: Explore at regional zoom with moving trains in view.
- Actual: glides ease for 1.5 s then extrapolate for 4 s, longer than the 2 s delta, so `scheduleRender` loops every
  33 ms without end. Each frame assigns a new feature collection with all visible trains, so MapLibre rebuilds the
  source index and re-runs label layout and collision about 30 times a second, at the default frame rate (120 Hz
  display; `preferredFramesPerSecond` never set). At zoom 14+ each frame is a full `render()` including car boxes and 3D
  polygons. `controller.contains` calls `visibleCoordinateBounds` once per train.
- File: apps/Clack/Clack/Features/Explore/ExploreModel.swift:253-262, :315; apps/Clack/ClackKit/Sources/ClackCore/Logic/ExploreLogic.swift:12, :170, :208-213;
  apps/Clack/Clack/Map/LiveMapView.swift:148-152; apps/Clack/Clack/Map/MapStyle.swift:365-390.
- Fix idea: stop extrapolating when the next fix is due or run it at ~10 fps; a small source for moving trains only;
  lower frame rate; skip in Low Power Mode.
- Severity: major. Confidence: high.

**E5. Every pan or zoom reconnects from scratch**
- Where: apps/Clack/Clack/Features/Explore/ExploreScreen.swift:79; apps/Clack/ClackKit/Sources/ClackCore/API/EventStream.swift:63-66;
  apps/server/src/routes/livemap.ts:69-71.
- Actual: the bbox is in the task id, so each settle (after 400 ms) closes the stream and opens a new one on a new
  `URLSession` that is never invalidated (fresh TLS each time; sessions pile up). Each connect sends a full,
  uncompressed snapshot (about 0.5 KB per train; the all-countries snapshot was 221 KB for 405 trains).
- Severity: major. Confidence: medium.

**E6. Bursts of track-segment requests**
- Where: apps/Clack/Clack/Features/Explore/ExploreModel.swift:288-300.
- Actual: each new moving `prev>next` stretch at zoom 7+ fires its own `GET /live/segment`; zooming into a busy area
  starts dozens at once, again after each pan. The `segments` cache has no limit.
- Severity: minor. Confidence: high.

**E7. REST JSON is decoded on the main thread**
- Where: apps/Clack/ClackKit/Sources/ClackCore/API/APIClient.swift:113-134 (`NonisolatedNonsendingByDefault`, callers
  are `@MainActor`); OfflineCache.swift:53-67; TripDetailScreen.swift:88, :130-134.
- Actual: every decode (legs, passport, geometry, stops) runs on main; `OfflineCache.store` does two atomic writes and
  compiles 11 regexes per GET; trip detail refetches `/legs/:id` and re-decodes the route polyline on every live update
  (~20 s).
- Severity: minor. Confidence: high.

**E8. Explore's whole body re-evaluates every 2 s**
- Where: apps/Clack/Clack/Features/Explore/ExploreScreen.swift:330-334, :111-116; ExploreModel.swift:222-238.
- Actual: the status chip reads seven model properties in the root body, and the model writes `streamDown` and
  `lastMessage` on every event even when unchanged. Sheets, the selected train and search results (`trainHits()`
  sorting every train) rebuild every 2 s, offscreen too.
- Severity: minor. Confidence: high.

**E9. One-second clocks rebuild whole lists**
- Where: apps/Clack/Clack/Features/Stations/BoardScreen.swift:180 (whole board in `TimelineView(.periodic(by: 1))`);
  TripDetailScreen.swift:302, :335, :337, :340 (three 1 s blocks, whole stop list); apps/Clack/Clack/Features/Trips/FeaturedCard.swift:26.
- Fix idea: tick lists on the minute; keep 1 s for countdown text.
- Severity: minor. Confidence: medium.

**E10. Animations that run forever**
- Where: apps/Clack/ClackKit/Sources/ClackDesign/Components/StatusLine.swift:57-60 (live dot pulses for the whole
  trip); apps/Clack/Clack/Map/StationSceneView.swift:61 (route dots at 20 fps while a route shows).
- Severity: polish. Confidence: medium.

**E11. Walk recorder invalidates its screen at 50 Hz and saves on main**
- Where: apps/Clack/Clack/Features/Settings/WalkLogger/WalkRecorder.swift:22, :61-63, :176-190; WalkScreens.swift:102, :139, :161;
  WalkStore.swift:63-65.
- Actual: motion samples go into the observed `log`, read by the recording view; every 20 s the whole growing log is
  JSON-encoded on main (about 180k samples an hour).
- Severity: minor. Confidence: medium.

**E12. Map setup cost**
- Where: apps/Clack/Clack/Map/MapStyle.swift:424; RouteMapView.swift:288; LiveMapView.swift:371-372.
- Actual: every MapLibre map loads and parses the whole Nordic `/api/map/rail-network.geojson`. Explore may be built at
  launch and fetch a whole-Nordic snapshot even when Trips is showing (not verified).
- Severity: minor. Confidence: low.

**E13. No Low Power Mode or thermal handling**
- Actual: `isLowPowerModeEnabled` and `thermalState` are never read.
- Severity: polish. Confidence: high.

**E14. Slow spots without feedback**
- Where: journey detail map; Share journey; Explore.
- Actual: the planner's journey map stayed blank about 10 s before tiles appeared; the share sheet took about 4 s with
  no spinner; Explore outside the Nordic area (Belgium) showed a black lower half.
- Evidence: [2026-11-01/s_08_journey_change_disabled_map.png](2026-11-01/s_08_journey_change_disabled_map.png) (blank map).
- Severity: minor. Confidence: medium.

Done well: the route draw-on animation is finite; zoomed-out redraws are throttled to 10 s; SSE decode is off main;
Explore's stream closes when the tab is left; the 3D station view sleeps between train changes; Live Activity updates
come from server pushes at most once a minute; widgets use timer text and diff before reloading.

### Accuracy

**A1. Helsinki board drops the ring trains I and P**
- Where: Explore > Helsinki > Departures (and Arrivals); `GET /api/stations/fi:HKI/board`.
- Expected vs actual: Digitraffic lists 59 departures in the window, including 8844 I 07:36 track 4, 8644 P 07:38
  track 16, 8846 I 07:51 track 3. Clack lists 37; all 22 missing rows are I/P ring trains (Helsinki → Helsinki via the
  airport, every 10 min each). Arrivals: no 86xx/88xx rows. The 37 shown rows match on time, delay, track and
  cancellation.
- Evidence: https://rata.digitraffic.fi/api/v1/live-trains/station/HKI?departing_trains=60 vs Clack, both read 07:37:05.
- File: apps/server/src/boards/finland.ts:53-54 (`if (!endpoint || endpoint === ctx.code) continue;`).
- Fix idea: keep them, with a "via Airport" style destination.
- Severity: major. Confidence: high.

**A2. The first viewer after the server idles sees positions 13 hours old as live**
- Where: `GET /api/live/trains` (and, by the same code path, the stream).
- Expected: no trains, or trains marked stale, until fresh feeds arrive.
- Actual: at 07:35:39 the endpoint returned `mode: "stopped"`, `upstreamAt` 2026-10-31 18:25 (13.2 h old), 149 trains
  with ids dated 2026-10-31 (e.g. SJ 574 near Umeå, `estimated: false`, 133 km/h). Twenty seconds later the ingest
  was running with fresh data.
- File: apps/server/src/livemap/ingest.ts:415 (`stop()` never clears `this.trains`); apps/server/src/routes/livemap.ts:58-66
  (`acquire()` then an immediate snapshot).
- Severity: major. Confidence: high for REST (observed); medium-high for the stream.

**A3. Finnish car count and type come from the first section of the composition only**
- Where: live map car boxes and train card; `compositionOf`/`vehicleOf`.
- Expected vs actual:
  - IC 909 Turku satama → Tampere, near Loimaa: Digitraffic has 7 coaches Turku satama–Turku, then **4 coaches**
    Turku–Tampere (126 m). Clack: `cars: 7`.
  - Night train 269 Helsinki → Kolari, between Ylitornio and Pello: Digitraffic's Oulu–Kolari section is a **Dr19**
    diesel with 14 vehicles (sleepers CEmt, restaurant, car carriers). Clack: `trainType: fi_sr3_ic` (electric Sr3 +
    InterCity coaches), `cars: 9` (the Helsinki section).
  - Separately, any Sr3-hauled night train gets the IC drawing (`vehicle_prefix: Sr3` → fi_sr3_ic), though a
    `loco_sleeper` family exists.
  - Digitraffic's real `totalLength` (Sm5 75 m, Sm3 160 m, IC 178 m) is fetched and thrown away.
- Evidence: https://rata.digitraffic.fi/api/v1/compositions/2026-11-01/909 and /compositions/2026-10-31/269, read
  07:37:42; Clack `/api/live/trains` 07:36:08 and 07:47.
- File: apps/server/src/digitraffic/trains.ts:191-209 (the `at` argument exists, livemap/finland.ts:409-410 doesn't pass
  it), :194 (`lengthM`); data/train_types.json:131.
- Severity: major. Confidence: high.

**A4. SJ Oslo → Stockholm: planner's Oslo departure times differ from Entur and from Clack's own Oslo S board**
- Where: Plan a journey > Oslo S → Stockholm C, Monday 2026-11-02.

  | Train | Clack planner (se3 timetable) | Entur, and Clack's Oslo S board |
  |---|---|---|
  | 626 | 05:56 local | 05:47 local |
  | 660 | 07:27 local (Kongsvinger 08:57) | 07:16 local (Kongsvinger 08:57) |
  | 674 | 14:36 local | 14:31 local |
  | 638, 648 | 11:46, 16:52 | match |

- Also: the Oslo S board rows for 626 and 660 have `trip: null` (not linked to the timetable trip).
- Effect: if Entur is right, a rider going by the planner reaches Oslo S 5–11 min after the train left. Which source
  is right is unverified (Entur carries Bane NOR's timetable; SJ's site wasn't checked).
- Evidence: https://getclack.app/api/search?q=Oslo%20S%20Stockholm%20C&date=2026-11-02 (07:40:49); Entur
  estimatedCalls for NSR:StopPlace:337 (about 07:42).
- File: apps/server/src/search/timetable.ts and the planner index (merging se3 and Norwegian trips).
- Severity: major. Confidence: high on the disagreement, medium on which is right.

**A5. Norwegian GPS positions run about 30 s behind, up to 1.4 km off**
- Where: Explore, Vy and Go-Ahead trains.
- Expected vs actual: Clack's `fixAt` was 28–31 s older than Entur's `lastUpdated` for the same vehicle, and Entur
  gives no speed, so nothing is carried forward. Running trains were a median 585 m from Entur's latest point; 18 of
  42 were over 500 m off; worst 1404 m (R12 509). Example RE20 107: Entur 59.491115, 10.706800 at 07:38:59.9; Clack
  59.50129, 10.71313 with `fixAt` 07:38:30.
- Evidence: https://api.entur.io/realtime/v2/vehicles/graphql (mode RAIL) vs Clack, 07:39:05.
- File: apps/server/src/livemap/norway.ts (20 s poll). Fix idea: Entur's vehicle subscription, and speed from
  successive fixes so the carry-forward in positioning.ts applies.
- Severity: major. Confidence: high.

**A6. Stockholm → Narvik night train shown as a tight change at Boden**
- Where: Plan a journey > Tomorrow > "Stockholm Narvik".
- Expected vs actual: Clack gives SJ 94 to Boden 05:42, change to SJ 98 at 06:07, `comfort: "tight"`, "typically 18 min
  late". Trafikverket's coach order is `Lok-17-18-20-21-22-23-24-25` for 94 at Stockholm C and `Lok-17-18-19-20` for 98
  from Boden, so coaches 17–20 look like a through portion and riders in them don't change. SJ sells it as one night
  train (SJ's site couldn't be fetched to confirm). No night-train or sleeper label appears anywhere.
- Evidence: [2026-11-01/s_09_night_train_narvik.png](2026-11-01/s_09_night_train_narvik.png); `/api/search`
  07:40:44; Trafikverket TrainAnnouncement for 94/98, 07:41.
- File: apps/server/src/search/planner.ts (change building); coach matching would need `parseComposition`
  (apps/server/src/legs/trainTypes.ts).
- Severity: major. Confidence: medium (through coaches inferred from coach numbers).

**A7. Planner offers journeys that another listed option beats outright**
- Where: Plan a journey.
- Actual:
  - Göteborg C → Oslo S: 19:24 VR 2050 to Stockholm C, SJ 1 night train to Helsingborg, then Snälltåget 30 back through
    Göteborg, arriving 13:16 next day. Vy 398 leaves later (20:10) and arrives 23:47 the same evening, direct.
  - Oslo S → Stockholm C: 638 to Södertälje Syd, 286 north to Ljusdal, night train 71 back to Stockholm C, 04:05 next
    day (1039 min). Direct 648 leaves later and arrives 21:24.
  - Helsinki → Rovaniemi: 9621 05:10 to Tikkurila, southbound night train 266 back to Pasila, 2 h wait, IC 23. Same
    arrival as IC 23 from Helsinki at 08:20. 9117 → 276 → 25 has the same shape.
  - Oslo S → Bergen: Go-Ahead 705 to Kongsberg, 726 back to Hokksund, Vy 61. Leaves 2 h earlier than direct 61, same
    arrival.
- Expected: drop a journey that leaves no later and arrives no earlier than another, especially with more changes,
  across the next-day window too.
- Evidence: `/api/search` for each pair, date 2026-11-02, 07:40:41–07:41:20.
- File: apps/server/src/search/planner.ts; `rank` in apps/server/src/routes/search.ts.
- Severity: major. Confidence: high.

**A8. Copenhagen → Hamburg picks the wrong station and says nothing**
- Where: Plan a journey > "Copenhagen Hamburg"; station search "Hamburg".
- Expected: Hamburg Hbf first; then the ECE/IC trains, or a clear "outside what Clack covers".
- Actual: resolves to **Hamburg Bergedorf**. "København H Hamburg Hbf" gives 0 journeys and 0 results with no note,
  while Clack's own København H board lists ECE 393 → Hamburg Hbf. Malmö C → Berlin Hbf also gives 0. Station search
  lists Hamburg-Altona and Hamburg-Bergedorf with `country: "NO"` (NSR:StopPlace:64372, 64112).
- Evidence: `/api/search` 07:40:47; `/api/stations/search?q=Hamburg` about 07:41; KH board 07:39:07.
- File: apps/server/src/search/ (ranking, interpretation); apps/server/src/import/gtfs-dk.ts probably drops German stops;
  the NSR country comes from the Norway import.
- Severity: major. Confidence: high for the behaviour, medium for the cause.

**A9. Oslo S station map is missing tracks 5–8, 11 and 12 and draws tram/metro platforms as rail**
- Where: Oslo S station map; data/stations/760000100.json.
- Expected vs actual: OSM has relations r4121521 (5;6), r6825729 (7;8), r4121516 (11;12); NSR lists quays 1–19; Entur
  used tracks 5, 6, 7, 8, 11 and 12 this morning. Clack's map has B, C, E, F, S, T, 19, 1–2, 3–4, 9–10, 13–14, 15–16,
  17–18. B, C, E, F, S and T are OSM ways tagged tram/subway (Jernbanetorget), given tracks "b", "c" and so on. Trains
  at 5–8, 11, 12 can't be placed. The research file (data/stations/research/NO-OSL_S/_report.json) already has
  r4121521, so the gap is in the export.
- Evidence: Overpass https://overpass-api.de/api/interpreter 07:48; Entur Oslo S calls 07:40:10.
- Severity: major. Confidence: high.

**A10. No sectors on the Malmö C or Stockholm C maps, though most Malmö C trains use them**
- Where: Malmö C station map > level −2, pinch zoom; Stockholm C station map.
- Expected: 2a/2b drawn and labelled as separate pieces when zoomed (as the boards show them).
- Actual: Trafikverket's tracks today at Malmö C: 1b 206, 2b 205, 3a 217, 4a 207 of about 1000 calls; at Stockholm C
  12a, 15a/b, 16a/b, 17b, 18b, 19b about 170 of 500. Neither map has lettered edges (only 740000090 has any), so trains
  are drawn at the platform middle. OSM has no `railway:platform:section` at either. No Finnish or Norwegian map has
  sectors either (whether they need them was not checked). Note: the hosted server was one commit behind the sector
  labels commit, but the missing piece is the data.
- Evidence: [2026-11-01/s_15_malmo_citytunnel_zoom.png](2026-11-01/s_15_malmo_citytunnel_zoom.png); Trafikverket
  TrainAnnouncement 07:48:33; `/api/stations/{id}/map` 07:42:48.
- File: data/stations/740000003.json, 740000001.json; packages/shared/src/station.ts (`platformPoint`, `platformSectors`).
- Severity: major. Confidence: high.

**A11. DSB S-tog drawn 2.3–4.7 times too long**
- Where: live map car boxes and 3D; data/train_types.json:54 (`dk_stog` cars 8) × 24 m per car
  (apps/Clack/ClackKit/.../TrainKit.swift:42).
- Expected vs actual: an SA is 8 short articulated cars, about 84 m; an SE is 4 cars, about 42 m
  (https://da.wikipedia.org/wiki/S-tog, read 07:30). Clack: about 198 m for both.
- Severity: major. Confidence: high on count, medium on exact length.

**A12. Six hand-made drawings would be deleted by the refresh script, and their sources aren't recorded**
- Where: scripts/trains/export_svg.py:17 (`HAND_MADE_PREFIX = 'fi_'`), :35-37.
- Actual: Type 69, Type 93, El 18, C10, X10p and X15p have no generator; running the documented refresh deletes these 13
  SVGs from assets/trains. docs/TRAIN_ART.md lists only `fi_*` as hand-made. Their photo and measurement sources are
  not recorded anywhere (commit 2ecc4da8).
- Severity: major. Confidence: high.

**A13. Passport CO₂: every train gets SJ's electric factor**
- Where: Passport CO₂; apps/server/src/stats/passport.ts:87 (`co2FactorsFor`), comment :84-86; `about.co2Body`.
- Expected: IVL U11173 (May 2026) gives 0.27 g/pkm for the average *SJ* train on SJ's own electricity (§5.4); SPEC §15
  calls it a simplification for electric Swedish trains only.
- Actual: every leg in SE, NO, FI and DK uses 0.27, including diesel IC3, MQ and Lint in Denmark, Nordland and Røros
  lines, Dm12, Y31/Itino. Denmark falls through at `?? co2Factors().SE`, and the "how we calculate" text mentions only
  Norway and Finland.
- Evidence: IVL PDF (https://cdn.sj.se/files/hulddl9x/production/93949dadb90990885c55266093ae4db2ec64f8d4.pdf/U11173%20Rapport%20Klimatdata%20fo%CC%88r%20Personresor%20SE.pdf),
  p.4 and p.57, read 07:41. data/co2_factors.json matches the report's numbers exactly.
- Severity: major. Confidence: high.

**A14. Finnish live-train stop lists include points the train passes**
- Where: `/api/live/trains/fi:155|2026-11-01/stops`, `/api/trains/155/2026-11-01`; planner `stopsBetween`.
- Expected vs actual: Digitraffic has 14 stopping stations for IC 155 (12 commercial); Clack returns 68 "stops", with
  interpolated times and no flag for pass-throughs. Helsinki → Rovaniemi IC 35 says 119 stops (about 25 real).
- File: apps/server/src/livemap/trainStops.ts (no noPickup/noDropoff); apps/server/src/search/timetable.ts has them but
  doesn't pass them on; apps/server/src/import/gtfs-fi.ts:196 keeps pickup_type=1 rows.
- Severity: minor to major (depends on how the train sheet renders them; not checked on screen). Confidence: high on
  the data.

**A15. Finnish board rows have no line letter**
- Where: `productName` always null on Finnish rows (apps/server/src/boards/finland.ts:92); Digitraffic's
  `commuterLineID` (I, P, K, Z, R…) is read only by the live map.
- Evidence: Helsinki board row 9825: null; Digitraffic "Z" (07:37:05).
- Severity: minor. Confidence: high (whether the app gets it some other way was not checked).

**A16. Moving trains shown as standing, or "At" a station at speed**
- Where: Explore; live trip card.
- Expected vs actual: 7 of 134 Swedish GPS-matched trains were `state: standing` while Trafikverket's GPS said 38–99
  km/h (1759 Pågatåg 99, 17607 Krösatåg 61, 2918 SL 60, 3033 Västtåg 49, 2518 SL 47, 1506 41, 3731 38). Positions were
  right. The live card for SJ 523 read "At Tranås · 122 km/h", then 105, then 58 km/h over a minute (Tranås planned
  09:32 local). Likely cause: the last report is still an arrival because the departure report is late.
- Fix idea: GPS speed over 3–5 km/h overrides "arrived"; "Arriving at Tranås" until the speed is near 0.
- Evidence: Trafikverket TrainPosition vs Clack, 07:36:50; walkthrough 2 hierarchy, about 08:25.
- File: apps/server/src/live/positioning.ts, apps/server/src/livemap/ingest.ts.
- Severity: minor. Confidence: high.

**A17. Train type disagrees between screens**
- Where: Stockholm C board vs Explore; SJ 523 search result vs trip header.
- Actual: Mälartåg 223 (Stockholm C → Norrköping) and two others are `regina` on the board and `er1` on the live map
  (3 of 62 compared; which is right is unverified). SJ 523 is "X2000 / High-speed" in search with an X2000 drawing,
  but the trip header says "InterCity".
- Evidence: [2026-11-01/s_04_sj523_stops.png](2026-11-01/s_04_sj523_stops.png),
  [2026-11-01/s_05_trip_detail_sj523.png](2026-11-01/s_05_trip_detail_sj523.png); board 07:37:05, live 07:38,
  compared 07:49:35.
- File: apps/server/src/boards/board.ts vs apps/server/src/livemap/ingest.ts `trainTypeFor`.
- Severity: minor. Confidence: high.

**A18. Network status: "Between Hyllie and Hyllie", and two delays**
- Where: Explore > Network status > Late trains.
- Actual: "Öresundståg 1037 +16 min, Between Hyllie and Hyllie"; opening the train shows +19.
- Expected: "At Hyllie" and one delay.
- Evidence: walkthrough 1 hierarchy text, about 08:00.
- Severity: minor. Confidence: high.

**A19. Stockholm C amenity hours and duplicates**
- Where: Stockholm C station map; data/stations/740000001.json, scripts/stations/740000001.edits.json.
- Expected vs actual: three Pressbyrån entries carry Stora hallen's hours ("Mo-Fr 05:15-23:30; Sa 05:15-23:00; Su
  06:00-23:00"). Jernhusen says Cityterminalen "Mån-fre 05.15-23.00, Lör 05.15-21.00, Sön 05.15-23.00" and Norra hallen
  "Mån–fre 05.15–23.30, Lör–sön 06.00–23.30". Duplicates: toilet osm:node/2494165898 twice (one as "Rena sitsen"
  without hours), Burger King, Upper Crust and 7-Eleven twice each. At København H, DSB Bagagecenter and DSB Billetter
  / Salg & Service appear twice (OSM and DSB page; hours agree with dsb.dk).
- Evidence: https://www.jernhusen.se/hitta-din-station/stockholms-centralstation/mat-och-butiker/ (07:51); dsb.dk (07:50).
- Severity: minor. Confidence: medium (Clack's entries are unnamed, so which unit is which is inferred).

**A20. Drammen map lacks track 1; Helsinki map has a tram stop as platform "52"**
- Actual: Drammen (NSR_StopPlace_11.json) has 6, 2–3, 4–5; OSM way 1305136492 has ref "1" and NSR quays 1–6. Helsinki
  (fi_HKI.json) "52" comes from osm:way/1135803013, tagged `tram=yes`. Asker and Tampere match OSM.
- Evidence: Overpass 07:44–07:49.
- Severity: minor. Confidence: high.

**A21. København H S-tog platforms 9–10 and 11–12 have no edges**
- Actual: the board gives "9", "12", "9-10", "11-12"; the map platforms have no edge lines, so a standing S-tog can't
  be placed. Heights (0.92) match OSM.
- Severity: minor. Confidence: high.

**A22. Car counts missing, so the template default is used**
- Where: data/train_types.json; fallback apps/Clack/ClackKit/.../TrainKit.swift:49-59. Applies whenever there's no live
  count: always in 3D, always in Norway and Denmark.

  | Type | Clack | Source says | Source (read UTC) |
  |---|---|---|---|
  | X31 | 4 | 3 cars | https://sv.wikipedia.org/wiki/X31 (07:25) |
  | Regina | 4 | 2 or 3 cars | https://sv.wikipedia.org/wiki/Regina_(tåg) (07:32) |
  | Type 74/75 | 4 | 5 cars | https://en.wikipedia.org/wiki/NSB_Class_74 (07:20) |
  | Sm2 | 4 | 2 cars | https://en.wikipedia.org/wiki/VR_Class_Sm2 (07:24) |
  | Sm4 | 4 | 2 cars | https://en.wikipedia.org/wiki/VR_Class_Sm4 (07:30) |
  | Dm12 | 2 | 1 car | https://en.wikipedia.org/wiki/VR_Class_Dm12 (07:30) |
  | Y1 | 2 | single railcar | data/train_types.json:20 (its own "about") |

- Severity: minor. Confidence: high.

**A23. Coupled units never drawn in the station 3D view**
- Where: apps/Clack/.../StationScene3D.swift:388 (`carCount(live: nil, …)`); ExploreModel.swift:489.
- Actual: a doubled X2000, Type 73 or X40 is drawn as one unit in 3D, while the live map doubles it. Norway and Denmark
  never have a live count. `carCount`'s `known` flag is never read, so a guess looks like a fact.
- Severity: minor. Confidence: high.

**A24. Locomotives and the X2000 power car are not counted**
- Where: apps/server/src/legs/trainTypes.ts:69-73; apps/server/src/digitraffic/trains.ts:193; TrainKit.carCount.
- Actual: loco-hauled trains are drawn one vehicle short. X2000 is "1 power car + 4 or 5 intermediate + 1 control
  coach" (https://en.wikipedia.org/wiki/X_2000, 07:22); the `cars: 6` rule may miss 6-vehicle sets.
- Severity: minor. Confidence: medium.

**A25. Train facts without a source**
- Where: data/train_types.json:4-36.
- Actual: 33 of 63 types have no `_source`; 12 have none at all (rc6_sleeper, loco_coaches, loco_sleeper, y1,
  heritage, no_type69, no_type69_72, no_type93, x11_x14, itino_y2, di4_coaches, flytoget). The x74 "since 2015,
  formerly MTR Express" note has none. Unsourced operator rules: vr→x74, oresundstag→x31, pagatag→x61, sl→x60,
  go-ahead-norge→no_type73/72, sj-nord→no_type76, and Vy's no_type72, no_type69_72 and `no_flirt` rules (only the
  Notodden rule cites one). `vy` + `intercity` → Flirt also covers the Bergensbanen day trains 61, 63, 601, 67; the
  reviewer's understanding is these are often El 18 + coaches or Type 73. **Unverified**: Entur gives no vehicle type.
- Severity: minor. Confidence: high on missing sources, low on the Bergen question.

**A26. Passport flight comparison uses rail km**
- Where: apps/server/src/stats/passport.ts:89-93.
- Expected vs actual: IVL uses each mode's own distance (Stockholm–Malmö: flight 531 km, train 598; Stockholm–Sundsvall:
  319 vs 396, Tables 12–13). Clack multiplies rail km by the flight factor, overstating "would have emitted by flying"
  by about 10–25%, and shows a flight figure for a 5 km commuter hop.
- Severity: minor. Confidence: high.

**A27. Passport distances can be straight lines, and unknown counts as 0**
- Where: apps/server/src/routes/legs.ts:122, :218; apps/server/src/.../trackSegments.ts:108; passport.ts:474 (`distanceM ?? 0`).
- Actual: distance starts as the straight line between stops and is replaced by track length only when the rail graph
  routes it. `PassportLeg` drops `isEstimatedGeometry`, so totals mix track and straight-line km unflagged; a null adds
  0 silently. The text says "Distance along the track".
- Severity: minor. Confidence: high.

**A28. "Latest arrival" and "earliest departure" ignore times after midnight**
- Where: apps/server/src/stats/passport.ts:172-173.
- Actual: sorted by minutes since 00:00, so a 00:40 arrival can never be "latest", and a 00:15 departure beats a 05:30
  commuter as "earliest". A service-day boundary around 03:00 would fix both.
- Severity: minor. Confidence: high.

**A29. Smaller position gaps in Sweden and Denmark**
- Swedish: SJ 525 (171 km/h) was 2059 m from its Trafikverket fix once (07:36:37), not repeated 13 s later
  (positioning.ts `advanceM`). Severity minor, confidence low.
- Swedish: six trains with Trafikverket GPS were not on the map (7714, 7716, 7817, 7917, 7517, 2915; probably short
  workings with no announcement match). Severity minor, confidence medium.
- Danish: positions differ from Rejseplanen's own calculated positions by median 255 m, 6 of 77 over 1 km (ICL 14
  5647 m, IC 818 4806 m, ECE 393 2825 m); both sides are estimates and Clack labels all Danish trains as estimated.
  Severity minor, confidence medium.
- Severity: minor. Confidence: as listed.

**A30. Smaller data points**
- Denmark: NT and Midttrafik trains show the line ("75", "92") as the train number; several trains share it
  (DENMARK_DATA_FINDINGS already notes the numbers are unverified).
- Göteborg C platform heights for tracks 9 and 10 are ambiguous: the register rows "9,8 låg", "10,9 mellan 0.58" and
  "10,11 låg 0.35" overlap, and island platforms are mapped per track (data/stations/740000002.json). Confidence low.
- Replacement and connecting buses (15 rows, e.g. SJ 60167/60169, Västtågen 63740) are left off boards as SPEC §11
  says; a rider whose train is replaced sees nothing. A product decision.
- Passport: the CO₂ switch is local `@State`, not the setting (widgets keep the setting), and offers 2 of 7 sourced
  options (PassportScreen.swift:18, :33, :282; Settings.swift:289); the comment calls car_1 "petrol", but IVL's 190 is
  the average car (petrol alone is 200).
- Passport: Sweden's length (1,572 km) has no source; Denmark's is approximate and not in SPEC §14
  (passport.ts:45-47, :54). Norway's 1,699 km matches https://snl.no/Norge.
- scripts/trains/x2000.py:3 says the rebuilt livery is not drawn, while :39 and :66 draw `sj` (X2C) and `sj-x2`;
  its fleet note (10 rebuilt) is out of date (14 of 36 by September 2026, per Wikipedia).
- Severity: polish. Confidence: high unless noted.

### Workflows and layout

**W1. A train that is already running is hidden behind "Show earlier"**
- Where: Find your train > type "523", at 08:54 local.
- Expected: trains running now listed first (logging the train you're on is the app's main job).
- Actual: only Vy 523 (15:31) shows. SJ 523 left at 07:22 and was 32% along; it appears only after "Show earlier".
- Evidence: [2026-11-01/s_03_number_523.png](2026-11-01/s_03_number_523.png).
- Severity: major. Confidence: high.

**W2. No lifts or step-free routes**
- Where: Explore > Stockholm C > Station map > search / Directions; Malmö C City Tunnel level.
- Expected: lifts marked and a step-free route option (travellers with luggage, prams, wheelchairs).
- Actual: no Lifts chip (Toilets, Food, Shops, Tickets, Lockers, Info); "lift"/"elevator" finds nothing; directions
  from Centralens huvudentré to platform 12 say "Take the stairs down… Take the stairs up" with no alternative; Malmö's
  tunnel level shows no lifts or escalators. The app has no lift concept.
- Evidence: [2026-11-01/s_14_station_route_stairs.png](2026-11-01/s_14_station_route_stairs.png),
  [2026-11-01/s_13_station_map_stockholm.png](2026-11-01/s_13_station_map_stockholm.png).
- Severity: major. Confidence: high.

**W3. You can't change where you got on or off after adding a trip**
- Where: Trip > ⋯ (only Refresh and Delete); "Was it a different train? Change it"; car/seat fields.
- Expected: an Edit for the stops.
- Severity: minor. Confidence: medium.

**W4. No commuter trains for "Stockholm Uppsala"**
- Where: Find your train > "Stockholm Uppsala", with "Include commuter trains by default" on.
- Expected: the SL pendeltåg (lines 40/41) or a hint to use Stockholm City.
- Actual: only Mälartåg and SJ.
- Evidence: [2026-11-01/s_02_route_search.png](2026-11-01/s_02_route_search.png).
- Severity: minor. Confidence: medium.

**W5. Explore country filter reads backwards; the train counter is unclear**
- Where: Explore > Filters > Countries.
- Actual: with every switch off, all trains show; turning Sweden on shows only Sweden. The "N trains running" counter
  read "1 train running" right after a filter change and "423" while zoomed onto Belgium with nothing in view.
- Expected: all on by default (off = hide); a counter that clearly means all or in-view.
- Severity: minor. Confidence: high.

**W6. Station map opens cluttered**
- Where: Stockholm C, Malmö C, Göteborg C station maps.
- Actual: dozens of POIs carry "?" badges (hours unknown) with no legend; platform numbers cut off at the left edge
  ("16"); raw OSM tags as names ("ticket", "atm", "locker", "toilet"); look-alike duplicates in the list (2× "Cash
  machine", 2× "7-Eleven"). At Göteborg C, "15/…" and "3/…" are cut at the right edge and the "0" level button sits on
  them.
- Expected: platforms framed on open, a legend for "?", readable names.
- Evidence: [2026-11-01/s_13_station_map_stockholm.png](2026-11-01/s_13_station_map_stockholm.png),
  [2026-11-01/s2_2_sv_dark_stationmap_goteborg.png](2026-11-01/s2_2_sv_dark_stationmap_goteborg.png).
- Severity: minor. Confidence: high.

**W7. Station-map search sheet needs two taps to close; keyboard covers "Start from"**
- Where: Station map > Search / Directions > From.
- Actual: the first tap only dismisses the keyboard and moves the sheet. In "Start from" the keyboard covers most of the
  list, so taps meant for rows land on keys (stray letters were typed this way).
- Severity: minor. Confidence: high.

**W8. Passport ignores a trip in progress**
- Where: Passport tab while SJ 523 was 32% along.
- Actual: "Your passport starts here, 0 of 1", and it still offers "Find a train" though trips exist. CO₂ and the share
  card couldn't be tested because nothing had finished.
- Expected: show the trip in progress, or say "after your first arrival"; drop the add button once trips exist.
- Severity: minor. Confidence: high.

**W9. The tab bar covers content**
- Where: Trip detail right after "View trip"; scroll views at large text sizes.
- Actual: the "Get alerts for this train?" banner sits half under the floating tab bar; at large sizes the last row of
  every scroll view (a "Relaxed · 70 min to ch…" line, a stop, a board row) is covered.
- Evidence: [2026-11-01/s_05_trip_detail_sj523.png](2026-11-01/s_05_trip_detail_sj523.png),
  [2026-11-01/s2_5_axl_journey_wordbreak.png](2026-11-01/s2_5_axl_journey_wordbreak.png),
  [2026-11-01/s2_7_axl_trip_stops_clipped.png](2026-11-01/s2_7_axl_trip_stops_clipped.png).
- Severity: minor. Confidence: high.

**W10. Location prompt on first Explore tap with no explanation**
- Actual: the system prompt appears immediately (its text is good). A short pre-prompt, or asking only on "My
  location", would be kinder.
- Severity: polish. Confidence: high.

**W11. Wording and confirmations around adding**
- Actual: "Find your train" (welcome), "Find a train" (empty state), "Add train" (+), sheet title "Plan a journey",
  button "Add to trips" in one place and "Add to Clack" in another. The "Added" confirmation for a 2-train journey names
  only the last leg ("Göteborg C → København H, Öresundståg 1079"; both legs were saved).
- Expected: one verb and name; "Oslo S → København H, 2 trains".
- Severity: polish. Confidence: high.

**W12. Delete trip has no Cancel and no undo**
- Where: Trip > ⋯ > Delete trip (dismiss only by tapping outside).
- Severity: polish. Confidence: high.

**W13. Repeated and slightly-off text**
- Actual: "Relaxed · 70 min to change" then "7 min walk · 70 min to change" (planner and Trips). "Next stop: Ski 09:12"
  while the stop list says 09:13 (Vy 1909). "Next stop: Stockholm C 09:05" for a train that hasn't left its first
  station ("Departs 09:05"). "On its way" on a not-yet-departed Mälartåg. Welcome list cuts off "København Øs…" and
  "Arlanda Express 78…". "+1" in amber under a time can read as "+1 day".
- Evidence: [2026-11-01/s_08_journey_change_disabled_map.png](2026-11-01/s_08_journey_change_disabled_map.png),
  [2026-11-01/s_01_welcome.png](2026-11-01/s_01_welcome.png), [2026-11-01/s_07_trips_list.png](2026-11-01/s_07_trips_list.png).
- Severity: polish. Confidence: high.

**W14. Map labels crowd controls**
- Actual: on trip detail the "Stockholm C" label crowds the ⋯ and share buttons; on the Trips card "Live position" sits
  on "Bergen". Explore at far zoom has no place names.
- Evidence: [2026-11-01/s_05_trip_detail_sj523.png](2026-11-01/s_05_trip_detail_sj523.png),
  [2026-11-01/s_07_trips_list.png](2026-11-01/s_07_trips_list.png).
- Severity: polish. Confidence: medium.

**W15. Explore says "Live data unavailable · retrying" while it is just connecting**
- Actual: for 10–20 s after launch, before "458 trains running".
- Expected: "Loading live trains…" until a real failure.
- Severity: polish. Confidence: medium.

**W16. No 3D view in Release**
- Actual: the 3D button is Debug-only (StationMapScreen.swift, Jönköping C only). Fine if intended; noted so testers
  don't hunt for it.
- Severity: polish. Confidence: high.

### Bugs

**B1. The live trip screen contradicts itself**
- Where: Trip detail for SJ 523 while running.
- Actual: "Live now · Platform 11 · On time" and right below "Live times appear closer to departure."; the Activity
  section says "Live updates appear here while the train runs." while it runs.
- Evidence: [2026-11-01/s_05_trip_detail_sj523.png](2026-11-01/s_05_trip_detail_sj523.png).
- Severity: major. Confidence: high.

**B2. Train Wi-Fi login pages break the offline fallback**
- Where: apps/Clack/ClackKit/Sources/ClackCore/API/APIClient.swift, OfflineCache.swift; apps/Clack/Clack/App/ConnectionState.swift.
- Actual: the saved copy is used only on a `URLError`. A captive portal answering HTTP 200 HTML (or a redirect) counts
  as online, decoding fails, and the saved trips are not shown; no offline strip either. Likely on SJ/Vy Wi-Fi before
  login.
- Severity: major. Confidence: medium-high (code path clear; not tested).

**B3. Weak signal means a 15 s wait before anything shows**
- Actual: the saved copy is read only after the request fails (15 s GET timeout), so each screen can wait up to 15 s on
  a train in poor coverage. Expected: show saved, then refresh.
- Severity: major. Confidence: high.

**B4. Train placement silently stops after one failed request in a tunnel**
- Where: apps/Clack/Clack/App/RiderReporter.swift:87-92; LocationModel.swift.
- Actual: one failed `liveMine()` makes `running` empty and calls `stopFollowing()`, which invalidates the background
  session; it can only restart from the foreground, so placement stops for the rest of the trip.
  `pausesLocationUpdatesAutomatically` is left true, so iOS may pause during a long stop and not resume in the
  background.
- Severity: minor. Confidence: medium (code only).

**B5. "Open station map" for a change is a dead button; walk times disagree**
- Where: Plan a journey > Oslo S → København H > journey detail > change at Göteborg C.
- Actual: the button is disabled but looks enabled; tapping does nothing. The same change on Trips links to the map.
  Walk time: 7 min in the planner, 5 min in Trips ("Platform 7 → 14 · 5 min walk").
- Evidence: [2026-11-01/s_08_journey_change_disabled_map.png](2026-11-01/s_08_journey_change_disabled_map.png).
- Severity: minor. Confidence: high.

**B6. Launch screen is white or black for seconds, then flashes yellow**
- Where: cold launch.
- Expected: brand yellow from the first frame.
- Actual: Info.plist sets `UILaunchScreen > UIColorName = launch-bg`, but that colour set exists only in
  apps/Clack/ClackKit/Sources/ClackDesign/Resources/Assets.xcassets, not in the app target's catalogue, so iOS falls back
  to white (light) or black (dark). In the simulator: white 0–6 s, yellow splash at 7 s, usable Trips at about 8–9 s
  (a real phone is usually faster).
- Evidence: [2026-11-01/s3_4_launch_white_3s.png](2026-11-01/s3_4_launch_white_3s.png),
  [2026-11-01/s3_5_launch_yellow_splash_7s.png](2026-11-01/s3_5_launch_yellow_splash_7s.png).
- Fix: add `launch-bg` to apps/Clack/Clack/Assets.xcassets.
- Severity: minor. Confidence: high.

**B7. Offline gaps (from code)**
- Writes aren't queued: add, delete, car/seat, confirm arrival just fail offline; nothing retries. (The message the
  user sees was not checked.) Minor, high.
- Station maps are cached only if opened online before; the tile pack stops at zoom 10; boards aren't cached, so "which
  platform" at a change can't be checked offline. Minor, high.
- Map packs are always built from the dark style; `pack?.resume()` runs without watching progress or errors; "maps
  saved" counts packs, not completed ones (apps/Clack/Clack/Map/OfflineMaps.swift). Polish, low-medium.
- The cache is in Caches, which iOS may clear when space is short. Polish, medium.
- Severity: minor. Confidence: as listed.

### Design, strings and accessibility

**D1. At AX-XXXL the Plan a journey sheet is wider than the screen**
- Where: + > Plan a journey at AX-XXXL.
- Actual: title reads "a journey", the "Today" chip shows "y", "Pick a date" shows "date", the placeholder and recent
  searches are cut on both sides. Content seems laid out at a fixed width larger than the screen and centred.
- Evidence: [2026-11-01/s2_10_axxxl_plan_sheet_offscreen.png](2026-11-01/s2_10_axxxl_plan_sheet_offscreen.png).
- Severity: major (a blocker for users at that size). Confidence: high.

**D2. Flip-tile times wrap and clip at AX-L**
- Where: Trips card, trip detail.
- Actual: "07:22 –" on one line, "11:54" on the next, "+1" alone below; on trip detail "DEP…", "ARRI…", and "11 5…"
  runs off the right edge.
- Expected: cards stacked at accessibility sizes; times never clipped.
- Evidence: [2026-11-01/s2_4_axl_trips_attribution.png](2026-11-01/s2_4_axl_trips_attribution.png),
  [2026-11-01/s2_7_axl_trip_stops_clipped.png](2026-11-01/s2_7_axl_trip_stops_clipped.png).
- Severity: major. Confidence: high.

**D3. Words break mid-word at AX-L**
- Where: Trips journey card, trip stops, Göteborg C board.
- Actual: "Götebor / g C", "Stockhol / m C", "Varb / erg C", "Möln / dal", "Depart / ed"; the journey leg squeezes date
  and times next to a fixed "340 km" column.
- Evidence: [2026-11-01/s2_5_axl_journey_wordbreak.png](2026-11-01/s2_5_axl_journey_wordbreak.png),
  [2026-11-01/s2_7_axl_trip_stops_clipped.png](2026-11-01/s2_7_axl_trip_stops_clipped.png),
  [2026-11-01/s2_8_axl_board_broken.png](2026-11-01/s2_8_axl_board_broken.png).
- Severity: major. Confidence: high.

**D4. The departure board is nearly unusable at AX-L**
- Where: Göteborg C board.
- Actual: time, destination and platform/status columns stay side by side, so the destination gets a third of the width
  and rows are very tall. The Departures/Arrivals control doesn't scale.
- Expected: one column per row (time + platform, destination below).
- Evidence: [2026-11-01/s2_8_axl_board_broken.png](2026-11-01/s2_8_axl_board_broken.png).
- Severity: major. Confidence: high.

**D5. Settings at AX-XXXL: labels break, values truncate**
- Actual: "Appear / ance", "Langua / ge"; values "Eng…", "Sw…", "Kilome…", "24-ho…"; the Appearance control doesn't
  scale.
- Expected: label above value, as iOS Settings does.
- Evidence: [2026-11-01/s2_9_axxxl_settings_truncated.png](2026-11-01/s2_9_axxxl_settings_truncated.png).
- Severity: major. Confidence: high.

**D6. Map attribution grows over the map at AX-L**
- Where: Trips card map, trip-detail map.
- Actual: "© OpenStreetMap contributors · Protomaps" scales with Dynamic Type and covers about a third of the map, over
  the route and the Malmö C label.
- Evidence: [2026-11-01/s2_4_axl_trips_attribution.png](2026-11-01/s2_4_axl_trips_attribution.png),
  [2026-11-01/s2_6_axl_trip_detail_overflow.png](2026-11-01/s2_6_axl_trip_detail_overflow.png).
- Severity: minor. Confidence: high.

**D7. Underlying cause: `dynamicTypeSize` never handled; fixed-size icons**
- Actual: 0 uses of `dynamicTypeSize`. `lineLimit(1)` on key text: WelcomeView.swift:83, BoardRowView.swift:123,
  ServiceHeader.swift:60, ExploreSheets.swift:108, ExploreScreen.swift:297, StationMapScreen.swift:303, :567 (78 in all,
  many with `minimumScaleFactor`, which is fine). `LucideIcon` (ClackDesign/LucideIcon.swift:42) and Controls.swift:197
  stay 12–18 pt at accessibility sizes.
- Severity: minor. Confidence: medium.

**D8. The live trip card is one button that reads only "View journey"**
- Where: Trips, live card.
- Expected: a label with status, delay and next stop, or the card not wrapped in one Button.
- Actual: one button "View journey: Stockholm C to Malmö C"; if SwiftUI merges the children into that label (usual for
  a Button), VoiceOver never hears "Live", the times, delay, "43% of the way", "Between Linköping C and Tranås" or the
  next stop.
- Severity: major. Confidence: medium (needs a VoiceOver run).

**D9. Delays and times read without meaning**
- Where: Trips card, trip detail, boards.
- Actual: delays read "+1", "+3" with no "minutes late". A board row reads "09:19, 09:16, Alingsås…" without saying which
  is new; the arrival card reads "11:53" (struck out, the timetable) then "+1", and the strikethrough isn't spoken.
- Expected: "Expected 09:19, planned 09:16, 3 minutes late".
- Severity: major. Confidence: high.

**D10. VoiceOver can't reach anything on the Explore map**
- Where: Explore; apps/Clack/Clack/Map/LiveMapView.swift (no accessibility code).
- Actual: the map is one element ("Map, Zoom 4x"); trains are reachable only through search. MapLibre's own "You Are
  Here, 63 degree(s) north…" and "Compass" are exposed.
- Expected: a "Trains in view" list or elements for visible trains, or at least a hint to use search.
- Severity: major. Confidence: medium.

**D11. `text-3` ink fails 4.5:1 and carries real information**
- Where: ClackDesign/Resources/Assets.xcassets/Colors/text-3.colorset; 43 uses.
- Actual: #8A8A8A on white ≈ 3.4:1; #6E6E6E on #0A0A0A ≈ 3.9:1. Used for the network-status explanation
  (NetworkPanel.swift:52), corridor hint and notice source (ExploreSheets.swift:277, :304), 3D hints and credits, the
  version line (SettingsScreen.swift:275-276), map attributions. `unknown` draws "—" at the same contrast. No colour set
  has a high-contrast variant, so Increase Contrast changes nothing.
- Expected: ≥ 4.5:1 for text (DESIGN §16), e.g. about #767676 on white; high-contrast variants.
- Severity: major. Confidence: high.

**D12. Swedish uses "resa" for both trip and journey**
- Actual: `nav.trips` = "Resor" (lists single trains) and `passport.journeys` = "Resor" (counts journeys), so Passport
  shows "Tåg 12 / Resor 7" next to a tab "Resor" with 12 items. Journey is "Resa", "Resväg" and "reseväg" in different
  keys (`journey.label`, `nav.journey`, `add.connectionNoteMore`).
- Expected: one fixed pair, e.g. trip = "resa"/"tågresa", journey = "resväg", used everywhere.
- Severity: major. Confidence: high.

**D13. The app's language isn't passed to the system**
- Where: apps/Clack/ClackKit/Sources/ClackCore/Models/Settings.swift:156 (`language: .en`); apps/Clack/Clack/App/AppModel.swift:201.
- Actual: default English whatever the phone's language (home country, by contrast, follows the region). No
  `.environment(\.locale, …)`, so date pickers (AddTrainSheet.swift:323, :831; StationMapScreen.swift:496), ShareLink,
  menus and permission prompts follow the phone; `reasons.formatted(.list(type: .and))` (ExploreSheets.swift:471) gives
  "Försenat på grund av A and B"; VoiceOver reads Swedish text with the phone's voice.
- Expected: default to Swedish when the phone is Swedish; set `\.locale` at the root.
- Severity: major. Confidence: high.

**D14. Swedish UI shows English data text**
- Where: Trip detail > Om tåget (Swedish).
- Actual: amenity details stay English under Swedish headings ("Tyst avdelning · 2 klass Lugn carriage", "At your seat
  on the rebuilt X 2000", "Breakfast served at your seat before 09:00…", "Steps up into the train; wheelchair lift").
  The train description is English ("Sweden's tilting high-speed train…"); `/api/train-types` with `Accept-Language: sv`
  returns English `about` (TrainCard.swift:34). In the English UI the reverse happens: "Djur tillåtet", "2 klass Lugn
  carriage". "Some actual times" under Your seat is unexplained.
- Evidence: [2026-11-01/s2_1_sv_amenities_english.png](2026-11-01/s2_1_sv_amenities_english.png),
  [2026-11-01/s2_3_sv_train_english_desc.png](2026-11-01/s2_3_sv_train_english_desc.png),
  [2026-11-01/s_06_trip_amenities.png](2026-11-01/s_06_trip_amenities.png).
- Severity: minor. Confidence: high.

**D15. Server error texts reach users in English only**
- Where: AddTrainSheet.swift:604, :619, :688, :853; PlannedJourneyViews.swift:222 show `APIError.message`
  (APIClient.swift:11 "English, not localised"); apps/server/src/routes/legs.ts:60-90, :195-200.
- Actual: a Swedish user sees "You already added this train on this date", "The train doesn't take passengers at X",
  "Train numbers are letters and digits only". Breaks the String Catalog rule.
- Severity: minor. Confidence: high.

**D16. Untranslated level name on station maps**
- Actual: in Swedish the level label stays "Platforms and hall"; the level buttons show only "+1" and "0", so that's the
  only name.
- Evidence: [2026-11-01/s2_2_sv_dark_stationmap_goteborg.png](2026-11-01/s2_2_sv_dark_stationmap_goteborg.png).
- Severity: minor. Confidence: high.

**D17. Station names shown several ways**
- Actual: planner and trips "København H"; boards and train cards "Köpenhamn H"; welcome list "København Østerport";
  Danish live trains "Østerport St.", "Nørreport St."; search shows "Stockholms S" (the short code). Station search
  lists "Göteborg Sävenäs" (a yard).
- Expected: one display name per station, in the app's language.
- Evidence: [2026-11-01/s_12_board_stockholm.png](2026-11-01/s_12_board_stockholm.png); hierarchy text.
- Severity: minor. Confidence: high.

**D18. Swedish grammar and wording**

  | Key | Now | Should be |
  |---|---|---|
  | `share.late`, `train.usuallyLate` | "… min sen" | "… min sent" (as `passport.minutesLate` already says) |
  | `status.cancelled`, `delay.cancelled` | "Inställd" | "Inställt" (as `train.statusCanceled`) |
  | `widgets.nextJourney.description` | "… från perrongen till framme." | "… från perrongen tills du är framme." |
  | `widgets.passport.description` | "folie-kortet" | "foliekortet" |
  | `station3d.trains` | "Tåg, närmaste 30 minuterna" | "Tåg de närmaste 30 minuterna" |
  | `liveMap.legendAhead` | "Streckad: dit det ska" | "Streckad: dit tåget ska" |
  | `liveMap.notRunningBody` | "har gått klart för dagen" | "har kört klart för dagen" |
  | `tripCard.board` | "PÅ" | "PÅSTIGNING" |
  | `record.why.cancelled` | "tog en ersättning" | "tog en ersättningsbuss" |
  | `liveMap.simulated` (other) | "%lld tåg · simulerat" | "%lld tåg · simulerade" |
  | `record.why.border_reports` | "är väntad" | "är beräknad" |

- Severity: minor. Confidence: high.

**D19. Swedish terms used inconsistently**
- Operator: "Operatör", "Tågbolag", "Bolag", "trafikbolagens" (pick "tågbolag"). Notifications: "Notiser" and
  "aviseringar" (iOS says "Notiser"). "Byte i" vs "Byte vid" (`tripCard.changeAt`). `cause.platformChange`
  "Plattformsbyte" vs "Spårändring" elsewhere. "Inget direkttåg" vs "Inget direkt tåg".
- Severity: minor. Confidence: high.

**D20. Status by colour only**
- Actual: on-time rows say nothing; passed stops have green (actual) times and the rest black (planned) with nothing
  spoken; the passed route line is green. Station-map POI open/closing/closed is a 7 pt green/amber/grey dot only
  (StationSceneView.swift:228-234).
- Expected: "departed 09:02" / "expected 09:32"; state in words.
- Severity: minor. Confidence: high.

**D21. Stop rows and station-map POIs read poorly**
- Actual: each stop row reads "Departures from Linköping C, 09:02" (action first, no platform), with a nested button
  repeating it. POIs are bare names: three "Espresso House" alike; "Subway" with no category (heard as the metro);
  "toilet" (raw value fallback, StationSceneView.swift:248); "?" read as "question mark". Platforms and tracks are one
  image, so no platform can be found.
- Expected: "Linköping C, departed 09:02, platform 1" with "Opens departures" as a hint; "Espresso House, café, opening
  hours unknown".
- Severity: minor. Confidence: high.

**D22. Small VoiceOver issues**
- Duplicated words: "Changed, Changed", "Västtågen, Västtågen 3536", "SJ, SJ 523", two "Live" texts.
- Settings menus: the value ("English", "Kilometres") is a separate text, probably not spoken with the button. Use
  `accessibilityValue`.
- Filter button count not spoken (ExploreScreen.swift:213-224); `add.filtersOn` exists.
- "lucide-gauge" next to "179 km/h" may be spoken on its own; check once.
- Severity: polish. Confidence: medium-high.

**D23. Tappable platform tag isn't a button**
- Where: apps/Clack/Clack/Features/TripDetail/TripDetailScreen.swift:673-687.
- Actual: `.onTapGesture` on a ~26 pt tag with `.accessibilityElement(children: .ignore)`, no `.isButton`, no hint.
  VoiceOver users can't find that the platform is editable.
- Severity: minor. Confidence: high.

**D24. Manual-add time pickers have no label and ignore the clock setting**
- Where: apps/Clack/Clack/Features/Add/AddTrainSheet.swift:831 (`DatePicker("", …).labelsHidden()`).
- Actual: VoiceOver reads "10:51" with no "Departed"/"Arrived"; "Not set" shown only by opacity; 12/24 h follows the
  phone, not `settings.clock`.
- Severity: minor. Confidence: high.

**D25. Full pills on the station map**
- Where: apps/Clack/Clack/Map/StationSceneView.swift:213-215, :259-261.
- Actual: platform chips and place labels are 22 pt tall with radius 11 (fully round); widths computed from character
  count, so text is cut at large sizes.
- Expected: `Radius.controlSm` (10), DESIGN §2.3.
- Severity: minor. Confidence: high.

**D26. Tap targets under 44 pt**
- StatsWidgetView.swift:81-85 (32×24); StationMapScreen.swift:487-498 (time chip 34 pt, near-invisible DatePicker
  overlay); `IconButton(size: .overMap)` 34 pt for Close/Favourite in sheet headers (ExploreSheets.swift:116, :271,
  :361, :406, :409; StationMapScreen.swift:388-398), borderline over maps.
- Severity: minor. Confidence: high.

**D27. Hard-coded or drifted colours**
- Unknown operator falls back to yellow (RouteMapView.swift:239, :322; MapLibreSupport.swift:147); DESIGN §2.1 says the
  strong colour. Dark platform fill `#4a4a4a` vs DESIGN `#3a3a3a` (MapStyle.swift:181, :261). Unknown/other `#9AA0A6` vs
  `#8E8E8E`/`#8A8A8A` (ExploreLogic.swift:417, :420). Label backing `UIColor(44,44,46)` (LiveMapView.swift:521).
- Severity: minor. Confidence: high.

**D28. Dark mode: faint medals and vanishing Danish trains**
- Locked Passport medals: dark grey glyphs on near-black.
- Explore dark: navy/purple Danish dots almost vanish; a light outline would help.
- Evidence: [2026-11-01/s3_3_dark_passport_medals.png](2026-11-01/s3_3_dark_passport_medals.png),
  [2026-11-01/s3_2_dark_explore.png](2026-11-01/s3_2_dark_explore.png). Dark Trips, trip detail, board and Settings
  looked right ([2026-11-01/s3_1_dark_trips.png](2026-11-01/s3_1_dark_trips.png)).
- Severity: polish. Confidence: medium.

**D29. Formatting, plurals and small wording**
- "km/h" always, even with miles (LiveComponents.swift:59).
- "(12%)" built in code; Swedish wants "12 %" (PassportScreen.swift:249).
- CO₂ "0.4 kg" in Swedish should be "0,4 kg" (`String(format:)`, PassportScreen.swift:285; `%g` at :252).
- `passport.mapLabel` not plural: "all 1 trains" (PassportScreen.swift:168).
- `settings.alerts.arrival` "Welcome at your destination" → "Welcome to your destination".
- Mismatched corners: fill `Radius.input` 12, border radius 14 (StationMapScreen.swift:306-307).
- Explore filter sheet uses system `.footnote` / `.secondary` (allowed in a Form, not tokens).
- Unknown POI category would show the raw key `stationMap.cat.<raw>`.
- Hard-coded English in "Test alerts" (SettingsScreen.swift:161, TestAlertsScreen.swift:291-333) besides the walk tool.
- Severity: polish. Confidence: high.

### Server

**S1. A date that matches the pattern but doesn't exist gives a 500**
- Where: `GET /api/trains/523/2026-13-45`, `GET /api/search?q=523&date=2026-13-45`.
- Expected: 400, like `/trains/523/xx`.
- Actual: 500 `{"statusCode":500,"error":"Internal Server Error","message":"Invalid time value"}`.
- Evidence: curl, 07:48.
- File: apps/server/src/routes/livemap.ts:168, :212 (only the regex is checked); apps/server/src/routes/search.ts.
- Severity: major. Confidence: high.

**S2. `/history/prepare` starts loading for impossible dates**
- Actual: `?date=2026-02-31` → 200 `{"sweden":"loading","norway":"loading","finland":"loading"}`. Denmark is missing from
  the answer.
- Severity: minor. Confidence: high on the response, medium on what it fetches.

**S3. `/stations/popular` takes about 4.9 s cold**
- Actual: 4.88 s first, 0.08 s after. A first launch or a fresh server shows a slow Add screen.
- Severity: minor. Confidence: medium (one sample).

**S4. Server polish**
- `/passport` sends `refs` (all operators and types, 26.8 KB) on every call, even with no trips; widgets call it twice
  per refresh.
- Error bodies come in two shapes (`{error}` and Fastify's); the app handles both.
- Severity: polish. Confidence: high.

Checked and fine: unknown station, bad board type, unknown train, gone train, unknown segment and bad alternatives all
give clean 4xx; times carry an IANA `tz` everywhere; delay causes come with a `code` the app translates.

## 4. Accuracy tables

### Sweden

| Area | Compared against | Time read (UTC) | n checked | n wrong | Notes |
|---|---|---|---|---|---|
| Positions (GPS) | Trafikverket TrainPosition, https://api.trafikinfo.trafikverket.se/v2/data.json | 07:36:37, 07:36:50 | 134 | 1 over 500 m after delay; 1 transient 2.06 km | Median 0 m, p90 118 m, max 1155 m. 6 GPS trains not on the map (A29) |
| Estimated flag | Same | 07:36:50 | 159 trains, 28 estimated | 0 | 3 flagged with 2.5–3.5 min old GPS: fair |
| Standing/running | Trafikverket GPS speed | 07:36:50 | 134 | 7 | Standing at 38–99 km/h (A16) |
| Boards: times | Trafikverket TrainAnnouncement | 07:37:35 | 91 (Cst 21, G 17, Mc 53) | 0 | Sunday: no estimates in the window |
| Boards: tracks | Same | 07:37:35 | 91 | 0 | Sector letters relayed ("12a", "1b") |
| Boards: cancellations | Same | 07:37:35 | 91 | 0 | None cancelled in window; repeat on a weekday |
| Boards: missing rows | Same | 07:37:35 | 15 absent | 0 | All buses, left out by SPEC §11 (A30) |
| One trip (SJ 525) | Trafikverket per-stop announcements | 07:38:42 | 9 stops | 0 | Times and tracks |
| Car counts | Trafikverket coach order | 07:37–07:49 | 28 | 0 | 132 other trains `cars: null` (no source) |
| Train types | Clack board vs Clack live map | 07:49:35 | 62 | 3 | Regina vs ER1 (A17) |
| Planner Cst → G | Trafikverket departures | 07:40:41 | 34 | 0 | All 34 in `results` |
| Planner Cst → Narvik | Trafikverket coach orders 94/98 | 07:41 | 1 | 1 (probable) | Through coaches shown as a change (A6) |
| Planner G → Oslo | Clack's own options | 07:40:45 | 9 | 1 | Dominated detour (A7) |
| Station maps: tracks | OSM Overpass, https://overpass-api.de/api/interpreter | 07:43–07:47 | Cst 18, G 16, Mc 11 | 0 | |
| Station maps: sectors | Trafikverket TrackAtLocation, service day | 07:48:33 | Cst, G, Mc | 2 stations | Mc and Cst lack sectors (A10) |
| Platform heights | Trafikverket register (as cited) | 07:43–07:47 | 42 | 0 confirmed | G 9/10 ambiguous (A30) |
| Amenity hours | Jernhusen, https://www.jernhusen.se/hitta-din-station/ | 07:50–07:51 | Mc 6, Cst 11 | Mc 0, Cst 2 | A19 |

### Norway

| Area | Compared against | Time read (UTC) | n checked | n wrong | Notes |
|---|---|---|---|---|---|
| Positions (GPS) | Entur vehicles, https://api.entur.io/realtime/v2/vehicles/graphql | 07:39:05 | 42 | 18 over 500 m | Median 291 m; running median 585 m, max 1404 m; ~30 s lag (A5) |
| Flytoget types | Same (vehicleId) | 07:39:05 | 6 | 0 | 0–1070 m off from the same lag |
| Estimated trains | Same | 07:39:05 | 19 Clack-only | – | All `estimated: true` |
| Board Oslo S | Entur journey planner, https://api.entur.io/journey-planner/v3/graphql (NSR:StopPlace:337) | 07:40:10 | 80 | 0 | One extra Clack row (Flytoget 3725) |
| Board Bergen | Same (NSR:StopPlace:548) | 07:40:29 | 8 | 0 | |
| Board Trondheim S | Same (NSR:StopPlace:59977) | 07:40:38 | 5 | 0 | |
| Planner Oslo → Bergen | Entur trip() | 07:41:20 | 5 | 0 | Night 605 found; 1 backtracking option (A7) |
| Planner Oslo → Trondheim | Entur trip() | 07:41:20 | 8 | 0 | Identical incl. night 405 |
| Planner Oslo → Stockholm | Entur Oslo S calls for 2026-11-02 | about 07:42 | 5 SJ trains | 3 | 626, 660, 674 times differ (A4); Ljusdal detour (A7) |
| Planner Oslo → Copenhagen | Entur (Norwegian part only) | 07:40–07:42 | 8 | 0 | Swedish/Danish legs not verified |
| Train types | data/train_types.json rules; Entur line codes | 07:39–07:42 | 65 | 0 shown wrong; 1 unverified | Bergensbanen day trains as Flirt (A25) |
| Station maps | OSM Overpass + NSR quays | 07:44–07:49 | 3 (Oslo S, Drammen, Asker) | 2 | Oslo S tracks 5–8, 11, 12 missing (A9); Drammen track 1 (A20) |

### Finland

| Area | Compared against | Time read (UTC) | n checked | n wrong | Notes |
|---|---|---|---|---|---|
| Positions (GPS) | Digitraffic, https://rata.digitraffic.fi/api/v1/train-locations/latest | 07:36:08 | 60 | 0 | Median 26 m, p90 188 m, max 279 m |
| Positions (estimated) | Same | 07:36:08 | 7 (+269) | 1 doubtful | 8840 3.7 km off, but its own fix was 4 min old |
| Coverage | Same | 07:36:08 | 100 vehicles | 0 passenger missing | 31 absent are freight or not yet departing |
| Board Helsinki | Digitraffic live-trains/station/HKI | 07:37:05 | 59 | 22 missing | All I/P ring trains (A1) |
| Board Tampere | Digitraffic live-trains/station/TPE | 07:37:19 | 16 | 0 | |
| Cancellations | Digitraffic /trains/2026-11-01 | 07:37 | 0 in window | – | Only cancellations at 01:49; untested |
| Trip live times (IC 155) | Digitraffic /trains/2026-11-01/155 | 07:38:13 | 24 calls | 0 | 68 "stops" vs 12 commercial (A14) |
| Train types and carriages | Digitraffic /compositions/2026-11-01 | 07:37:42 | 67 | 2 | 909 and 269, first section only (A3) |
| Planner HKI → ROI | Digitraffic live-trains HKI/ROI, 2026-11-02 | 07:40:40 | 6 | 0 | Night 265, 273 found; 2 nonsense options (A7) |
| Station maps | OSM Overpass; Digitraffic tracks | 07:44–07:47 | 2 stations, 24 platforms | 1 | Helsinki "52" tram stop (A20) |

### Denmark

| Area | Compared against | Time read (UTC) | n checked | n wrong | Notes |
|---|---|---|---|---|---|
| Board København H | Rejseplanen app backend StationBoard (same upstream as Clack) | 07:40:08 | 71 | 0 | Not an independent source; dsb.dk and rejseplanen.dk web are client-rendered |
| Board Odense | Same | 07:40:08 | 15 | 0 | |
| Positions | Rejseplanen JourneyGeoPos (RP's own estimates) | 07:40:18 | 77 | 6 over 1 km | Median 255 m, max 5.6 km; both sides estimates (A29) |
| Estimated label | API payload and app code | 07:40 | 107 | 0 | All `estimated: true`, drawn at 70% with no speedometer |
| Train types and carriages | da.wikipedia S-tog, IC3 | 07:29–07:30 | 2 types | 1 | S-tog 2.3–4.7× too long (A11); IC3 3 cars right |
| Planner KH → Hamburg | Clack's own KH board | 07:40:47 | 1 | 1 | Bergedorf, 0 results, no note (A8) |
| Planner Stockholm → Copenhagen | Trafikverket (no Danish stops) | 07:40:46 | 6 | – | All via Lund or Hässleholm; whether a direct train ran is unverified |
| Station map KH | OSM platform edges and heights | 07:44–07:49 | 13 tracks | 0 tracks; 2 platforms without edges | A21 |
| Amenity hours KH | dsb.dk station page | 07:50 | 3 | 0 | Duplicates (A19) |

Passport sources (all countries): IVL U11173 (read 07:41) matches data/co2_factors.json exactly; Norway's length
matches Store norske leksikon (07:43). See A13, A26–A28, A30.

## 5. Workflow notes

| Task | Steps / taps | How findable | What would make it shorter |
|---|---|---|---|
| Understand the first screen | 0 | Clear: "Trains leaving soon", "Find your train", "Not now" | Fix the cut-off names |
| Add Stockholm C → Uppsala C by route | 4 (Find your train, type, result, Add to trips) | Easy | Show the SL commuter option (W4) |
| Add SJ 523 while it runs | 6 (Add another, type, **Show earlier**, tap, scroll, Add to Clack) | Medium: the running train is hidden | Running trains first (W1); skip the get-on/off step for the whole route |
| Open the added trip | 1 (View trip) | Easy | – |
| Delete a trip | 4 (open, ⋯, Delete trip, Delete trip) | Medium: hidden in ⋯ | Swipe to delete on Trips; Cancel and undo (W12) |
| Edit stops / seat | Seat: scroll to the bottom; stops: not possible | Hard | An Edit item in ⋯ (W3) |
| Plan Oslo → Copenhagen tomorrow and add it | 5 (+, Tomorrow, type, tap, scroll, Add) | Findable, but "Plan a journey" only appears inside the sheet | A visible planner entry |
| Find night trains to Narvik | 3 | Easy, but no night-train label | Night/sleeper label (A6) |
| Follow a friend's train | 4 (Explore, search number, tap, Follow), or Network status > late train | Medium: you must know Explore has search | "Follow a train" next to Add |
| Departure board Stockholm C | 4 (Explore, search, station, "Departures from…") | Medium: only via Explore or a trip's stops | A boards/stations entry on Trips |
| Walk from entrance to platform | 7+ (map, Directions, From, pick, To, platform, Directions) | Medium | "Main entrance to my train's platform" on the trip screen |
| Lifts / step-free route | Not possible | – | Lifts layer and step-free routing (W2) |
| Passport, CO₂, share card | 1 tab; empty until a trip ends | Easy to find, empty | Show trips in progress (W8) |
| Settings: version, privacy | Trips or Passport > gear > scroll | Easy | – |
| Find your user id (for support) | Not shown | – | Show it in Report a bug or Export |

## 6. Ideas

Ranked by value to a traveller.

1. **Lifts, escalators and a step-free route on station maps.** The one thing a rider with luggage, a pram or a
   wheelchair needs at a change, and nothing in the app has it today.
2. **Departure boards outside Explore.** A Stations entry on Trips (favourites, nearby, recent) would make the boards a
   first-class tool instead of a hidden one.
3. **"Show saved, then refresh" and queued writes offline.** Trains have tunnels and portal Wi-Fi; a trip saved or
   changed offline should go up later, and screens shouldn't wait 15 s.
4. **Sectors on maps where boards use them** (Malmö C, Stockholm C first). Trafikverket uses sectors for most Malmö C
   calls, so "where do I stand" is answerable once the map has them.
5. **Edit a trip's stops.** People board late and get off early; today the only fix is delete and re-add.
6. **Night-train / sleeper label and through coaches.** Makes Narvik, Kolari and the Norwegian night trains read as what
   they are, and removes false "tight change" warnings.
7. **"From the entrance to my platform" on the trip screen.** Turns a 7-step route into one tap at the moment it's needed.
8. **"Follow a train" next to Add.** Following friends' trains already works well; it just isn't findable.
9. **"Not covered" in the planner** when a destination (Hamburg, Berlin) is outside the data, instead of an empty list.
10. **Platform-only alerts** (platform change for my train) as a lightweight alert option for people who turn off the rest.
11. **Show trips in progress in Passport**, so a first-time user sees something on day one.
12. **The user id in Report a bug / Export**, so support can find a user's data without guessing.

## 7. Throwaway user ids from this review

Delete these from the hosted server.

| Id | Made by | Expected data | Action |
|---|---|---|---|
| `10ca0ff3-120f-410f-8d02-b94c5ce09c8a` | The app on first launch (walkthroughs) | SJ 523 Stockholm C → Malmö C on 2026-11-01; journey Oslo S → København H on 2026-11-02 (Vy 103 + Öresundståg 1079); following Snälltåget 3941 on 2026-11-01; probably a share link for SJ 523; a deleted Mälartåg 918 trip | Delete the user row (cascades) |
| `57431048-8687-4bc5-877a-318055c851ab` | Read-only API header | None expected | Check for an empty user row; delete if there |
| `0173167c-9dc7-4d05-9324-c85161f54309` | Read-only API header | None expected | Check for an empty user row; delete if there |
| `cd7a4ea0-cc16-4a90-969c-eac61cf15610` | Read-only API header | None expected | Check for an empty user row; delete if there |
| `9c6fa82d-778f-49cd-838b-0e480dc5abe8` | Generated, never used | None | – |
| `bbf82a95-02a7-4aff-adc4-9a35b82a40a9` | Generated, never used | None | – |
| `4b59fc63-250f-4bb8-88ab-f322ccc76a34` | Generated, never used | None | – |
| `332c42b7-80eb-4d62-bd87-67ffbe10f1db` | Generated, never used | None | – |

**Housekeeping:** the open item in docs/APP_STORE.md that says `Identity.swift` "does not yet mark the Keychain item as
synchronizable" is out of date: the item is now written with `kSecAttrSynchronizable: true` in the shared access group
(Identity.swift:107-139), with a non-synced fallback only when that write fails.
