# Clack iPhone client: screen and behaviour inventory (for the SwiftUI port)

> The web app this file cites (`apps/web`) was removed from the repository; its last state is commit `787192a`.

Source of truth: `apps/web/src` as of 2026-10-23. All paths below are relative to `apps/web/src/` unless they start
with `packages/`, `data/`, `docs/`, `assets/` or a repo-root document name. Citations are `file:line` or
`file:start-end`. Where the code and DESIGN.md/SPEC.md disagree, the code is described (parity target) and the
disagreement is flagged as **[doc differs]**. Things I could not settle from the code are flagged **[unclear]**.

The web app is one React tree; on a phone (< 1024 px) it shows a bottom tab bar, on desktop a sidebar. Only the phone
layout matters for the port. The laptop "phone frame" (`PhoneFrame.tsx`, `main.tsx:14-29`, key `clack.layout`) is a
desktop-browser convenience and is **not** part of the iPhone app.

> Reference for [docs/SWIFT_PORT.md](../SWIFT_PORT.md), written from the code on 2026-10-23. Line numbers drift; when this and the code disagree, the code wins.
>
> Changed since: the simple family outlines (`TrainArt.tsx`) are gone. Wherever this file mentions TrainArt or a silhouette (train picker, search results, Passport train types, §3.12), the app now shows `TrainPicture`: the drawn model, or the nearest drawn one unpainted and faded (SWIFT_PORT.md B7). The live map's `mine` flag and the trip stream are now per phone on the server (API.md).

---

## 1. Navigation map

### 1.1 Routes (`App.tsx:24-51`)

| Path | Component | Notes |
| --- | --- | --- |
| `/` | `TripsPage` | Primary tab "Trips". Query `?tab=past` opens the Past segment (`pages/TripsPage.tsx:387`). |
| `/trips/:id` | `TripDetailPage` | One leg ("trip"). |
| `/journeys/:id` | `JourneyPage` | Several legs grouped as a journey. |
| `/passport` | `PassportPage` | Primary tab "Passport". |
| `/stations` | `StationsPage` | Station search (reached from the Trips header magnifier). |
| `/explore` | `LiveMapPage` | Primary tab "Explore" (live map). Query `?train=<number>&date=<YYYY-MM-DD>&key=<tripKey>` focuses a train. |
| `/live` | `ToExplore` → `<Navigate to="/explore{search}" replace>` | Legacy alias, keeps its query (`App.tsx:18-22`). |
| `/stations/:id` | `BoardPage` | Departures/arrivals board. `?type=arrivals` selects arrivals. |
| `/stations/:id/map` | `StationMapPage` | Station plan + Layover Guide. Query: `from`, `to`, `arr`, `dep`, `a`, `b`, `xa`, `xb`, `live` (see §2.10). |
| `/dev/station/:id` | `StationMapPage` | Dev builds only (`App.tsx:41`). Not needed in the port. |
| `/add` | `AddTripPage` | Full-screen sheet over everything (CSS `.sheet-page` z-index 30 covers the tab bar, `styles.css:312`). Query: `trip`, `date`, `from`, `to`, `replace`. |
| `/settings` | `SettingsPage` | Not a tab; opened from a gear icon. |
| `/about` | `AboutPage` | From Settings. |
| `/privacy` | `PrivacyPage` | From Settings. |

There is no 404 route: unknown paths render the shell with an empty main area **[unclear: no catch-all route]**.

### 1.2 Tab bar (`components/AppShell.tsx:12-16, 112-119`)

Order and icons (Lucide): 1. **Trips** `/` (TrainFront) · 2. **Explore** `/explore` (Compass) · 3. **Passport**
`/passport` (Stamp). Labels `nav.trips`, `nav.explore`, `nav.passport`. Icon 22 pt, stroke 1.75. Active tab: label in
`--text`, icon in `--accent-ink`; inactive `--text-3` (`styles.css:123-136`). Bar height 64 + safe-area, glass
background with blur and a top hairline. The tab bar stays visible on every route except `/add` (covered by its sheet)
and modal sheets (backdrop z-index 40). Explore and the station map are laid out to end above the tab bar
(`styles.css:635, 700`).

**[doc differs]** DESIGN.md §3 still lists Trips/Passport/Settings tabs; the code (and docs/archive/PRODUCT_BRIEF_STATUS.md)
use Trips/Explore/Passport with Settings behind a gear.

Secondary entry points to non-tab screens:
- Settings gear (`SettingsLink`, `components/AppShell.tsx:64-71`): in the headers of Trips and Passport only (not on
  Explore).
- Trips header also has a magnifier → `/stations` and a "+" → `/add` (`pages/TripsPage.tsx:429-437`).
- An offline banner floats at the top of every screen while offline (`components/AppShell.tsx:82-86`, §3.4).
- `TicketReturnPrompt` floats above the tab bar on every screen when a ticket hand-off is pending (§3.7).

### 1.3 Landing screen (`landing.ts`, applied in `components/AppShell.tsx:22-61`)

Runs **once per app start** (web: once per browser tab session via `sessionStorage['clack.landed']`), only when the
start URL is exactly `/` with no query, and is abandoned if the user touches or types before it resolves:

1. Mark started (`sessionStorage.clack.landed = '1'`); if already set, do nothing (`AppShell.tsx:27-36`).
2. Register one-shot `pointerdown`/`keydown` listeners that set `touched` (`:37-39`). Swift: any tap/gesture before
   the decision cancels it.
3. `lastTab = readLastTab()` from `localStorage['clack.lastTab']` (`landing.ts:51-58`), valid values
   `trips|explore|passport`.
4. `GET /api/legs`. On success `resolveLanding({legs, now, lastTab})`; if the result is not `trips`, still untouched,
   and still on `/`, replace-navigate to that tab's path (`AppShell.tsx:41-45`). On failure: go to `lastTab` if it
   is set and not `trips` (`:46-48`).
5. On every route change, if the path is a tab root (`tabForPath`, `landing.ts:66-71`), save it as last tab
   (`AppShell.tsx:57-60`, `landing.ts:59-65`).

`resolveLanding` (`landing.ts:42-48`): `trips` if any leg `isActive`; else `trips` if any leg `isImminent`; else
`lastTab`; else `explore`.
- `times(l)` (`:20-25`): dep = `actualDep` ?? (`schedDep` + `depDelayMin`×60 s); arr = `actualArr` ??
  `live.arrivalEta` ?? `schedArr`.
- `isActive` (`:28-34`): false if `canceled` or `live.status=='cancelled'`; true if live status `en_route`/`at_stop`;
  false if live `arrived` or `actualArr` set; else `dep ≤ now ≤ arr + 10 min` (`LANDING.arrivalGraceMs`).
- `isImminent` (`:37-40`): `dep > now && dep − now ≤ 3 h` (`LANDING.attentionWindowMs`). Cancelled legs count.
Tests: `landing.test.ts`.

The **Splash** (`components/Brand.tsx:22-46`) covers the first paint: shown until settings have loaded *and* at least
900 ms have passed, then fades out over 400 ms (CSS 350 ms opacity, `styles.css:146-151`). Content: the wordmark (five
split-flap tiles "c l a c k", last tile yellow) at 64 px with a yellow rule under it, tagline `app.tagline` near the
bottom (18 % from bottom, 13 px, letter-spacing 0.22 em). Tiles flip in: 420 ms each, `cubic-bezier(.3,.7,.2,1)`,
60 ms stagger, rotateX −90°→0 with opacity (`styles.css:155-162`). Reduced motion: no flip.

### 1.4 Sheets and modals and how they open

| Sheet / modal | Where | Opened by | Closed by |
| --- | --- | --- | --- |
| Add-a-train sheet (whole page) | `/add`, `pages/AddTripPage.tsx:527-652` | "+" buttons, "Find a train", Plan (Explore), Use instead (disruption) | X → `/`; Back inside |
| Train sheet (live train), 3 detents | Explore, `LiveMapPage.tsx:906-973`, `TrainSheet` `:996-1110` | Tap a train marker; search result; `?train=` focus; station sheet row | X (deselects), drag down, tap title folds |
| Scheduled-train sheet | Explore, `ScheduledSheet` `:1157-1226` | `?train=` not on the map; station-sheet row not on map | X |
| Not-running sheet | Explore, `NotRunningSheet` `:1229-1257` | `GET /trains/...` failed | Close / Unfollow |
| Station sheet (on map) | Explore, `LiveStationSheet` `:1266-1326` | Tap a station square or label; station search result | X |
| Search results card | Explore `:740-769` | Focus/typing in the search field | Close link / picking |
| Filters card | Explore `:770-818` | Filters button | Done |
| Legend card | Explore `:839-855` | Info button | Info button again |
| Place search (modal, backdrop) | Station map, `PlaceSearch` `StationMapPage.tsx:388-522` | Search button (find), From/To end buttons | Backdrop tap, X, picking |
| Amenity (POI) sheet (modal) | Station map, `PoiSheet` `:551-609` | Tap a POI pin / list row / search row in find mode | Backdrop, X, Route here / Start here |
| Share sheet (modal) | Passport, `share/ShareSheet.tsx:183-237` | Share icon in the Passport header (only when trains > 0) | Backdrop, X |
| Ticket return prompt | App shell, `components/Tickets.tsx:104-168` | App becomes visible/focused > 5 s after tapping a Buy-ticket link | Not now / Close |
| Toast (trip detail) | `pages/TripDetailPage.tsx:266-270` | A live event arrives | Auto after 6 s |
| Native `confirm()` dialogs | Trip delete (`TripDetailPage.tsx:225`), Delete my data (`SettingsPage.tsx:120`) | Buttons | OK/Cancel → use `.confirmationDialog`/alert |

Modal sheets (`.board-sheet`) slide up 24 px with fade in 220 ms (`styles.css:622-623`), max height 85 % of the
screen, top radius 24, backdrop `--scrim`.

### 1.5 Deep links

There is **no custom URL scheme or universal link** in the iOS project (`ios/App/App/Info.plist` declares only
`NSLocationWhenInUseUsageDescription` and portrait orientation). "Deep links" are in-app URLs; the Swift app needs an
equivalent internal router with these parameters:

| URL | Built in | Meaning |
| --- | --- | --- |
| `/explore?train=N&date=D&key=K` | `BoardPage.tsx:28-32`, `TripsPage.tsx:301`, `Disruption.tsx:148,167`, `TripDetailPage.tsx:250` | Open Explore focused on train N on service date D (timetable key K optional). |
| `/add?trip=K&date=D[&from=seq&to=seq][&replace=legId]` | `LiveMapPage.tsx:954,1214`, `Disruption.tsx:151` | Go straight to the confirm step for timetable trip K; `replace` marks that leg "not taken" after saving. |
| `/?tab=past` | `PassportPage.tsx:250` | Trips with the Past segment selected. |
| `/stations/:id?type=arrivals` | `BoardPage.tsx:221` | Board, arrivals. |
| `/stations/:id/map?from=&to=&arr=&dep=&a=&b=&xa=&xb=&live=` | `components/Connection.tsx:84-97` | Layover Guide between two tracks. |
| `/trips/:id`, `/journeys/:id`, `/stations/:id` | many | Detail screens. |

Future push notifications / Live Activities / widgets (docs/IOS.md §"Widgets, Live Activities and notifications")
are **not built**; there are no notification handlers in the web code.

**Native app.** The Swift app has the `clack://` scheme. The forms it opens (`trip/<legId>`, `journey/<id>`,
`board/<stationId>?arrivals=1`, `explore?train=&date=&key=`, `tab/<trips|explore|passport>`, `trips`, `explore`,
`passport`, `add?trip=&date=&from=&to=&replace=`, `arrival/<legId>?journey=<id>`) are listed and parsed in
`ClackCore/Logic/DeepLink.swift`. `Router.open` (`App/Route.swift`) is the one way in, for links, alert taps and the
`-url` launch argument.

---

## 2. Screens

Shared conventions used below:
- "Leg" = one train ride you saved (API `Leg`/`LegDetail`, `api.ts:188-308`). "Trip" in the UI = leg.
- All API paths are under `{API_BASE}/api` (`api.ts:27`). Every request carries `X-Clack-User: <deviceId>` when a
  device id exists; SSE and `<img>` URLs carry `?u=<deviceId>` instead (`apiBase.ts:11-15`). GET requests time out
  after 15 s and are treated as "offline" (`api.ts:16, 25-36`).
- Times are formatted in the **station's** time zone with `fmtTime` (§3.1). Default zone `Europe/Stockholm`.
- "FlapTime/SplitFlap": split-flap digits (§3.10). `size='text'` is plain text; `sm/md/lg` are tiles.
- Delay pill = coloured text, not a box (§3.11).

### 2.1 Trips (`/`, `pages/TripsPage.tsx:382-511`)

**Purpose.** Home: the train you're on or the next one, other upcoming trips, followed trains, and past trips by month.

**Data / API.**
- On open: `GET /follows` (`:389-391`), `GET /legs` (`:392-396`). Retry re-calls `GET /legs`.
- Live: shared SSE `GET /live/stream` (event `live`, payload `LiveUpdate {legId, live, events}`); each update replaces
  `live` on the matching leg in the list (`:398`).
- Featured card also fetches `GET /legs/:id` once per leg and caches it for the session (`details` map, `:176,
  186-197`); its route map fetches `/map/status` and tiles (§3.13).
- Each Layover line between trips calls `GET /stations/:id` (+ `GET /stations/:id/map` when `hasMap`) once per
  station per session (`components/Connection.tsx:12-27`).

**Partitioning (computed on each render with `now = Date.now()`).**
- `arrivalOf(leg)` (`:28`): `actualArr` ?? max(`schedArr`, live `arrivalEta` if `isLive(leg.live)`).
- Upcoming = `arrivalOf > now`, sorted by `schedDep` ascending; Past = `arrivalOf ≤ now`, sorted by `schedDep`
  descending (`:400-401`).
- Featured ("hero", `:403-406`): first upcoming leg that `isActive` (landing rules) → state `active`; else the first
  upcoming → `upcoming`; else the most recent past leg that isn't cancelled and arrived < 6 h ago
  (`RECENT_ARRIVAL_MS`, `:179`) → `arrived`.

**Layout top to bottom.**
1. Header: large title `trips.title`; right: magnifier → `/stations`, "+" → `/add`, gear → `/settings` (`:427-438`).
2. Segmented control Upcoming | Past (`:439-445`), keys `trips.upcoming`, `trips.past`. Local state only (initial
   from `?tab=past`).
3. Error banner `trips.loadError` with link `trips.retry` (`:446-453`).
4. Loading: three skeleton rows (shimmer 1.2 s, `styles.css:307-309`) while `legs === null`.
5. Empty (no legs at all, either tab, `:455-471`): dotted-line illustration (SVG path `M10 45 C 80 5, 200 70, 290
   15`), `trips.emptyTitle`, `trips.emptyBody`, buttons "+ `trips.findTrain`" → `/add` and "`trips.exploreTrains`" →
   `/explore`. On the Upcoming tab the Following section still shows under it (`:472`).
6. **Upcoming tab** (`:473-494`):
   - Featured card (`Featured`, `:182-261`) or, when there is no hero, `NothingAhead` (`:264-285`: dotted line with
     two end dots, `trips.whereNext`, `trips.whereNextBody`, same two buttons). If there is a hero but nothing
     upcoming (an arrived hero), `NothingAhead` shows **below** it too (`:476`).
   - Pill list: the remaining upcoming legs (hero excluded) as `LegRow upcoming`; between two consecutive items that
     `meets()` (including hero → first row) a `Layover` line (`:477-491`).
   - Following section (`:288-323`, §2.1.4).
7. **Past tab** (`:495-508`):
   - Review cards first: every past leg with `ride == 'review'` (`ReviewCard`, `:326-357`).
   - `trips.noPast` if no past legs.
   - Month groups: header `fmtMonth(schedDep of first leg, origin tz)` ("October 2026"). Legs that share a
     `journeyId` are gathered into one `JourneyCard` in travel order (`:407-423`, `components/Journey.tsx:35-59`);
     single legs are `LegRow`.

