# Clack in Swift: moving to the Mac and porting the app

This is the plan the native SwiftUI iPhone app was built from, written for Claude working on the Mac: the decisions,
the rules and the build order. Each step was one session of work. All fifteen steps and the native-only features (B9)
are done; later work is tracked as workstreams A to J ("Clack: from ported to stellar"), see the end of this file.

The server did not change for the port. The Swift app is the only client. The web app that came first (`apps/web`,
removed after the port) was the "parity target": where this file or the files in `swift-port/` cite it, read its last
state with `git show 787192a:apps/web/src/<path>`.

Three reference files go with this one, written from the code on 2026-10-23 (line numbers may drift; the code wins):

- [`swift-port/API.md`](swift-port/API.md): every server endpoint and stream, field by field, with units and errors.
- [`swift-port/SCREENS.md`](swift-port/SCREENS.md): every screen, sheet and piece of client logic, with a parity
  checklist per screen.
- [`swift-port/DESIGN_SYSTEM.md`](swift-port/DESIGN_SYSTEM.md): every colour, radius, font, animation, map style and
  icon.

---

# Part B: the port (Claude)

## B0. Rules for every step

- **Read first:** `CLAUDE.md`, this file, and the reference file(s) the step names. Before writing a screen, read its
  section in `swift-port/SCREENS.md` **and the web source it cites**; the web code is the parity target.
- **Accuracy rules carry over unchanged:** nothing made up; show less rather than guess (CLAUDE.md).
- **The server doesn't change** unless a step says so. If a step can't be done without a server change, stop and say
  why. Server changes come with tests (`npm test`).
- **Build after every change** (Xcode via the MCP connection, or
  `xcodebuild -project apps/Clack/Clack.xcodeproj -scheme Clack -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`)
  and fix every error and warning before saying a step is done.
- **Port the tests too.** Where the TypeScript has tests (listed per step), write the same cases as Swift Testing tests
  in `ClackTests` and make them pass. Same inputs, same expected outputs.
- **Each step ends** with: a clean build, passing tests, a short list for Garner of what to check in the simulator,
  and a commit once he's checked it (CLAUDE.md commit rules; commit only your own files, by path).
- **Don't edit generated copies.** `apps/Clack/Clack/Resources/i18n/*.json`, `Assets.xcassets/Trains/` and
  `AppIcon.appiconset` are written by `scripts/ios/sync_assets.py`; change the originals and re-run it.
- **New files go in the folders below.** Xcode's project uses synchronized folders, so a file Claude creates under
  `apps/Clack/Clack/` is part of the app without editing the project file. Don't hand-edit `project.pbxproj` unless
  there's no other way; settings changes go through Xcode (ask Garner) or the build settings UI.

## B1. Decisions (fixed)

| Topic | Decision | Why |
|---|---|---|
| UI | SwiftUI, iOS 17 minimum, iPhone only, portrait | `@Observable`, the newer MapKit/SwiftUI APIs, `sensoryFeedback`; iOS 17 covers almost every iPhone in use. |
| State | Observation (`@Observable` classes), no third-party state libraries | Built in, works with SwiftUI. |
| Concurrency | Swift 6 language mode as the Xcode template sets it; UI and models on the main actor; networking in `nonisolated` async functions or an actor | Matches the template's defaults; no data races. |
| Networking | `URLSession` with async/await; one `APIClient`; Server-Sent Events read with `URLSession.bytes(for:)` | No dependencies. |
| Models | `Codable` structs mirroring API.md exactly | One source of truth: the server. |
| Maps | MapLibre Native (a Swift package), with a style built in code from `apps/web/src/map/style.ts` | Same look and the same tiles as the web; the server serves plain z/x/y tiles and the label fonts for it (B2). |
| Strings | The web's `en.json`/`sv.json`, read at runtime by `L10n` (B5), same keys | One set of texts for both apps; 764 strings already translated and tested. |
| Train pictures | The SVGs in `assets/trains/`, in the asset catalog (B7) | Drawn once, used everywhere. |
| Identity | Random UUID v4 in the Keychain, sent as `X-Clack-User` | No sign-in (App Review 5.1.1(v)); survives reinstalls. "Delete my data" removes it. |
| Offline | JSON copies of the same GET responses the web keeps, in the Caches folder | Same behaviour as the web's offline mode. |
| Dependencies | MapLibre only. Ask Garner before adding any other package. | Fewer things to break or review. |
| Analytics, ads, tracking | None | Privacy answers in docs/APP_STORE.md depend on it. |

## B2. Where things go

