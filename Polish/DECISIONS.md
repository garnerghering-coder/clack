# Polish pass 1: every decision, and how to undo it

Owner, 2026-11-14: "ensure everything is reversible… note a before and after for easy comparison, so any could be
reverted if desired."

Each entry below says what the thing was, what it is now, how it was done and how to put it back:
- **Look choices** are one-line switches in `apps/Clack/ClackKit/Sources/ClackDesign/Look.swift`. Set the switch back
  to its old case and rebuild.
- **Everything else** names its commit. `git revert <commit>` undoes a whole step, or the files listed undo one part.

Screenshots are in `Polish/before/` and `Polish/after/`, with the same file names in both.

Commits so far: `2343ccc5` (words) and `5402af50` (foundations).

## Look switches (Look.swift)

| ID | Element | Before | After | How | Undo |
|---|---|---|---|---|---|
| L1 | Chosen chip, chosen segment (the thumb), a map toggle that is on | Yellow fill, black text (the old DESIGN §2.1) | Ink fill: the text colour (black on light, white on dark), with the background colour on it | `Look.selection = .ink`, read by `ChipButton`, `SegmentedControl.Thumb` and `MapButtonFace` in `Clack/Design/Controls.swift` | `Look.selection = .yellow` |
| L2 | Buttons in content (`ClackButtonStyle`: cards, rows, sheets, empty states) | Liquid Glass on iOS 26+ (`.glassProminent` yellow, `.glass` clear) | Solid system styles: `.borderedProminent` yellow for primary, `.bordered` grey for secondary, `.bordered` with a red label for danger | `Look.contentButtons = .solid`, in `ClackButtonStyle` (`Controls.swift`) | `Look.contentButtons = .glass` |
| L3 | On/off switches (`Toggle`) | Yellow tint | The system's green | `Look.toggles = .system`; toggles call `.clackToggleTint()` (converted in the Settings step) | `Look.toggles = .yellow` |
| L4 | The platform on a trip's time block | Solid yellow tag | The grey `PlatformTag` the stop list uses | `Look.timeBlockPlatform = .tag` (trip detail step) | `Look.timeBlockPlatform = .yellow` |