#### 2.1.1 Featured card (`Featured`, `:182-261`)
One tappable card → `/trips/:id` (accessibility label `trips.viewJourney`). CSS: radius 16, hairline, gradient
surface (`styles.css:803-812`). Re-renders every 1 s when active, else every 30 s (`:185`).
- **Map strip** (140 pt tall; 160 at ≥ 600 px): non-interactive `RouteMap` with no controls, route = decoded
  `detail.geometry` or ridden stop coordinates; stops = only board and alight as `end` dots (`:199-205, 213-218`).
  Train marker and the travelled/ahead split only when `grounded`: state active, live is fresh (§3.3), has lat/lon and
  a `positionSource` (`:208-209`); `progress = live.progress`. Empty map placeholder when < 2 points.
  Top-left glass tag (`:219-221`): `trips.routePreview` (upcoming) · `trips.routeSummary` (arrived) ·
  `live.estimatedPosition`/`live.livePosition` (grounded) · `trips.noPositionShort` (active, no fresh position).
- **Body**:
  - Row: OperatorBadge 28, "Operator Number" (or `trips.train`), chip `trips.planned` (upcoming) /
    `trips.arrived` (arrived) / `LiveChip` (active) (`:224-230`).
  - Route title "Origin → Destination".
  - Times: `Times size="lg" intro` (flip tiles, all tiles flip in on first show): expected dep – expected arr, a
    struck timetable time when it differs by ≥ 1 min, and `+N` superscript for day offset (`:54-68`, `expected()`
    `:44-51`: dep = actualDep ?? schedDep+depDelay; arr = actualArr ?? live.arrivalEta ?? schedArr+arrDelay).
  - Active: DelayPill(`live.arrivalDelayMin`); then either `HeroConnection` (if the next leg of the same journey
    starts where this one ends, `nextInJourney` `:360-366`): "Change at X · Track a → b · n min walk" + connection
    chip (`:369-380`) — or a compact `LiveModule` (§2.3.2).
  - Arrived: caption `trips.arrivedAt` (actual) or `trips.scheduledTimes`, plus a "Stamp `trips.inPassport`" hint.
  - Upcoming: countdown pill (`countdown()` §3.1.9), chip `trips.platform` if `depPlatform`, DelayPill(depDelay) if
    known.

#### 2.1.2 LegRow (`:74-108`) — also used in Past, JourneyCard, JourneyPage
Link → `/trips/:id`. A "pill" row with an operator-colour gradient (`--op`), dimmed to 55 % opacity when `ride ==
'not_taken'`. Re-renders every 60 s.
- Left: OperatorBadge 32.
- Main: (upcoming only) countdown line in accent; "Origin → Destination"; meta "`fmtDay(schedDep)` · dep–arr
  (text Times) · `fmtDuration(schedArr − schedDep)`"; meta "Operator Number · `trips.platform` (upcoming only)".
- Side: chip `record.needsCheck` (ride review), chip `record.notTaken` (not taken). Upcoming: DelayPill(depDelay) if
  not null. Past: DelayPill(arrDelay; shown as unknown "—" when `dataQuality=='scheduled_only' && status=='planned'`)
  and distance caption (`trips.approxDistance` "≈" variant when `isEstimatedGeometry`).

#### 2.1.3 Layover line (`Layover`, `:115-165`) and `meets()` (`:168-173`)
`meets(a,b)`: a.destination == b.origin and `0 − 2 h < b.schedDep − (a.actualArr ?? a.schedArr) < 12 h`.
Shows dashed vertical line, clock icon, `fmtDuration(min)` + `trips.layoverAt` (struck planned duration and accent
current one when they differ) or `trips.layoverMissed` when negative (red, class `at-risk`); "arr → dep" FlapTime text
with struck timetable times; `connection.tracks` "Track a → b"; and when the station has a map, "Map
`trips.layoverMap` ›" and the whole row links to the Layover Guide (`stationMapHref`). Times from
`connectionTimes()` (§3.6). Hidden if either time unknown.

#### 2.1.4 Following (`:288-323`)
Header `trips.following`. One pill per follow (`GET /follows` → `Follow[]`), link → `/explore?train=N&date=D`.
Shows OperatorBadge 30, label (or `liveMap.train` "Train N"), "Operator N", and either `live.nextStop` "Next stop:
name hh:mm" (time in Europe/Stockholm) or `trips.notRunning`; side: chip "Eye `trips.followingChip`" and DelayPill
when running. Footer caption `trips.followingNote`. Follows never count as trips.

#### 2.1.5 ReviewCard (`:326-357`)
"Did you take this train?" card: caption `record.question`, link title "Operator Number · A → B", caption
"`fmtDay` · `record.why.<rideReason ?? no_reports>`", buttons Yes/No (`record.yes`/`record.no`) →
`POST /legs/:id/ride {answer}`; on success the row's `ride`/`rideReason` update in place; buttons disabled while busy.

**Interactions.** Tap rows/cards → detail; segmented switch; retry; Layover → station map; Following → Explore.
No swipe, long-press or pull-to-refresh is implemented **[doc differs: DESIGN §4 describes swipe-to-delete,
long-press menu and pull-to-refresh; none exist in code]**.

**Offline.** `GET /legs` and `GET /legs/:id` fall back to the stored copy (§3.4); the banner shows.

**i18n prefixes.** `trips.*`, `nav.*`, `record.*`, `connection.*`, `live.*`, `liveMap.train`, `status.cancelled`,
`delay.*`.

### 2.2 Journey (`/journeys/:id`, `pages/JourneyPage.tsx:1-97`)

**Purpose.** A multi-leg journey door to door.
**API.** On open `GET /journeys/:id` (`:22-24`) → `{id, legs: (Leg & {geometry})[]}`. Live: on a `live` SSE update for
any of its legs, reload `GET /journeys/:id` at most every 20 s (`:26-31`).
**Layout.** Back link "← `nav.trips`" → `/`; title "first.origin → last.destination"; `fmtLongDate(first dep)`;
three tiles: `journey.doorToDoor` = `fmtDuration(last.(actualArr??schedArr) − first.(actualDep??schedDep))`,
`passport.trains` = number of legs, `detail.distance` = sum of `distanceM` (`:49-77`); a card with a `MultiRouteMap`
(each leg in its operator colour, no station dots, rail network per setting, `:78-86`); then the legs in order, each a
`LegRow`, separated by a `ConnectionCard` when the previous leg ends where this starts, else a `TransferChip`
(`:87-94`).
**States.** Skeleton card while loading; any load error → "← Trips" + `journey.notFound` (`:33-41`).
**i18n.** `journey.*`, `passport.trains`, `detail.distance`, `connection.*`.

`TransferChip` (`components/Journey.tsx:9-32`): planned = `next.schedDep − prev.schedArr` min; actual =
`(next.actualDep ?? next.schedDep) − prev.actualArr`; missed when prev arrived after next left; tight when not
missed and (actual ?? planned) < 10. Text `journey.transfer` (+ `journey.actually` when actual ≠ planned, +
`journey.missed`/`journey.tight`).

`ConnectionCard` (`components/Connection.tsx:99-125`): "Change at X" + ConnectionChip; caption "Track a → b · n min
walk · n min layover"; `connection.timetableOnly` when times aren't live; red banner `connection.brokenBanner` when
broken; button "Map `connection.openMap`" to the Layover Guide when the station has a map.

`JourneyCard` (Past list; `components/Journey.tsx:35-59`): header link → `/journeys/:journeyId` with caption
`journey.label` (plural on legs.length) and "first.origin → last.destination"; legs as LegRows with TransferChips;
background = one radial operator-colour glow per leg at 18 % stacked over `--surface`.

### 2.3 Trip detail (`/trips/:id`, `pages/TripDetailPage.tsx:109-443`)

**Purpose.** Everything about one leg, organised by stage: before departure, on the train, after arrival.

**API.**
- On open and after every live tick for this leg: `GET /legs/:id` (`:132-144`; offline fallback to stored copy).
  404 → "not found" state; other failure with nothing stored → `offline.tripNotKept`.
- Live SSE `/live/stream`: for `u.legId == id` set `live = u.live` immediately, refetch the leg, and if any event in
  `u.events` other than `departed` exists, show it as a toast for 6 s (`:147-158`; text from `eventText`, §2.3.3).
- Refresh button: `POST /legs/:id/refresh` → replaces the leg (`:215-222`).
- Ride answers: `POST /legs/:id/ride {answer: yes|no|undo}` (`:223`).
- Delete: confirm `detail.deleteConfirm`, `DELETE /legs/:id`, navigate to `/` (`:224-228`).
- Train type: `PATCH /legs/:id {trainType}` (TrainCard). `GET /train-types` (cached).
- Child components: `GET /journeys/:journeyId` (Disruption, Risk, JourneyConnections — three separate calls),
  `GET /alternatives?...` (Disruption), `GET /legs/:id/risk` every 5 min (Risk, before departure only),
  `GET /legs/:id/progress` (welcome card), `GET /amenities`, `GET /operators`.
- Clock ticks every 1 s (`:123`).

**Derived state (`:176-213`).**
- `status = statusKey(leg, live, now)` (§3.3).
- `tracking = isLive(live)` (status boarding/en_route/at_stop).
- `shown` = `localLive(leg, live, now)` when tracking and `now − live.updatedAt > 60 s` (`LOCAL_AFTER_MS`), else
  `live` (§3.5 dead reckoning) (`:206`).
- `stage`: `during` if shown.status en_route/at_stop; `after` if shown.status arrived, or `actualArr`, or `now >
  arrivedBy` (arrivedBy = actualArr ?? live.arrivalEta (if tracking) ?? schedArr); else `before` (`:207-209`).
- Train marker when tracking and shown has lat/lon; estimated = `positionSource != 'gps' || localEstimate`.
- `beyond` = countries of ridden stops with `reportSource === null`; `borderAt` = name of the stop in
  `borderEvidence.alight ?? board` (`:200-204`).

**Layout top to bottom.**
1. **Map** (`:232-258`), height min(55 % screen, 520 pt), page sheet overlaps it by 24 pt with top radius 24
   (`styles.css:194-197`). `RouteMap` interactive with controls, `animate` (draw-on), rail network per setting,
   route = decoded geometry or ridden stops; stops = ridden stops (board/alight `end`, through `mid`); train marker;
   `progress = live.progress` while tracking. Floating buttons: back (top-left) → `/`; "show all trains" Radar
   (→ `/explore?train=<number>` while tracking, else `/explore`); map's own layers/follow/recenter (§3.13).
   Centered glass chip `detail.estimatedRoute` when `isEstimatedGeometry`.
2. **Head** (`:260-265`): OperatorBadge 32, "Operator Number", category chip `products.<category>`, then `LiveChip`
   (tracking) or status text `status.<planned|boarding|live|completed|cancelled>` coloured (`styles.css:400-403`).
3. Toast (fixed top, slides in 250 ms).
4. Title "Origin → Destination"; `fmtLongDate(schedDep, origin tz)`.
5. **Welcome card** (`:277-283`) when stage after, not cancelled, and `now − (actualArr ?? schedArr) < 60 min`:
   `progress.welcome` (station), `progress.welcomeBody` (time, train), and `TripProgress quietIfNothing` (§2.12).
6. **DisruptionCard** (§2.3.4). 7. **RiskCard** only in stage before (§2.3.5).
8. **Stage card** (`:290-340`):
   - before: countdown pill; chip `trips.platform` or caption `detail.platformLater`; DelayPill(depDelay, or while
     tracking `delayMinutes(schedDep, board stop estimatedDep)`) unless cancelled; red banner
     `detail.canceledBanner` if cancelled; caption `live.updated` (ago from `live.updatedAt`) or
     `detail.timetableOnly`.
   - during: full `LiveModule` (§2.3.2) with `shown`.
   - after: strong line = `status.cancelled` / `trips.arrivedAt` (actual) / `detail.scheduledArrival`; caption
     `detail.actualTimes` / `detail.scheduledOnlyNote`; if ride not auto/confirmed a line
     `record.state.<ride>` with `record.why.<reason>` (review in orange); buttons: review → Yes/No; auto/confirmed →
     link "Stamp `detail.seePassport`" → `/passport` and link `record.correctNo` (answer no); not_taken → link
     `record.undo` (answer undo).
9. **Times row** (`:342-362`): two `TimeBlock`s side by side (`:28-67`): label (`detail.departure`/`detail.arrival`)
   with DelayPill; struck timetable time (placeholder line kept for alignment when unchanged); big split-flap time
   (34 pt tiles, intro flip) of actual ?? sched, struck-through when cancelled; `+N` days on arrival; platform chip or
   "–" placeholder. Departure actual = actualDep ?? (tracking ? board estimatedDep); arrival actual = actualArr ??
   (tracking ? live.arrivalEta). Delay = leg delay ?? live-derived.
10. **Tiles** (`:365-384`): Distance (`≈ ` prefix when estimated geometry), Duration (`(arr−dep)` using actual ??
    sched), Delay tile (button) with DelayPill(arrDelay ?? live.arrivalDelayMin); tapping toggles an explanation
    caption: `delay.explainUnknown` / `delay.explainLate` (count) / `delay.explainEarly` / `delay.explainOnTime`.
11. `JourneyConnections` (`components/Connection.tsx:128-146`): ConnectionCards for the change into and out of this
    leg when its neighbours in the journey meet at the same station.
12. **Stops** card (`:388-400`): timeline of board…alight by default; "Show full route"/"Hide full route" link
    (`detail.showFullRoute`/`detail.hideFullRoute`) when there are `before`/`after` stops. `StopRow` (`:69-107`):
    dot coloured by operator, dim for unridden; station name links to `/stations/:stationId` (struck if cancelled);
    caption `detail.gotOn`/`detail.gotOff`; `detail.noLiveData` for ridden stops with `reportSource === null`;
    deviations except "Spårändrat" joined by " · "; time: board uses dep, others arr (fallback dep); actual = actual ??
    estimated (estimate shown in italics, class `estimate`); colour by `delayBand(delayMinutes(sched, actual))`;
    struck timetable time when it differs; platform with a Repeat icon when deviations include "Spårändrat".
13. **TrainCard** (§2.3.6). 14. **On board** card `onboard.title` + `Onboard` (§2.3.7).
15. **ActivityLog** (`components/Live.tsx:119-140`) when tracking or there are events: `activity.title`, list of
    events with `fmtTime(ts, origin tz)` and `eventText`; `activity.empty`.
16. **Details** card (`:411-428`): data-quality chip `detail.quality.<q>` + `detail.qualityNote.<q>` (hidden when
    `full`, or `partial` with `beyond` countries); `detail.beyondLiveData` (with border station) or
    `detail.beyondLiveDataNoReport`; `detail.estimatedDistance`; `detail.source`.
17. **Actions**: Refresh (hidden when `status == 'snapshotted'`; disabled while busy), Delete (danger).

**States.** Loading skeleton card; `detail.notFound` with back link; `offline.tripNotKept`.

#### 2.3.1 LiveChip (`components/Live.tsx:12-24`)
`localEstimate` → grey `offline.chip`; fresh (§3.3) → green dot (blinks 1.8 s) + `live.chip`; else grey
`live.stale` with `agoKey(dataAt)`.

#### 2.3.2 LiveModule (`components/Live.tsx:33-93`)
- Progress bar 0–1 from `live.progress` with a dot in operator colour (hollow when estimated or local estimate);
  dot moves with a 1 s linear transition (`styles.css:415`); accessibility `live.progressLabel`.
- "Where" line: `live.boardingAt` (status boarding, origin name) / `live.atStop` (prevStop name) /
  `live.between` (prev, next) + Speedometer (GPS only, not local estimate, speed fix ≤ 60 s old; Gauge icon + "N km/h",
  `:143-151`).
- `live.nextStopName` + FlapTime(eta, next stop tz), hidden while boarding.
- Not compact: `live.arrivesLabel` + FlapTime(arrivalEta, dest tz) + DelayPill(arrivalDelayMin).
- Caption: `live.updated` (`agoKey(dataAt)`) · source = `offline.estimated` / `live.livePosition` /
  `live.estimatedPosition` / `live.noPosition`.

#### 2.3.3 Event texts (`eventText`, `components/Live.tsx:95-117`)
departed → `activity.departed` (origin); arrived → `activity.arrivedLate` (delay>0) or `activity.arrived`; delayed →
`activity.delayedOnTime` (delay ≤ 0) or `activity.delayed` (`fmtDelay`, destination); platform_changed →
`activity.platformDeparture`/`activity.platformArrival` (from, to; by `payload.which`); cancelled →
`activity.cancelled`; short_turned → `activity.shortTurned` (station names from `payload.stationIds`).

