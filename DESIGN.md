# Clack — Design & Functionality Spec

Companion to `SPEC.md`. **SPEC.md owns data sources, architecture, data model and build order. This file owns what the app looks like, how every screen behaves, and how live tracking works.** If they conflict on UI/UX, this file wins; on data/architecture, SPEC.md wins. Flag any conflict to the owner.

Priorities used below: **P0** = must exist in the Phase 1 demo, **P1** = should, **P2** = nice to have (build last, cut first).

---

## 1. Product feel

Clack is a Flighty-style app for trains: calm, dark, precise, a little playful. It should feel like a departure board that has been designed by someone who loves trains.

**The "clack" motif.** Old station departure boards flip their digits with a clacking sound. Clack uses this as its signature animation: times, delays and big stat numbers update with a **split-flap flip** (see §10). No sound in the web app (optional haptic tick later on iOS). The logo and app icon use a single split-flap tile.

**Tone of copy:** friendly, short, never snarky about delays. Examples: "On time", "+8 min", "No trains yet. Add your first one.", "Scheduled times only; we couldn't find actual times for this trip."

**Primary platform:** phone (mobile-first PWA, later wrapped in Capacitor for iOS). Desktop is a responsive layout of the same app, not a separate design.

## 2. Visual language

### 2.1 Colors (owner, 2026-10-21: monochrome with signal yellow, dark and light)

Black, white and greys carry the interface; **signal yellow** is the one accent. Yellow is a *fill* (primary buttons, the selected segment or chip, the Passport hero card, the "k" tile) with black type on it. Where the accent has to be text or an icon, use `accent-ink`: yellow on dark, black on light (yellow text on white is unreadable). Both themes are tokens in `styles.css`; the user picks System / Dark / Light in Settings (default Dark).

| Token | Dark | Light | Use |
|---|---|---|---|
| `bg` | `#0A0A0A` | `#FFFFFF` | App background |
| `surface` | `#151515` | `#F4F4F4` | Cards, sheets |
| `surface-raised` | `#1F1F1F` | `#E9E9E9` | Chips, inputs, pressed states |
| `hairline` | `rgba(255,255,255,0.09)` | `rgba(0,0,0,0.09)` | Dividers, card borders (1px) |
| `text` | `#FFFFFF` | `#0A0A0A` | Main text |
| `text-2` | `#A3A3A3` | `#5C5C5C` | Secondary text |
| `text-3` | `#6E6E6E` | `#8A8A8A` | Hints, disabled |
| `accent` | `#F8D64A` | `#F8D64A` | Signal yellow fills; black type on top (`on-accent` `#0A0A0A`) |
| `accent-ink` | `#F8D64A` | `#0A0A0A` | Accent as text or icon (links, active tab icon) |

Maps follow the theme (dark: `#151515` land on `#0A0A0A` water; light: `#F7F7F7` land on `#DFE2E5` water). The strong colour for unknown operators and live-map clusters is yellow on dark and black on light; your own train on the live map always gets a yellow halo.

**Delay colors (final, owner-approved bands).** Applied to delay badges, stop times, timeline segments and the Passport delay chart. *Always* show the number or word too (e.g. "+8"), never color alone.

| Band | Delay (arrival unless stated) | Color | Label |
|---|---|---|---|
| On time | 0 min or early | green `#3DDC84` | "On time" (or "−2" if early) |
| Slight | 1–15 min | yellow `#F5D90A` | "+8" |
| Late | 16–30 min | amber `#FF9500` | "+22" |
| Very late | 31+ min | red `#FF453A` | "+47" |
| Cancelled | — | red outline + strikethrough times | "Cancelled" |
| Unknown / no data | — | grey `#8E8E8E` dark, `#8A8A8A` light (monochrome theme) | "—" |

Bands are constants in one file (`delayBands.ts`) so they can be tuned. The **on-time % stat** in the Passport uses a separate constant `ON_TIME_MAX_DELAY_MIN = 5` (a common rail punctuality convention; configurable), and the Passport also shows the four-color distribution so strictness is visible.