```
apps/Clack/Clack/
  ClackApp.swift            app entry, scene, theme, splash
  App/                      AppModel (settings, identity, operators, train types, amenities), Router, Tabs
  API/                      APIClient, Endpoints, EventStream (SSE), OfflineCache, Reachability
  Models/                   Codable models (one file per area in API.md: Legs, Boards, LiveMap, Passport, ...)
  Logic/                    ports of shared logic: Format, Landing, LiveStatus, Progress (dead reckoning),
                            Polyline, Delay, Disruption, Hours, StationRouting, Onboard, Tickets
  Design/                   Tokens (colours, radii, fonts), components (Card, Chip, StatusText, SplitFlap,
                            OperatorBadge, Medal, TrainPicture, Buttons, SegmentedControl, Sheet)
  Map/                      MapStyle (port of style.ts), RouteMapView, MultiRouteMapView, LiveMapView, markers
  Features/
    Trips/  TripDetail/  Journey/  AddTrip/  Explore/  Passport/  Stations/  Board/  StationMap/
    Settings/  Share/  About/
  Resources/
    i18n/en.json, sv.json   (generated by scripts/ios/sync_assets.py)
    Fonts/                  Inter, Space Grotesk (B6)
  Assets.xcassets/          AppIcon, Trains/ (generated), Colors/
apps/Clack/ClackTests/      Swift Testing tests, one file per Logic/ file
```

**Server address** (`API/Config.swift`, a copy of the file as it is):