#### 2.3.4 DisruptionCard (`components/Disruption.tsx:22-209`)
- Loads the journey (`GET /journeys/:id`) to find the next leg that starts where this one ends (`:22-31`). With a next
  leg, runs `useConnection` and passes the connection status **only** when there is a delay (arr delay > 0, actual
  arrival after scheduled, next depDelay < 0 **[unclear: "< 0" looks inverted; kept for parity]**, or next
  cancelled) or the status is `broken` (`:33-39`).
- `assessDisruption` (shared, §3.8) over: canceled, board/alight stop cancelled, deviations of ridden stops, delays,
  schedDep, `arrived` (= actualArr or (status ≠ planned and schedArr < now)), connection. No urgency → nothing shown.
- `AlertCard` (`components/Alert.tsx:20-46`): tone `info` when arrived, `severe` when a severe kind (canceled,
  skips_board, skips_alight, connection_missed) or replacement, else `warn`; icon Info / AlertTriangle; title
  `disruption.title.<first kind>` (or `disruption.title.delayed_past` after arrival); dismiss key
  `disruption:<legId>:<kinds joined>` (§5).
- Lines per kind: `disruption.canceled|skipsBoard|skipsAlight|replacement|delayed|arrivedLate|connectionMissed|
  connectionAtRisk`.
- "Why": `disruption.why` with `delayReasons(deviations, lang)` joined by `disruption.and` (§3.8).
- Alternatives (only when not arrived and severe, `:64-76`): `GET /alternatives?from&to&after&exclude`.
  - connection missed (not cancelled): from = next leg's origin, to = journey's final destination, after =
    (actualArr ?? schedArr + arrDelay) + 5 min, exclude = next.timetableTripKey;
  - else: from = this origin, to = final destination, after = max(now, schedDep − 30 min), exclude = this
    timetableTripKey.
  - Toggle button: `disruption.looking` (loading) / `disruption.noAlternatives` (0, disabled) /
    `disruption.viewSuggested` / `disruption.hideSuggested`; `disruption.noneFound` caption when 0.
  - Expanded list: optional `disruption.journeyContinues`; direct rows: OperatorBadge 24, "dep → arr", caption
    "Operator Number · <other day: fmtDay>", buttons `disruption.live` → `/explore?train&date&key` and
    `disruption.useInstead` → `/add?trip&date&from&to&replace=<this leg>`; connection rows with `add.changeAt` and a
    Live button; footer `disruption.altsNote`.
- Rights (`passengerRights`, §3.8): `disruption.rightsTitle`; text per regime/claim (`rightsOperator`, `rightsSeShort`,
  `rightsSeShortClaim`, `rightsEu`, `rightsEu_<claim>`); links: EU (en/sv URL) or Konsumentverket, and
  `disruption.linkOperator` to the operator's `ticketUrl`. `disruption.passportNote` when cancelled.

#### 2.3.5 RiskCard (`components/Risk.tsx:11-60`)
`GET /legs/:id/risk` on open and every 5 min (`:16-25`); journey fetched to find the next leg. Hidden when no
warnings. AlertCard tone `watch`, icon Activity, title `risk.titleNow` (any non-pattern warning) or
`risk.titlePattern`; dismiss key `risk:<legId>:<kinds>`. One line per warning with a chip `risk.kind.<kind>` and text
`risk.routeNow|ahead|stationNow|pattern`; plus `risk.change` when a "now" warning exists and the planned change to the
next leg is < 10 min. Footer `risk.honest` with checkedAt time.

#### 2.3.6 TrainCard (`components/TrainCard.tsx:11-91`)
`train.title`. With a known type: `TrainPicture` (§3.12) height 46; name + chip `train.yourChoice` (source user) /
`train.planned` (composition) / `train.typical`; `type.about`; note `train.plannedNote`/`train.typicalNote` unless
user; facts `train.topSpeed` "N km/h", `train.since`, `train.builder` when present. Without: `train.unknown`. Link
`train.change`/`train.cancel` toggles a picker listing every type (`TrainArt` silhouette 18 + name; active one
marked); choosing calls `PATCH /legs/:id {trainType}`; `train.resetTypical` (sends null) when the current source is
user.

#### 2.3.7 Onboard (`components/Onboard.tsx:32-106`)
`typicalAmenities(table, operatorId, trainType)` (§3.9) minus catering/sleeper when today's facts cover them; claims
with `value === false` hidden. Today's facts (Trafikverket) first as chips: catering (`onboard.catering.<kind>`, with
`onboard.cateringInCar` car letter), sleeper, notices `onboard.notices.<n>` with a warning icon. Then caption
`onboard.typically` and a list (icon per key, label `onboard.keys.<k>`, string values appended "Key: Bistro",
`partial` → `onboard.partial`; `note` appended unless compact). Footer (not compact): `onboard.source` + host links of
distinct sources + `onboard.checked` with `fmtDay(verified)`. Nothing at all → `onboard.unknown` (compact: render
nothing).

### 2.4 Add a train (`/add`, `pages/AddTripPage.tsx`)

**Purpose.** Find a timetable train for a date and save the part you rode; or enter one by hand.

A full-screen sheet (`role=dialog`) with header `add.title` and an X → `/` (`:528-535`). Body is a state machine
(`:537-648`): `saved` → Done; `manual` → ManualTrip; `pickedConn` → ConfirmConnection; `picked` → Confirm; else Search.

**Search step** (`:546-647`).
1. Date row (`DateRow`, `:33-81`): chips `add.today`, `add.tomorrow`, `add.pickDate` (opens the native date picker;
   max today + 365 days; no minimum), label `fmtDay(date at 12:00 UTC, 'UTC')` + hint `add.pastTrip` for past dates.
   "Today" = local date in Europe/Stockholm (`todayIso`).
2. Search field (autofocus, placeholder `add.placeholder`, no autocorrect).
3. Empty query: caption `add.examples` + chips `SJ 523`, `Stockholm → Göteborg`, `Snälltåget Stockholm Malmö` (fill
   the query), then `add.popular` station list (`GET /stations/popular`, on open).
4. Query: debounced 150 ms, `GET /search?q=&date=` (abortable; re-run on date change) (`:468-494`). Response
   `SearchResponse` (`api.ts:103-112`).
5. Interpretation chips (`:571-595`): operator text, `add.trainNumber`, from, "→", to — each removable; removing
   rebuilds the query as "`op number from → to`" (`rebuild`, `:509-514`).
6. Error banner `add.searchError`.
7. Station suggestions `add.stations` (hidden when the top suggestion is the already-recognised `to` and there are
   results). Picking a station (`pickStation`, `:504-508`): when typing the destination, replace everything from the
   separator (regex `SEPARATOR` `:21`: `→ -> => > – — " - " to till`) with " → Name"; else set
   "`[operator text ]Name → `". Focus stays in the field.
8. Archive banner when `outsideTimetable`: `add.historyLoading|historyFailed|historyNorway|historyUnavailable`. While
   `history` is `loading` re-search every 3 s; `failed` every 15 s (`:497-501`).
9. Results: filter chips `add.filterAll|Long|Regional|Commuter` (`inFilter` `:22-24`: long = high_speed,
   intercity, night; regional = regional, heritage; commuter = commuter), then `ResultCard`s (`:83-121`): dep time –
   duration – arr time (+N), station names, TrainArt silhouette + type name when known, OperatorBadge 26 + operator
   name (or routeName), train number, product chip, `add.stopsBetween` (plural) or `add.direct`,
   `add.alsoKnownAs`.
10. No results: `add.noTrain` (number searched) / `add.noDirectChange` (connections exist) / `add.noDirect`. Then
    `add.withChange` connection cards (`:124-156`: total time, both legs' operator, number, "hh:mm A → hh:mm B",
    `add.changeAt`).
11. Link `manual.cta` once a search has completed (`:641-645`).
12. Loading: two skeleton cards while loading and no response yet.

**Confirm step** (`Confirm`, `:227-376`). On open `GET /timetable/trips/:key?date=` and
`GET /timetable/trips/:key/geometry?date=` (`:240-244`).
- Back link (`add.back`, or `common.back` + history back when opened with `?trip=`).
- Title `add.confirmTitle`; mini `RouteMap` (180 pt, non-interactive): ridden segments solid, the rest of the train's
  route as faint dashed "context", stops = ridden stops (ends big, middle small) (`:263-272, 296-306`).
- Head: OperatorBadge 30, "Operator Number", product chip.
- Summary "From → To · ≈ distance · duration" (`approx` when geometry missing or any segment estimated; distance =
  sum of segment `lengthM` inside the ridden range, else haversine between stops `:26-31, 265`).
- From | To segmented selector (`To` active first). Caption `add.tapFrom`/`add.tapTo`.
- Stop picker list: each stop with dot, name, `add.from`/`add.to` chip on the ends, `add.noBoarding`/`add.noAlighting`
  restrictions, time (dep, or arr for the "to" stop). Tap rules (`tap`, `:246-258`): picking from → must be < toSeq
  and not `noPickup`, then switches to picking to; picking to → must be > fromSeq and not `noDropoff`. Non-selectable
  rows disabled.
- Duplicate banner (409): `add.duplicate` with `add.addAnyway` (force) / `add.cancel`. Error banner `add.saveError`.
- `BuyTicket` when departure is in the future (§3.7).
- Sticky primary button `add.addToClack` → `POST /legs {tripKey, serviceDate, fromSeq, toSeq, force}`.

**ConfirmConnection** (`:159-226`): the connection card, `add.connectionNote`, a BuyTicket per leg, primary
`add.addBoth` saving both legs in order; 409s are collected: banner `add.duplicate` (both) or `add.duplicateOne`
with `add.keepAsIs` (go to Done with the one saved) and `add.addAnyway` (force only the duplicates).

**Manual** (`components/ManualTrip.tsx:57-130`): back link; `manual.title`, `manual.intro`; From/To station fields
(`GET /stations/search?q=&limit=12`, 150 ms debounce, top 5; a picked station shows as a removable chip,
`manual.change` label); `manual.dep`/`manual.arr` time inputs (local time at each station); operator select
(`GET /operators`, sorted by name; first option `manual.unknown`); `manual.number` (numeric, max 10); kind chips
`manual.kinds.intercity|regional|commuter|night|heritage` (default intercity); `manual.timesNote`; error banner (server
message); `manual.save` enabled when both stations set, different, and both times → `POST /legs/manual {fromStationId,
toStationId, date, dep, arr, operatorId, trainNumber, category}`. Prefilled from the interpreted from/to.

**Prefill from `?trip=K&date=D[&from][&to]`** (`:433-461`): `GET /timetable/trips/K?date=D`; builds a `TripResult`
(from/to by seq, defaults first/last stop) and jumps to Confirm. Failure → search error banner.
`replace=<legId>`: after any save, `POST /legs/<replace>/ride {answer:'no'}` (fire and forget) (`:428-432`).

**Done** (`:378-404`): animated check (circle + tick stroke-draw 350 ms after 100 ms, green, `styles.css:394-395`),
`add.added`, route, "Operator Number", `TripProgress` when the trip already arrived (§2.12), buttons `add.viewTrip`
→ `/trips/:id` and `add.addAnother` (reset to search, refocus).

**i18n.** `add.*`, `manual.*`, `products.*`, `tickets.*`, `progress.*`, `common.back`, `common.close`.

### 2.5 Explore / live map (`/explore`, `pages/LiveMapPage.tsx`)

**Purpose.** A calm radar of every train running in Sweden/Norway; tap a train or station for details; follow trains;
plan a trip from one.

The whole map component is re-created when the theme changes (`:1260-1263`).

**API.**
- `GET /map/status` (once per app session, shared) and the basemap tiles `pmtiles://{origin}/api/map/basemap.pmtiles`
  (HTTP range requests) when `status.basemap` is non-null; `GET /map/rail-network.geojson` (lines + station points
  with `kind:'station', id, name, dpd`) (`:320`).
- SSE `GET /live/trains/stream?bbox=W,S,E,N` (3 decimals), opened 400 ms after the map settles and re-opened on every
  `moveend` (debounced) (`:478-516`). Events:
  - `snapshot` `{trains: LiveTrain[], total, upstreamAt, mode?}` → replace the set.
  - `delta` `{changed: LiveTrain[], moved?: [id, lat, lon, bearing, speedKmh, at, estimated][], removed: string[],
    total, upstreamAt}` → merge (moved = position-only update of a known train) (`:497-509`).
  - `onerror` → `streamDown = true`; `onopen` → false.
- `GET /follows` on open; `PUT /follows {trainNumber, serviceDate, operatorId, label}` / `DELETE
  /follows/:number/:date` then re-`GET /follows` (`:550-560`).
- Select a train: `GET /live/trains/:id` → `{train, trip, legId}` (`:594-628`); then
  `GET /timetable/trips/:key/geometry?date=` for its route; while its sheet is open
  `GET /live/trains/:id/stops` now and every 30 s (`:680-692`).
- Train without a position: `GET /trains/:number/:date[?key=]` → `TrainView`; refreshed every 30 s while its sheet is
  open (`:630-677`); plus its geometry.
- Station sheet: `GET /stations/:id`, then (if `hasBoard`) `GET /stations/:id/board?type=departures` (`:1272-1284`).
- Search: `GET /stations/search?q=&limit=12` (≥ 2 chars, not all digits, 200 ms debounce, top 5) (`:526-535`).
- Clock ticks every 5 s (`:204`).

**`LiveTrain` fields** (`:27-47`): id, number, date, lat, lon, bearing, speedKmh, at (fix time), estimated, operatorId,
productName, product, trainType, origin, destination, next, nextEta, delayMin, mine.

**Map setup** (`:303-475`). Initial bounds lon 4.5–31.7, lat 55.3–70.2 (Bergen–the Finnish east border, Malmö–Nordkapp; widened for Finland, centre 63, 17 at zoom 3.8 until the fit applies). No
attribution control (text attribution at the bottom: "© OpenStreetMap contributors · Protomaps · Trafikverket · Entur
(NLOD)", `:856`). Layers, bottom to top:
1. Basemap (§3.13), rail network lines (and `rail-stations` dots from z9).
2. `live-stations` symbols from z5: station image = 20×20 px rounded square (14×14, radius 3, stroke 3) filled
   `bg`, stroked `text` colour, pixelRatio 2 (`stationImage`, `:148-160`); size interpolate z5 0.55, z9 0.75, z13 1.
   Shown only when `dpd ≥ step(zoom): 60 below 6.5, 25 from 6.5, 8 from 8, 0 from 9.5` (`:323-327`).
3. `live-station-labels` from z6: name, Noto Sans Regular 10.5, offset 0.8 em below, label colour with bg halo 1.2;
   `dpd ≥ step(zoom): 90, 40 from 7.5, 15 from 9, 0 from 11` (`:337-346`). Moved to the top of the stack (`:440`).
4. Train source clustered: `clusterMaxZoom 6`, `clusterRadius 36` (`:347`).
   - `clusters`: 76×76 px disc radius 27, light: white 96 % with 8 % black edge / dark: rgba(44,44,46,.94) with 55 %
     white edge, shadow 8 px blur, pixelRatio 2 (`clusterImage`, `:129-145`); icon size step on point_count 0.85,
     ≥10 1.05, ≥50 1.3; count text Noto Sans Medium 12/13/15. Tap → zoom +2 at the tap.
   - `train-followed`: ring radius 10, stroke text colour 2 (followed trains).
   - `train-mine`: radius 13, fill rgba(248,214,74,.28), stroke #f8d64a 2 (your own trips).
   - `train-dot` symbol: per operator colour image. With bearing: "puck" with a heading cone; without: plain disc
     (`trainMarkerImage`, `:98-126`): 96×96 px canvas at pixelRatio 2; cone = sector ±0.55 rad around up, radius 46,
     radial gradient colour 50 %→0 %; white disc r 15.5 with shadow (blur 6, y 1.5, 35 % black); colour disc r 12.
     Rotated to bearing, map-aligned. Size interpolate z5 0.6 (mine 0.72), z9 0.78 (0.9), z13 0.95 (1.1). Own trains
     sort on top.
   - `train-selected` under the dot: circle r 11, train colour at 35 %, white stroke 2, filter = selected id.
   - `train-label` from z9: train number; from z11 "number · destination"; Noto Sans Medium 11, 1.3 em below.
5. Selected route layers added under `train-mine` (`routeLayers`, §3.13).

**Marker animation** (`:222-286`): on each update, trains that moved and are on screen at zoom ≥ 7 glide from the old
to the new position over 1500 ms with ease-out cubic (`1 − (1−k)³`); others jump. Rendering is batched per animation
frame.

**Filtering** (`visible`, `:211-219`): only mine; only followed (key `number|date`); only delayed (`delayMin > 5`);
products (any of high_speed, intercity, regional, commuter, night); operators (set). Filter count badge on the button
= products + operators + each toggle.

**Taps.** Train dot: of the dots within ±10 px, choose the one nearest the finger (`:424-438`). Station square: ignored
if a train/cluster is under the finger, else open the station sheet (`:447-456`); station label always opens it.

**Layout.**
1. Full-bleed map (ends above the tab bar).
2. Top bar: search field (`liveMap.searchPlaceholder`) and Filters button (sliders icon, count badge) (`:720-739`).
3. Search results card (while focused and non-empty): train hits = running trains whose number starts with the
   query's digits (max 6; OperatorBadge 22, "Product/Operator Number", "origin → destination"); station hits (square
   glyph, name, `liveMap.station`); none → `liveMap.noTrainMatch` (all digits) / `liveMap.noMatch`; Close link.
   Picking a station: close search, deselect, `GET /stations/:id`, ease to it at zoom ≥ 10, open station sheet.