**Operator colors.** Each operator has one brand color used for the route line, the badge and timeline accents. Do not guess exact brand hex values. Use this approach: ship a curated palette of 12 luminous colors that read well on dark, assign by operator id (stable), and add explicit overrides for the biggest operators (SJ, SL, Skånetrafiken, Öresundståg, Snälltåget, MTR Express, Vy, Mälartåg, Norrtåg, Västtrafik/Västtågen) after checking each operator's public brand page. Always check contrast of the color against `surface`. Operator colors never replace delay colors.

### 2.2 Typography
- UI: **Inter** (fallback system UI font). Use `font-variant-numeric: tabular-nums` for every time, delay and stat so digits don't jitter.
- Big numbers (times on trip detail, Passport hero): Inter Tight or Space Grotesk, weight 600–700, in split-flap tiles (§10).
- Scale: Display 40/44, Title 28/34, Headline 20/26, Body 16/22, Caption 13/18, Micro 11/14. Use real iOS-style large titles on the main tabs.
- Station names: Body weight 600. Train numbers and codes: caption weight 600, letter-spacing +0.02em.

### 2.3 Shape, spacing, depth
- 4px spacing grid; 16px screen gutters on mobile; 24px on tablet/desktop.
- Radii, one scale (owner, 2026-10-23): tags (platform) 6, small controls (34 px buttons, filter chips, date field) 10, buttons/inputs/segmented controls 12, cards 16, sheets 24 (top corners), operator badge 10. Circles only for icon buttons, the FAB and dots. Nothing is a full pill.
- Status is written, not boxed (owner, 2026-10-23: "tiny pill box with a bit of text"): delay, Live, GPS/estimated, speed, Planned/Arrived, category, notices are coloured or grey text in a line, with a dot or icon where it helps. Delay colours have darker "ink" versions for light mode. Only over a map does a status get a backing (a glass label, radius 10).
- Buttons: primary is a yellow fill, secondary a raised surface with a hairline; both radius 12, the same as inputs and the segmented control.
- Depth is mostly color and hairlines, not shadows. Floating elements (FAB, sheet) get a soft shadow (`0 8px 24px` at 45% black on dark, 12% on light).
- Icons: Lucide, 20px, 1.75 stroke.

### 2.4 Map style (the signature visual)
- **Basemap:** low-contrast, following the theme (land and water colours in §2.1; no roads except major motorways at 6% white, minimal labels: only large cities and the stations in the current view, in `text-secondary`). Self-hosted PMTiles via MapLibre (see SPEC §4).
- **Route line (three stacked strokes):**
  1. Glow: operator color at 35% opacity, 12px wide, Gaussian blur ~6px.
  2. Body: operator color at 85% opacity, 4px wide, round caps and joins.
  3. Core: operator color lightened 55% toward white, 1.5px wide.
- **Past vs future (live trips):** the part already travelled is full brightness; the part ahead is the same color at 80% opacity, dashed (1.5 × line width dash and gap).
- **Stops:** intermediate stops = 6px white dot with 1.5px `bg` ring. Origin/destination (your boarding/alighting) = 12px operator-color dot with 2px white ring, with name labels. Stops you passed through but didn't ride are not drawn on the map (only in the timeline).
- **Rail network layer (toggle, on by default; owner 2026-10-21):** all rail lines as 1px `rgba(255,255,255,0.12)` lines under the route; stations as tiny dots at zoom ≥ 9.
- **Train marker (live):** on the trip map, a 14px operator-color circle with white 2px ring, a small heading chevron, and a pulsing halo (scale 1→2.4, opacity .5→0, 1.8s loop). On the Explore map, a flat Apple-Maps-style disc (white rim, operator-colour centre, a soft heading cone), no rings or pulse (owner 2026-10-21); your own train gets a yellow halo, a followed one a ring. If the position is **estimated** (no GPS), the marker is hollow (ring only) and the label says "Estimated position".
- **Draw-on animation:** when a trip detail opens, the route line draws from origin to destination over ~1.2s (ease-out) while the camera fits the bounds with 48px padding. Skip if `prefers-reduced-motion`.
- **Attribution:** small "© OpenStreetMap contributors" bottom-left, in `text-tertiary`.