```swift
nonisolated enum Config {
    /// Where the Clack server is: the hosted one, on the internet, for every build on a phone. Only a debug build in the
    /// simulator uses the server running on this Mac (`npm run dev`), because that is where it is being worked on.
    /// `-apiBase https://...` as a launch argument points a debug build anywhere else.
    static let apiBase: URL = {
        let hosted = URL(string: "https://clack-garner.duckdns.org")!
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "apiBase"), let url = URL(string: override) { return url }
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:3001")!
        #else
        return hosted
        #endif
        #else
        return hosted
        #endif
    }()
    /// Operators' logos are trademarks; Garner has the operators' approval to use them (docs/APP_STORE.md, 5.2.1).
    static let showOperatorLogos = true
    /// Shown on the Privacy screen when set (docs/APP_STORE.md, 1.5).
    static let supportEmail: String? = nil
}
```

Every path in API.md is under `/api`: `Config.apiBase.appending(path: "api/legs")`.

**Map sources for MapLibre Native** (added to the server for this port; tested in `apps/server/test/mapTiles.test.ts`):

- Basemap: vector source, `tiles: ["<base>/api/map/tiles/{z}/{x}/{y}.mvt"]`, `minzoom: 0`, `maxzoom: 10` (MapLibre
  over-zooms above 10). Missing tiles answer 204. Layers as in `map/style.ts` (Protomaps layer names `earth`, `water`,
  `places`, `boundaries`, `roads`).
- Glyphs: `"<base>/api/map/fonts/{fontstack}/{range}.pbf"` (Noto Sans Regular, Noto Sans Medium).
- Rail network: GeoJSON source `"<base>/api/map/rail-network.geojson"`.
- `GET /api/map/status` tells whether the basemap exists yet (without one, draw the background only, like the web).
- Attribution text exactly as DESIGN_SYSTEM.md §5.1, bottom-left; MapLibre's own attribution button off.

## B3. Conventions for the code

- **Times:** REST legs, stops, live state and events send ISO strings; everything else sends epoch milliseconds
  (API.md §6). Decode every time field with one type that accepts both:

  ```swift
  struct Instant: Codable, Hashable, Comparable {
      let ms: Double
      var date: Date { Date(timeIntervalSince1970: ms / 1000) }
      init(from decoder: Decoder) throws {
          let c = try decoder.singleValueContainer()
          if let n = try? c.decode(Double.self) { ms = n; return }
          let s = try c.decode(String.self)
          guard let d = Instant.iso.date(from: s) ?? Instant.isoNoFraction.date(from: s) else {
              throw DecodingError.dataCorruptedError(in: c, debugDescription: "not a time: \(s)")
          }
          ms = d.timeIntervalSince1970 * 1000
      }
      // encode as ms; static ISO8601DateFormatter instances with and without .withFractionalSeconds
  }
  ```

- **Optional means optional:** every field API.md marks `?` or `| null` is optional in Swift. Unknown enum values
  must not fail decoding: give string enums an `unknown(String)` case (or decode them as `String` and map).
- **snake_case** only where the API has it (station maps, `max_kmh`): explicit `CodingKeys`, no global key strategy.
- **Ids in paths:** trip keys contain `:` and live-map ids contain `|`: percent-encode path segments.
- **Time zones:** format every time in its station's `tz` (API.md, Format below). Never the phone's zone.
- **Strings:** never write user-facing text in Swift; use `L10n` keys from en.json/sv.json. A new string means a new
  key in **both** JSON files (the web's `locales.test.ts` checks they match) and re-running the sync script.
- **Accessibility:** every icon-only button has a label from the strings; support Dynamic Type for body text; respect
  Reduce Motion (skip flips, draw-ons and glides, as the web does).

## B4. Identity, requests and streams

- `Identity`: on first launch create `UUID().uuidString.lowercased()` and store it in the Keychain
  (`kSecClassGenericPassword`, service `clack.user`, accessible after first unlock). Send it on every request as
  `X-Clack-User`. "Delete my data" (`DELETE /api/me`) deletes the Keychain item, the offline cache and local
  preferences, then resets the in-memory state to a fresh launch.
- `APIClient.request`: JSON body only when there is one (`Content-Type: application/json` only then: Fastify rejects
  an empty JSON body); 15 s timeout for GETs; 204 means no body; non-2xx decodes `{ error, duplicateOf? }` into an
  `APIError`. A network failure or timeout on a GET falls back to `OfflineCache` and marks the app offline (banner).
- `OfflineCache`: stores successful GETs whose path matches the web's list (API.md §1, `offline.ts:14`), at most 60
  entries, oldest dropped. Never live data.
- `EventStream`: `URLSession.bytes(for:)` with the header; parse `event:`/`data:` lines, skip `:` comments, dispatch
  on a blank line; reconnect 5 s after a drop (the server says `retry: 5000`); stop when the Task is cancelled. Use a
  session whose request timeout is longer than the heartbeat (120 s). Three streams use it: `/live/stream` (trip
  tracking; the server sends each phone only its own trips), `/stations/:id/board/stream`, `/live/trains/stream`
  (live map, with `snapshot`, `delta` and the 7-element `moved` tuples, API.md §3.3).

## B5. Strings (L10n)

`Resources/i18n/en.json` and `sv.json` are the web's files, copied by `python3 scripts/ios/sync_assets.py`. Load both
at launch (they end up in the app bundle as `en.json` and `sv.json`).

- Keys are dot paths into the nested JSON: `L10n.t("trips.title")`.
- Interpolation: replace every `{{name}}` with the value: `L10n.t("live.updated", ["ago": "12 s"])`.
- Plurals: i18next style, only `_one` and `_other` (English and Swedish both use just these). With a `count`, use
  `key_one` when count == 1, else `key_other`, and `count` is also a `{{count}}` value:
  `L10n.t("add.stopsBetween", count: 3)`.
- Missing key: return the English text, else the key itself (the web does the same with `fallbackLng: 'en'`).
- The language is the `language` setting from the server (`en` default, not the phone's language), and it switches
  live. Make `L10n` observable so views update.
- Dates and numbers: locale `sv_SE` when the language is Swedish, else `en_GB` (format rules in B8, step 3).

## B6. Design system

All values are in `swift-port/DESIGN_SYSTEM.md`; DESIGN.md wins where they differ (its §0 conflicts were settled on
2026-10-23: DESIGN.md now matches the owner's later decisions).

- **Colours:** one Color Set per token in `Assets.xcassets/Colors/` with Any (light) and Dark appearances, named as in
  CSS (`bg`, `surface`, `text-2`, `accent`, `accent-ink`, `on-time`, `on-time-ink`, ...). The app follows the
  `theme` setting (`system` / `dark` / `light`, default `dark`) with `.preferredColorScheme`.
- **Radii:** one enum: `tag 6`, `controlSm 10`, `input 12`, `card 16`, `sheet 24`. Nothing fully rounded except
  circles (dots, badges' round flags, medals). The web still has a few hard-coded radii outside the scale
  (DESIGN_SYSTEM.md §0 row 11): use the nearest token instead.
- **Fonts:** Inter for text, Space Grotesk 600 and 700 for big numbers and the split-flap digits (800 is asked for in a
  few places on the web, but only 700 is loaded there, so 700 is what shows: use 700). Both are SIL OFL. Get the
  `.ttf` files from the projects' own releases ([Inter](https://github.com/rsms/inter/releases): `InterVariable.ttf`;
  [Space Grotesk](https://github.com/floriankarsten/space-grotesk/releases): SpaceGrotesk-SemiBold and -Bold), put
  them with their `OFL.txt` in `Resources/Fonts/`, and list them under **Fonts provided by application** in the
  target's Info. Tabular digits for every time, delay and stat: `.monospacedDigit()`.
- **Status is written, not boxed:** delays and live state are coloured text using the `-ink` colours, never pills.
- **Icons:** SF Symbols chosen to match the Lucide icons the web uses (DESIGN_SYSTEM.md §6 lists them per screen,
  with suggested symbols; check each one looks right).
- **Components to build first** (step 4): Card, Chip, StatusText/DelayText, SplitFlap, OperatorBadge (initials in
  the brand colour, radius = size × 0.28), primary/secondary buttons (radius `input`), segmented control, sheet
  frame, skeleton rows.

## B7. Train pictures

`sync_assets.py` puts every SVG from `assets/trains/` into `Assets.xcassets/Trains/` as `<model>-<livery>` with
**Preserve Vector Data** on. Check the first one renders correctly (gradients and clip paths) in the simulator; if a
drawing looks wrong, tell Garner which.

`TrainPicture` in Swift is a direct port of `apps/web/src/components/trains/TrainPicture.tsx` (read it):

- `DETAILED`: type id → model asset prefix, the liveries drawn for it, `liveryOf`, `notFor`. Note the one name that
  differs: type `x61_vt` uses the files `x61vt-*`.
- A drawn model, operator's livery drawn → `<model>-<livery>`; operator's livery not drawn → `<model>-plain`.
- Model not drawn, or the operator is in `notFor` → the nearest drawn model by family (`STAND_IN`, keyed by the type's
  `art`) as `-plain`, faded: a horizontal gradient mask from clear at the left to opaque at 60%, at 80% opacity.
- Type `uncertain`, or no type at all → the same stand-in (`x60` when there's no type), at 45% opacity.
- The web's caption rule stays: show the type's name, or `liveMap.typeUnknown` when there's no type.

## B8. Build order

Each step: what to build, what to read, the tests to port, and how Garner checks it. Do them in order; later steps
use earlier ones.

### Step 1. Foundation

- Run `python3 scripts/ios/sync_assets.py` (strings, train drawings, app icon into the project).
- Create `apps/Clack/CLAUDE.md` with one line pointing to the repository's `CLAUDE.md` and this file, so Claude Agent
  inside Xcode (whose project folder is `apps/Clack`) finds the rules too.
- `Config`, `Identity`, `APIClient` (B2, B4), `L10n` (B5), and the Models for settings, operators, train types,
  amenities and legs (API.md §2.2, §2.6, §2.8).
- `AppModel` that loads settings, operators, train types and amenities at launch.
- A temporary screen listing `GET /api/legs` (route and date per leg) to prove it all works.
- Tests: `L10n` (interpolation, plurals, fallback), `Instant` decoding (ISO with and without fractions, ms),
  decoding a real `/api/legs` response (save one from the running server as a test fixture).
- **Garner checks:** the simulator shows the trips the web app shows at localhost:5173 (if the web app has none, add
  one there first).

### Step 2. Running on a real iPhone

- (Done) The Mac-hostname setting this step first asked for is gone: debug builds in the simulator use `localhost:3001`.
- **Garner checks:** with `npm run dev:phone` running, the app on his iPhone shows the same list; iOS asks to allow
  local network access (allow).

### Step 3. Logic ports, with their tests

Port these pure functions to `Logic/`, each with the TypeScript test cases as Swift tests:

| Swift file | From | Tests to port |
|---|---|---|
| Format | `apps/web/src/format.ts` | `apps/web/src/format.test.ts` |
| Landing | `apps/web/src/landing.ts` | `apps/web/src/landing.test.ts` |
| LiveStatus | `apps/web/src/live.ts` (`statusKey`, freshness, `agoKey`) | cases from SCREENS.md §3.3 |
| Polyline | `packages/shared/src/polyline.ts` | `polyline.test.ts` |
| Delay | `packages/shared/src/delay.ts` | `delay.test.ts` |
| Progress | `packages/shared/src/progress.ts` (`liveView` and helpers) + `apps/web/src/offline.ts` `localLive` | server tests that cover `liveView` (`apps/server/test`, grep `liveView`) |
| Disruption | `packages/shared/src/disruption.ts` | `disruption.test.ts` |
| Hours | `packages/shared/src/hours.ts` | `hours.test.ts` |
| StationRouting | `packages/shared/src/station.ts` | `station.test.ts` |
| Onboard | `packages/shared/src/onboard.ts` (`typicalAmenities`) | cases from SCREENS.md §3.9 |
| Tickets | `apps/web/src/components/Tickets.tsx` (`ticketHref`) | `apps/web/src/tickets.test.ts` |
| Settings | `packages/shared/src/index.ts` (`Settings`, defaults, choices) | `settings.test.ts` (the validation parts the client needs) |

- **Garner checks:** nothing to see; Claude shows the test results (all passing, with the count per file).

### Step 4. Design system and app shell

- Colours, radii, fonts, components (B6). The splash (wordmark tiles flipping in, ≥ 900 ms and until settings load,
  400 ms fade; SCREENS.md §1.3) and the tab bar Trips · Explore · Passport (SCREENS.md §1.2) with empty screens, the
  Settings gear, the offline banner, the landing rule (step 3's `Landing`, run once per launch, cancelled by a tap).
- A hidden "Design" screen in Debug builds showing every component in both themes, for checking.
- **Garner checks:** splash, tabs, both themes, the design screen against the web app.

### Step 5. Trips

SCREENS.md §2.1 (Trips) and §2.2 (Journey), and the web files they cite. Featured card (without its map until step 8:
leave a placeholder), Upcoming/Past, leg rows, layover lines, Following, review cards, journey cards, the Journey
screen. Live updates from `/live/stream`.
- **Garner checks:** the parity checklist for Trips in SCREENS.md §6, side by side with the web app.

### Step 6. Trip detail

SCREENS.md §2.3, including Disruption, Risk, TrainCard (with the train picker), On board, Activity, Stops, Details,
the welcome card and TripProgress (§2.12). Map placeholder until step 8. Dead reckoning when updates stop (step 3's
Progress).
- **Garner checks:** SCREENS.md §6 Trip detail checklist; a trip that's running now if there is one.

### Step 7. Add a train

SCREENS.md §2.4: date row, search with its chips and suggestions, results, connections, confirm with the stop picker,
duplicates, manual trips, Done, the `?trip=` prefill and `replace`. Buy-ticket links open in Safari; the return prompt
(§3.7) when the app comes back.
- **Garner checks:** add the same train in both apps; both show the same trip.

### Step 8. Maps

`Map/MapStyle` from `map/style.ts` (both themes, sources from B2), then `RouteMapView` (trip detail and featured card:
the three-stroke route, travelled/ahead split, stops, train marker with halo, draw-on, fit with padding) and
`MultiRouteMapView` (journey and Passport). DESIGN_SYSTEM.md §5 has every value. Fill the placeholders from steps
5 and 6.
- **Garner checks:** a trip's map next to the web's: same route, colours, labels, attribution.

### Step 9. Explore (the live map)

SCREENS.md §2.5: the stream with bbox re-subscribe, clustering, train markers drawn like the web's canvas images,
your own trains and followed trains, gliding, station squares and labels, search, filters, legend, status chip, the
train sheet with three heights, scheduled and not-running sheets, the station sheet, `?train=` focus.
- **Garner checks:** SCREENS.md §6 Explore checklist; smooth panning with all of Sweden in view.

### Step 10. Stations and boards

SCREENS.md §2.7 and §2.8: search with favourites, recents and popular; the board with its stream, filters, "show
earlier", favourite star; tapping a row opens the train on Explore.

### Step 11. Station map and Layover Guide

SCREENS.md §2.10 and §3.16: the plan drawn with SwiftUI `Canvas` (levels, shapes, platforms, POIs), pan and zoom,
routing and directions from step 3's StationRouting, opening hours, place search, "My location" (Core Location, when
in use, only on tap; the position stays on the phone), the Layover Guide mode from a connection.

### Step 12. Passport and sharing

SCREENS.md §2.6, §2.11, §3.14, §3.15, §3.18: the passport card, map, milestones and medals, collections, records,
delays, CO₂. Share cards rendered with `ImageRenderer` (sizes and contents from §3.18; map image from MapLibre's
snapshotter), shared with `ShareLink`.

### Step 13. Settings, About, Privacy, Delete my data

SCREENS.md §2.9, §2.13, §4. Delete my data as in B4.

### Step 14. Polish and parity pass

Go through every checklist in SCREENS.md §6 with Garner. Haptics where iOS apps use them (`sensoryFeedback` on
follow, save, delete). VoiceOver labels. Dynamic Type. Reduce Motion. Launch screen in both themes.

### Step 15. Ship

Follow docs/APP_STORE.md and docs/SERVER.md: `Config.apiBase` for Release (done), the privacy manifest (done), Swedish
location text (done), TestFlight. The Capacitor wrapper and the web app were removed from the repository before
shipping.

## B9. After the port: native-only features (done)

Built, each as its own step: the Home Screen and Lock Screen widgets, the Live Activity for the train you are on, and
alerts sent by the server's push (docs/IOS.md). Ticket import from the share sheet and offline mode are built too.

---

Later work is tracked as workstreams A to J ("Clack: from ported to stellar"), not as steps in this file.