These switches don't touch the following, which stay as they were:
- The floating map controls and the tab bar stay Liquid Glass.
- The launch screen stays yellow in both themes (owner's choice).
- The Passport cover stays yellow and keeps its 24 pt corners: it is a passport, an object, not a card.

## Tokens

| ID | Element | Before | After | How | Undo |
|---|---|---|---|---|---|
| T1 | Spacing | About 830 number literals (`.padding(14)`, `spacing: 10`…), some of them off the grid | `Space.xxs…xxxl` (2, 4, 8, 12, 16, 24, 32, 48) everywhere. The design lint rejects numbers in feature code. | `ClackDesign/Spacing.swift`. A script replaced the literals (commit `5402af50`); the values it snapped are in table S. | One line: put the old number back (table S). All of it: `git revert 5402af50`, which also undoes the rest of the foundations. |
| T2 | Animation curves | About 20 different curves (easeOut 0.18–1.6 s, five `timingCurve`s, `.default`) | `Motion.tap` (snappy 0.2 s), `.layout` (smooth 0.3 s), `.appear` (smooth 0.35 s), `.signature` (spring 0.45 s, bounce 0.25). With Reduce Motion, `Motion.reduced` (a 0.2 s cross-fade). | `ClackDesign/Motion.swift`, used through `.motion(_:value:)` and `withMotion` | Change a token's curve in `Motion.swift` (every use follows), or put the old curve back at one call site |
| T3 | Haptics | `.sensoryFeedback` and UIKit generators, with mixed meanings | `Haptic.selection`, `.snap`, `.success`, `.warning`, `.error`: one meaning each. The lint rejects raw ones. | `ClackDesign/Haptics.swift`, used through `.haptic(_:trigger:)` | Per site, in table H |
| T4 | Split-flap timing | Two 180 ms halves, 50 ms stagger (five digits take about 0.56 s) | Two 90 ms halves, 30 ms stagger (about 0.3 s) | `Motion.flapHalf`, `Motion.flapStagger` | Set them to 0.18 and 0.05 |
| T5 | Split-flap with Reduce Motion | The new value appears at once | The changed tiles cross-fade over 0.2 s | `SplitFlap` (`.transition(.opacity)` and `Motion.reduced`) | Remove the `.animation(reduceMotion ? …)` line in `SplitFlap.body` |
| T6 | Split-flap identity | Every tile rebuilt on every change | Only the changed tiles get a new id | The `.id(...)` in `SplitFlap` | Put back `.id("\(index)-\(sequence)")` |

## Shared components

| ID | Element | Before | After | Where | Undo |
|---|---|---|---|---|---|
| C1 | Pressed state | 64 `.buttonStyle(.plain)` buttons with the system's faint dim | `PressStyle`: dims under a veil and sinks to 97 % at once, then eases back (no shrink with Reduce Motion) | `ClackDesign/Components/PressStyle.swift`, applied screen by screen (the map buttons already have it) | Per site: `.buttonStyle(.plain)` |
| C2 | Loading placeholders | `Skeleton(height:)` bars at guessed heights | `Placeholder { … }`: the real row or card with sample data, redacted and breathing, so nothing moves on first paint | `Clack/Design/States.swift` | Per site: the old `Skeleton(...)` |
| C3 | Empty and failed states | Written by hand on each screen (about 36 texts and 11 banners) | `EmptyStateView` (what goes here, one button, an optional link) and `ErrorStateView` (what happened, what still works, Try again) | `Clack/Design/States.swift` | Per site |
| C4 | Toasts | Only trip detail had one, at the top, of its own | `Toaster` in the environment: one line above the tab bar for 4 s (6 s with Undo), read out by VoiceOver, with the error haptic when it reports a failure | `States.swift`, hosted in `RootView.stack` and in the sheets | Remove `.toastHost` in `RootView` |
| C5 | Ticket return prompt | At the root, with `.padding(.bottom, 64)` to clear the tab bar | Drawn inside the tab you're on, whose safe area already clears the bar. Its state lives in `TicketReturnState`, so there aren't three copies. | `RootView.swift`, `TicketViews.swift` | Revert those two files to before commit `5402af50` |
| C6 | AdaptiveStack | — | An HStack that stacks vertically at the accessibility text sizes | `ClackDesign/Components/AdaptiveStack.swift` | Per site |
| C7 | FreshnessLine | Only on the board and the live modules | "Updated 2 min ago" (the clock time past 90 min, the date past a day), with an optional "Couldn't refresh ·" in front | `ClackDesign/Components/FreshnessLine.swift` | Per site |
| C8 | Split-flap tick | — | `SplitFlap(tick: true)` plays one light tick when a live change lands | `SplitFlap.swift` | `tick: false` at the call site |

## Haptics (H)

| Where | Before | After | Why |
|---|---|---|---|
| Deleting a trip (Trips, trip detail) | `.warning` after it worked | None | A warning means trouble, and a confirmed delete isn't trouble. Ordinary actions get no haptic. |
| Settings › Delete my data | `.warning` when done | `.success` when done | It worked. |
| Settings › Start over | `.warning` on both edges of `busy`, so twice | `.error` once, when it failed | One meaning, played once. |
| Explore: tapping a train on the map | `UISelectionFeedbackGenerator` | None | The ring answers the tap. A haptic for every map tap means nothing. |
| Explore: following a train | `.selection` whenever the follow count changed, including on load and on returning to the tab | `.success` when the server confirms a follow or unfollow | Trigger on the action, never on loaded state. |
| Favourite star (board, station sheet) | `.selection` on the value, so it buzzed when you opened a favourite station | `.selection` on the tap. The star changes at once and rolls back with a toast if the server refuses. | Same reason. |
| Walk mode, each step | `.impact(.medium)` | `.snap` (a light impact) | The vocabulary has one impact weight. |
| Arrival | A heavy impact, then success about 1 s later | One haptic: a light snap as the board settles, or success when a medal came with the trip | One haptic, and a quieter one. |

## Words (W)

These changes are in commit `2343ccc5`: `docs/WORDLIST.md` and the catalog. Every changed key is in that commit's diff of
`Localizable.xcstrings`. To see each before and after, run
`git show 2343ccc5 -- apps/Clack/ClackKit/Sources/ClackCore/Resources/Localizable.xcstrings`.

| Now | Was |
|---|---|
| Find a train | Find your train / Add train / Add a train |
| Add to trips | Add to my trips |
| Add to trips (the manual form's button) | Add trip |
| Lägg till ett tåg till | Lägg till ett till |
| Try again | Retry |
| tågbolag | operatör / bolag |
| tågslag | slag |
| Radera resan | Ta bort resan |
| "Check your connection and try again" | "Is the server running?" |
| Stop following | Unfollow |

Swedish durations now read "2 h 48 min" instead of "2h 48m" (`Format.duration(_:language:)`).

## Spacing snaps (S)

These values were off the scale and moved to the nearest step. Every other value kept its number under a token name.
The lines are as they were before commit `5402af50`.

| Where | Change | Line before |
|---|---|---|
| `Clack/Design/PassportCard.swift:34` | spacing 10 → 8 | `VStack(alignment: .leading, spacing: 10) {` |
| `Clack/Design/PassportCard.swift:58` | spacing 10 → 8 | `LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)` |
| `Clack/Design/PassportCard.swift:58` | spacing 10 → 8 | `LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)` |
| `Clack/Design/PassportCard.swift:58` | spacing 10 → 8 | `LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)` |
| `Clack/Design/PassportCard.swift:64` | padding 6 → 4 | `.padding(.top, 6)` |
| `Clack/Design/PassportCard.swift:74` | padding 20 → 24 | `.padding(.top, 20).padding(.horizontal, 20).padding(.bottom, 16)` |
| `Clack/Design/PassportCard.swift:74` | padding 20 → 24 | `.padding(.top, 20).padding(.horizontal, 20).padding(.bottom, 16)` |
| `Clack/Design/Shell.swift:64` | spacing 6 → 8 | `HStack(spacing: 6) {` |
| `Clack/Design/Shell.swift:101` | spacing 6 → 8 | `HStack(spacing: 6) {` |
| `Clack/Design/Shell.swift:108` | padding 6 → 4 | `.padding(.vertical, 6)` |
| `Clack/Design/Shell.swift:133` | padding 20 → 24 | `.padding(.top, 20)` |
| `Clack/Features/Stations/StationMapScreen.swift:145` | padding 116 left (off the scale, check by hand) | `.padding(.top, 116)` |
| `Clack/Features/Stations/StationMapScreen.swift:384` | padding 64 left (off the scale, check by hand) | `.padding(.top, 64)` |
| `Clack/Features/Stations/StationMapScreen.swift:409` | padding 112 left (off the scale, check by hand) | `.padding(.trailing, 12).padding(.top, 112)` |
| `Clack/Features/Stations/StationMapScreen.swift:426` | padding 168 left (off the scale, check by hand) | `.padding(.horizontal, 16).padding(.top, 168).padding(.bottom, 220)` |
| `Clack/Features/Stations/StationMapScreen.swift:426` | padding 220 left (off the scale, check by hand) | `.padding(.horizontal, 16).padding(.top, 168).padding(.bottom, 220)` |
| `Clack/Features/Explore/NetworkPanel.swift:35` | padding 64 left (off the scale, check by hand) | `.padding(.horizontal, 16).padding(.top, 64)` |
| `Clack/Features/Explore/SearchPanel.swift:33` | padding 64 left (off the scale, check by hand) | `.padding(.horizontal, 12).padding(.top, 64).padding(.bottom, 32)` |
| `Clack/Features/Add/AddTrainSheet.swift:849` | padding 40 left (off the scale, check by hand) | `.padding(.top, 40)` |
| `Clack/Features/TripDetail/TicketViewer.swift:32` | padding 20 → 24 | `.padding(.top, 20).padding(.horizontal, 16).padding(.bottom, 8)` |
| `Clack/Features/TripDetail/TripDetailScreen.swift:294` | padding 20 → 24 | `.padding(.top, 20)` |
| `Clack/Features/Trips/TripsComponents.swift:242` | padding 28 left (off the scale, check by hand) | `.padding(.leading, 28)` |
| `Clack/Features/Trips/TripsComponents.swift:390` | padding 28 left (off the scale, check by hand) | `.padding(.vertical, 28)` |
| `Clack/Features/Trips/WelcomeView.swift:27` | spacing 20 → 24 | `VStack(alignment: .leading, spacing: 20) {` |
| `Clack/Features/Trips/WelcomeView.swift:45` | padding 120 left (off the scale, check by hand) | `.padding(.horizontal, 16).padding(.bottom, 120)` |
| `Clack/Map/MultiRouteMapView.swift:83` | padding 6 → 4 | `.padding(.leading, 8).padding(.bottom, 6).allowsHitTesting(false)` |
| `ClackKit/Sources/ClackDesign/Flag.swift:73` | padding 10 → 12 | `.padding(.vertical, 10)` |
| `ClackKit/Sources/ClackDesign/Components/TripCard.swift:631` | spacing 6 → 8 | `VStack(alignment: .leading, spacing: 6) {` |
| `ClackKit/Sources/ClackDesign/Components/TripCard.swift:646` | spacing 6 → 8 | `VStack(alignment: .leading, spacing: 6) {` |
| `ClackKit/Sources/ClackDesign/Components/TripCard.swift:657` | spacing 6 → 8 | `VStack(alignment: .leading, spacing: 6) {` |
| `ClackKit/Sources/ClackDesign/Components/TripCard.swift:677` | spacing 10 → 8 | `HStack(alignment: .center, spacing: 10) {` |
| `ClackKit/Sources/ClackDesign/Components/TripCard.swift:684` | spacing 6 → 8 | `HStack(spacing: 6) {` |
| `ClackKit/Sources/ClackDesign/Widgets/DeparturesWidgetView.swift:98` | padding 6 → 4 | `.padding(.vertical, 6)` |

These are off the scale on purpose:
- The share card image (`ShareCard.swift`), which is drawn at 1080 × 1350 and has its own scale.
- The debug timeline demo.
- Positions that clear the floating controls on the station map and the Explore panels. Each is marked
  `design-lint: allow` with its reason.

## Screens

Each screen's step adds its own table below: element, before, after, how, undo.

### 1. Launch and first run

| ID | Element | Before | After | How | Undo |
|---|---|---|---|---|---|
| P1.1 | System launch screen | White (dark: black): `launch-bg` lived only in the package's asset catalog, which iOS can't read before the app runs, so a cold start flashed white, then yellow | Yellow from the first frame, the same as the splash after it | `scripts/ios/make_colors.py` also writes `launch-bg.colorset` into `apps/Clack/Clack/Assets.xcassets` | Delete that colour set (and the lines in `make_colors.py`) |
| P1.2 | Splash length | Until the server answered settings, operators, train types and amenities, plus at least 0.7 s; up to about 15 s on a weak connection; taps ignored | Goes once the wordmark has flipped in (≈ 0.5 s) and the first screen can draw; at the latest after 1.2 s; at once on a tap | `RootView` (`splashSkipped`, the 1.2 s task, `.onTapGesture`) | `RootView.swift` from before this step's commit |
| P1.3 | Settings and reference data at start | Network first; the kept copy only after a failure or the 15 s timeout | The kept copies paint first (settings, operators, train types, amenities), then the server's answer replaces them in place | `AppModel.applySaved()`, `APIClient.saved` (`Clack/App/SavedCopy.swift`, reads the existing cache only) | Remove the `applySaved` line at the top of `AppModel.load()` |
| P1.4 | Wordmark flip on the splash | 0.42 s per tile, 60 ms apart (≈ 0.66 s) | 0.3 s per tile, 40 ms apart (≈ 0.46 s) | `Brand.swift`, `Wordmark` | Put the old numbers back |
| P1.5 | Landing rule (open on the tab that matters) | Never ran: `onChange(of: tab, initial: true)` counted the first appearance as a touch and overwrote the remembered tab | Runs: only a real change counts as a touch | `RootView.swift`, `TouchWatch` | Put `initial: true` back |
| P1.6 | "Trains leaving soon" while loading | Two grey 64 pt bars | Two rows shaped like the real ones (badge, route, times, button), redacted | `WelcomeView.rowLayout` inside `Placeholder` | `WelcomeView.swift` from before this step's commit |
| P1.7 | Departures failed | One grey line ("Couldn't fetch departures right now.") with no way to retry | `ErrorStateView` with Try again | `WelcomeView.soon` | Same |
| P1.8 | "Near you" | iOS's location prompt straight away; if there was no position or no trains, nothing happened | One sentence first ("To show trains from the stations nearest you, Clack needs your location once. It isn't kept."), then iOS's prompt; no position, nothing near, or a failure each says so in a toast | `WelcomeView` (`askingLocation`, `loadNear`), strings `firstRun.nearAsk*`, `firstRun.nearNoPosition`, `firstRun.nearEmpty` | Same |
| P1.9 | Adding a suggested train fails | Spinner stops, nothing said | Toast "Couldn't add the train. Try again in a moment." | `WelcomeView.add` | Same |
| P1.10 | Long names and times in the suggestions | One line each (names and times truncated) | Names wrap to two lines; times never truncate; the row stacks at accessibility sizes | `WelcomeView.rowLayout` (`AdaptiveStack`) | Same |
| P1.11 | Empty suggestions text | "…Find yours below." (the button is above) | "…Use Find a train above." | catalog `firstRun.soonEmpty` | catalog |
| P1.12 | Bottom padding | Fixed 120 pt for the tab bar | The scroll view's own safe area | `WelcomeView` | Put `.padding(.bottom, 120)` back |

### 2. Find a train (the Add sheet)

| ID | Element | Before | After | How | Undo |
|---|---|---|---|---|---|
| P2.1 | Confirm step ("Where did you get on and off?") while the train loads | Nothing held the map's or the stops' place, so the picker, rows and main button jumped down about 100 pt when it arrived (user test) | A 180 pt map placeholder, the summary line redacted, six stop placeholders, from the first frame | `ConfirmStep` in `AddTrainSheet.swift` | That file from before this step's commit |
| P2.2 | The train couldn't be loaded | "Couldn't save: <raw error>", no retry | "Couldn't load this train's stops…" with Try again (`ErrorStateView`) | `ConfirmStep.loadFailed` | Same |
| P2.3 | Save failed (all steps) | "Couldn't save: <server or system message in English>" | "Couldn't save the trip. Check your connection and try again." | catalog `add.saveFailed` | Same, and the catalog |
| P2.4 | Stops that can't be picked | Looked like the others, did nothing; VoiceOver called them buttons | Dimmed to 45 % and disabled | `ConfirmStep.stopRow` | Same |
| P2.5 | From / To picker | Yellow when chosen; VoiceOver read one label for both | Selection ink (Look L1), concentric inner corners, names wrap to two lines; each end reads "From, Stockholm C" with a hint | `ConfirmStep.endPicker` | Same |
| P2.6 | Result card times at AX sizes | "07:2 / 2" (wrapped) | Times never shrink or wrap; the three parts stack when they don't fit | `TimesRow` (`ViewThatFits`) | Same |
| P2.7 | Result card in VoiceOver | Read piece by piece | One sentence: "SJ 523, Stockholm C 07:22 to Malmö C 11:53, 4h 31m" | catalog `add.resultLabel` | Same |
| P2.8 | Result card press | `.plain` (faint dim) | `PressStyle` | `ResultCard`, `ConnectionResultCard` | Same |
| P2.9 | Loading results | Two 120 pt bars | Two cards shaped like a result (`ResultCardSample`) | `SearchStep` | Same |
| P2.10 | Filter chips | Wrapped to two lines in English, ran off the edge in Swedish | One row that scrolls sideways, in every language | `trainResults` | Same |
| P2.11 | "427 427" | Guard on one card only | One rule for every card (`AddTrainLogic.standInName`) | `AddTrainSheet.swift`, `PlannedJourneyViews.swift` | Same |
| P2.12 | Journey filter sheet | Fixed 190/300 pt detents (clipped at AX sizes), Clack's own segmented control inside a system Form, yellow tint | `.medium/.large` with a grabber, the system's segmented control (the app's rule), accent ink | `JourneyFilterSheet` | Same |
| P2.13 | Date picker sheet | Custom surface background and corners, yellow chosen day and yellow Done | System sheet with a grabber; chosen day in selection ink; Done stays the one yellow | `DateRow` | Same |
| P2.14 | Main buttons on the connection and manual steps | Inline, narrow, could sit under the keyboard | Pinned at the bottom like the confirm step (`sheetAction`) | `ConfirmConnectionStep`, `ManualTripStep` | Same |
| P2.15 | Unset times on the manual form | A faded time picker that looked disabled | A "Set time" button; the picker appears once set | `ManualTripStep.timeRow`, catalog `manual.setTime` | Same |
| P2.16 | Alerts offer after adding | Button, then the reason under it | The reason, then the button | `DoneStep` | Same |
| P2.17 | Hint text in the search field | "Train number, route, or operator" | "SJ 523 or Stockholm Göteborg" (a real example) | catalog `add.placeholder` | catalog |
| P2.18 | Sharing a ticket file | Never mentioned in the Add sheet | One line under the examples | catalog `add.shareTicketHint` | Remove the `Text` in `SearchStep` |
| P2.19 | Search failed | A red banner, no retry | `ErrorStateView` with Try again | `SearchStep` | Same |
| P2.20 | "Popular stations" header | Could show over an empty list | Only with stations under it | `SearchStep` | Same |
| P2.21 | Follow a planned journey | Said "Following" even when the server refused | Says it at once, goes back with a toast if refused | `PlannedJourneyStep.follow` | `PlannedJourneyViews.swift` |
| P2.22 | "Add anyway" on a planned journey | A new journey group each try, splitting the forced train off | One group for every try | same file (`group` state) | Same |
| P2.23 | A planned journey's routes | Fetched one train after another | Fetched together | `loadRoutes` (task group) | Same |
| L5 | Sheets (`SheetFrame`, every Add step) | Custom surface background, 24 pt corners | The system's sheet (Liquid Glass at partial heights on iOS 26, its own corners) | `Look.sheets = .system` | `Look.sheets = .surface` |

## Build 71: bugs, trust and chrome

| ID | Element | Before | After | How | Undo |
|---|---|---|---|---|---|
| B71.1 | Explore tilt (owner's bug: "struggled to get out of the tilted view") | Only a flag remembered the tilt: a pinch or pan during the 0.6 s animation left the map half-tilted with nothing to correct it; tilted, the visible box reached the horizon, failed the size check, and the station detail never refreshed, so leaving the station never flattened the map; out only below zoom 15 | The real pitch is checked at every view change and asked for again when it disagrees (a hand tilt while tilted is still allowed); tilted, the detail box is taken round the centre; a failed detail fetch drops the structures; in at 16, out below 15.5 (DESIGN §2.7); a re-created map starts the rule again; Reduce Motion tilts without animating | `ExploreLogic.wantTilt / pitchNeedsFix / detailBox` (tested), `ExploreModel.updateTilt`, `LiveMapView.setTilt` | Revert the tilt commit |
| B71.2 | Station-map clusters (owner's bug: "+1"/"+4" never split, piled up at København H) | A fixed 26 px grid: neighbours across a cell edge overlapped, places on one spot could never split, each tap zoomed 2.2× up to the cap, dimmed (filtered-out) places counted, yellow "+N" badges overlapped | Pins at least 40 pt apart (pin and count bubble never overlap); places that would still share a spot at the closest zoom open a list ("4 places here") instead of zooming; dimmed places don't count; the bubble says the total in ink, not yellow | `StationSceneLogic.shownPois` (distance), `staysTogether`, `StationSceneView.poiPin`, `StationMapScreen` (`PoiGroup` sheet); 3 new tests | Revert the clusters commit |
| B71.3 | Trips and Passport scrolled into the clock | The hidden system bar left the status bar's area transparent | A backdrop in the background colour behind the status bar | `statusBarBackdrop()` in `Shell.swift`, used by `TripsScreen`, `PassportScreen` | Remove the two `.statusBarBackdrop()` lines |
| B71.4 | Network panel | Lines wider than the card were centred and cut at both edges; "Done" | Content held to the card's width; "Close" | `NetworkPanel.swift` | Revert those lines (the panel becomes a sheet in build 73) |
| B71.5 | Explore attribution | Three lines of credits above the tab bar, half covered by sheets | One line: "© OpenStreetMap" (a link to /copyright) · Protomaps, plus "heights © <owner>" while 3D heights show; the full credits (with the NLOD sentence) in the ⓘ legend and in Sources & methodology. Each licence's rule is in `docs/ATTRIBUTION.md`. Trafikverket's API licence isn't recorded in the app: marked unverified there | `ExploreScreen.bottomLeft`, `legendCard`; catalog `liveMap.credits`, `explore.creditShort.*` | Put the old `Text` back in `bottomLeft` |
