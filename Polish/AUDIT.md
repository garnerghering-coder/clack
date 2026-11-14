# Clack polish pass 1: audit

Branch `polish/pass-1`, from build 70 (`ae6bd5d3`). Nothing in the app has changed yet. This file and `Polish/before/`
are all there is so far.

**Read:** CLAUDE.md, DESIGN.md, docs/SWIFT_PORT.md (by reference), the 2026-11-07 user test (`report.md`, `CHANGES.md`,
the briefs and digests), and the code of every screen, widget and the Live Activity. The app ran in the iPhone 17 Pro
simulator against the hosted server with two throwaway users: a fresh one, and one with 7 trips across SE/NO/DK. Both get
deleted at the end of the pass.

**Deployment target:** iOS 17.0 for the app, widgets and ClackKit. Everything newer needs a gate:

| API | Needs |
|---|---|
| Zoom transition | iOS 18 |
| Liquid Glass | iOS 26 (already gated in `Controls.swift`) |
| `swipeActionsContainer()` | iOS 27 |
| `.sensoryFeedback` | iOS 17, no gate |
| `.contentTransition(.numericText())` | iOS 17, no gate |
| `.symbolEffect(.replace)` | iOS 17, no gate |

**Baseline:** the Debug simulator build has 0 warnings.

**Severity:**
- **S1:** broken, untrue or dead. A failure shown as a fact, a dead tap, truncated times, the landing rule never running.
- **S2:** inconsistent or rough. It works, but it doesn't feel finished.
- **S3:** a nit.

**Status of the user test:** 55 of its 96 findings were fixed in build 59. This audit only includes the still-open
findings that are about feel, layout, copy or states. They are marked **UT**. Feature requests from the test (import,
commute, board by date and so on) stay out, as the brief asks.

---

## 0. Where the code disagrees with the brief (the code wins; telling you as asked)

1. **The fonts are not IBM Plex Mono.** Text is **Inter**, and the big numbers and split-flap tiles are **Space
   Grotesk Bold** (`ClackDesign/Typography.swift`, DESIGN §2.2). Controls use SF. Every time already uses tabular
   digits. I'll keep Inter and Space Grotesk.