## 3. Navigation & layout

**Mobile:** bottom tab bar with three tabs: **Trips**, **Explore** (the live map), **Passport**. Settings opens from a gear in the Trips and Passport headers. Trips has a "+" button in the header. Trip detail, Add trip, and Journey view open as full-height sheets/pages with back/close.

**Tablet/desktop (≥ 1024px):** left sidebar (logo, Trips, Passport, Settings, big "Add train" button). Trips screen becomes a split view: list on the left (400px), selected trip's map + details on the right. Passport and Settings are centered content (max width 960px). Add trip opens as a centered modal (560px wide).

## 4. Screen: Trips (home) — P0

**Header:** large title "Trips"; right side: "+" icon button. Below: a segmented control **Upcoming | Past**.

**Hero card (top of Upcoming).** The next or currently active leg. Full-width card, 16:9-ish, background is a dimmed mini map of the route with the glow line. Overlay content:
- Top row: operator badge + "SJ 523" + category chip; right: status pill.
- Middle: "Stockholm C → Göteborg C" (Headline), times "08:03 → 10:51" in split-flap digits.
- Bottom: a pill with a countdown ("Departs in 2d 3h", "Departs in 24 min", "Boarding", "Live now" with pulsing dot) and, if known, a platform chip "Platform 12" and the delay badge.
- **If the trip is live** the bottom area becomes a progress module: thin progress bar with a train dot between origin and destination, and a line "Next: Katrineholm 08:41 (+3)". Tapping opens trip detail.
- If nothing is upcoming, the hero becomes a friendly prompt: dotted line illustration + "Where to next?" + Add train button.

**Upcoming list.** Below the hero: remaining upcoming legs as rows (see row anatomy).

**Past list.** Grouped under sticky month headers ("October 2026"). Legs that belong to the same journey are shown inside one **journey card** with the legs stacked and connected by a thin line, with transfer chips between them ("14 min transfer · Hässleholm"). Single-leg journeys are plain rows.

**Row anatomy (leg):**
- Left: 36px operator badge (rounded-square, operator color, logo or short name).
- Middle, line 1: "Stockholm C → Göteborg C" (Body 600, ellipsis if long). Line 2 (caption, secondary): "SJ 523 · Fri 17 Oct · 08:03–10:51".
- Right: arrival delay pill (colored per §2.1) and below it distance in caption ("455 km"). Unknown data shows a grey "—" pill.
- Interactions: tap = open detail; swipe left = Delete (with undo toast); long-press = menu (Move to journey, Split journey, Delete).

**Behaviors**
- Pull to refresh re-fetches live data for upcoming/active legs.
- Completed legs auto-snapshot when the app is opened or live tracking observes the arrival (SPEC §10).
- Empty state (no legs at all): centered dotted-line illustration, "No trains yet", "Add the train you took today, or one from years ago.", primary Add train button.
- Loading: skeleton rows (shimmer). Error: inline banner "Couldn't refresh. Showing saved data." with Retry.

## 5. Screen: Add trip — P0

Opens as a full-height bottom sheet (mobile) or modal (desktop). Title "Add a train", close button top-right.

