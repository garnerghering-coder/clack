# Changes after user test run 2 (2026-11-07, build 59)

App version after this pass: **1.0 (build 60)**. Server changes are in `apps/server` (deploy with the usual pull + restart):
- the live-map stream
- the search's home-country fallback
- the network status's cancellations
- the privacy page

Run 2 had four personas on build 59: the Craft Skeptic (second time), the Design Critic, the Performance Critic and the
App Reviewer. Their logs are in `UserTesting2/logs/`. There was no merged report; the findings below come from the
logs, read against run 1's `UserTesting/reports/2026-11-07/CHANGES.md`.

## Summary

**The owner's decisions for this pass.**
- **Test tools** show in TestFlight and Xcode builds, never in App Store builds, and that has to be visible, not just
  claimed.
- **5.2.1 (logos):** the owner has the operators' permission (given verbally, by phone and at conferences). No code
  change.
- **Privacy wording:** fix it.
- **The rest:** act on it.
- **Added during the pass**, from the owner's question about Jönköping C: "cancelled or buses? and why isn't that in
  Network now?"

**What matters most.**
1. **Test tools reach TestFlight.** The cause of the past trouble: "Test alerts", the design gallery and their screens
   were `#if DEBUG`, so a TestFlight archive (a Release build) never had them. Only the walks and the Wallet switch
   used the runtime check.
   - Now one rule decides for every tool: `BuildChannel` (ClackCore, tested; StoreKit lookup in the app).
   - The Settings footer says "· TestFlight" or "· Xcode" in test builds, so the installed build shows which it is.
   - Checked on screen in a **Release** simulator build in all three modes: `-buildChannel testflight` shows the four
     rows and they open; `appstore` and no override show neither rows nor server hash.
2. **The live map costs less.** Zoomed out, the stream went from about 600 KB a minute to about 150 KB.
   - Measured on the local server: 30–40 s samples of the wide view.
   - Nothing keeps running once you leave Explore: 0.1 % CPU and 0.5 wake-ups a second on Trips afterwards.
   - Zoomed-in CPU is lower too.
3. **Cancellations say what they are.**
   - A train cancelled with a bus instead reads "Replaced by bus", not "Cancelled", on every board.
   - Explore's station card showed cancelled trains as running; it doesn't any more.
   - Network now gets a "Cancelled, next two hours" section by stretch, saying whether a bus replaces them (Sweden,
     from Trafikverket).

**For a human to look at before the next TestFlight build.**
- **Confirm on the TestFlight install itself** that Settings ends "Version 1.0 (build 60) · TestFlight" with Station
  walks, Wallet passes, Test alerts and Design below it. The simulator can't produce a real TestFlight receipt, so this
  is the one check that couldn't be done here.