4. Filters card: product chips (`products.*`), `liveMap.onlyDelayed`, `liveMap.onlyMine`, `liveMap.onlyFollowed`,
   caption `liveMap.operators` + a checkbox row per operator currently on the map (sorted ids; OperatorBadge 20 +
   name), `liveMap.clearFilters` (when any), `common.done`.
5. Status chip + legend (Info) button, bottom-left over the map (CSS `.live-counter` left 12, bottom 28; legend card
   opens above it at bottom 70) (`:819-838`). Chip text, first match wins:
   - not loaded and stream not down → `liveMap.loading`;
   - (stream down and no message for > 20 s) or `mode == 'stopped'` → grey `liveMap.unavailable`;
   - `upstreamAt` older than 60 s → grey `liveMap.delayedData` (ago);
   - none shown and zoom ≥ 6.5 → `liveMap.noneMatch` (filters on) / `liveMap.noneHere`;
   - else green dot + `liveMap.simulated` (mode simulate) / `liveMap.trainsRunning` (count = server `total`).
6. Legend card: dot `liveMap.legendTrain`, square `liveMap.legendStation`, solid line `liveMap.legendDone`, dashed
   line `liveMap.legendAhead`, `liveMap.legendNote`.
7. Sheets (only one at a time; a selected train hides the others).

**Focus via `?train=N[&date=D][&key=K]`** (`:562-584`): wait until the map is ready; if a running train has that number
(and date) select it; otherwise once the first snapshot has arrived or 4 s have passed, `openScheduled(N, D ?? today
Stockholm, K)`. Done once.

**Selecting a train** (`select`, `:594-628`): fetch detail; open its sheet expanded; stops "loading" (or "none" if no
trip); highlight; ease to it at zoom ≥ 8 with a vertical offset of −min(320, 34 % of map height) so it sits above the
sheet; draw its timetable route: travelled part solid (glow/body/core) and the remainder dashed, split at the point on
the line nearest the train (`nearestOnLine`, `:76-90`; search starts 3 segments before the last cut so the split never
goes backwards, `drawSplit` `:289-300`), updated on every position update.

**Opening a scheduled train** (`openScheduled`, `:630-665`): `GET /trains/N/D`; failure → NotRunningSheet; if it now
has a live id on the map, select it instead; else show ScheduledSheet, draw the whole route as "ahead" (dashed) and
fit it with padding top 90, bottom min(420, 50 % height), sides 40, 600 ms.

**TrainSheet** (`:996-1110`), three detents:
- Header: OperatorBadge 32, title button "Product/Operator Number" (or `liveMap.train`) with chevron (tap = fold /
  unfold), X close. Grabber on top: drag between sizes; tap folds; keyboard ↑/↓/Enter.
- Detent heights (`targets`, `:1011-1018`): full = container − 24; mid = min(content height, 74 % of container, 680,
  full); small = min(header + footer + 120, mid).
- Drag (`:1030-1065`): starts after 4 pt; dragging up > 24 pt from small expands; height clamped [96, full]; on release
  snap to nearest; velocity (EMA 0.7/0.3, px/ms) < −0.5 goes at least one size up from where the drag began, > 0.5 one
  size down. Settle animation 220–230 ms `cubic-bezier(.2,.8,.2,1)` (`styles.css:1057`).
- Body scrolls; header tightens when scrolled > 6 pt. Footer actions pinned.
- **Intro (live train, `:913-939`)**: (not collapsed) TrainPicture (detailed side view when available; `liveMap.typeUnknown`
  caption otherwise type name); "origin → destination" (… for unknown); `liveMap.detailsLoading` when nothing known;
  `live.nextStopName` + FlapTime(nextEta, Stockholm); chips: DelayPill(delayMin), position label
  (`liveMap.posEstimated` / `liveMap.posOld` (min) when fix > 2 min old / `liveMap.posGps` in green), Speedometer (not
  estimated); caption `live.updated` (ago from `at`).
- **Actions**: Follow toggle (`liveMap.follow` with Eye / `liveMap.following` with Check) and either
  `liveMap.inYourTrips` → `/trips/:legId` (when the train is one of your legs) or `liveMap.plan` →
  `/add?trip=&date=` (disabled with no timetable trip).
- **Body**: StopList (`:1113-1151`): `liveMap.stops`; per stop: time (last stop arr, others dep ?? arr); real = actual
  ?? estimated; late/early colour and struck planned when they differ by a whole minute; mark passed (dimmed, filled
  dot), next (first not passed and not cancelled, bold), cancelled (`liveMap.canceledStop`); `liveMap.track`. States
  `liveMap.stopsLoading` / `liveMap.stopsNone`. Then compact `Onboard` (typical only); BuyTicket from the next
  catchable stop to the last stop (`:964-970`, not offered as "add to trips" when already in your trips);
  `board.notInTimetable` when no trip.
- Close → deselect: clear route, keep the camera where it is.

**ScheduledSheet** (`:1157-1226`): same frame; status chip: `train.statusCanceled` (all stops cancelled, red) /
`train.statusArrived` (last passed) / `train.statusDeparts` (time) / `train.statusNoPosition`; caption
`train.liveTimes` (any actual/estimated) or `train.timetableOnly`; same actions (follow label = "first → last" stop
names); StopList; Onboard; BuyTicket first → last.

**NotRunningSheet** (`:1229-1257`): badge + "Operator N"; follow label; `liveMap.notRunningTitle`,
`liveMap.notRunningBody`; Unfollow (if followed) / Close.

**LiveStationSheet** (`:1266-1326`): name, county; next 4 departures not done and not cancelled, sorted by estimated
?? advertised (FlapTime with struck advertised, OperatorBadge 18, endpoints, `trips.platform`); tapping a row opens
the train (live if on the map with that number and date, else scheduled); `common.loading`, `board.empty`; buttons
`liveMap.allDepartures` → `/stations/:id` (has board) and `stationMap.open` → `/stations/:id/map` (has map).

**i18n.** `liveMap.*`, `live.*`, `train.*`, `board.notInTimetable`, `board.empty`, `stationMap.open`, `products.*`,
`common.*`, `trips.platform`.

### 2.6 Passport (`/passport`, `pages/PassportPage.tsx:151-530`)

**Purpose.** Your rail history: totals, map, milestones, collections, records, delays, CO₂; share cards.

**API.** `GET /passport?year=<YYYY|all>&commuter=<bool>&comparison=<flight|car_1>` on open and whenever year or
comparison changes (`:168-171`); commuter = `settings.includeCommuter` (no switch on this page). `GET /legs` once (for
the share sheet). All numbers come from the server (`Passport`, `api.ts:359-385`); CO₂ and milestones are computed
server-side (`apps/server/src/stats/passport.ts`).

**Layout.**
1. Header `passport.title`; Share icon (only when `totals.trains > 0`) and gear.
2. Sticky year chips (horizontal scroll): `passport.allTime` + one per `data.years` (`:236-247`).
3. Review banner `passport.reviewBanner` (count) → `/?tab=past` when `review.length > 0`.
4. Empty (no trains): `passport.emptyTitle`, `passport.emptyHow`, `trips.findTrain` → `/add`, `trips.exploreTrains` →
   `/explore`.
5. **Passport card** (`PassportCard` `:113-132`, `:269-310`): yellow-to-amber gradient card (radius 24) with
   guilloche rings and a sheen sweep (1.6 s after 0.3 s); tilts with the pointer (±3° X, ±4° Y) **[Swift: optional,
   e.g. device motion or drag]**. Content: caption `passport.railPassport`, kind `passport.yearPassport` (year) /
   `passport.allTimePassport`; round emblem with a train icon; big distance in Space Grotesk 56 (`km` or `mi` = km /
   1.609344, rounded, locale grouping); a "flavor" button cycling facts on tap (§3.15); 4 tiles: trains, journeys,
   time on trains (`fmtDuration(minutes)`), stations; MRZ-style line
   `P<CLACK<<{year|ALL}<<KM{km}<<J{journeys}<<S{stations}<<C{countries}` padded with `<` and cut to 44 chars, monospace.
6. Map card: `MultiRouteMap` with every counted leg (operator colour; geometry or end stops) and station dots sized by
   visit count (§3.13).
7. Milestones card (`:65-110`): `passport.milestones`; achieved medals (first 6, `passport.showAllMilestones` /
   `passport.showFewer`), each linking to the leg that reached it, label `milestoneLabel` (§3.14), month/year of `at`;
   `passport.nextMilestones` with locked medals and progress ring, `passport.progressOf`; footer
   `passport.milestonesNote`. Medals pop in (scale .6→1, 450 ms, overshoot curve, 60 ms stagger,
   `styles.css:880-884`).
8. Group header `passport.collections`: Operators bars (OperatorBadge 30, name, `passport.trainsCount` · distance; bar
   width ∝ count, operator colour); Train types (TrainArt silhouette in neutral colour, name, count · distance,
   `passport.typesNote`); Countries (round flag 24, `countries.<code>`, count; `passport.borders`); Stations visited
   (chips linking to `/stations/:id`, "×count"; first 12 then `passport.showAllStations`; `passport.stationsNote`);
   Products bars (accent colour, `products.<key>`).