### 5.1 Layout, top to bottom
1. **Date row:** pill chips **Today · Tomorrow · Pick date**, plus the selected date shown ("Fri 17 Oct"). Choosing a past date shows a subtle hint "Past trip". Date picker is a native-feeling calendar; years are quickly selectable (people add old trips).
2. **Search field** (autofocus): placeholder "Train number, route, or operator". Under it, three tappable example chips: `SJ 523`, `Stockholm → Göteborg`, `Snälltåget Stockholm Malmö`.
3. **Interpretation chips:** as the user types, show how the input is understood as removable chips, e.g. `SJ` · `train 523`, or `Stockholm C` → `Göteborg C`. Tapping a chip's × edits that part. This makes the "smart" parsing visible and debuggable.
4. **Autocomplete dropdown** (while typing a station): rows with station name, small subtitle (e.g. county), recents first with a clock icon. Accent- and case-insensitive ("Goteborg" finds "Göteborg C"). After choosing the first station, the field shows "Stockholm C →" and the cursor waits for the destination.
5. **Results list** (once the query is complete): see 5.2.
6. Footer link: **"Can't find it? Add manually"** (opens the manual form, §5.4).

### 5.2 Results
Each result is a card:
- Large times "08:03 → 10:51" (split-flap style, smaller than hero), duration "2h 48m" between them.
- Operator badge + name, train number, category chip (High-speed / InterCity / Regional / Commuter / Night / Heritage).
- If the date is today: live delay "+4 now" and platform if known.
- Sorted by departure time. Filter chips above the list: **All · Long-distance · Regional · Commuter**.
- Only **direct trains** appear (Clack is not a journey planner). If none: "No direct train found. Add each train separately." with the manual add link.
- If the chosen date is older than the live timetable window the app searches the historical archive: show a spinner "Searching the archive…". If nothing is found: "We couldn't find this train in the timetable archive. You can add it manually."

### 5.3 Confirm step
Tapping a result opens **"Where did you get on and off?"**:
- Top: a mini map (height ~180px) showing the full train route faintly and the selected segment glowing.
- Below: the train's full stop list as a vertical list; two selectors, **From** and **To**, preselected to the searched stations (or first/last stop for a train-number search). Tapping a stop sets From/To; the segment highlights on the mini map and the summary updates: "Stockholm C → Göteborg C · 455 km · 2h 48m".
- Primary button **Add to Clack**.
- If the same train number is already logged for that date: inline warning "You already added this train on this date" with options Add anyway / Cancel.

### 5.4 Manual add (fallback)
A simple form: **From** and **To** (station autocomplete), **Date**, optional **Departure time**, **Arrival time**, **Operator** (dropdown), **Train number**. Button **Add trip**. The saved leg is labeled **"Manual"** and its map line is labeled "Estimated route". It counts for distance, stations, countries and CO₂ but not for delay stats.

### 5.5 After saving
A success state in the sheet: green check animation, summary of the leg, and two buttons: **View trip** and **Add another** (keeps the date and the last stations as recents so logging a day of travel or a back-catalogue of old trips is fast). No CSV import in Phase 1.

### 5.6 States
Loading skeletons for results; offline/API-down banner "Timetable search needs a connection"; empty query shows recents and examples.

## 6. Screen: Trip detail — P0