2. **Yellow is more than "the primary action".** DESIGN §2.1 makes yellow the fill for primary buttons, **the selected
   segment or chip**, **the Passport cover** and the "k" tile. That is the root of every "two yellow things" finding
   below. Your one-yellow rule needs a decision (Needs Garner #1).
3. **Glass is on content buttons, not just the control layer.** DESIGN §2.3 makes every `Button` Liquid Glass:
   chips, result-card actions and the Settings segmented switches. The brief says glass belongs to navigation and
   controls only (Needs Garner #2).
4. **The launch screen is yellow in both themes** (`launch-bg` #FFD400). DESIGN §14 says black or white with the
   theme. Neither the brief nor the code is wrong by itself, so this is Needs Garner #3.
5. **DESIGN §10's motion table is longer than the brief allows.**
   - The Passport count-up is 900 ms. The brief's limit is about 0.35 s for anything seen often.
   - The route draw-on is 1.2 s.
   - The flap is 2 × 180 ms halves plus a 50 ms stagger. Five digits come to about 560 ms.

   I propose shorter values in §2 and will update DESIGN §10 to match if you agree.
6. **The trip card isn't where the brief expects.** The brief says "TripCard" for the trip card. In the code,
   `ClackDesign/Components/TripCard.swift` is the **Live Activity** card. The card in the Trips list is `LegRow`, and
   the one at the top is `FeaturedCard`.
7. **Swipe actions on trips were declined in build 59** because the target is iOS 17. The iOS 27 SDK now has
   `swipeActionsContainer()` for a `ScrollView` + `LazyVStack`, which is what Trips uses. With an `#available(iOS 27)`
   gate it becomes possible, and the hold menu stays for iOS 17–26.

---

## 1. Cross-cutting findings (these drive Phase 2)

| # | Sev | Problem (evidence) | Change |
|---|---|---|---|
| X1 | S1 | **No shared pressed state.** There are 64 `.buttonStyle(.plain)` buttons: cards, rows, `IconButton`, `MapButton` and stop names. They only get the system's faint dim. All three Clack button styles are `PrimitiveButtonStyle`, so none of them reads `isPressed`. | One `PressStyle: ButtonStyle`: scale 0.97, a raised-surface overlay, `.snappy(duration: 0.2)`, no scale under Reduce Motion. Use it on every non-glass tappable thing. Glass buttons keep the system's own press, which is already immediate. |
| X2 | S1 | **Failures are shown as facts.** Five places do it (details per screen): Explore's station sheet says "No trains in this window", a train tap says "This train isn't running right now", a journey says "not found", a followed journey says "ended", and a station map says "There's no map for this station yet". | One `LoadState<T>` with `.loading/.loaded/.empty/.failed(Error)` and one `ErrorStateView`: what happened, what still works, and Retry. A 404 is the only thing that means "empty". |
| X3 | S1 | **Silent failures after a tap.** Delete a trip, ride review Yes/No, save a platform, follow (Explore and a planned journey), stop following, favourite, and Delete my data all use `try?`. The UI either stays put with no message or shows success when nothing was saved (`PlannedJourneyViews.swift:250`). | Apply at once, then reconcile with the server. On failure, roll back and show a toast ("Couldn't delete. Try again."). One `Toast` view, which already exists for live events on trip detail, moves to the shared layer. |
| X4 | S1 | **Times truncate at AX sizes.** `07:2` / `2` on the search result card (before/52). `lineLimit(1)` on names in `WelcomeView`, `ServiceHeader`, `StatusLine` and Tile. Long names truncate ("Stoc…", "CPH Ai…") on Trips at AX3 (before/50). | Times get `.fixedSize()` and never shrink. Names allow 2 lines, then truncate. Rows switch HStack to VStack at `isAccessibilitySize` (one `AdaptiveStack` component). |
| X5 | S2 | **No spacing scale.** There are about 830 literal paddings and spacings. Most sit on 4 pt already, but there are outliers: 1, 5, 6 (13×), 7, 9, 10 (11×), 14 (10×), 18, 30 and 50. | `Space` tokens (below) replace every literal, and the outliers are snapped to the scale. |
| X6 | S2 | **About 20 different animation curves in 24 places.** They include easeOut 0.18/0.2/0.25/0.3/0.35/1.6, easeInOut 0.2/0.25/0.9, linear 1/1.2, five `timingCurve`s and `.default`. Explore's sheet snap is a fixed 0.22 s curve plus a `Task.sleep`. | `Motion` tokens (below). Every animation goes through them, scoped with `.animation(_:value:)`. |
| X7 | S2 | **Haptics with mixed meanings.** `.warning` is used for a successful delete (Trips, trip detail, Settings). Start over fires twice. `.selection` fires on *load* (Explore follows count, favourite star). Arrival plays heavy impact and success within 1 s. Three raw UIKit generators are mixed with `.sensoryFeedback`. | A `Haptic` vocabulary (below), with each trigger on the user's action rather than on loaded state. |
| X8 | S2 | **`.numericText()` and `.symbolEffect` are used 0 times.** Delays, countdowns, "Arrives", Passport stats, the Live Activity times and widget stats jump without a transition. Some lack `.monospacedDigit()` (Live Activity times, Year and Passport widgets). | Every changing number gets `.contentTransition(.numericText(value:))` plus tabular digits. Changing icons (Follow, favourite, alerts bell) get `.symbolEffect(.replace)`. |
| X9 | S2 | **Skeletons are the wrong size.** `Skeleton(height:)` is one bar, so 12 screens use 120 pt whatever replaces it. Trips shows three 64 pt bars where a 300 pt card and 85 pt rows go. Add's skeleton is 120 pt for a 180 pt card. The confirm step has no placeholder for its map, which is very likely **the ~100 pt jump from the user test** (`AddTrainSheet.swift:569-592`). | Skeletons drawn from the real layout: `.redacted(reason: .placeholder)` over a sample `LegRow`, `FeaturedCard`, `ResultCard`, Passport cover and map, with the shimmer kept. A reserved 180 pt map slot on the confirm step. |
| X10 | S2 | **Saved data isn't shown first and never says its age.** `APIClient` asks the network first and only falls back to the cache on failure or after a **15 s timeout**. Trips shows skeletons for up to 15 s on a weak train connection. The offline strip says "showing saved data" with no age. | The screen paints from the cache at once with "Updated 12 min ago", then refreshes in place. **Needs Garner #6:** `APIClient` is networking and off-limits, but this can be done in the view models alone (read `cache` first, then call). Spinners are delayed 300 ms. |
| X11 | S2 | **Empty and error states are hand-rolled.** There is no shared view: 11 `Banner(.error)`s and about 36 inline "empty/failed" texts in 19 files. Trips' empty state has two buttons. | One `EmptyStateView` (what goes here, plus one button) and one `ErrorStateView`, each with a preview for every state. |
| X12 | S2 | **No state restoration.** There is no `@SceneStorage`, and `AppRoute` isn't `Codable`. After iOS closes the app in the background you land on Trips, at the top, with no open trip or sheet. **UT** (Flighty). | `AppRoute: Codable`. Tab, Upcoming/Past, the three paths and the open sheet go in `@SceneStorage` and are restored on launch. Scroll position is restored with `scrollPosition(id:)` on Trips and Passport. |
| X13 | S1 | **The landing rule never runs.** `RootView.swift:270`: `onChange(of: router.tab, initial: true)` sets `touched = true` on first appear. `land()` then always leaves the tab alone, and the "last tab" is overwritten with `.trips` before it's read. | Drop `initial: true`, or ignore changes until `hasLanded`. |
| X14 | S2 | **Words drift.** "Find your train" / "Find a train" / "Add train" all name one action. Swedish adds a sixth: "Lägg till i resor / i mina resor / tåg / resa / ett tåg / ett till". trip/train/journey are mixed: "No trains yet" sits under the title "Trips", and "View journey" is used for a single train. Operatör/Tågbolag/Bolag; Fjärrtåg/InterCity/Slag/Typ; Done vs Close; "Normal" vs "Normalt"; four back styles. **UT.** Swedish `Format.duration` gives "2h 48m". `String(format: "%g")` ignores the decimal comma. Junk keys like "%@ → %@" are made by `Text("\(a) → \(b)")`. "© OpenStreetMap contributors" and "km/h" are hard-coded. | `Docs/WORDLIST.md` (draft in §4) is enforced across the catalog in both languages. `Text(verbatim:)` for composed names. |
| X15 | S2 | **Accessibility settings beyond Reduce Motion are ignored.** Reduce Transparency, Increase Contrast and Bold Text have 0 handlers. text-3 is about 3.9:1 on dark and 3.5:1 on light, yet it's used for placeholders and struck times. | Glass falls back to solid surfaces under Reduce Transparency. Hairlines and text-3 get stronger under Increase Contrast. text-3 is used for disabled things only; hints move to text-2. |
| X16 | S2 | **Magic padding for bars:** `.padding(.bottom, 64)` (TicketReturnPrompt), 120 (Welcome), `top + 60` / `top + 48` (the trip map). On trip detail before departure, **"Turn on alerts" sits under the tab bar at rest** (before/08). | `safeAreaInset` / `safeAreaPadding` / `contentMargins` everywhere. The trip sheet's first resting height keeps its primary action above the bar. |
| X17 | S3 | **Formatters and sorting run in `body`.** `Format.day` and `Format.distance` build a formatter per call, inside rows. Trips sorts and groups on every live tick. Passport decodes every polyline when the fact line is tapped. Journey decodes polylines in `body`. Board re-sorts every second. Trip detail runs `TripDetailLogic.shown` four times a second. | Formatters are cached per locale and zone. Derived lists are computed once when the data changes. Polylines are decoded once. Ticks go down to 15–60 s where seconds aren't shown. Measured before and after in Instruments (§6). |

---

## 2. Foundations to add (Phase 2)

All of these go in `ClackKit/Sources/ClackDesign` unless noted.

**Tokens**

| Token | Values | Notes |
|---|---|---|
| `Space` | `xxs 2, xs 4, s 8, m 12, l 16, xl 24, xxl 32, xxxl 48` | 16 is the screen gutter (DESIGN §2.3). |
| `Radius` (exists) | tag 6 · controlSm 10 · input 12 · card 16 · sheet 24 · bar 2 · badge 10 | Adds `Radius.inner(_ outer:, padding:)` for concentric corners. Three places aren't concentric today. The Passport cover's 24 (sheet radius on a card) needs a ruling: Needs Garner #7. |
| `TextRole` (exists, 36 roles) | unchanged sizes | Tracking now scales with Dynamic Type (it's computed from the base size today). The roles stay on `relativeTo:` text styles. Six `.font(.system(size:))` stragglers move to roles. |
| `Ink` (exists) | + `Ink.textHint` (text-2) | Increase Contrast variants for hairline and text-3 go in the colour assets via `make_colors.py`. |
| `Motion` | `tap = .snappy(duration: 0.2)` · `layout = .smooth(duration: 0.3)` · `appear = .smooth(duration: 0.35)` · `signature = .spring(duration: 0.45, bounce: 0.25)` (signature moments only) · `flapHalf = 0.09 s`, `flapStagger = 0.03 s` | Five digits come to about 0.3 s. Each token has a `reduced` variant (`.easeInOut(0.2)` cross-fade, or nil). `View.motion(_:value:)` picks the right one from the environment. |
| `Haptic` | `.selection`: a value changes under the finger (date chips, year chips; never where the system control already does it). `.snap`, which is `.impact(.light)`: a sheet reaching a detent, a flap landing. `.success`: a trip added, a medal or stamp earned, a follow confirmed. `.warning`: a trip on screen becomes cancelled. `.error`: an action failed. | Each is a `View` modifier with a trigger. One `Settings.haptics` switch, but only if Core Haptics is used for the flap (see §5). |

**Components**
- **`PressStyle`**: scale plus overlay on `isPressed`, with `Motion.tap` (X1).
- **`CardStyle`**: surface, `Radius.card`, hairline and `Space.l` padding, as `.card()`. Rows inside a card get concentric corners.
- **`ClackButtonStyle`**: kept, with its roles (primary/secondary/danger). Its behaviour inside content depends on Needs Garner #2.
- **`Skeleton`**: keeps the shimmer. Adds `.placeholder(_ sample:)` over a real row or card, so the size matches by construction (X9).
- **`EmptyStateView`** and **`ErrorStateView`**: icon, one line, one button. The error state has Retry and an optional "what still works" line. Built on `ContentUnavailableView` with Clack's type and tint (X2, X11).
- **`UpdatedLine`**: exists in widgets and moves to the shared layer: "Updated 2 min ago", turning stale after 2 min (X10).
- **`Toast`**: one transient line for "Couldn't save", "Removed · Undo" and live events (X3).
- **`AdaptiveStack`**: HStack, or VStack at accessibility sizes (X4).
- **`SplitFlap`**: exists. Changes:
  - shorter timings (`Motion.flapHalf`);
  - a cross-fade under Reduce Motion (today the value just appears);
  - stable ids for unchanged tiles;
  - an optional `onLand` that the haptic can hang on;
  - a VoiceOver label from the catalog.

Every new piece gets a `#Preview` for each state, shown in the existing Design Gallery (`-design`).

---

## 3. Per screen, in the order a new user meets them

### 3.1 Launch and first run (before/01, 02)
| Sev | Problem | Change |
|---|---|---|
| S1 | The splash **blocks every touch** (`allowsHitTesting(!hideSplash)`) until settings, operators, train types and amenities have loaded. On a weak connection that can take **up to about 15 s** (the API timeout). **UT** Commuter: "2–3 s yellow screen". | Read the settings from the cache. The splash is skippable by a tap and ends at ≤ 1 s or when the first frame is ready, whichever is first. The wordmark flap plays during that time and can be interrupted. |
| S1 | The landing rule never runs (X13). | As X13. |
| S2 | "Trains leaving soon" shows two grey boxes. If that load fails, the screen says "Find yours below" with no Retry, and the Find button is actually *above*. | Skeletons shaped like the real rows. `ErrorStateView` with Retry. The string is fixed. |
| S2 | "Near you" asks for location, then does nothing if the result is empty or fails: a dead tap after a permission prompt. It also asks with no in-app sentence first. | One sentence first ("To show trains near you, Clack needs your location once"). Then a real empty state or error. |
| S2 | A failed "Add" on a suggested train goes silent (`WelcomeView.swift:135`). | Toast with the error, and the row stays. |
| S2 | `lineLimit(1)` on the route and the times line. | 2 lines for names; times `fixedSize`. |
| S3 | `.padding(.bottom, 120)` stands in for the tab bar. | Safe-area inset. |

### 3.2 Find a train (before/03, 04, 33, 43, 52)
| Sev | Problem | Change |
|---|---|---|
| S1 | **Confirm step jumps**: the 180 pt map and stop list appear only once the trip loads, so the From/To picker and rows move down. This is the user test's "main button jumped about 100 pt". | Reserve the map slot and stop-row skeletons from first paint. |
| S1 | Times wrap at AX3 ("07:2 / 2", before/52). | `fixedSize` times. The duration compresses first, then the card stacks vertically. |
| S1 | Unpickable stops look pickable (`allowsHitTesting(false)` only), and VoiceOver still calls them buttons. | Dimmed, `.disabled`, explained by the header line. |
| S1 | `PlannedJourneyViews.follow()` shows "followed" when the call failed. "Add anyway" makes a new group id, so the train lands in a different journey. | Roll back with an error. Keep the group in state. |
| S2 | A failed trip **load** is shown as "Couldn't save: <raw error>", with no retry. | Separate load-failed state with Retry and words from the catalog. |
| S2 | Three yellow things at once: the date chip, the "All" filter chip and Add. | See Needs Garner #1. My proposal: selected chips become ink (text colour fill, bg text), and yellow stays on Add. |
| S2 | Filter chips wrap to a second line in English (before/04) but scroll off the edge in Swedish (before/43). The same control does two different things. | One horizontally scrolling chip row, with an edge fade. |
| S2 | Primary buttons on the manual, connection and ticket steps are inline and narrow, so they can sit under the keyboard. The confirm step already pins its action. | `.sheetAction` on every step: pinned, full width, above the keyboard. |
| S2 | The result card isn't one VoiceOver element. From/To are labelled on the HStack, which probably hides both buttons' own labels. | One sentence per card ("SJ 523, Stockholm C 07:22 to Malmö C 11:53, 4 h 31 min, high-speed"). Each end button is labelled "From, Stockholm C". |
| S2 | The filter sheet uses fixed `.height(190/300)` detents, which clip at AX sizes. It also uses the custom `SegmentedControl` inside a `Form`, against its own rule. | `.medium` with a grabber; `FormSegmentedControl`. |
| S2 | Search, paging and "Popular stations" failures are silent. An empty "Popular stations" header can show over nothing. | Error line; hide the empty header. |
| S2 | The "427 427" repeat guard is on one card only. Three other card variants can still repeat the number. **UT** residue. | Shared helper for the service name. |
| S3 | Unset time pickers at 0.5 opacity look disabled. The placeholder "Train number, route, or operator" describes the field instead of giving an example. | "Set time" placeholder. Hint text "SJ 523 or Stockholm → Göteborg". |
| S3 | The Add sheet doesn't mention that ticket files can be shared into Clack (**UT**, 1 line). | One line under "Can't find your train?". |

### 3.3 Trip detail (before/07, 08, 09, 41, 51, 61)
| Sev | Problem | Change |
|---|---|---|
| S1 | **The yellow platform tag looks like a button.** It's an `onTapGesture` with a target about 22 pt high, no pressed state and no button trait, and it does nothing when there's nothing to edit. **UT** Commuter. | A real `Button` with a 44 pt hit area and `PressStyle`, only when it can edit. Otherwise a plain grey `PlatformTag` like the stop list. |
| S1 | "Turn on alerts" sits under the tab bar at rest (before/08). | The sheet's resting height and bottom inset keep the action clear (X16). |
| S1 | **VoiceOver can't reach Follow or re-centre.** `RouteMapView.swift:136` puts `.accessibilityElement(children: .ignore)` on the ZStack that holds the button. | The ignore and label go on the map view only. |
| S2 | No haptic when the trip you're looking at becomes **cancelled**. The toast and the announcement are there. | `Haptic.warning` on false→true of `canceled` only. |
| S2 | Several yellow things in every stage: both platform tags, the "Upcoming" line, "Turn on alerts". Later "Get off next" plus the tags, or Yes plus the stamp icon. | Platform tags go grey (`PlatformTag`). Yellow stays on one action per stage (Needs Garner #1). |
| S2 | It says the same thing twice: "Arrives 10:55 +4" in the StatusCard **and** LiveModule, and the header's "Upcoming/Boarding" again in the StatusCard. | LiveModule goes `compact`, and the header's status hides while the StatusCard shows it. |
| S2 | Live values swap with no transition: countdown, Arrives, next-stop ETA, delay, platform. The rail fill and train dot jump each second, and the map marker jumps on each update. | `.numericText()` for countdown, delay and ETA. The flap for the two big times (exists) and the platform (signature #2). The marker is animated linearly over 1 s (none with Reduce Motion). |
| S2 | Loading is one 120 pt skeleton. "Not kept" has no retry. Save platform, refresh and delete are silent on failure. Ride-check Yes/No can be sent twice. | Skeleton shaped like map and sheet. Retry. Toast plus rollback. A busy guard. |
| S2 | TimeBlock reads in pieces ("DEPARTURE", "Platform 3", "+4", "08:07"). Stop delays have no "+4" and no VoiceOver delay; colour and the struck time are the only signal. | One sentence ("Departure 08:07, 4 min late, timetabled 08:03, platform 3"). `timeLabel` includes the delay. |
| S2 | Only the stop *name* opens the board, a target about 20 pt high. | The whole row is the button, with a chevron. |
| S2 | Four 1-second tickers each recompute `shown`, and `segmentFills` rebuilds route distances every second on the main actor. | One moment per tick, passed down. Cumulative distances cached with the decoded route. |
| S3 | Live-trip copy shows on past trips ("No live data here"), and "Late turnaround" appears under every stop. The "—" is never explained. **UT.** | Past trips hide live-only notes. One note per card, not per stop. "—" gets an (i) InfoNote once. |
| S3 | Header map eats vertical flicks (**UT**, declined for the header map). | Leave it (owner declined). Listed for completeness. |

### 3.4 Journey (before/10)
| Sev | Problem | Change |
|---|---|---|
| S1 | Any error, offline included, says "not found" (`JourneyScreen.swift:63`). | 404 alone means missing. Otherwise saved data or `ErrorStateView`. |
| S2 | No pull-to-refresh and no "Updated" line. Polylines are decoded in `body`. | Add both; decode once. |
| S2 | The two ends of a leg card never reflow at AX sizes. | `AdaptiveStack`. |
| S2 | "Stop sharing" ends the live link with no confirmation or undo. | Undo toast. Sharing restarts with the same link if undone in time. |
| S3 | Switching overview and focused train is an instant swap that jumps to the top. `JourneyNow.swift` is unused. | Cross-fade with `Motion.layout`. Remove the dead file (it isn't a feature: nothing references it). |

### 3.5 Trips list (before/05, 06, 30, 40, 50, 60)
| Sev | Problem | Change |
|---|---|---|
| S1 | **Delete waits for the server and fails silently.** The row stays until the server answers. | Remove at once with `Motion.layout`; on failure put it back and toast. The confirmation dialog stays, with no undo, so it's one safeguard and not both. |
| S1 | **The featured card reads to VoiceOver as "View journey: A to B"** only: no times, countdown, delay or platform. | One sentence, with "Opens the journey" as a hint. Each `LegRow` also reads as one sentence ("expected 07:20", not "07:14 07:20 right arrow"). |
| S2 | **Swipe and the hold menu don't match.** There are no swipe actions, and the hold menu is only on single-train rows (`JourneyCard`, `FeaturedCard` and `FollowingCard` have none). | iOS 27: `swipeActions` + `swipeActionsContainer()` with Delete. The same hold menu on every card type, in the same order (Delete last, destructive). |
| S2 | Skeleton is three 64 pt bars; real content is a ~300 pt card then 85 pt rows (X9). | Placeholders shaped like the real cards. |
| S2 | Error text is wrong when saved trips show: "Couldn't load your trips." sits over a full list. | "Couldn't refresh. Showing trips from 12 min ago." with Retry (DESIGN §4). |
| S2 | The empty state has two buttons (Find a train / Explore live trains). | One button. Explore becomes a text link (Needs Garner #8 if you want it gone). |
| S2 | "Following" appears twice on Upcoming: two sections with the same header, and the word again on each row. | One section; the word drops from rows. |
| S2 | Two yellow things: the segmented thumb is always yellow, and Past adds a yellow "Yes" on each ride-review card. | Needs Garner #1. |
| S2 | Rows don't reflow at AX sizes; names truncate (before/50). | `AdaptiveStack`, 2-line names. |
| S2 | No transition from card to detail. | Zoom transition (iOS 18+), kept only if the back swipe still feels right. |
| S3 | "In your Passport" looks like a link but opens the trip. | Text-2, not accent ink. |
| S3 | `LegRow` and Banner use 14 pt padding; followed rows aren't concentric in their card. | 16; `Radius.inner`. |
| S3 | Every row runs its own one-minute clock; sorting and grouping run on every tick (X17). | One `TimelineView` at the screen; derived lists computed in the model. |
| S3 | The same journey reads differently under Upcoming and Past ("4 trains → Oslo S" vs "2 trains → Falköping C"). **UT.** | Copy only, if the grouping data allows it. Otherwise it's left (data model: out of bounds). |

### 3.6 Passport (before/11–14, 31, 44, 62)
| Sev | Problem | Change |
|---|---|---|
| S1 | **Changing the year can show the wrong numbers.** If the load fails, the old data stays under the new year's title ("2025" over all-time totals), and the same mismatch flashes during every load. | Data is kept with the year it belongs to. While loading, the old numbers stay with the old chip selected, then roll to the new ones with `.numericText()`. |
| S2 | The error banner has no Retry, and a failed refresh is silent. | `ErrorStateView` and `UpdatedLine`. |
| S2 | Skeleton is one 120 pt bar; the page is chips, a ~330 pt cover and a 280 pt map. | Placeholders shaped like each. |
| S2 | The numbers jump on a year change. | `.numericText()` on the distance, tiles, %, kg (signature #4 covers new medals). |
| S2 | The fact line is a button inside the cover's link, so VoiceOver can't reach it. Each tap rebuilds the map data on the main actor. | The fact moves out of the link, or becomes an accessibility action. Its state moves into the card; routes are built once per data. |
| S2 | Yellow: the selected year chip, the cover, the "Up next" bar, the CO₂ thumb, and in the empty state "Find a train". | The cover stays. The rest is Needs Garner #1. |
| S2 | The collections pager leaks the next page's text, and the selected chip isn't scrolled into view. The Slag footnote is laid out off-screen, and the "where I've been" map tile does nothing when tapped. **UT.** | Clip the pager; `scrollPosition` to the selected chip; fix the footnote frame. The map tile already opens full screen at the top card, so the dead tile in Breakdown gets a link or loses its tap look. |
| S3 | Medals use `id: \.offset`, so the pop-in lands on the wrong medal. The entrance is 0.45 s + stagger (~0.75 s). | Stable key; `Motion.signature` only for a new medal, otherwise a plain fade. |
| S3 | Records truncate ("Stockholm C → Götebo…" in Worst delay); tiles that open a trip look like tiles that don't. | 2 lines; a chevron on tappable tiles. |
| S3 | Strings built in code (" · ", "(n%)", " kg"); `%g` ignores the Swedish comma. "Show all {{count}}" is reused for operators and train types. | Catalog keys and `FormatStyle`. A neutral key. |

### 3.7 Explore (before/15, 16, 32, 63)
| Sev | Problem | Change |
|---|---|---|
| S1 | **A board failure reads "No trains in this window."** (`ExploreSheets.swift:456`). | `ErrorStateView` with Retry. |
| S1 | **A train-fetch failure reads "This train isn't running right now…"** (`ExploreModel.swift:825`, `TrainDetailSheet.swift:58`). | Same. |
| S2 | A train tap that fails twice just drops the ring: a dead tap. | Toast "Couldn't load this train". |
| S2 | Follow waits for two network calls before the button changes, and a failure is swallowed. The `.selection` haptic fires on *load* (follows count) and on returning to the tab. | Optimistic flip, roll back with a toast. `Haptic.success` on confirm only. |
| S2 | Favourite star buzzes when opening a station that's already a favourite. | Trigger on the toggle only. |
| S2 | **Icon-only buttons:** filter, network panel ("~"), info, locate. The network panel, one of the user test's favourite screens, sits behind an unlabelled squiggle. | Over the map, space is tight: the network button gets a short label ("Network"), and the others keep VoiceOver labels (they have them). |
| S2 | The status chip lives in the screen's `body`, so the whole screen re-evaluates every ~2 s. Zoom ≥ 14 runs a full `render()` at 10 Hz on the main actor (type lookup by linear search, dictionaries rebuilt). Station detail is decoded on the main actor. | Status chip as its own view. A type lookup dictionary. Feature building and decoding off the main actor. Measured (§6). |
| S2 | The auto-tilt ignores Reduce Motion; sheet snap is a fixed curve plus `Task.sleep` (fling velocity lost). | `reduceMotion ? 0 : 0.6`; spring snap from the measured velocity, `Haptic.snap` at the detent. |
| S2 | Locate asks for location with no in-app sentence first. | One sentence first. |
| S3 | The sheet's close and star buttons are 34 pt (the map size) on a sheet. Network panel uses "Done", every other Explore overlay uses "Close". | 44 pt; "Close". |
| S3 | Search sits top-left, out of thumb reach; "Station" is printed five times in results (**UT**). | Leave the field (system placement for a map search). Drop the repeated word: the icon says it. |
| S3 | The attribution line is hard-coded English; `"\(a) → \(b)"` makes junk catalog keys. | Catalog; `Text(verbatim:)`. |

### 3.8 Station board and station map (before/17, 18)
| Sev | Problem | Change |
|---|---|---|
| S1 | The station map's times use **Europe/Stockholm everywhere** (`StationMapScreen.swift:64, 884`). Finnish maps are an hour off. | The station's own zone (`Format.zone`). *This is a display bug, not a data change.* |
| S2 | "No map for this station yet" also shows when the fetch failed. | Error state. |
| S2 | The board re-sorts every row every second; refresh, "Show later" and "Show earlier" failures are silent. "Show earlier" failing empties the list. | 15 s tick; inline error with Retry. |
| S2 | `board.empty` still says "in this window" though the window chip is gone. | "No more departures today." |
| S3 | No legend for the "?" and green-dot pins (**UT**). | A legend row in the existing "About this map" sheet. |

### 3.9 Settings (before/19, 42, 53)
| Sev | Problem | Change |
|---|---|---|
| S2 | Yellow everywhere: two segmented thumbs, about 15 yellow toggles, and Share once an export is ready. | Toggles get the system tint (green) or ink; Needs Garner #1 for the thumbs. |
| S2 | `.warning` after a successful delete; Start over buzzes twice; Delete my data fails silently. | `.success` / `.error` once on the result; error caption. |
| S2 | "Home country: From your fir…" truncates (before/19). | The value wraps under the label at large sizes, or a shorter value ("Automatic"). |
| S2 | Export is two steps ("Prepare", then "Share the file"). **UT.** | One button that prepares and opens the share sheet, with a spinner on the button. |
| S2 | Locate-me asks for permission with no sentence first (RiderSharingCard). | One sentence first. |
| S3 | `TicketReturnPrompt().padding(.bottom, 64)` can cover the last rows. The user test's untappable rows aren't reproduced on build 70; this is the likely cause. | Safe-area inset; `contentMargins` on `Page`. |

### 3.10 Arrival (before/20)
| Sev | Problem | Change |
|---|---|---|
| S2 | The station name is one row of tiles that overflows past xxLarge ("KØBENHAVN LUFTHAVN KASTRUP" is 26 tiles). | Rows break at word boundaries; the name also in plain text for VoiceOver. |
| S2 | A failed load leaves the skeleton up for ever. | Error state. |
| S3 | Heavy impact then success within 1 s; yellow caption plus yellow Done. | One haptic (signature #5); one yellow. |

### 3.11 Widgets and Live Activity (before/21, 22) — consistency only
| Sev | Problem | Change |
|---|---|---|
| S2 | The Live Activity's departs/arrives times lack `.monospacedDigit()`; no `.numericText()` anywhere, so delays jump. Year and Passport widget stats aren't tabular. | Add both. |
| S2 | The Departures widget's error says "Retrying…" (reused `board.error`), but a widget doesn't visibly retry. | A widget string: "Couldn't update. Open Clack to try again." |
| S3 | The Next-journey widget's progress bar is yellow; DESIGN §2.5 says operator colour. | Operator colour. |
| S3 | The Lock Screen card reads in pieces. | One combined sentence. |
| S3 | Gallery order and small-widget truncation (**UT**). | Two-line names in the small widget; the large next-trip widget first in the bundle. |

---

## 4. Word list (draft; becomes `Docs/WORDLIST.md` in Phase 2)

| Use (en) | Use (sv) | Never use | Meaning |
|---|---|---|---|
| Find a train | Hitta ett tåg | Find your train, Add train, Add to Clack | Opening search (button and sheet title). |
| Add to trips | Lägg till i resor | Add trip, Lägg till i mina resor, Lägg till tåg | Saving a found train. |
| Add by hand | Lägg till för hand | Add manually, Add it by hand | The manual form. |
| trip | resa | train (for a saved ride), leg | One ride on one train that you saved. |
| journey | resväg | trip (for several) | Several trips that connect. Only when there's more than one train. (sv as the catalog has it today: `nav.journey` = "Resväg".) |
| train | tåg | service | The vehicle and its number ("SJ 523"). |
| operator | tågbolag | Operatör, Bolag | SJ, Vy, VR… |
| train type | tågtyp | Slag, Typ, category | X2000, Sm5… (category stays "Long-distance/Regional/Commuter"). |
| Close | Stäng | Done (for dismiss), ✕ alone without label | Dismiss a sheet with no changes. |
| Done | Klar | Close (after editing) | Finish an edit. |
| Delete | Ta bort | Remove, Radera | Destructive removal. |
| Follow / Stop following | Följ / Sluta följa | Track, Watch | Following a train you don't ride. |
| Updated 2 min ago | Uppdaterad för 2 min sedan | Last refreshed | Freshness line. |
| Couldn't load… / Couldn't save… | Kunde inte hämta… / Kunde inte spara… | Oops, Something went wrong, Error | Failure, followed by what still works. |
| Try again | Försök igen | Retry (button) | The retry action. |
| No connection | Ingen anslutning | Offline mode | The offline strip. |
| Normal | Normalt | Normal (sv) | Walk pace and comfort (one Swedish form). |
| Platform | Spår | Track (en) | The platform number. |

Durations in Swedish become "2 tim 48 min", not "2h 48m". Decimals use the locale. One date style per context:
"Fri 17 Oct" in rows and "Friday 17 October 2026" in headers.

---

## 5. Signature moments (pick at most five)

| # | Moment | What happens | Cost and risk | My take |
|---|---|---|---|---|
| 1 | **Cold launch** | The wordmark flaps in tile by tile (it exists today and blocks the app). New: ≤ 0.6 s total, a tap skips, and it ends early if the first frame is ready. Under Reduce Motion it's a still wordmark and a cross-fade. | Low: the splash already exists, and this makes it shorter and skippable. | **Yes.** It's the brand and costs no time. |
| 2 | **A time or platform changes on trip detail** | One flip of only the changed tiles, plus one sharp tick. The tick is `Haptic.snap` on `onLand`, or Core Haptics for a crisper single transient. | Medium. The flap exists for times; the platform becomes a flap. It needs care not to fire on first appear. | **Yes.** This is the "clack" itself. |
| 3 | **Adding a train** | After Add, the sheet closes and the new card lands in Trips: it slides from the sheet's direction into its slot, the others make room (`Motion.signature`), and success sounds once. Today there's a check-mark draw inside the sheet. | Medium. It needs the add sheet to close onto Trips. | Yes, if you keep the "Added" page as it is; the landing then happens after "Done". |
| 4 | **Passport stamp** | A new station, country or medal presses in (scale 1.15→1, slight rotation settle, one success). Only for what's new since the last visit; the rest just appears. | Medium. It needs a "seen" marker stored on the phone (UserDefaults, not the data model). | **Yes.** It is the reward the whole log builds to. |
| 5 | **Arrival** | The arrival screen exists. It gets a quiet end: the board settles, one soft haptic (not two), and nothing more. | Low. | Yes, as restraint. |

Not proposed: a count-up on the Passport (seen too often), or the route draw-on beyond 0.6 s.

If you choose #2 with Core Haptics, I'll add one **Haptics** switch in Settings, as the brief says.

---

## 6. Performance plan (Phase 4 numbers)

These get measured with Instruments (SwiftUI and Animation Hitches templates via `xctrace`), on the simulator before and
after, then on your phone if you want real numbers:
- **Trips:** scroll 50+ trips (the throwaway user gets 55).
- **Passport:** scroll and change the year.
- **Explore:** pan at country zoom and at zoom 14+.

Expected wins come from X17 and the Explore main-actor work. The simulator numbers will be labelled as simulator
numbers, not device numbers.

---

## 7. Needs Garner

1. **One yellow thing per screen vs DESIGN §2.1.** Today these are all yellow: the selected segment thumb, the selected
   chip, the Passport cover, the toggles and the platform tags. Options:
   - (a) Yellow only for the primary action and the Passport cover. Selected chips and segments become ink (text
     colour fill), and toggles take the system green.
   - (b) Keep the yellow selection fills, and accept two yellow things where a screen has both.

   **I recommend (a).**
2. **Glass on content buttons.** DESIGN §2.3 makes every button glass, including chips and in-card actions. The brief
   wants glass only on bars and floating controls. Options:
   - (a) Content buttons become solid fills: yellow primary, `surfaceRaised` secondary. Glass stays on the tab bar,
     toolbars, map buttons and the Trips/Settings segmented switch.
   - (b) Keep it as it is.

   **I recommend (a).**
3. **Launch colour.** Yellow in both themes (the code) or black/white with the theme (DESIGN §14)?
4. **The motion budget.** OK to shorten the flap to about 0.3 s for five digits, drop the 900 ms count-up for
   `.numericText()`, and cut the route draw-on to 0.6 s? DESIGN §10 gets updated to match.
5. **Swipe on trips.** iOS 27 gets swipe-to-delete (gated). Should the swipe also offer "Share", or Delete only?
6. **Cached data first.** OK to read the offline cache in the view models before the network call, without touching
   `APIClient`? This also fixes the up-to-15-s splash.
7. **The Passport cover's 24 pt radius.** Keep it as artwork, or make it 16 like every card?
8. **Trips empty state's second button** ("Explore live trains"): make it a text link, or remove it?
9. **Signature moments.** Choose up to five from §5.

---

## 8. Order of work after you've cut this

1. **Phase 2 foundations:** the tokens, `PressStyle`, `CardStyle`, `Skeleton.placeholder`, Empty and Error views,
   `UpdatedLine`, `Toast`, `AdaptiveStack`, the `SplitFlap` changes, the word list, then literals replaced across the
   app. These are a few mechanical commits that the tests and the build check.
2. **Phase 3, one commit per screen:** launch and first run → find a train → trip detail (with journey and arrival) →
   Trips → Passport → Explore (with board and station map) → Settings → widgets and Live Activity.
3. **Phase 4 verification:**
   - The before shots again into `Polish/after/`, plus the matrix: iPhone 17e and 18 Pro Max, sv/en, default,
     xxxLarge and AX3, light and dark, Reduce Motion/Transparency and Increase Contrast, offline and slow, fresh and 55
     trips.
   - The Instruments numbers.
   - `CHANGES.md` with the on-device checklist.

Each phase ends with the app's tests, `swift test`, `npm test` (lint) and a clean build. Build numbers are bumped per
update as CLAUDE.md asks.

**Screenshots so far, in `Polish/before/` (42):** 01–22 cover each screen; 30–33 offline; 40–44 Swedish; 50–53 AX3;
60–63 dark.