9. Group `passport.records`: Record tiles (link to the leg when it's a LegRef): longest trip (distance), longest time,
   biggest delay (`passport.minutesLate`), most ridden route (`passport.timesCount`), busiest station
   (`passport.visitsCount`), earliest departure (time in Stockholm), latest arrival.
10. Group `passport.moreStats`: Delays card — `passport.noDelayData` when basedOn 0; else on-time % big, band bar
    (flex per band count: on_time, slight, late, very_late), legend with counts and % , records: time lost, average
    delay (`passport.minutesShort`), worst delay, cancellations; `passport.basedOn`.
11. CO₂ card: saved kg (rounded, locale), `passport.co2Saved` with mode; segmented Flying | Car (`CO2_CHOICES` =
    flight, car_1; initial from settings, falling back to car_1 for retired values) — local only, re-fetches the
    passport; `passport.co2Detail` (train kg 1 decimal under 10) + link `passport.howWeCalculate` → `/about`.
12. ShareSheet when sharing (§2.11).

**States.** Skeleton while loading; error → title + `passport.loadError` (no retry button).
**i18n.** `passport.*`, `products.*`, `countries.*`, `trips.findTrain`, `trips.exploreTrains`, `share.title`.

### 2.7 Stations search (`/stations`, `pages/StationsPage.tsx:9-100`)

**API.** On open: `GET /stations/favorites`, `GET /stations/recent`, `GET /stations/popular` (`:19-24`); typing:
`GET /stations/search?q=&limit=12` debounced 120 ms (`:26-37`).
**Layout.** Back "← `nav.trips`" → `/`; title `stations.title`; autofocused search `stations.placeholder`. Empty
query: sections `stations.favorites`, `stations.recent` (minus favourites), `stations.popular` (minus favourites and
recents), each a list of `StationRow` (round flag 32, name, county or `countries.<code>`; Trafikverket codes are never
shown, `components/StationRow.tsx:6-21`), favourites marked with a yellow star. Query: results or `stations.noMatch`.
Tap → `/stations/:id`.
**i18n.** `stations.*`, `countries.*`, `nav.trips`.

### 2.8 Station board (`/stations/:id`, `pages/BoardPage.tsx:84-297`)

**API.**
- On open: `GET /stations/:id` (→ missing state on error), `POST /stations/:id/viewed` (adds to recents) (`:104-108`).
- When `station.hasBoard`: SSE `GET /stations/:id/board/stream?type=departures|arrivals` (event `board` → full
  `Board`; the server sends the current board at once and after every shared poll); reconnects on type change;
  `onerror` → error flag (`:111-124`).
- "Show earlier": `GET /stations/:id/board?type=&from=<board.from − 3 h>&to=<board.from>` once (`:126-134`).
- Favourite star: `PUT|DELETE /stations/:id/favorite` → `{favorite}` (`:157-161`).
- Clock ticks every 1 s.

**Layout.** Back "← `stations.title`" → `/stations`; header with station name, county, map button (when `hasMap`) →
`/stations/:id/map`, star toggle (`stations.favorite`/`stations.unfavorite`). Status line: green `live.chip` when
`now − board.updatedAt < 2 min`, else grey `live.stale`; plus `live.updated`. Segmented `board.departures` |
`board.arrivals` (changes `?type`). Filter chips: windows `board.window.1h|3h|day` (default 3h), `board.commuter`
toggle (default `settings.includeCommuter`), product chips for products present on the board (high_speed, intercity,
regional, commuter, night), operator chips when > 1 operator. `board.noBoard` when the station has none; loading (two
skeleton rows + `board.loading`); error banner `board.error` when no board.

**Row** (`:34-82`), tappable → `/explore?train=N&date=<trip serviceDate or advertised date in Stockholm>&key=<trip
key>`:
- Time: split-flap of shown time (actual ?? estimated ?? advertised, Stockholm tz), struck advertised when the minute
  differs.
- Main: endpoints joined (or "—"); `board.via` (departures) / `board.from` (arrivals) with via stops; meta: OperatorBadge
  18, "productName ?? operator name, number", "· type name"; first two deviations in yellow.
- Side: platform chip (radius 6) — orange with the old platform struck when `platformChange` is unknown-time or
  < 15 min old, plus `board.changed`; DelayPill cancelled, or DelayPill(delayMin) when estimated or actual exists;
  `board.departed`/`board.arrived` when done.
- Past rows (shown time < now, not cancelled) are dimmed; cancelled styled.

**Row filter** (`:136-149`): without "earlier": hide rows whose shown time < now − 10 min (not cancelled) and
cancelled rows advertised < now − 10 min; hide advertised > now + window; commuter filter; operator and product sets.
Empty → `board.empty` + `board.widen` (1h→3h→day) unless already day.

**i18n.** `board.*`, `stations.*`, `live.*`, `products.*`, `delay.*`.

### 2.9 Settings (`/settings`, `pages/SettingsPage.tsx:69-138`)
See §4 for each setting. Layout: title `settings.title`; error banner `settings.saveError` (last save failed); cards:
(1) Theme three-way segmented control; (2) Display name, Language, Distance unit, Clock, CO₂ comparison; (3) Include
commuter, Show rail network; (4) `settings.changing`: Walk pace, Step-free, Heavy luggage, caption
`settings.changingNote`; (5) row `settings.about` → `/about`; (6) `settings.yourData`: row `settings.privacy` →
`/privacy`, button `settings.deleteData` (§2.9.1). No back button (reached from the gear; the tab bar remains).

#### 2.9.1 Delete my data (`:118-138`)
Confirm `settings.deleteConfirm` → `DELETE /api/me` → remove every local `clack.*` key (`offline.ts:32-38`, which
also drops the device id so the next request starts a fresh user) → caption `settings.deleted` in place of the button.
On failure, return to idle silently. **[Swift: also clear Keychain/UserDefaults/caches; the settings in memory are not
reset by the web code — unclear whether intended.]**

### 2.10 Station map and Layover Guide (`/stations/:id/map`, `pages/StationMapPage.tsx:53-356`)

**Purpose.** A schematic plan of a station, one level at a time, with amenities and their opening state, and walking
directions between any two points (tracks, entrances, amenities, "my location"); with a layover window it becomes the
Layover Guide.

**API.** On open `GET /stations/:id` and `GET /stations/:id/map` (`StationMap`, `packages/shared/src/station.ts:78-96`)
(`:74-78`). Both kept offline (§3.4). Clock every 30 s. Geolocation only on "My location" tap.

**URL state** (`:80-89, 131-140`): `from`, `to` = endpoint specs (track "11"/"17b", `p:<poiId>`, `n:<nodeId>`,
`me:<nodeId>`); `arr`, `dep` = ms; `a`, `b` = operator ids (chip colours); `xa`, `xb` = "1" when a train is
cancelled; `live` = "1" when both times are real-time. Changing ends replaces the URL; arr/dep/a/b/xa/xb are dropped
unless both ends are plain tracks.

**Logic.**
- `profile` from settings (pace, stepFree, luggage). `route = routeBetween(map, resolveEndpoint(from),
  resolveEndpoint(to), profile)` (§3.16).
- Reference window: [arr, dep] when both, else [picked time] or [now]; POI state = `openState(opening_hours, from,
  to)` (§3.17).
- "Along my path": `secondsFrom(map, route nodes, profile)`; a POI is "along" when its node is ≤ 40 s away; the detour
  shown is `ceil(2 × seconds / 60)` min.
- Dimmed POIs: not in the active category filter, or (along on) not along the path.
- Initial level: the level of the start (from ?? to) node, else the level with `order == 0`, else the first; re-run
  when the ends change (`:95-100`).
- Platform marks: track ends get a coloured chip on their platform (`stationMap.arriveChip` with arr time /
  `stationMap.fromChip`, `stationMap.departChip` with dep time / `stationMap.toChip`; colours = operator a/b); other
  ends get a pin (kind from/to/me) (`:116-122`).
- Connection chip in layover mode when both ends are tracks: `connectionStatus` with walk = route seconds, size class
  from station info (default large), live flag from URL (`:123-126`).
- Directions: `instructions(map, route, fromE, toE)`; each step's level = its own level for stairs/escalator/lift,
  else the previous step's (`:127-130`).

**Layout.**
- Full-bleed `StationScene` (§3.16) or a list view (all non-dimmed POIs sorted open → closing soon → unknown → closed,
  then category, then name; row: category icon badge, name, "category · level · detour", state text).
- Top bar: back (history back), title (station name), search (opens PlaceSearch "find"), departures (TrainFront) →
  `/stations/:id`, Radar → `/explore`.
- Category filter chips (single-select toggle): `stationMap.filters.toilets|food|shops|tickets|lockers|info` (`:37-44`:
  toilets=toilet; food=cafe,restaurant,kiosk; shops=shop,pharmacy; tickets=ticket; lockers=locker;
  info=info,waiting,atm).
- Right side: level chips (only with > 1 level; sorted top to bottom by `order` desc; label "+N" / "0" / "−N"; active
  yellow) and the map/list toggle. Current level name as a small glass label.
- Bottom card (`:234-323`):
  - No route and not planning: chip "Route `stationMap.directions`" (starts planning) and a time chip (`stationMap.now`
    or the picked time; native time input sets "today at hh:mm" local; reset chip).
  - Planning or any end set:
    - Layover mode: big "`stationMap.walk` n min" (or "—"), ConnectionChip, close X.
    - Otherwise: From and To end buttons (`stationMap.from`/`stationMap.to`, value or `stationMap.choose`; locate icon
      for "me"), close X, swap button (`stationMap.swap`).
    - Walk time (`stationMap.here` when < 30 s); `stationMap.noStepFree`/`stationMap.noRoute` when no path;
      `stationMap.locationNote` for "me"; `stationMap.layover` ("from–to, n min").
    - Chips `stationMap.steps` (toggle the step list) and `stationMap.alongPath`.
    - Step list: `stationMap.step.<key>` with track/place/level/min; on multi-level routes each step is a button that
      switches the plan to its level (current one highlighted).
  - Footer caption `stationMap.hoursNote` · © OpenStreetMap contributors.
- PlaceSearch modal (`:388-522`): title `stationMap.pickFrom`/`pickTo`/`searchTitle`; search (diacritics-folded,
  case-insensitive substring); in from/to mode with an empty query a "My location" row (`stationMap.myLocation`,
  hints `locating`/`notHere`/`noLocation`/`myLocationHint`): geolocation (high accuracy, 12 s timeout, max age 30 s)
  → `toLocal` → `nearestNode(level, …, 120 m + min(accuracy, 150))` → pick `me:<node>`, or "far"; tracks grid (all
  tracks of all platforms, numeric sort; match exact/prefix/"Track N" text); entrances (unique labels; unnamed
  entrances named by compass direction from the platforms' centroid using `stationMap.entranceDir` +
  `stationMap.compass.<n|ne|…>`); places (POIs sorted by state rank then name, Swedish collation). In find mode a
  POI opens its sheet; otherwise picking sets the end. `stationMap.noResults`.
- PoiSheet (`:551-609`): icon, name (or category), chips: state (`stationMap.closesAt` time or
  `stationMap.state.<s>`), category, level, fee (`stationMap.free` / `stationMap.fee`), detour; hours
  (`stationMap.hours`, the raw string with ";" → " · " when parseable) + `stationMap.hoursNote`; buttons
  `stationMap.routeHere` (sets "to") and `stationMap.startHere` (sets "from").

**States.** Skeleton while loading; no map (or no level) → back + `stationMap.none`.
**i18n.** `stationMap.*`, `connection.*`, `liveMap.showAll`, `common.*`.

### 2.11 Share sheet (Passport, `share/ShareSheet.tsx:33-237`)

**API.** `GET /passport?year=all&commuter&comparison` (all time) and, for the shown year (the selected year, else the
newest year), `GET /passport?year=Y&...` (`:47-57`). Uses `GET /legs` from the Passport page. Map snapshot needs the
basemap and `GET /map/rail-network.geojson`.

**Layout.** Header `share.title` + X; segmented: year (label = the year, or `share.year`), `share.variant.all`,
`share.variant.journey`, `share.variant.medal` (disabled without achieved medals); picker for journey (counted legs =
those in `passport.map`, newest first; label "A → B · Month Year") or medal (`milestoneLabel`); preview image
(skeleton while drawing; `share.nothing` when nothing to show); captions `share.privacy` and status; buttons
`share.save` (download PNG `clack-<year|passport|journey|medal>.png`) and `share.share` (system share sheet with the PNG
file; falls back to save + `share.savedInstead`). Defaults: journey = longest-distance leg (else first map entry);
medal = first achieved. Card content and drawing: §3.18.

### 2.12 TripProgress (component, `components/TripProgress.tsx:13-81`)
Used on the Done step and the welcome card. `GET /legs/:id/progress` → `TripProgress`. Not counted → caption
`progress.notCounted` (or nothing when `quietIfNothing`). Else: unlocked medals (`progress.unlockedOne` /
`progress.unlocked`) each popping in (scale .6→1, 600 ms, overshoot, delay 0.4 s + 120 ms × i; `styles.css:988-990`);
"firsts" chips (`progress.firstStation`, `progress.firstOperator`, `progress.firstCountry`); moved families as bars
filling from `before` to `after` (CSS width transition 1.1 s `cubic-bezier(.2,.8,.2,1)` after 0.3 s, started two frames
after mount), label `milestoneLabel`, value `passport.progressOf` or `progress.reached`. Quiet and nothing to show →
nothing.

### 2.13 About (`/about`, `pages/AboutPage.tsx:5-32`) and Privacy (`/privacy`, `pages/PrivacyPage.tsx:9-40`)
Static text pages with a back link to Settings. About: `about.intro`; `about.sourcesTitle` with items
`about.sources.trafikverket|gtfsSweden3|gtfsSverige2|entur|osm|stationMaps|onboard`; `about.delaysTitle` +
`about.delaysBody` (max = `ON_TIME_MAX_DELAY_MIN` = 5); `about.co2Title` + `about.co2Body`. Privacy: `privacy.intro`;
sections stored, phone, location, notCollected, sharing, deletion (`privacy.<part>Title/Body`); contact section only when
`VITE_SUPPORT_EMAIL` is set (mailto link); `privacy.updated` with the literal date `2026-10-23` (`PrivacyPage.tsx:36`).
**[doc differs]** DESIGN §12 wants a CO₂ factors table on the sources page; the code shows only text.

---

## 3. Client-side logic the Swift app must replicate

### 3.1 Formatting (`format.ts`, tests in `format.test.ts`)

Locale: `sv-SE` when the app language is Swedish, else `en-GB` (`locale()`, `:6`).

1. **`fmtTime(ms, tz, clock)`** (`:8-12`): null → `--:--`. `24h`: en-GB `HH:mm` in `tz`. `12h`: en-US numeric hour,
   2-digit minute, then " AM/PM" rewritten to " am"/" pm" (`7:04 pm`). Always the station's tz, independent of language.
2. **`fmtDay(ms, tz, now)`** (`:15-18`): weekday short, day numeric, month short in the app locale ("Tue 20 Oct",
   Swedish "tis 20 okt"), adding the year when its year (in `tz`) differs from `now`'s; the first comma removed.
3. **`fmtLongDate(ms, tz)`** (`:20-22`): weekday long, day, month long, year; first comma removed.
4. **`fmtMonth(ms, tz)`** (`:24-26`): month long + year ("October 2026").
5. **`localDate(ms, tz)`** (`:29-31`): `YYYY-MM-DD` in `tz`.
6. **`dayOffset(fromMs, fromTz, toMs, toTz)`** (`:34-36`): whole days between the two local dates ("+1").
7. **`fmtDuration(minutes)`** (`:38-43`): h = floor(min/60), m = round(min % 60); h ≥ 24 → "`{d}d {h%24}h`"; h > 0 →
   "`{h}h {mm}m`" (minutes zero-padded); else "`{m}m`". Not localised (same in Swedish).
8. **`fmtDistance(m, unit)`** (`:45-49`): null → "—"; km = m/1000, mi = m/1609.344; rounded integer with locale
   grouping + " km"/" mi".
9. **`fmtDelay(min)`** (`:51-55`): null → "—"; 0 → "0"; >0 → "+N"; <0 → "−N" (U+2212 minus).
10. `todayIso(tz='Europe/Stockholm')`, `addDaysIso(iso, n)` (noon UTC arithmetic), `isoToNoonMs(iso)` (`:57-59`).
11. **Countdown** (`countdown`, `pages/TripsPage.tsx:30-41`): dep = actualDep ?? schedDep. Cancelled (leg or live) →
    `status.cancelled`; now ≥ `arrivalOf` → `trips.arrived`; now ≥ dep → `trips.liveNow`; ≤ 30 min to dep →
    `trips.boarding`; else `trips.departsIn` with "`{d}d {h}h`" / "`{h}h {m}m`" / "`{m} min`" (mins rounded).
12. **"ago"** (`agoKey`, `live.ts:78-83`): seconds = max(0, round(Δ/1000)); < 5 → `live.justNow`; < 90 →
    `live.secondsAgo` (n); else `live.minutesAgo` (round(s/60)).
13. **Milestone centre text** (`centre`, `components/Medal.tsx:44-48`): target 1 or ≥ 40 000 → no number (icon);
    ≥ 1000 → "1k", "2.5k", "10k" (max 1 decimal, en); else the number.
14. **`ms(t)`** (`api.ts:437`): REST gives ISO strings, the live stream epoch ms; null/"" → null. The Swift model
    should accept both for `LiveState` time fields (`updatedAt`, `positionAt`, `eta`, `arrivalEta`, `reportedAt`) and
    `LegEvent.ts`.
15. **Delay band** (`delayBand`, `packages/shared/src/delay.ts:8-15`): cancelled → `cancelled`; null → `unknown`; ≤ 0 →
    `on_time`; ≤ 15 → `slight`; ≤ 30 → `late`; else `very_late`. `delayMinutes(adv, act)` (`:18-21`) = difference of the
    two times floored to whole minutes. `ON_TIME_MAX_DELAY_MIN = 5` (`:3`).
16. **DelayPill text** (`components/DelayPill.tsx:6-15`): cancelled → `delay.cancelled`; unknown → `delay.unknown`;
    0 → `delay.on_time`; else `fmtDelay`. Colour = band ink colour (§3.11).

i18n mechanics (`i18n/index.ts`): i18next, English fallback, `{{name}}` interpolation, plural suffixes `_one`/`_other`
on `count` (e.g. `add.stopsBetween_one`), `t(key, {defaultValue})` for countries. Language comes from the server
setting (`settings.tsx:29-31`). Both locales have 890 lines (`i18n/locales/en.json`, `sv.json`); `locales.test.ts`
checks key parity. Swift: convert to a String Catalog with plural variants; keep the key names.

### 3.2 Landing resolver
See §1.3 (`landing.ts`). Constants: attention window 3 h, arrival grace 10 min.

### 3.3 Live status and freshness (`live.ts`)

- **One shared SSE connection** to `GET /api/live/stream?u=<id>` while at least one screen listens; closed when the last
  listener leaves; EventSource auto-reconnects; the server sends full state every tick, so nothing is replayed
  (`:10-36`). Event name `live`, data `LiveUpdate {legId, live: LiveState, events: LegEvent[]}`. Listeners: Trips
  list, Trip detail, Journey. Swift: one `URLSession` SSE client with reconnect/backoff, fan-out via Combine/async.
- `STALE_MS = 2 min` (`:49`); `dataAt(live)` = `reportedAt` ?? `updatedAt` (`:52`); `isFresh` = now − dataAt < 2 min.
- `SPEED_FRESH_MS = 60 s` (`:57`).
- `isLive(live)` = status boarding / en_route / at_stop (`:60`).
- **`statusKey(leg, live, now)`** (`:63-76`): cancelled (leg or live) → `cancelled`; if live is fresh: boarding →
  `boarding`, en_route/at_stop → `live`, arrived → `completed`; otherwise from the clock: dep = actualDep ?? schedDep,
  arr = actualArr ?? schedArr; `leg.status != planned` or now ≥ arr → `completed`; now ≥ dep → `live`; ≤ 30 min before
  dep → `boarding`; else `planned`.
- `useNow(everyMs)` ticks: Trips featured 1 s (active) / 30 s, LegRow 60 s, Trip detail 1 s, Board 1 s, Explore 5 s,
  Station map 30 s, Disruption 30 s.

### 3.4 Offline caching and connection state (`offline.ts`, `api.ts:18-43`)

- **What is kept**: the JSON body of successful GETs whose path (without `/api`, including the query string) matches
  (`offline.ts:14`): `/legs`, `/legs/:id`, `/journeys/:id`, `/operators`, `/train-types`, `/settings`, `/amenities`,
  `/stations/:id` (no query), `/stations/:id/map`. Live data, boards, search, passport, follows are never kept.
- **Storage**: `localStorage['clack.offline:' + path] = JSON`; an LRU index `clack.offline.index` (array of paths,
  most recent last) capped at 60 entries; oldest evicted first; failures (quota/private mode) are ignored
  (`:18-29`). Swift: an on-disk cache (files or SQLite) with the same key set and LRU cap.
- **Read path**: when `fetch` throws (network error or the 15 s GET timeout) and the request wasn't cancelled by the
  page: mark offline; if GET and kept, return the kept body (`api.ts:28-35`). Any HTTP response (even an error) marks
  online (`:37`). HTTP errors are not served from the cache.
- **Connection state**: starts from `navigator.onLine`; browser `online`/`offline` events and request outcomes update
  it; `useOffline()` subscribes (`offline.ts:51-74`). Shown as the top banner `offline.banner` with a WifiOff icon
  (`components/AppShell.tsx:82-86`). Swift: `NWPathMonitor` + request outcomes.
- **Forget** (`forgetLocalData`, `:32-38`): removes every `clack.*` localStorage key (after Delete my data).
- The web also has a service worker app-shell cache `clack-shell-v1` (`public/sw.js`) — not needed natively.

### 3.5 Dead reckoning on the phone (`offline.ts:76-109`, shared `packages/shared/src/progress.ts`)

Trip detail only. When the leg is tracked (`isLive`) and the last live update is older than **60 s**
(`LOCAL_AFTER_MS`, compares `live.updatedAt`, `TripDetailPage.tsx:206`), the phone computes the position itself with
`localLive(leg, live, now)`:
1. Ridden stops (roles board/through/alight) → `LiveStop` with all times as ms.
2. Line = decoded `leg.geometry`, else the ridden stops' coordinates.
3. GPS fix = last live lat/lon/bearing/speed/positionAt **only if** `positionSource == 'gps'`.
4. `liveView(stops, line, gps, now)`; merge over the last live state; keep `updatedAt`/`reportedAt`; set
   `localEstimate = true` (UI shows "No connection" chip and "estimated from the last report").

`liveView` (`progress.ts:141-242`) — port exactly; it is the same algorithm the server runs:
- `expectedTimes(stops)` (`:76-87`): walking forward with a carried delay (starting 0): arr = actualArr ??
  estimatedArr ?? schedArr + delay; when a stop has a real/estimated arr, delay = max(0, that − schedArr); dep =
  actualDep ?? estimatedDep ?? schedDep + delay, never before arr; update delay from dep likewise.
- depAt = times[0].dep ?? arr; arrAt = last.arr ?? dep. arrivalDelayMin = `delayMinutes(alight.schedArr ?? schedDep,
  alight.actualArr ?? estimatedArr ?? (schedArr ? expected arr : null))`.
- Board or alight stop cancelled → `cancelled`, progress null.
- Arrived (alight actualArr, or now ≥ arrAt > 0) → `arrived`, progress 1, position = alight stop.
- Not departed (no board actualDep and now < depAt) → `boarding` if now ≥ depAt − 30 min (`BOARDING_MS`), else
  `scheduled`; nextStop = board.
- Else prev = last stop reached (actual time, or expected time ≤ now); next = prev + 1 (clamped); `en_route` if prev was
  left (actualDep or expected dep ≤ now) else `at_stop`. Stops are located along the line in order (`locate`, `:97-118`:
  nearest point projection with a local equirectangular metric, monotonic). Position m along the line: at_stop → the
  stop; en_route → linear in time between prev dep and next arr.
- Fresh GPS (≤ 2 min, `GPS_FRESH_MS`) → GPS position, progress = located GPS / total, speed if ≤ 60 s.
- No fresh GPS but a fix ≤ 30 min old while en route: never behind the last fix; within 5 min (`DEAD_RECKONING_MS`)
  and speed > 0, advance from the last fix at the last speed; capped at the next stop.
- Position = `pointAt(line, cum, m)` with bearing (great-circle initial bearing of the segment); source `estimated`.
- `cumulative` uses haversine with R = 6 371 008.8 m.

### 3.6 Connections between legs (`components/Connection.tsx`, shared `station.ts:357-416`)

- `connectionTimes(a, b)` (`:32-40`): arrival = a.actualArr ?? a.live.arrivalEta ?? (a.schedArr + arrDelay);
  departure = b.actualDep ?? (b.live status scheduled/boarding ? b.live.eta : null) ?? (b.schedDep + depDelay);
  `live` = both from real-time sources.
- `useConnection(a, b)` (`:42-63`): station = a.destination; station info + map cached per session; walk route =
  `routeTracks(map, a.arrPlatform, b.depPlatform, profile)`; a map that can't connect the platforms falls back to the
  size estimate (logged); `connectionStatus({... walkSeconds: route?.seconds, sizeClass: info.sizeClass ?? (map ?
  'large' : 'medium'), timesLive})`.
- `connectionStatus` (`station.ts:402-416`): layover = (dep − arr)/1000 s; walk = mapped seconds ?? size estimate
  (small 120 s, medium 240 s, large 420 s); cancelled → `broken`; missing layover/walk, or a mapped walk with a
  missing platform → `unknown`; slack = layover − walk − 60 s deboard − 30 s board; < 0 `miss`; < 300 s `tight`;
  estimated walk or not live → `margin`; else `easy`.
- Chip (`ConnectionChip`, `:74-81`): `margin` → `connection.marginSpare` (min = floor(slack/60)); others →
  `connection.status.<s>` + " · `connection.spare`" when spare ≥ 0 and not broken. Colours: easy = on-time green,
  tight = slight yellow, miss/broken = very-late red, unknown/margin = grey (`:65-72`).
- `stationMapHref` (`:84-97`) builds the Layover Guide URL (§1.5).

### 3.7 Ticket links (`components/Tickets.tsx`, test `tickets.test.ts`)

- Shown only when the operator (from `GET /operators`) has a `ticketUrl` and the trip's arrival time is in the future
  (`:73`). No checkout or affiliate links.
- `ticketHref(base, deepLink, trip)` (`:57-65`): no `ticketDeepLink` → `ticketUrl`; else replace `{from}`, `{to}` with
  URL-encoded station names, `{date}` with `YYYY-MM-DD` and `{time}` with `HH:mm` of the departure in the from
  station's tz (sv-SE formatting).
- Button "ExternalLink `tickets.buyAt` (site = hostname without `www.`)" + caption `tickets.searchFor` (from, to,
  `fmtDay`, time, "Operator Number"). Opens externally (Swift: `SFSafariViewController` or `openURL`).
- When not already in your trips and the trip has a timetable key and service date, tapping stores
  `clack.ticketPending = {…TicketTrip, at: now, site}` (`:83-86`).
- `TicketReturnPrompt` (`:104-168`, in the shell): on `visibilitychange`/`focus`, if a pending entry exists, is < 3 h old
  (`PENDING_MAX_MS`) and was written > 5 s ago, show a card: `tickets.backTitle` (site), `tickets.backBody` (from, to,
  train), buttons `tickets.notNow` (clears) and `tickets.addToTrips` → `POST /legs {tripKey, serviceDate, fromSeq,
  toSeq}`; then `tickets.added` / `tickets.already` (409) / `tickets.failed` with Close; the pending entry is cleared
  either way. Swift: trigger on `scenePhase` becoming `.active`.

### 3.8 Disruption, rights, reasons (`packages/shared/src/disruption.ts`)

- `assessDisruption(d, now)` (`:43-61`): kinds in order: `canceled` (then nothing else from the train), else
  `skips_board`, `skips_alight`, `replacement` (deviation matches `/ersättningsbuss|buss(ar)? ersätter|ersätts med
  buss|replacement bus/i`), `delayed` (max(dep, arr delay) ≥ 15); plus `connection_missed` (connection miss/broken) or
  `connection_at_risk` (tight). Urgency: none if no kinds; `info` if arrived; severe kinds (canceled, skips_*,
  connection_missed): `act_now` within 3 h of schedDep, `heads_up` within 48 h, else `info`; others `heads_up` within
  3 h else `info`. (The card shows for any non-null urgency.)
- `passengerRights` (`:77-86`): all-Norwegian journey → `operator`; international or ≥ 150 km → `eu`
  (cancelled → refund_or_reroute; arrival delay ≥ 120 → compensation_50; ≥ 60 → compensation_25); else `se_short`
  (cancelled or ≥ 20 min → price_reduction). Links `RIGHTS_LINKS` (`:88-91`).
- `delayReasons(deviations, lang)` (`:123-125`): unique mapped reasons from the fixed `DELAY_REASONS` table
  (`:98-120`), in order seen.

### 3.9 Typical amenities (`packages/shared/src/onboard.ts:58-68`)
Operator-wide claims overridden by operator+type claims; claims older than 365 days (`CLAIM_MAX_AGE_DAYS`) by
`verified` are dropped; no operator → none. Table from `GET /amenities` (cached).

### 3.10 Split-flap digits (`components/SplitFlap.tsx`, CSS `styles.css:600-617`)
- Each character on its own tile (gradient top/bottom halves, hinge line); `:`, space and `.` are plain separators.
- When the value changes, only changed character positions flip; flipped tiles are staggered 50 ms left to right
  (counting only flipping tiles). Each flip: the old top half rotates 0 → −90° in 180 ms ease-in, then the new bottom
  half rotates 90° → 0 in 180 ms ease-out (total 360 ms per tile).
- `intro`: on first show every tile flips in from blank.
- Reduced motion: no flip, just swap.
- `FlapTime` (`:59-93`): null → "—"; when `sched` differs by ≥ 1 minute, the timetabled time is shown struck through
  before the new one, which is drawn in the accent colour. `size='text'` = plain tabular digits; `sm/md/lg` = tiles.
- Sizes in use: featured `lg` 28 pt; trip-detail time blocks 34 pt tiles radius 7; board rows 18 pt.
**[doc differs]** DESIGN §10 says 280 ms per digit and 40 ms stagger; code is 2 × 180 ms and 50 ms.

### 3.11 Visual tokens needed for parity (`styles.css:2-101`, DESIGN §2)
Dark / light values: bg `#0a0a0a`/`#ffffff`; surface `#151515`/`#f4f4f4`; surface-raised `#1f1f1f`/`#e9e9e9`; hairline
9 % white/black; text `#fff`/`#0a0a0a`; text-2 `#a3a3a3`/`#5c5c5c`; text-3 `#6e6e6e`/`#8a8a8a`; accent `#f8d64a` (both),
on-accent `#0a0a0a`, accent-ink `#f8d64a`/`#0a0a0a`. Delay fills: on-time `#3ddc84`, slight `#f5d90a`, late `#ff9500`,
very-late `#ff453a`, unknown `#8e8e8e`; light-mode inks `#12813f`, `#8a6a00`, `#b4570a`, `#c4271c`. Radii: tag 6,
control-sm 10, input/button 12, card 16, sheet 24 (no full pills; circles only for icon buttons and dots). Tab bar 64.
Fonts: Inter Variable (body), Space Grotesk 600/700 (flap digits, big numbers, share cards). Icons: Lucide.
Station-plan colours `styles.css:698-699` (path `#f8d64a`/`#0a0a0a`, platform `#2a2a2a`/`#dcdcdc`, hall
`#1b1b1b`/`#efefef`, shop `#222`/`#e6e6e6`, me `#3b8bff`/`#1a6ff0`, unit, unit-food, unit-service).
Reduced motion disables all animations (`styles.css:476-478`).

### 3.12 Train pictures (`components/trains/TrainPicture.tsx`, `components/TrainArt.tsx`)

Decision (`TrainPicture`, `:84-96`), given a train type (`GET /train-types` → `{id, name, art, uncertain?, …}`) and an
operator id:
1. No type, or `type.uncertain` (the type names two models) → **grey silhouette**: `TrainArt(art = type.art ?? '',
   color '#8a8a8a')` in a dimmed wrapper (`.train-art-unknown`).
2. Type id not in `DETAILED`, or the operator is in that entry's `notFor` → `TrainArt(type.art, operator colour)`
   (family silhouette with the operator colour as the livery stripe).
3. Else the detailed side view, livery = (operator in `liveries`) ? (`liveryOf[operator]` ?? operator) : `'plain'`
   (unpainted).
`hasDetailedArt(typeId, operatorId)` (`:75-76`) decides the wider "side" layout on Explore sheets.

`DETAILED` registry (`:40-73`), type id → liveries (no entry uses `notFor` today):

| Type id | Drawn liveries (operator ids) | liveryOf | SVG files in `assets/trains/` |
| --- | --- | --- | --- |
| x3 | arlanda-express | | x3-plain, x3-arlanda-express |
| x2000 | sj | sj → `sj-x2` | x2000-plain, x2000-sj, x2000-sj-x2 (also x2000_trailer-* exist, unused by the registry) |
| x40 | sj | | x40-plain, x40-sj |
| x55 | sj | | x55-plain, x55-sj |
| rc6_coaches | sj | | rc6_coaches-plain, rc6_coaches-sj |
| x60 | sl | | x60-plain, x60-sl |
| x61 | pagatag | | x61-plain, x61-pagatag |
| x61_vt | (none: always plain) | | **x61vt-plain** (file name differs from the type id) |
| x62 | norrtag | | x62-plain, x62-norrtag |
| x74 | vr | | x74-plain, x74-vr |
| y31 | krosatag, vasttagen | | y31-plain, -krosatag, -vasttagen |
| x31 | oresundstag, dsb | | x31-plain, -oresundstag, -dsb |
| x11 | krosatag | | x11-plain, x11-krosatag |
| er1 | malartag | | er1-plain, er1-malartag |
| flytoget71 | flytoget | | flytoget71-plain, -flytoget |
| flytoget78 | flytoget | | flytoget78-plain, -flytoget |
| regina | vasttagen, tib, x-taget, sj, malartag | | regina-plain + those (regina-varmlandstrafik exists but is deliberately not used) |
| no_flirt | vy | | no_flirt-plain, -vy |
| no_type72 | go-ahead-norge, vy | | no_type72-plain, -go-ahead-norge, -vy |
| no_type73 | sj-nord, go-ahead-norge | | no_type73-plain, -sj-nord, -go-ahead-norge |
| no_type76 | sj-nord | | no_type76-plain, -sj-nord |

The detailed components also accept `muted` (opacity .35 + filter) but `TrainPicture` never passes it. `height` is
ignored for detailed pictures; CSS sizes them (`styles.css:1060-1066`): 56 pt tall on the trip's Train card
(horizontally scrollable wrapper), 54 pt tall on Explore sheets (stacked above the type name), max width 100 %. The grey
fallback is 45 % opacity, greyscale. Swift: bundle the 54 exported SVGs (or PDFs) from `assets/trains/`
(`scripts/trains/export_svg.py`), keep this registry as data, and never pick a livery not listed.

**Family silhouettes (`TrainArt`, `:117-200`)** — procedural; port the drawing code (Canvas/Path):
- Box: car top y 7, bottom 31, height 40; width = Σ car lengths + gap × (n−1) + 4; drawn from x = 2; rendered height
  `height`, width scaled proportionally.
- Families (`family`, `:17-61`): `x2000` (cab coach 46 + 4 coaches 44 + power car 38 blunt, gap 2); `coradia` (4 × 40
  round); `regina` (3 × 48 round); `contessa` (3 × 48 sloped); `flirt` (5 × 36 sloped); `x3` (4 × 42 pointy);
  `double_deck` (4 × 44 round, double); `loco` (4 coaches 46 + loco 30 cab, gap 2); `loco_sleeper` (sleepers);
  `railcar` (1 × 52 cab/cab); `steam` (2 wooden 34, tender 16, steam engine 34); default 3 × 44 round.
- Nose path shapes (`outline`, `:64-85`), windows/doors/louvres per kind (`windows`, `:87-115`), pantograph on power/loco
  /first EMU car, steel gradient `#eef1f5 → #c3c9d1 → #8e96a1`, glass `#262c35`, livery stripe (height 2.2 at bottom −
  5.5) in the given colour, skirt, bogies (two wheels r 2.2 at 18 %/82 %, tender 30 %/70%), rail line.
- Data: `data/train_types.json` gives each type's `art` family (e.g. x55 → regina, x74 → flirt, y31 → railcar).

### 3.13 Maps (`map/style.ts`, `map/RouteMap.tsx`, `map/MultiRouteMap.tsx`)

- **Basemap**: vector PMTiles from the server (`pmtiles://{origin}/api/map/basemap.pmtiles`), used only when
  `GET /api/map/status` returns a non-null `basemap` (fetched once per app session, `RouteMap.tsx:41-47`). Layers
  (`style.ts:61-116`): earth fill (land), water polygons, country borders dashed [3,2] 1 px, motorways from z6
  (0.5→1.5 px), towns from z8 (11 pt, 70 % opacity), cities from z3 (11→13 pt, sorted by population rank). Glyphs
  "Noto Sans Regular/Medium" served from the app (`/map/fonts/{fontstack}/{range}.pbf`, `style.ts:123`). Without a
  basemap: just the land-coloured background. Colours `DARK`/`LIGHT` (`style.ts:7-36`). Swift: MapLibre Native iOS
  can read the same PMTiles and style JSON (bundle the glyph PBFs or host them).
- **Rail network** overlay (`style.ts:132-151`): GeoJSON from `GET /api/map/rail-network.geojson`; lines 1 px `rail`
  colour; station points r 1.6 from z9.
- **Route layers** (`routeLayers`, `style.ts:154-205`): context (rest of the train's route) 2 px dashed [2,2] at 30 %;
  ahead 4 px dashed [1.5,1.5] at 80 %; glow 12 px blur 6 at 35 %; body 4 px at 85 %; core 1.5 px of the colour
  lightened 55 % toward white (`lighten`, `:48-57`); mid stops r 3 white with bg/text ring 1.5; end stops r 6 colour with
  white ring 2; end labels Noto Sans Medium 13 with variable anchor and halo.
- `opColor(brand)` (`:39`): the operator's `brandColor`, else `#f8d64a` (dark) / `#0a0a0a` (light).
- **RouteMap** (`RouteMap.tsx:133-338`): fit to the route (or stops) with padding {72, 96, 64, 72} (interactive with
  controls) or {28, 28, 56, 56} (mini), max zoom 13; refit (animated 1.2 s) when the route changes unless following.
  Draw-on (trip detail, `animate`, not live, not reduced motion): the line grows from the start over 1.2 s ease-out
  cubic by length; end dots first, all stops at the end (`:196-213`). Live split: `splitAt(route, progress)` by length
  fraction into travelled (solid) and ahead (dashed) (`:120-127`). Train marker: 14 pt operator-colour dot with a 2 pt
  white ring, white heading chevron rotated to bearing (hidden without bearing), pulsing halo (scale 1 → 2.4, 0.5 → 0
  opacity, 1.8 s loop); estimated → hollow (bg fill, 3 pt operator ring) (`:251-277`, `styles.css:426-431`).
  Controls: Layers toggle (rail network; added lazily on first switch-on, `:280-288`), Follow train (only with a train;
  keeps the camera centred, 800 ms ease; any drag turns it off), Recenter (refit, stops following). "Map unavailable"
  fallback text if the map can't be created. Attribution "© OpenStreetMap contributors · Protomaps".
- **MultiRouteMap** (Passport, Journey; `MultiRouteMap.tsx:33-141`): fit all route points, padding 36, max zoom 10;
  every route as glow (10 px blur 5 at 22 %, so overlaps get brighter) + body (2.5 px at 75 %); station dots radius by
  visit count (1 → 3, 10 → 7, 50 → 11), white with bg ring 1.5, bigger ones on top. Rebuilt when the route set or the
  rail-network flag changes. Non-interactive? **[unclear: `interactive` isn't set, so the MapLibre default
  (interactive) applies]**.
- All maps are re-created when the theme changes.

### 3.14 Milestones and medals (client side: `components/Medal.tsx`, `PassportPage.tsx:59-63`)

Achieved/next milestones come from the server. The client:
- `milestoneLabel(t, m)` (`PassportPage.tsx:59-63`): distanceKm ≥ 40 000 → `passport.milestone.earth`; distanceKm →
  `passport.milestone.distanceKm` (n with locale grouping); journeys 1 → `passport.milestone.firstJourney`; else
  `passport.milestone.<family>` with count.
- Medal drawing (`Medal.tsx:51-100`), viewBox 120 × 150: ribbon (two coloured polygons + shadow notch), rim circle r 43
  with a metal gradient, face r 34 with the family gradient, highlight rings, centre text (Space Grotesk via CSS; 26 pt,
  21 pt when > 3 chars) with a small family icon above, or a large icon when there is no number; shine ellipse.
  Family face colours (`:9-17`), icons (`:18`; ≥ 40 000 km uses a globe), metals bronze/silver/gold/platinum
  (`:19-24`). Metal level (`metalFor`, `:36-41`): single-level families → gold; else index of target in `LEVELS`
  (`:26-34`, mirrors the server's `MILESTONES`) × 4 / count, floored. Locked medals are greyed (CSS) with a progress arc
  (r 38.5, stroke 8.5, accent, starting at 12 o'clock) of `value/target`.
- `bare` (share cards) omits the number so the card can draw it.

### 3.15 Passport flavour lines (`PassportPage.tsx:200-217`)
Cycle on tap, in this order, skipping empty ones: earth laps ≥ 1 → `passport.flavor.earth` (1 decimal) / ≥ 0.01 →
`passport.flavor.earthPct` (%); Sweden lengths ≥ 0.05 → `passport.flavor.sweden`; minutes > 0 → `passport.flavor.time`;
top route → `passport.flavor.route`; busiest month (`YYYY-MM`) → `passport.flavor.month` (month long + year);
late minutes ≥ 30 → `passport.flavor.late`. Index resets only on remount.

### 3.16 Station maps (`map/StationScene.tsx`, shared `station.ts`)

**Data**: `GET /api/stations/:id/map` returns one `StationMap` (repo files `data/stations/<stationId>.json`, 15
stations today: Stockholm C (4 levels, rotation 35°), Göteborg C, Malmö C, Alvesta, Uppsala C, Hässleholm,
Helsingborg C, Karlstad C, Halmstad C, Jönköping C, Lund C, Katrineholm C, Kristianstad C, Gävle C, Växjö; all
`osm_draft`). `StationInfo.hasMap` says whether one exists. Coordinates are metres in a local frame (x east, y south),
origin lat/lon given; `view.rotation` degrees rotates the plan so platforms run up the screen.

**Rendering** (SVG; port to SwiftUI `Canvas` or Core Graphics):
- World transform: translate(tx, ty) · scale(k) · rotate(rotation). Labels, pins, chips and icons are drawn at world
  points but counter-rotated and scaled 1/k so they stay upright and screen-sized (`at()`, `:216`).
- Plan (`Plan`, `:357-397`), bottom to top: building polygons (all levels) in surface colour; **other levels'
  platforms as a faint ghost** (text colour 5 %); this level's hall/room/shop polygons (stroke 0.6/k); track polylines
  (stroke 1.1/k, 40 % text-3); POI unit outlines tinted by category; this level's platforms (single fill); when
  k > 2.2, small squares for stairs/escalators/lifts (5/k).
- Selected POI outline highlighted.
- Route on this level: per step polyline (edge geometry, reversed when walked backwards; straight when missing) as a
  glow (10/k) plus marching dots (4.5/k wide, dash 0 / 10/k; dashes animate at 0.9 s per cycle unless reduced
  motion) (`:274-286`, `styles.css:724-727`).
- Level-change glyph (circle r 11, up/down arrows) at each stairs/escalator/lift step touching this level.
- Platform chips (`:220-234, 300-308`): one per platform node on this level, label = platform `ref`; unmarked chips
  within 28 screen px merge ("3/4", numeric sort); marked chips (arrive/depart) use the operator colour with a white
  stroke, width max(40, 6.6 × chars + 16); unmarked width max(22, 7.5 × chars + 10); unmarked chips overlapping a
  marked one are hidden.
- POI pins (`:236-261, 310-334`): circle r 12 with category icon (Lucide mapping `POI_ICONS`, `:25-40`), state dot
  (open green / closing soon orange / closed grey) or "?" for unknown; dimmed (32 % opacity) when filtered out or
  closed. De-cluttered: one pin per 26 px screen cell, ranked toilets first, then open → closing → unknown → closed, dimmed
  last. Names (≤ 18 chars, ellipsis) only when k > 3.2, one per 96 × 30 px cell, under the pin.
- Pins for non-platform ends: dot r 6.5 (+ halo r 16 for "me") and a label bubble above (width ≤ 190, text ≤ 28
  chars); from = text colour, to = accent, me = blue.
- **Fit** (`:129-160`), re-run when `fitTo` (from|to|level) or the size changes: points = route nodes, else the chosen
  ends (±60 m), else POIs (15th–85th percentile ± 25 m), else platform outlines; scale k = min(route ? 9 : 40,
  max(0.5, availW / max(dx, 20)), max(0.5, availH / max(dy, 20))); padding (route with marks 110/40, route 70/40,
  else 16/16); insets top 140 and bottom 250 (layover) / 320 (route/planning) / 150, right 60 (level buttons).
- **Gestures** (`:163-212`): one finger pans; two fingers pinch-zoom around their midpoint; wheel zoom; k clamped
  [0.3, 40]; a tap counts only if the pointer didn't move. Swift: `MagnificationGesture` + `DragGesture`, hit-testing
  for POIs and platform chips.

**Routing** (`station.ts`): Dijkstra over an undirected edge graph (`routeNodes`, `:182-228`) with per-profile edge
costs (`edgeSeconds`, `:157-164`): step-free excludes non-step-free edges; walk × pace (relaxed 1.25, normal 1, brisk
0.8); stairs × pace × (luggage 1.8) + (luggage 15 s); escalator × (luggage 1.2) + (luggage 5 s); lift unchanged.
`routeBetween` (`:301-307`): same platform → 30 s, same node → 0 s. Endpoints (`resolveEndpoint`, `:279-299`): track
spec → the platform whose `tracks` include the track with trailing letters stripped (`platformForTrack`,
`:255-259`, "17b" → "17"); `p:` POI → its node; `n:`/`me:` node. `secondsFrom` (`:231-252`) multi-source Dijkstra for
detours. `toLocal` (`:310-313`) equirectangular (111 320 × cos(lat0), 110 574). `nearestNode` (`:316-326`) on a level
among nodes used by some edge. `instructions` (`:338-355`): leave/start, merged consecutive walks, stairs/escalator/
lift up/down by level `order` (consecutive same kind merged), arrive/reach; seconds rounded.

**Multi-level navigation**: level chips switch the plan; tapping a step switches to that step's level; the initial level
follows the route start; other levels' platforms are ghosted.

### 3.17 Opening hours (`packages/shared/src/hours.ts`)
`parseHours` (`:147-188`) supports `24/7`, weekday lists/ranges (Mo–Su, wrapping), `PH`, several comma-separated spans,
spans past midnight, `off`/`closed`; rules split on `;` or ", " before a weekday; later rules override earlier ones;
anything else → unknown. Swedish public holidays incl. midsummer/christmas/new-year eves (`swedishHolidays`,
`:210-222`, Easter by the anonymous Gregorian algorithm). Evaluated in Europe/Stockholm wall clock (`isOpenAt`,
`:242-249`, including yesterday's past-midnight spans). `openState(text, from, to, soon=30)` (`:258-278`): single
moment → closed / open / closing_soon (closes within 30 min, with `closesAt`); window → open (whole window) /
closing_soon (open part of it) / closed. Checked minute by minute.

### 3.18 Share cards (`share/shareCard.ts`, `share/mapSnapshot.ts`, `share/ShareSheet.tsx`)

**Card**: 1080 × 1350 px PNG (`shareCard.ts:9-10`), margin 64, colours bg `#0a0a0a`, surface `#161616`, text white,
text-2 `#a6a6a6`, accent `#f8d64a` (always dark, regardless of theme). Fonts: display Space Grotesk, body Inter.
Drawn after fonts are ready (`:247`).
- Background (`:80-97`): fill; radial yellow glow 20 % → 0 from (0.95 W, 0) radius W; concentric guilloche rings
  (stroke 5 % yellow, 1.5 px) centred (0.9 W, 0.05 H), radius 40…1500 step 22.
- Header (`:99-124`): wordmark at (64, 52), size 36: five rounded tiles (radius 7, tile 0.95 × size wide, 1.18 × tall,
  gap 5), `#1f1f1f` with white letters, last yellow with black letter, weight 800; tagline (700 20 px text-2) at x =
  end + 14, y 82; kicker uppercase (800 26 px accent) at (64, 168).
- `fitText` (`:52-77`): shrink from `size` to `minSize` in steps of 2 until it fits; else wrap at min size to ≤ 2 lines
  with an ellipsis.
- **Stats layout** (`:276-310`): title (800, 72→44, ≤ 2 lines) from y 172; map box at title bottom + 30, width 952,
  height 500 − 70 × (extra title lines) + (no medals ? 40 : 0), radius 32 (`drawMap`, `:127-208`): the snapshot drawn
  "cover" (keep aspect, centred), else the route lines projected equirectangularly to fit (w − 180, h − 180) as a glow
  (18 px, 18 %) and a 7 px yellow line, else a dotted bezier motif; station labels (700 28 px with a dark 7 px stroke,
  above or below depending on half, clamped inside); thin 8 % white rim. Hero value (700 140 px) at map bottom + 140
  with the unit (700 52 px text-2); stats row 78 below (value 700 54 px, label uppercase 700 22 px, equal columns); up
  to 4 medals below (104 px wide, shadow, label 700 20 px).
- **Medal layout** (`:255-274`): one medal 460 px wide centred at y 210; title centred at y 900 (72→44); sub
  (600 30 px) 56 below; divider; centred stats row 230 below the title block.
- Medal images (`drawMedal`, `:211-227`): the Passport medal SVG rendered without its number (240 px off screen,
  `ShareSheet.tsx:229-233`), drawn with a shadow, then the number in Space Grotesk 800 at 72 % black.
- **Content per card** (`ShareSheet.tsx:67-129`) — never times, ticket details, train numbers or current position:
  - Year: kicker `share.yearKicker`, title `share.yearTitle` (year), hero distance (number without unit) + unit,
    stats journeys / time on board (`share.onBoard`) / stations, map of that year's routes, medals achieved that year
    (max 4).
  - All time: `share.allKicker`, `share.allTitle`, hero distance, stats journeys / stations / countries
    (`share.countries`), all routes, first 4 medals.
  - Journey: kicker "`share.featured` · Month Year", title "A → B", hero leg distance, stats duration on board (actual
    times if known) and operator (`share.operator`), the one route with end labels (when it has exactly 2 end points),
    medals that leg earned.
  - Medal: `share.medalKicker`, title = milestone label, sub `share.unlocked` (month year), stats total distance /
    journeys / stations.
- **Map snapshot** (`mapSnapshot.ts:19-82`): an off-screen 476 × 250 pt map (half the box) at pixel ratio 2 with the
  dark basemap, the rail network (station dots disabled), routes as accent glow (12 px, blur 6, 30 %) + 4 px line, end
  points r 5 `#0a0a0a` with white 2.5 ring; fit with padding 56/56/64/64, max zoom 10, no animation; waits for `idle`
  (≤ 8 s; load timeout 10 s); copies the canvas and projects the label points. Cached per (variant, routes) while the
  sheet lives. Failure → null → lines-only fallback. Swift: `MLNMapSnapshotter` with the same style, or draw the lines
  only.

### 3.19 Operator badge (`components/OperatorBadge.tsx:13-41`)
- With logos enabled (`VITE_OPERATOR_LOGOS != 'false'`; **the App Store build sets it to false**, `.env.ios`) and an
  operator `logoUrl` (server path `/api/operators/:id/logo`, loaded with `?u=`), show the image (radius
  round(size × 0.28)); on load error fall back.
- Otherwise a rounded square in `brandColor` (unknown operator `#3a4555`) with `shortName` (or "?") in white 800 with a
  text shadow; font size = size × 0.36, or × 0.30 when the label is longer than 2 chars; radius round(size × 0.28).
  **[doc differs]** DESIGN §2.3 says badge radius 10; SPEC §18 says logos live in `apps/web/public/operators/` (they're
  served by the server, from `data/logos/`).
- Sizes used: 18, 20, 22, 24, 26, 28, 30, 32, 36 (default).

### 3.20 CO₂
Computed **server-side** (`/passport` → `co2 {comparison, trainKg, comparisonKg, savedKg}`; factors in
`data/co2_factors.json`). The client only switches the comparison (`flight`/`car_1`) and formats the numbers.

### 3.21 Other client rules worth keeping
- Round flags (`components/Flag.tsx`): SE, DK, NO, DE, AT drawn as SVG in a circle; any other country a grey disc.
  **FI** has a country name but no flag (grey disc) **[unclear: intended?]**.
- Alerts can be dismissed per trip and situation (§5 `clack.dismissedAlerts`, keeps the last 200 keys).
- Device identity (`apiBase.ts:25-38`): with a remote server, a random UUID on first launch (`clack.user`), sent as
  `X-Clack-User` / `?u=`; deleting data forgets it. Swift: store in Keychain; same header name. Never send the owner's
  email anywhere (CLAUDE.md).
- Status bar style follows the resolved theme (`native.ts:9-12`).

---

## 4. Settings (`Settings`, `packages/shared/src/index.ts:35-66`; UI `pages/SettingsPage.tsx`)

All settings are stored **on the server** per user: `GET /api/settings` at app start (`settings.tsx:22-27`), `PATCH
/api/settings` with a partial object on each change (optimistic; on failure revert and show `settings.saveError`,
`:38-48`). Validation rules in `mergeSettings` (`index.ts:69-118`). Until loaded, `DEFAULT_SETTINGS` apply (and the
splash stays up).

| Key | Values (default) | UI | Effect |
| --- | --- | --- | --- |
| `theme` | `system` · `dark` · `light` (**dark**) | 3-way segmented, `settings.themes.*` | Applies colours; also copied to `localStorage['clack.theme']` so the next launch paints the right theme before settings load (`theme.ts:27-40`, `index.html`). `system` follows the phone. Maps re-create. Status bar style. |
| `displayName` | string ≤ 60, trimmed (`''`) | text field, saved on blur | **[unclear]** stored but not shown anywhere in the web UI (type comment says "initials in the avatar"). |
| `language` | `en` · `sv` (**en**) | menu `settings.languages.*` | UI language and date/number locale. |
| `distanceUnit` | `km` · `mi` (**km**) | menu `settings.units.*` | All distances. |
| `clock` | `24h` · `12h` (**24h**) | menu `settings.clocks.*` | All times. |
| `co2Comparison` | server accepts `flight, car_1, car_2, car_3, car_avg, ev_1, coach`; UI offers `CO2_CHOICES` = `flight`, `car_1` (**car_1**) | menu `settings.co2.*` | Initial comparison on the Passport and share cards. |
| `includeCommuter` | bool (**true**) | switch | Passport and share-card stats include commuter legs; Board's commuter filter default. |
| `showRailNetwork` | bool (**true**) | switch | Rail network layer under routes on trip detail, Journey and Passport maps (the RouteMap toggle starts from it). Explore always shows it. |
| `walkPace` | `relaxed` · `normal` · `brisk` (**normal**) | menu `settings.paces.*` | Walk times in connections and station maps. |
| `stepFree` | bool (**false**) | switch | Routes avoid stairs; "no step-free route" messages. |
| `heavyLuggage` | bool (**false**) | switch | Slower stairs/escalators. |

Device-only preferences (not settings): last tab, theme copy, dismissed alerts, ticket hand-off (§5). The laptop
layout key is web-only.

---

## 5. Browser storage keys

`localStorage` (all wrapped in try/catch; private mode just forgets):

| Key | Holds | Written / read in |
| --- | --- | --- |
| `clack.user` | This phone's random UUID (only when talking to a remote server). | `apiBase.ts:25-38`, removed by `forgetDeviceId` (`:41-47`) / `forgetLocalData`. |
| `clack.theme` | `system` · `dark` · `light`, a copy of the server setting for first paint. | `theme.ts:8, 13-21, 27-31`; `index.html` inline script. |
| `clack.lastTab` | `trips` · `explore` · `passport`. | `landing.ts:50-65`. |
| `clack.offline:<path>` | JSON body of a kept GET (§3.4). | `offline.ts:9, 18-47`. |
| `clack.offline.index` | JSON array of kept paths, LRU order, ≤ 60. | `offline.ts:10, 21-25`. |
| `clack.dismissedAlerts` | JSON array of dismissed alert keys (`disruption:<legId>:<kinds>`, `risk:<legId>:<kinds>`), last 200 kept. | `components/Alert.tsx:11-31`. |
| `clack.ticketPending` | JSON `{operatorId, trainNumber, from{name,time,tz,seq}, to{…}, tripKey, serviceDate, at, site}`, valid 3 h. | `components/Tickets.tsx:23-46`. |
| `clack.layout` | `phone` · `full` (desktop phone frame). Web only, not needed. | `PhoneFrame.tsx:7-24`. |

`sessionStorage`: `clack.landed` = `'1'` once the landing decision ran this session (`components/AppShell.tsx:29-30`).
Swift: an in-memory "launched" flag per process.

Cache Storage (web only): `clack-shell-v1` (service worker app shell, `public/sw.js`).

"Delete my data" removes every `clack.*` localStorage key (`offline.ts:32-38`).

---

## 6. Parity checklist per screen

**App shell / launch**
- [ ] Splash: wordmark tiles flip in (60 ms stagger), tagline; stays ≥ 900 ms and until settings load; 400 ms fade.
- [ ] First paint uses the last theme (stored copy) before the server answers.
- [ ] Tab bar Trips · Explore · Passport, icons and active colours as specified.
- [ ] Landing: running or ≤ 3 h departure (incl. cancelled) → Trips; else last tab; else Explore; decided once per
      launch; a tap before `GET /legs` returns cancels it; failure → last tab.
- [ ] Offline banner appears on request failure/timeout (15 s) and disappears on the next response.
- [ ] Ticket return prompt appears when returning > 5 s after a Buy tap (≤ 3 h), adds the trip, handles 409.

**Trips**
- [ ] Upcoming/Past split by `arrivalOf` (late running trains stay upcoming).
- [ ] Featured: active > next > arrived < 6 h; never repeated in the list; map tag texts per state.
- [ ] Featured map shows a train marker and solid/dashed split only with a fresh (< 2 min) position.
- [ ] Featured times flip in on first show; struck timetable times when changed; "+1" after midnight.
- [ ] Countdown strings ("Departs in 2d 3h", "1h 5m", "24 min", Boarding ≤ 30 min, Live now, Arrived, Cancelled).
- [ ] HeroConnection replaces the live module when the next journey leg starts at this destination.
- [ ] Layover line between meeting trips, struck planned duration, red when missed, links to the station map when one
      exists.
- [ ] Following section with next stop/ETA or "not running"; opens Explore with the train focused.
- [ ] Past: review cards first (Yes/No updates in place), month headers, journey cards with transfer chips, not-taken
      rows dimmed.
- [ ] Live SSE updates move the featured progress without reloading.
- [ ] Empty, loading (3 skeletons), error with Retry.

**Journey**
- [ ] Door-to-door duration, trains count, total distance; combined map; ConnectionCard vs TransferChip choice;
      reload on live updates ≤ every 20 s; not-found state.

**Trip detail**
- [ ] Stage card switches before/during/after by the rules in §2.3.
- [ ] Map draw-on 1.2 s on first open (not when live or reduced motion); train marker hollow when estimated;
      Follow/Recenter/Layers; back and "show all trains" buttons.
- [ ] Live tick: marker moves immediately, leg refetched, toast for non-departed events (6 s).
- [ ] After 60 s without updates the phone dead-reckons (chip "No connection", source "estimated from the last report").
- [ ] TimeBlocks align (placeholder rows), split-flap times flip in, platform chips.
- [ ] Delay tile toggles the explanation text (late/early/on time/unknown, pluralised).
- [ ] Stop timeline: full-route toggle, estimates in italics, delay colours, platform-changed icon, "no live data" for
      unreported stops, station names open boards.
- [ ] Disruption card kinds, tone, title, reasons, alternatives (direct + with change, Live / Use instead), rights text
      and links, dismiss per situation.
- [ ] Risk card only before departure, refreshed every 5 min, dismissible.
- [ ] Welcome card within 60 min of arrival with Passport progress animation.
- [ ] Ride record line and buttons (Yes/No, Not taken, Undo, See Passport).
- [ ] Train card: picture rules (§3.12), source chip and note, facts, type picker and reset.
- [ ] On-board facts vs typical claims, sources and checked date.
- [ ] Activity log texts; Details quality/border notes; Refresh hidden when snapshotted; Delete with confirmation.
- [ ] Opens offline from the kept copy; "not kept" message otherwise; 404 → not found.

**Add a train**
- [ ] Date chips (Today/Tomorrow/Pick), past-trip hint, max +365 days.
- [ ] 150 ms debounced search; interpretation chips removable and rebuilding the query; station picking writes
      "Name → ".
- [ ] Archive states with automatic re-search (3 s loading, 15 s failed); Norway message.
- [ ] Filters All/Long/Regional/Commuter; result cards with silhouette and product; "N stops"/"Direct"; aka numbers.
- [ ] No-result messages; connection results and the two-leg save with duplicate handling.
- [ ] Confirm: mini map with context, From/To selector (To active first), stop tap rules and restrictions, distance
      (≈ when estimated), duplicate banner + Add anyway, Buy ticket for future trains.
- [ ] Manual add form validation and save.
- [ ] `?trip=` prefill goes straight to Confirm, Back returns; `replace=` marks the old leg not taken.
- [ ] Done: check stroke animation, Passport progress for past trips, View trip / Add another.

**Explore**
- [ ] Opens on Sweden+Norway bounds; clusters to z6; discs with heading cones; own trips yellow halo; followed white
      ring; selected enlarged.
- [ ] Bbox SSE re-subscribed 400 ms after panning; snapshot/delta/moved merge; 1.5 s glide at z ≥ 7 on screen.
- [ ] Status chip states (loading, unavailable after 20 s silence or stopped, delayed > 60 s, none here/none match,
      N trains running / simulated).
- [ ] Station squares/labels appear by zoom and departures-per-day thresholds; tap opens the station sheet (labels
      always; squares only when no train under the finger).
- [ ] Search: trains by number prefix (running only), stations (≥ 2 chars, not numeric); picking flies there.
- [ ] Filters: products, delayed > 5, mine, followed, operators present; count badge; clear.
- [ ] Train sheet: 3 detents with drag/flick rules; title tap folds; picture/type; next stop; delay; position label
      (GPS < 2 min / GPS n min old / estimated); speed; updated ago; stop list refreshing every 30 s; on-board; Buy
      ticket from the next stop; Follow; In your trips / Plan.
- [ ] Selected route solid behind / dashed ahead, never moving backwards.
- [ ] `?train=` focus: live → select; else after first snapshot or 4 s → scheduled sheet or not-running sheet.
- [ ] Scheduled sheet status texts and 30 s refresh; Not-running sheet with Unfollow.

**Passport**
- [ ] Year chips; review banner; empty state.
- [ ] Yellow passport card: distance in unit, flavour line cycling on tap, 4 tiles, MRZ line exactly as specified.
- [ ] Map of all routes with glow build-up and visit-sized dots.
- [ ] Milestones: first 6 + show all; links to the leg; next 3 locked with progress ring; pop-in animation.
- [ ] Operators/products bars, train types with silhouettes, countries with flags and border count, stations (12 +
      show all) linking to boards.
- [ ] Records (links where a leg), delay stats with band bar and legend %, CO₂ with Flying/Car toggle re-fetching.
- [ ] Share icon only when trains > 0.

**Share sheet**
- [ ] Four variants; medal disabled without medals; journey and medal pickers; defaults (longest trip, first medal).
- [ ] PNG 1080 × 1350 matches the layout in §3.18 (fonts, sizes, positions); real map snapshot with fallback.
- [ ] Save to Photos/Files and system share; long names shrink then wrap.

**Stations / Board**
- [ ] Favourites, recent (minus favourites), popular (minus both); 120 ms search; no Trafikverket codes shown.
- [ ] Board SSE live; Live/Stale chip by 2 min; departures/arrivals; windows 1h/3h/day; commuter default from settings;
      product and operator filters only when relevant; show earlier (3 h); widen button; platform change highlight
      for 15 min; rows open Explore with the train; favourite toggle; viewed recorded.

**Station map**
- [ ] Plan per level with ghosted other-level platforms, rotation, upright screen-sized labels, pan/pinch, fit rules.
- [ ] POI pins de-cluttered, state dots, names at zoom; category filters; list view sorted by state.
- [ ] Level chips (+N/0/−N) when > 1 level; initial level from the route start.
- [ ] Directions: from/to pickers (tracks, entrances by compass, places, My location with radius rules), swap, close.
- [ ] Route drawn with marching dots per level; level-change glyphs; steps list switching levels.
- [ ] Layover Guide: arrive/depart chips with operator colours and times, walk minutes, connection chip, layover text.
- [ ] Opening states for now, a picked time, or the layover window; "along my path" with detour minutes; POI sheet with
      hours, fee, Route here / Start here.
- [ ] Step-free profile changes routes and shows "no step-free route".

**Settings / About / Privacy**
- [ ] Every setting in §4 saves immediately, reverts on failure with the error banner.
- [ ] Theme switch applies instantly (incl. maps and status bar), system follows the phone.
- [ ] Delete my data: confirmation, server delete, local wipe (incl. device id), "deleted" message.
- [ ] About and Privacy texts; contact only when configured; privacy date.

**Cross-cutting**
- [ ] Every string from the String Catalog in English and Swedish; plurals.
- [ ] Times in the station's zone; 12h/24h; km/mi.
- [ ] Reduced motion disables flips, pulses, draw-on, marching dots, pop-ins.
- [ ] Offline: legs, leg details, journeys, operators, train types, settings, amenities, station info and maps open
      from the cache.
- [ ] Operator logos shown (approved by the operators, docs/APP_STORE.md); initials badge when an operator has no logo.

---

## 7. Static data and assets

### 7.1 What the web app bundles

| Asset | Path | Notes |
| --- | --- | --- |
| UI strings | `apps/web/src/i18n/locales/en.json`, `sv.json` | 890 lines each. |
| Inter Variable font | npm `@fontsource-variable/inter` (`main.tsx:3`) | Body text. |
| Space Grotesk 600, 700 | npm `@fontsource/space-grotesk` (`main.tsx:4-5`) | Flap digits, big numbers, share cards. |
| Map glyphs (Noto Sans Regular, Noto Sans Medium) | `apps/web/public/map/fonts/<fontstack>/<range>.pbf` (ranges 0-255 … 8192-8447; OFL licence `OFL.txt`), ~1.2 MB | Used by every MapLibre style (`style.ts:123`). |
| App icons | `apps/web/public/icons/icon-192.png`, `icon-512.png`, `apple-touch-icon.png`; `apps/web/public/favicon.svg` | iOS uses `ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png`. |
| Splash images | `apps/web/ios/App/App/Assets.xcassets/Splash.imageset/splash-2732x2732*.png` | Native launch; the in-app splash is drawn in code. |
| Icons | npm `lucide-react` | Map to SF Symbols or bundle Lucide SVGs (names used: TrainFront, Compass, Stamp, Search, Plus, Settings, WifiOff, X, ArrowLeft, Radar, RefreshCw, Repeat, Trash2, Map, Clock, Eye, EyeOff, Check, ChevronDown/Up/Right, Info, SlidersHorizontal, Gauge, Layers, LocateFixed, Navigation, Share2, Download, Star, ExternalLink, AlertTriangle, Activity, Flag, Globe2, MapPin, Moon, Route, Ticket, DoorOpen, List, ArrowDownUp, ArrowUpDown, Coffee, Wifi, Plug, VolumeX, Crown, Baby, PawPrint, Bike, Accessibility, Toilet, BedDouble, TriangleAlert, Armchair, Banknote, ShoppingBasket, Bus, CarTaxiFront, Luggage, Pill, ShoppingBag, UtensilsCrossed, Maximize2, Smartphone). |
| Detailed train drawings | `apps/web/src/components/trains/*.tsx` (generated by `scripts/trains/*.py`) | Same drawings exported as 54 SVGs in `assets/trains/<model>-<livery>.svg` (`scripts/trains/export_svg.py`). |
| Family silhouettes | `apps/web/src/components/TrainArt.tsx` | Procedural, port the code. |
| Medals | `apps/web/src/components/Medal.tsx` | Procedural SVG. |
| Round flags | `apps/web/src/components/Flag.tsx` | SE, DK, NO, DE, AT. |
| Wordmark | `apps/web/src/components/Brand.tsx` + CSS | Drawn in code. |
| Constants/logic | `packages/shared/src/*` | delay, polyline, counties, onboard, hours, station, disruption, progress, settings. |

### 7.2 Loaded from the server at runtime (not bundled)

`/api/operators` (incl. brand colours, ticket URLs; logos from `/api/operators/:id/logo`, source `data/logos/`),
`/api/train-types` (`data/train_types.json`), `/api/amenities`, `/api/stations/:id/map` (`data/stations/*.json`),
`/api/map/status`, `/api/map/basemap.pmtiles` (range requests), `/api/map/rail-network.geojson`, everything else.

### 7.3 What the Swift app needs to bundle

- Inter (variable) and Space Grotesk (600, 700) font files, registered in Info.plist (licences: OFL).
- Noto Sans Regular/Medium glyph PBFs if MapLibre Native should render labels offline from the bundle (or host them
  on the server and point the style's `glyphs` there).
- The 54 train SVGs from `assets/trains/` (as SVG or converted to PDF/vector assets in the asset catalog), plus the
  `DETAILED` registry as data (§3.12). Note the `x61vt` file name for type `x61_vt`.
- App icon and launch screen (existing asset catalog).
- String Catalog converted from `en.json` and `sv.json` (keep keys; plurals from `_one`/`_other`).
- Icons (SF Symbols mapping or Lucide SVG set).
- No station-map, operator or train-type JSON needs bundling (server-provided and cached offline), unless the port
  wants a first-launch fallback **[decision for the brief]**.
- Build-time config: API base URL (https), support email (optional), operator-logos flag (on: the operators approved it, docs/APP_STORE.md).