### 6.1 Layout (mobile)
- **Top ~55%:** full-bleed map with the route (§2.4). Floating controls on the map: back button (top-left), a layers button (top-right; toggles **Rail network** and **Follow train**), and a re-center button (bottom-right). Tapping a stop dot flies to it and highlights its row in the timeline.
- **Bottom sheet** with three snap points (peek showing header + times; half; full-height scroll). Content, in order:
  1. **Header row:** operator badge, "SJ 523", category chip, status chip (**Upcoming / Boarding / Live / Arrived / Cancelled**).
  2. **Route + date:** "Stockholm C → Göteborg C", "Friday 17 October 2026".
  3. **Times block:** two big split-flap time groups: departure (left) and arrival (right). Under each: platform chip ("Platform 12") and the delay pill. When actual differs from scheduled, show scheduled small and struck through above/next to the actual time.
  4. **Live module** (only for active legs; see §9): progress bar, current segment text ("Between Katrineholm and Hallsberg"), "Next stop: Hallsberg 09:12 (+4)", "Arrives 10:55 (+4)", freshness "Updated 12 s ago", and source "Live position" or "Estimated position".
  5. **Stats row (4 tiles):** Distance, Duration, Delay, CO₂ saved (tapping CO₂ opens the comparison switcher).
  6. **Stop timeline:** vertical line colored with the operator color for the travelled/ridden part and dimmed after. Each row: dot, station name, scheduled time, actual time (delay-colored), platform. Markers on your boarding and alighting stops ("You got on here" / "You got off here"). Stops before boarding and after alighting are dimmed and collapsed behind "Show full route". Cancelled stops are struck through. Platform changes show a small ↻ icon with a tooltip ("Platform changed 12 → 14").
  7. **Activity** (only if events exist): reverse-chronological log: "Platform changed 12 → 14 · 08:41", "Delay increased to +12 · 08:55".
  8. **Details:** category, operator, journey link, notes (editable text), data-quality badge when not full ("Scheduled times only"), source line ("Times: Trafikverket").
  9. **Actions:** Change boarding/alighting stops, Move to journey, Delete trip.
- **Desktop:** the left column is the trips list; the right 60% is the map with the same sheet content docked as a 380px panel over the map's left edge.
- **Opening animation:** route draws on, then the times flip into place (§10).

### 6.2 Behaviors
- For completed legs the screen is static and fully offline.
- For future legs: countdown instead of stats; map shows the planned route; stop times are scheduled only.
- For manual legs: no stop timeline beyond origin/destination; route labeled "Estimated route".
- Tapping the delay pill explains the number: "Arrived 8 min after the timetable."

## 7. Screen: Journey view — P1

A journey is an ordered group of legs. Opening one shows a header card (total door-to-door time, number of trains, total distance) and a vertical sequence of leg cards joined by **transfer connectors**:
- Connector shows the planned transfer time ("14 min in Hässleholm"). Under 10 minutes: yellow "Tight connection". When actuals are known and leg 1 arrived after leg 2 departed: red "Missed connection".
- Auto-grouping rule: next leg departs from the same station (or stop area) the previous leg arrived at, same day, gap ≤ 4 hours (SPEC §13). Users can drag a leg out (split) or merge via long-press menu.
- A combined map shows all legs, each in its own operator color.

## 8. Screen: Passport — P0

Scrollable page. Sticky top controls: **year chips** (All time, 2026, 2025, …) and a **"Include commuter trains"** switch. All content below respects both.

1. **Hero:** total distance as huge split-flap digits (count-up on first view) with unit toggle; under it a rotating flavor line (§8.1).
2. **2×2 stat tiles:** Trains (legs), Journeys, Time on trains (e.g. "5d 3h"), Stations.
3. **Map card:** every ridden route drawn together using additive blending so lines **glow brighter where you've ridden them more often**. Station dots scale with visit count. Tap to open full screen with year filter and the Rail network toggle.
4. **Stamps** (P2): horizontal carousel. Country stamps (large) and station stamps (small), ink-stamp style SVG (slight rotation, textured edge) with name and first-visit date. A "New stamp!" animation plays after a leg adds a new station or country.
5. **Records:** Longest trip (distance and duration), Biggest delay (links to the trip), Most-ridden route, Busiest station, Earliest departure, Latest arrival.
6. **Operators:** horizontal bars in operator colors with count and km; tap an operator to filter the log.
7. **Train types:** bars for High-speed, InterCity, Regional, Commuter, Night, Heritage.
8. **Delays** (only legs with full data; note "Based on N trains"): big **On time %** (≤5 min), total time lost, average delay, worst delay, cancellations; a **distribution bar** with the four delay colors (green/yellow/amber/red) so the strict view is visible.
9. **Borders & countries:** list with border crossings counted (e.g. Öresund bridge once Denmark exists).
10. **CO₂:** big "kg saved vs flying" with the comparison switcher chip row (**Flying · Car (solo) · Car (2) · Car (3) · Electric car · Coach**), plus "Train: X kg / Flying would have been: Y kg". Link "How we calculate this".
11. **Train log:** every completed leg, newest first, with search and operator/type filters; same row anatomy as Trips.