- **Links in light mode** are near-black (`accent-ink` light = #0A0A0A, DESIGN.md §2). The Design Critic said they stop
  reading as links. DESIGN.md wins on visuals, so this was left for the owner.
- **The trip page's map** is a little shorter before departure (42 % of the height, was 55 % of a smaller one), so
  the alerts question and its button sit above the tab bar. Check it looks right on the Pro Max.
- **Xcode's "Update to recommended settings"** is still in the Issue Navigator. It is applied by clicking it in Xcode,
  not by editing the project file, and was left for after this build so no settings change rides along with these
  fixes.

## Release-blocking

### Test tooling in Settings (App Review 2.1); test tools missing from TestFlight
- **Source:** app-reviewer.md (`04-settings-scroll2.png`, `11-test-alerts.png`), design-critic.md (`34-settings-bottom`),
  craft-skeptic.md (L27). The owner: past TestFlight builds lacked the tools.
- **Cause:** two gates. `#if DEBUG` (Test alerts, Design, the galleries, `AppRoute.testAlerts`) and a runtime check
  (walks, Wallet). The reviewer ran a Debug install, so saw everything; TestFlight got only half.
- **Status:** Fixed
- **Change:**
  - `ClackKit/Sources/ClackCore/Logic/BuildChannel.swift`: the rule. Test: `BuildChannelTests`.
  - `WalkStore.swift`: `BuildChannel.current()`, using the StoreKit sandbox receipt, else the `AppTransaction`
    environment.
  - `#if DEBUG` removed from `TestAlertsScreen`, `DesignGalleryView`, `WidgetGalleryView`, `ActivityGalleryView`,
    `TimelineDemoView`, `Route.swift` and `Destinations.swift`.
  - `SettingsScreen.TestToolsRow` holds all four tools.
  - `VersionFooter` names the channel.
  - Launch arguments for developers stay `#if DEBUG`.

### Operator logos (5.2.1)
- **Status:** No change needed. The owner has the operators' permission; answer Apple's question with that.

### Privacy text doesn't match the build ("asks after your first trip"; it asked at first launch)
- **Source:** app-reviewer.md finding 6; design-critic.md `00-first-launch`.
- **Cause:** `UsageAsk.check` counted any leg with a past arrival, so a reinstall (trips kept in the Keychain account)
  or a hand-added past trip made it fire at first launch.
- **Status:** Fixed
- **Change:**
  - `Usage.swift`: never on the first run; asked on a later start once a trip has ended.
  - `privacy.usageBody` (English and Swedish) and both hosted pages (`apps/server/public/privacy`, `/sv`) say exactly
    that.
  - The privacy date is now 2026-11-07.

## Marked Fixed in build 59, still seen in run 2

### The keyboard covers the seat fields; a floating Save pill over Seat; fields jump ~130 pt and the typed seat is lost
- **Source:** craft-skeptic.md F4 (L45, L46), design-critic.md (`22-seat-tap`, `25-seat-typed`).
- **Cause:**
  - A keyboard toolbar per field: on iOS 26 it floats as a glass pill.
  - The map's height came from the GeometryReader's height, which shrinks with the keyboard.
  - `onAppear(perform: reset)` overwrote typed text whenever the editor was rebuilt.
- **Status:** Fixed
- **Change:**
  - `SeatEditor.swift`: no keyboard toolbar (the keyboard's own Done key saves). Values are set at init and reset
    only when the trip or its saved values change while no field is focused. The focused field asks the page to
    scroll it into view.
  - `TripDetailScreen.swift`: map height from the height including the keyboard area, and a scroll to the seat
    fields on focus.

### Hand-add form: the train number's Done hidden / covering the form
- **Source:** craft-skeptic.md F4 (L11).
- **Status:** Fixed
- **Change:** `AddTrainSheet.swift`: Done sits in the row beside the field, not in a bar over the keyboard. The edit
  sheet, a system Form in a navigation stack, keeps its keyboard bar.

### "421" (bare number) shows only DSB 421 with no word about SJ 421
- **Source:** craft-skeptic.md F3 (L02), design-critic.md (`04-typed-421`), app-reviewer.md 10, performance-critic.md
  6. Four of four.
- **Cause:** `routes/search.ts` sent `otherDaysCountry` only when the settings had a home country, and a new phone has
  none.
- **Status:** Fixed
- **Change:**
  - `apps/server/src/search/homeCountry.ts`: settings, then the first trip's country, then the phone's region (the
    app now sends `region`), then Sweden. The same order the Passport uses. Test: `homeCountry.test.ts`.
  - `Endpoints.search` sends the region.

### Scrolled content runs under the back and ··· buttons with no blur
- **Source:** craft-skeptic.md F3 (L18, L31), design-critic.md (`18-trip-detail-mid`), app-reviewer.md 7.
- **Cause:** the ScrollView ignores the top safe area (full-bleed map), so the automatic edge effect didn't apply.
- **Status:** Fixed
- **Change:** `TripDetailScreen.swift`: `.scrollEdgeEffectStyle(.soft, for: .top)` (iOS 26+). Checked on screen in
  dark mode: the scrolled header fades under the bar.

### Tapping the selected Trips tab doesn't go back to the list
- **Source:** craft-skeptic.md F3 (L50).
- **Cause:** on iOS 26 TabView doesn't call its selection binding when the same tab is tapped.
- **Status:** Fixed
- **Change:** `App/TabReselect.swift`: a tap recognizer on the system tab bar that never blocks a touch. It notes the
  selected tab at touch-down; if it is unchanged after the tap, that tab's stack is cleared (`RootView`). The
  `TapTests` UI tests pass.

### The location prompt fires the moment Explore opens; the locate button jumps to iOS Settings when denied
- **Source:** app-reviewer.md 3 and 4, performance-critic.md 11 and 12.
- **Cause:**
  - `ExploreScreen` called `showMyDot` → `askIfNeeded` when the map was ready.
  - Setting `showsUserLocation` also makes MapLibre ask.
- **Status:** Fixed
- **Change:**
  - `LiveMapView.showUserDot` only with permission.
  - `ExploreModel.centreOnMe` asks iOS when not yet asked, and when denied shows a system alert ("Location is off for
    Clack" · Open Settings / Cancel).
  - The dot appears when permission arrives.
  - Checked: no prompt on opening Explore (Release build).

### The usage-data alert is the first thing on a new phone
- **Status:** Fixed (see the privacy entry).

### "Turn on alerts" sits under the tab bar when a trip opens
- **Source:** craft-skeptic.md F2 (L17), design-critic.md (`17-trip-detail-top`).
- **Status:** Fixed (to check on the Pro Max)
- **Change:** the map is 42 % of the height before departure, 50 % after.

### Settings note cut off: "Never your coordinates or…"
- **Source:** app-reviewer.md 8.
- **Status:** Fixed
- **Change:** `riders.settingNote` leads with the clause and fits two lines. The detail stays under "more".

### Appearance came up Dark on a light phone
- **Source:** craft-skeptic.md F3 (L00, L26).
- **Cause:** not reproduced. The simulator wasn't erased between personas. The phone's id survives a reinstall in the
  Keychain, so the restored account kept its saved Dark setting; new accounts default to System (build 59). The
  Design Critic, on the same build, saw System offered.
- **Status:** Harness artefact

### Fresh install already has trips, a past ride and a 485 km passport
- **Source:** design-critic.md (`01-welcome`, `31-passport`), app-reviewer.md 5.
- **Status:** Harness artefact (as in run 1)
- **Change:** none. Erase the simulator between personas (`xcrun simctl erase <udid>`).

### Explore dots hard to hit at the opening zoom; pull-to-refresh on Trips shows nothing
- **Status:** Deferred. The dots have the 44 pt box since build 59; a tap-to-zoom for dense areas is still to do.

## New in run 2

### Live map: ~17 % CPU zoomed in, ~600 KB a minute zoomed out, memory held after leaving, ~200 wake-ups a second everywhere after a map
- **Source:** performance-critic.md 1–3, 5 (`idle-explore-map.txt`, `poke-explore-zoomed-out.png`).
- **Cause:**
  - The server wrote every 2-second update to every stream, empty or not, in full for every train in a country-wide
    view.
  - The app eased trains at 30 frames a second and redrew everything every frame at the cars' zoom.
  - The location dot stayed on while another tab showed.
  - Fetched track pieces were never let go.
- **Status:** Fixed (partly: MapLibre's own loop while a map is on screen)
- **Change:**
  - **Server** (`routes/livemap.ts`):
    - A wide view (wider than about zoom 7) gets updates gathered every 10 s.
    - A train in a wide view is sent again only once it has moved about 1 km or changed state.
    - Empty updates aren't written; a heartbeat goes at most every 10 s, inside the app's 15 s stall watch.
    - Test: `liveStreamInterval.test.ts`.
    - Gzip was not used: Caddy buffers compressed streams (see the hosted-server notes).
  - **App:**
    - `ExploreModel`: 20 frames a second while easing (was 30), 10 at the cars' zoom.
    - Leaving the tab drops the glides and, past 300, the fetched tracks.
    - `ExploreScreen`/`LiveMapView` turn the location dot off while away.
- **Measured** (Release build, iPhone 17 Pro simulator; run 2 used a 17e):

  | | CPU | Wake-ups/s | Run 2 (17e, build 59) |
  |---|---|---|---|
  | Explore, zoomed in | 13.2 % | 212 | ~16.5 %, ~255 |
  | Explore, default zoom | 3.9 % | 205 | 5–7 %, ~260 |
  | Trips after leaving Explore | 0.1 % | 0.5 | ~120–200 |

  Zoomed-out stream: about 150 KB a minute, was ~600.
- **Still open:**
  - A map on screen still wakes ~200 times a second, and Passport ~120 times a second with its map. The simulator has
    no motion sensor and the card's sweep plays once, so it points to MapLibre's own render loop, which ships
    precompiled. Not changed.
  - About 50 MB stays held after a zoomed-in visit.

### Passport card redraws ~100 times a second with the phone still
- **Status:** Fixed (partly)
- **Change:** `MotionTilt.swift`: 20 readings a second (was 30), and a change too small to see writes nothing. See the
  note above on the map.

### The offline map (~3 MB) downloads unasked, also on mobile data
- **Source:** performance-critic.md 4.
- **Status:** Fixed
- **Change:**
  - `OfflineMaps.swift`: "Save maps for coming trips: On Wi-Fi / Always / Never", On Wi-Fi by default. Wi-Fi means a
    connection that isn't metered or in Low Data Mode (`NWPathMonitor`).
  - Settings > the maps card has the row.
  - New strings in English and Swedish.

### "Add to trips" on the number-search stop picker is cut in half and scrolls away; the two add paths look different
- **Source:** design-critic.md (`07-tapped-result`, `08-scrolled-add`).
- **Status:** Fixed
- **Change:** `Shell.swift`: `SheetFrame` pins a step's main button under its scroll view (`.sheetAction`).
  `ConfirmStep` and `PlannedJourneyStep` both use it. Checked on screen (SJ 421, Mon 9 Nov).

### "Add to trips" stays yellow after "already added", and a second tap quietly adds a copy
- **Source:** design-critic.md (`13-oresund-added`).
- **Status:** Fixed
- **Change:** `PlannedJourneyViews.swift`: the notice carries "Add anyway" and "Cancel", as on the one-train step; the
  main button is off while it shows. "Cancel" keeps any trains the first try did save.

### Past tense on future trips ("Tap the stop where you got on", "Got on at", "Departed")
- **Source:** app-reviewer.md 11, craft-skeptic.md (L07), design-critic.md 24.
- **Status:** Fixed
- **Change:** `add.tapFrom`/`add.tapTo` ("where you get on/off"), `manual.from`/`to`/`dep`/`arr` ("From", "To",
  "Departs", "Arrives"), in English and Swedish.

### "No live data in Sweden" on a hand-added trip
- **Source:** craft-skeptic.md F2 (L44).
- **Cause:** the check counted every stop without a report source, and a hand-added trip has none.
- **Status:** Fixed
- **Change:** `TripDetailScreen.swift`: a hand-added trip says "Added by hand: the times are the ones you entered."
  (`detail.addedByHand`) instead.

### Double full stop: "Inget tåg SJ 421 sön 8 nov.."
- **Source:** performance-critic.md 13.
- **Status:** Fixed
- **Change:** `Format.day` drops abbreviation stops (Swedish "nov."). Test in `LogicTests`.

### The Explore legend stays open across tabs and takes the next tap
- **Source:** craft-skeptic.md F3 (L47).
- **Status:** Fixed
- **Change:** it closes when the tab is left.

### 453 km in the picker, 485 km under Past for the same trip
- **Status:** Not reproduced. Today the stored trip and the add screen both give 453 km for Stockholm C → Göteborg C
  (SJ 421 and SJ 439). The 485 km was the tester's restored account.

### Yellow text links turn black in light mode
- **Status:** Declined for now (owner's call). DESIGN.md sets `accent-ink` light to #0A0A0A on purpose.

### Number search has no loading state; 824 KB confirmation map; Settings push chevron; first-launch 377 KB
- **Status:** Deferred (Low).

### Design-system consolidation (four pick-one controls, icon families, margins, the "trains running" pill, seven yellows)
- **Status:** Deferred to a design pass. Noted: the green-dot pill on Explore is close to the no-pill rule.

### Platform "not known" in search, "Platform 3" on the trip page; Øresund route green on the card, red on the page; "Seat and car" scrolls rather than opens; Hold menu has no lift; kilometres/24 h on en_US; no support URL
- **Status:** Deferred (Low).

## Added by the owner during the pass

### Jönköping C: "lots of trains cancelled — cancelled or buses?" and why not in Network now
- **Source:** the owner, 2026-11-07 ~18:00. The Jönköping C board at 17:03–20:01: six Västtågen departures (Skövde
  and Nässjö lines) cancelled, each with Trafikverket's "Buss ersätter" (ANA007); Krösatågen running.
- **Cause:**
  - The board said "Cancelled" with "Bus replaces train" in small text under the name.
  - Explore's station card didn't pass `canceled` at all, so cancelled trains looked like they were running.
  - Network now is built from the live map, and cancelled trains never run.
- **Status:** Fixed
- **Change:**
  - **Boards** (`BoardScreen`, `ExploreSheets`, `BoardRowView`, `DelayText`): a cancelled train with the source's bus
    note reads "Replaced by bus" ("Ersatt av buss") in the late ink, and the note isn't repeated.
    `LegStop.Cause.isBusReplacement`: ANA007, or the same words from a text-only feed. Test: `BusReplacementTests`.
  - **Network now** (`livemap/announcements.ts` `cancelledPart`, `livemap/network.ts` `cancelledGroups`,
    `ingest.cancelledTrains`, `/api/live/network`):
    - The section is "Cancelled, next two hours", by stretch, both directions together.
    - One company's stretches that share a station are joined.
    - Each line says whether a bus replaces all, some or none, plus the other reasons given ("Engineering work").
    - Sweden only for now, which the panel says.
    - Test: `cancelledNetwork.test.ts`.
  - Checked on screen: "Nässjö C – Skövde C · 5 trains cancelled from 18:20 · a bus replaces them".
  - **Not yet:** Norway, Finland and Denmark (their feeds carry cancellations too: a follow-up).

## Also in this pass
- **The departure tile's label broke mid-word** ("DEPARTU / RE") beside the platform tag on a Pro Max at the default
  size. It came from build 59's "let it wrap", and one word can't wrap without being cut. `TimeBlock` now puts the
  platform under the label when both don't fit on one line (`ViewThatFits`). Checked on an iPhone 18 Pro Max simulator.
- **Two app tests failed because of their fake servers, not the app.** `AddTrainHistoryTests` and
  `AddTrainPagingTests` counted the station suggestions the add sheet looks up while typing (added after these tests
  were written) as searches, so the counts were off. The paging test only failed when the suggestion request raced
  ahead of the search. Both fakes now answer suggestions separately.
- **Stale tests updated:**
  - `TapTests.testOpenATripAndGoBack` uses the system back button (build 59 removed `trip.back`).
  - `AddTrainPagingTests` expects build 59's day label on the first journey.
- **Tests:**
  - `npm test` (design lint + vitest): 721 pass.
  - `npm run typecheck`: clean.
  - ClackKit `swift test`: 441 pass.
  - App unit and UI tests through Xcode: all 80 pass.
- **Builds:** the app builds for the simulator in Debug and Release.
- **Build number:** 60 on `Clack` and `ClackWidgetsExtension`.