### 8.1 Flavor lines (secondary, small, rotate on tap or daily)
Derived only from the user's own data; never invented. Constants live in one file and must be verified by Claude Code before use.
- "**0.31× around the Earth**" (total km ÷ 40,075).
- "**3.2× the length of Sweden**" (total km ÷ approx. 1,572 km north–south; verify the figure).
- "**5 days and 3 hours** of your life on rails."
- "Your most-ridden line: **Stockholm C ⇄ Göteborg C** (23 times)."
- "Busiest month: **March 2026** (14 trains)."
- "Longest rail streak: **9 days in a row**." (P2)
- "You've spent **6h 12m** on late trains. Hang in there." (only if delay data exists)

## 9. Live tracking — P0 (in-app while the server is running)

### 9.1 What it does
For any leg that is upcoming within 24 hours, in progress, or finished within the last 30 minutes ("tracked legs"), Clack shows live status in the Trips hero, the trip detail and the activity log:
- Live delay at each stop and for the arrival (updates as the train progresses).
- Platform assignments and changes.
- Cancellations and short-turns.
- Where the train is: a **live position** marker when the train reports GPS, otherwise an **estimated position** along the track.
- Next stop and ETA.

**Out of scope for Phase 1:** push notifications, lock-screen Live Activities, tracking while the app/server is closed (these need hosting and, for Live Activities, a native iOS app). The architecture must not block them (see 9.4).

### 9.2 Data and how it works (verify in Phase 0)
1. **Times, delays, platforms, cancellations:** Trafikverket `TrainAnnouncement`. Trafikverket's API supports query-then-stream (server-sent events) subscriptions; if streaming is awkward or limited, poll every 20–30 s for tracked trains only. Phase 0 must confirm which works and the connection limits.
2. **Position:** Trafikverket `TrainPosition` (exists in the API's object list). Not every train reports a position, so the UI must handle absence gracefully.
3. **Estimated position (fallback):** from the last confirmed stop passage (actual time) and the next stop's estimated time, interpolate along the leg's geometry at constant speed between stops. Always label it "Estimated".
4. **Oxyfi realtime positioning is NOT used in Phase 1.** Its documented vehicle list is limited to a few regional operators, one websocket per key, and the server must relay it. Possible later addition.
5. **One poller per train per date**, shared by every user who tracks it (quota-friendly and multi-user ready). The backend pushes updates to open clients via Server-Sent Events (or WebSocket) from **our** server; the browser never talks to Trafikverket.
6. Pause polling when no client is viewing and no leg is within its tracking window.

### 9.3 Leg status state machine
`scheduled → boarding (T−30 min) → departed → en route → arrived → snapshotted`, with side events `delayed`, `platform_changed`, `cancelled`, `short_turned`. Each event is stored in `leg_events` (SPEC §7) and appears in the Activity log and as an in-app toast/banner while the app is open. On `arrived` plus final actuals, run the permanent snapshot (SPEC §10).

### 9.4 Forward compatibility
Store each event with a type, timestamp and payload so that push notifications can later be sent from the same event stream. Keep the poller as a server-side job independent of any browser session.

### 9.5 UI details
- Hero card and trip detail show a **LIVE** chip with a pulsing dot while tracked and fresh. If data is older than 2 minutes, the chip turns grey "Stale · updated 3 min ago".
- A **freshness label** is always visible on live modules ("Updated 12 s ago").
- A **Follow train** toggle keeps the map centered on the train marker; dragging the map turns it off.
- When the train position is unknown: "Position not available for this train" and the marker is hidden (the progress bar still works from stop times).
- Honest data: never present an estimate as GPS.

## 10. Motion & micro-interactions

| Interaction | Behavior |
|---|---|
| Split-flap | Each digit is a two-half tile; the top half flips down revealing the next digit; two 180ms halves per digit, 50ms stagger left→right; used for times, delays, Passport hero numbers. On live updates, only changed digits flip. |
| Route draw-on | 1.2s ease-out line draw with camera fit (trip detail first open). |
| Marker pulse | 1.8s loop, halo scale 1→2.4 and fade. |
| Sheet | Spring snap between peek/half/full. |
| Count-up | Passport numbers count up over 900ms on first view of the screen. |
| Success | Check mark stroke-draw (350ms) after adding a trip. |
| Stamp | Scale 1.4→1 with a slight rotation settle when a new stamp is earned. |

All motion obeys `prefers-reduced-motion` (replace with fades or no animation).

## 11. Screen: Settings — P0

Grouped list: **Appearance** (System / Dark / Light), **Language** (English, Svenska), **Units** (km / miles), **Clock** (24h / 12h), **Default CO₂ comparison**, **Include commuter trains by default**, **Show rail network on maps by default**, **Data** (Export my data as JSON/CSV; Delete all data), **About** (Sources & methodology, data attributions, version). Changes apply instantly.

## 12. Screen: Sources & methodology — P1

A plain page listing every data source (Trafikverket, Trafiklab/Samtrafiken GTFS, OpenStreetMap, basemap provider), licenses/attributions, and the CO₂ factors table with sources and years (from `data/co2_factors.json`). Explain the delay color bands and the on-time threshold.

## 13. First run — P1

1. Welcome screen: dark background, a glowing line draws across a dim map, wordmark "clack" flips in. Button **Get started**.
2. One screen of preferences: units and clock (defaults sensible, skippable).
3. Land on the empty Trips screen with the "Add your first train" prompt.
No sign-up in Phase 1.

## 14. Brand

- **Name:** Clack. Tagline **"EVERY TRAIN. EVERY TRIP."** (Swedish: "VARJE TÅG. VARJE RESA.").
- **Wordmark** (owner's design, 2026-10-21): lowercase "clack" on five split-flap tiles, each with the hinge line across the middle; the first four tiles are black/graphite with white letters, the **"k" tile is signal yellow with a black letter**. A rule underneath on the launch screen: yellow on black, black on white or yellow. Component: `components/Brand.tsx` (`Wordmark`, `Splash`).
- **Launch screen:** the wordmark flips in tile by tile, the rule, the tagline near the bottom; on the theme's background. Three colourways exist (black, signal yellow, white); the app uses black or white with the theme.
- **App icon:** one signal-yellow split-flap tile with a black "c" on black (`public/icons/`, `public/favicon.svg`).
- Name availability and trademark checks are still pending (see SPEC §20).

## 15. States & edge cases checklist

For every screen implement: loading (skeleton), empty, error (with retry), offline (show saved data and a banner), and long text (ellipsis, no overflow). Handle: trains crossing midnight (show "+1" on the arrival date), time zone display in the station's local time, very long routes (map fit), trips with a single stop segment, duplicate legs, deleting a leg that belongs to a journey (journey recalculates or disappears), cancelled trains the user "rode" (allow marking as "I didn't ride this").

## 16. Accessibility

- Contrast ≥ 4.5:1 for body text; color never the only signal (delay numbers always shown).
- Touch targets ≥ 44px; all controls reachable by keyboard on desktop; visible focus rings (accent).
- Maps have a text alternative: the stop timeline contains everything shown on the map.
- Support dynamic text sizing and `prefers-reduced-motion`; provide `aria-live="polite"` announcements for live status changes (delay changes, platform changes).

## 17. Responsive breakpoints

`< 640px` phone layout · `640–1023px` tablet (two-column Passport tiles, sheet becomes a side panel) · `≥ 1024px` desktop split view with sidebar.
