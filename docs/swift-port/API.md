# Clack HTTP API inventory (for the SwiftUI port)

> The web app this file cites (`apps/web`) was removed from the repository; its last state is commit `787192a`.

Source of truth read for this: `apps/server/src/app.ts`, every `apps/server/src/routes/*.ts`, the server modules that
build each response (cited per endpoint), `packages/shared/src/*`, the removed web client's `apps/web/src/api.ts`, `apiBase.ts`, `live.ts`,
`offline.ts`, and every web file that calls `fetch`, `EventSource` or `apiUrl(`.

Notation: `field: Type` = always present; `field?: Type` = key may be absent; `| null` = key present, value may be
null. "ms" = UTC epoch milliseconds (JSON number). "ISO" = an ISO-8601 UTC string with milliseconds and `Z`, e.g.
`"2026-10-23T08:12:00.000Z"` (a server `Date` run through `JSON.stringify`). "YYYY-MM-DD" = a plain date string.

> Reference for [docs/SWIFT_PORT.md](../SWIFT_PORT.md), written from the code on 2026-10-23. Line numbers drift; when this and the code disagree, the code wins.

---

## 1. Basics

### Base URL

- All endpoints live under `/api`: the app builds `Config.apiBase.appending(path: "api/...")` (`apps/Clack/Clack/API/Config.swift`).
  Release builds use the hosted server, `https://clack-garner.duckdns.org`; a debug build in the simulator uses
  `http://localhost:3001` (override with the launch argument `-apiBase <url>`). In production Caddy proxies everything
  to `127.0.0.1:3001`, with the live streams uncompressed and `flush_interval -1` so SSE is not buffered
  (`docs/SERVER.md`).
- Server port: `PORT` env, default **3001**, host `HOST` env, default `127.0.0.1` (`apps/server/src/env.ts`,
  `config.port`/`config.host`; `index.ts` calls `app.listen({ port: config.port, host: config.host })`).
- Map tile URLs need an absolute origin: the app builds them from `Config.apiBase`.

### Identity (no login)

- Every request carries the phone's id: header `X-Clack-User: <uuid>`; where a header can't be set (EventSource,
  `<img>`), query `?u=<uuid>` (or `&u=` if the URL already has a query). (`app.ts:51`, `apiBase.ts:11-14`).
- Server check (`app.ts:31`): `/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i`, i.e. a
  **UUID v4**, case-insensitive; the server lowercases it. Swift's `UUID().uuidString` (uppercase v4) passes.
- Header wins over `?u=` when both are present (`raw = header ?? query.u`).
- **A missing or malformed id becomes the shared local user `"local"`** (the laptop demo), unless the server runs with
  `CLACK_REQUIRE_USER=1` (a shared server should), which answers 401 instead. A Swift client must always send a valid
  v4 id.
- First request with a new id creates the user row with `DEFAULT_SETTINGS` (`app.ts:53-56`).
- Web: id made with `crypto.randomUUID()` on first launch, kept in `localStorage['clack.user']`; only used when
  `API_BASE` is set (`apiBase.ts:24-37`). After "Delete my data" it is forgotten (all `clack.*` keys removed,
  `offline.ts:32`), so the next request starts a fresh empty user. Swift: keep it in the Keychain or UserDefaults and
  delete it after `DELETE /api/me`.

### CORS

- None. The server sends no CORS headers: the only client is the native app, and a `URLSession` client sends no `Origin`.

### Health

- `GET /api/health` (`routes/health.ts`), no identity needed, public, never rate-limited. Response without the admin
  header: `{ ok: true, version: string }` (the commit the server runs; Settings shows it).
- With the admin header (see "Admin routes") it also returns:
  - `uptimeS: number` (seconds)
  - `memoryMb: { rss: number, heap: number }` (MB, rounded)
  - `feeds: { [feed: "trafikverket" | "entur"]: { okAt: number | null /*ms*/, failAt: number | null /*ms*/,
    failures: number, lastError: string | null, status: "ok" | "degraded" | "down" | "unknown" } }`. A feed key only
    appears once that feed has been called (`lib/health.ts:34`).
  - `gps: { accepted: number, rejected: number, recent: { key: string, at: string, reason: "area" | "jump",
    meters?: number, seconds?: number, kmh?: number }[] }` (`live/sanitize.ts:54`; `at` is a string, format not
    checked further: unclear).
- The Swift app reads only `version`. Use it for a "server reachable" check.

### Rate limits

Per minute, in memory (`plugins/rateLimit.ts`; override with `CLACK_RATE_LIMIT`, `CLACK_RATE_LIMIT_ANON`,
`CLACK_RATE_LIMIT_MAP`):

- 300 requests per phone id (header or `?u=`, valid v4 only).
- 120 per client address for requests without a valid id.
- 1500 for map tiles, glyphs and operator logos (`/api/map/*`, `/api/operators/:id/logo`), counted separately.
- Exempt: the SSE streams (`/api/live/stream`, `/api/live/trains/stream`, `/api/stations/:id/board/stream`) and
  `/api/health`.
- Over the limit: status **429**, body `{ "statusCode": 429, "error": "too many requests, try again in N seconds" }`,
  plus `Retry-After` and `X-RateLimit-*` headers. A client should wait `Retry-After` seconds, not retry in a loop.

### Admin routes

`/api/import/status`, `/api/audit`, `/api/live/status` and the extra `/api/health` fields need the header
`X-Clack-Admin: <CLACK_ADMIN_TOKEN>`. Without the header, with a wrong one, or when the server has no token set, they
answer 404 like an unknown path. The app never calls them.

---

## 2. Endpoints

Each block: method + path, params, body, response, status codes, TS type, and the web caller.

### 2.1 Me / account

#### `GET /api/me/export`
- This user's data (by `X-Clack-User`) as JSON, sent as an attachment:
  `Content-Disposition: attachment; filename="clack-export-YYYY-MM-DD.json"` (UTC date). `routes/export.ts`.
- 200 `{ exportedAt: string /*ISO*/, userId: string, legs: ExportLeg[], journeys: { id, userId, title, createdAt }[],
  follows: { userId, trainNumber, serviceDate, operatorId, label, createdAt }[], settings: Settings,
  stationFavorites: { userId, stationId, createdAt }[], stationRecent: { userId, stationId, lastViewed }[],
  stationRequests: { id, userId, stationId, createdAt }[] }`. Dates are ISO strings. `ExportLeg` is the raw `legs` row
  (database column names in camelCase, including `geometry`, `coach`, `seat`, `notes`) plus `stops` (the `leg_stops`
  rows, by `seq`) and `events` (the `leg_events` rows, by time).
- Covers the same user-owned tables as `DELETE /api/me`: users (settings), journeys, legs with their stops and
  events, followed trains, favourite and recent stations, station requests. Not included: the phone's Apple push
  addresses (`devices`, `live_activities`) and server bookkeeping (`push_log`, `leg_audits`).
- A new user gets empty arrays and default settings.

#### `DELETE /api/me`
- No body. Deletes the user row; everything (legs, journeys, follows, favourites, recents, settings) goes with it
  through `ON DELETE CASCADE` (`app.ts:61-69`). For the `local` user a fresh empty `local` row is made again.
- 204, no body.
- Web: `api.deleteMyData()` (`api.ts:442`), Settings page "Delete my data" (`pages/SettingsPage.tsx:125`), then
  `forgetLocalData()`.

### 2.2 Settings

#### `GET /api/settings`
- Response: `Settings` (`packages/shared/src/index.ts:35`), filled with `DEFAULT_SETTINGS` for missing keys
  (`routes/settings.ts:10-16`):
  - `displayName: string` (0 to 60 chars, trimmed; empty means no initials)
  - `language: "en" | "sv"`
  - `distanceUnit: "km" | "mi"`
  - `clock: "24h" | "12h"`
  - `co2Comparison: "flight" | "car_1" | "car_2" | "car_3" | "car_avg" | "ev_1" | "coach"` (the app only offers
    `flight` and `car_1`: `CO2_CHOICES`, `index.ts:25`)
  - `includeCommuter: boolean`
  - `showRailNetwork: boolean`
  - `theme: "system" | "dark" | "light"`
  - `walkPace: "relaxed" | "normal" | "brisk"`
  - `stepFree: boolean`
  - `heavyLuggage: boolean`
- Defaults (`index.ts:53`): `displayName ""`, `language "en"`, `distanceUnit "km"`, `clock "24h"`,
  `co2Comparison "car_1"`, `includeCommuter true`, `showRailNetwork true`, `theme "dark"`, `walkPace "normal"`,
  `stepFree false`, `heavyLuggage false`.
- 200. Web: `api.getSettings()` (`api.ts:440`), `settings.tsx` provider on app start. Offline-cached.

#### `PATCH /api/settings`
- Body: any subset of `Settings` (JSON object). Unknown keys or invalid values reject the whole patch
  (`mergeSettings`, `index.ts:69-118`).
- 200: the full merged `Settings`. 400: `{ error }`, e.g. `"unknown setting: foo"`, `"invalid theme: x"`,
  `"displayName must be a string of at most 60 characters"`, `"settings must be an object"`.
- Web: `api.updateSettings(patch)` (`api.ts:443`), `settings.tsx:42`.

### 2.3 Stations

Station ids are rikshållplats-style numeric strings: `"740000001"` (SE), `"760002402"` (NO), `"860000858"` (DK).
`code` is Trafikverket's signature: `"Cst"` for Swedish stations, dotted for foreign ones (`"No.nk"`, `"Dk.cph"`),
or null.

`StationHit` (`api.ts:45`; server `search/stations.ts:14`): `id: string`, `name: string`, `code: string | null`,
`country: string` (ISO 3166 alpha-2: `SE`, `NO`, `DK`, …), `county?: string | null`.

#### `GET /api/stations/search?q=<text>&limit=<n>`
- `q` string, optional (empty gives `[]`). `limit` optional integer, default 8, capped at 20 (web sends 12).
- Response: `StationHit[]` with `county` always present (`string | null`), best first (`routes/stations.ts:12-15`).
  Accent-insensitive and typo-tolerant; typing a signature ("Cst") finds that station.
- Web: `api.searchStations(q, signal)` (`api.ts:457`): Stations page, manual-trip form (`components/ManualTrip.tsx`),
  Live map search (`pages/LiveMapPage.tsx:530`, 200 ms debounce, first 5 shown).

#### `GET /api/stations/popular`
- Response: `{ id: string, name: string, code: string | null, country: string }[]`, 6 rows, no `county`
  (`routes/stations.ts:19-28`).
- Web: `api.popularStations()` (`api.ts:444`): Add trip and Stations pages before typing.

#### `GET /api/stations/favorites`
- Response: `{ id, name, code: string | null, country }[]`, ordered by name, for this user (`routes/boards.ts:123`).
- Web: `api.favoriteStations()` (`api.ts:462`), Stations page.

#### `GET /api/stations/recent`
- Response: same row shape, last viewed first, at most 8 (`routes/boards.ts:132`).
- Web: `api.recentStations()` (`api.ts:463`), Stations page.

#### `GET /api/stations/:id`
- Response `StationInfo` (`api.ts:387`; built in `routes/boards.ts:17-53`):
  - `id: string`, `name: string`, `code: string | null`, `country: string`
  - `tz: string` (IANA, e.g. `"Europe/Stockholm"`, `"Europe/Oslo"`)
  - `lat: number`, `lon: number` (WGS84 degrees)
  - `countyNo: number | null` (**sent but not in the TS type**; Swedish county number)
  - `baseTracks: number | null` (**sent but not in the TS type**; distinct base tracks)
  - `county: string | null` (county name from `SE_COUNTIES`)
  - `hasBoard: boolean` (Swedish signature without a dot, or a Norwegian NSR id)
  - `hasMap: boolean` (a validated station map exists)
  - `sizeClass: "small" | "medium" | "large" | null`
  - `favorite: boolean`
- 404 `{ error: "not found" }`.
- Web: `api.station(id)` (`api.ts:455`): Board page, Station map page, Connection card, Live map station sheet.
  Offline-cached.

#### `GET /api/stations/:id/map`
- Response: `StationMap` (`packages/shared/src/station.ts:78`), the station's JSON file in `data/stations/<id>.json`,
  validated (`stations/maps.ts:11`). Fields:
  - `station_id: string`, `name: string`, `updated: string`, `quality: "osm_draft" | "hand_curated"`
  - `sources: { type: "osm" | "manual" | "website" | "trafikverket", license?: string, retrieved?: string,
    url?: string, note?: string }[]`
  - `changelog: { date: string, who: string, what: string }[]`
  - `coord_system: "local_m"`; `origin: { lat: number, lon: number }`; `view?: { rotation: number }`
  - `levels: { id: string, name: string, order: number }[]`
  - `shapes: { level: string, kind: "building" | "hall" | "room" | "shop" | "track", name?: string,
    points: [number, number][] }[]`
  - `platforms: { id: string, ref: string, tracks: string[], level: string, geometry: [number, number][][],
    node: string }[]`
  - `nodes: { id: string, type: "platform" | "platform_access" | "hall" | "entrance" | "stairs" | "escalator" |
    "lift" | "gate" | "junction", level: string, x: number, y: number, platform?: string, name?: string }[]`
  - `edges: { from: string, to: string, seconds: number, step_free: boolean, kind: "walk" | "stairs" | "escalator" |
    "lift", meters?: number, geometry?: [number, number][], source?: "osm" | "manual" }[]`
  - `pois: { id: string, category: PoiCategory, icon?: string, name: string, level: string, x: number, y: number,
    node: string, fee?: null | "free" | { amount: number, currency: string }, opening_hours?: string | null,
    hours_source: "osm" | "manual" | "website" | null, hours_verified: string | null,
    outline?: [number, number][] }[]`
  - Coordinates are metres in a local frame around `origin`: x east, **y south** (`station.ts:4-5`).
  - Keys are snake_case (`station_id`, `step_free`, `opening_hours`, `hours_source`, `hours_verified`,
    `coord_system`); use explicit `CodingKeys`.
- 404 `{ error: "no map for this station" }` (also when the file fails validation).
- Web: `api.stationMap(id)` (`api.ts:456`): Station map page (`pages/StationMapPage.tsx:77`), connection walks
  (`components/Connection.tsx` `useStationMap`). Offline-cached.

#### `PUT /api/stations/:id/favorite` / `DELETE /api/stations/:id/favorite`
- No body. Response `{ favorite: true }` / `{ favorite: false }` (`routes/boards.ts:101-111`).
- PUT 404 `{ error: "not found" }` for an unknown station; DELETE always 200.
- Web: `api.setFavorite(id, on)` (`api.ts:460`), Board page star.

#### `POST /api/stations/:id/viewed`
- No body. 204. 404 `{ error: "not found" }`. Adds to "recent" (`routes/boards.ts:113-121`).
- Web: `api.stationViewed(id)` (`api.ts:461`), Board page on open.

### 2.4 Boards (departures and arrivals)

`Board` (`api.ts:427`; server `boards/board.ts:72`):
- `stationId: string`
- `signature: string` (Trafikverket signature for Swedish boards; the NSR id `NSR:StopPlace:…` for Norwegian ones,
  `boards/hub.ts:69-74`)
- `type: "departures" | "arrivals"`
- `from: number` (ms), `to: number` (ms): the window asked for
- `updatedAt: number` (ms): when the server fetched it
- `rows: BoardRow[]`, sorted by `advertised`, then `trainNumber`

`BoardRow` (`api.ts:405`; server `boards/board.ts:46`):
- `id: string` (Trafikverket ActivityId, or Entur's equivalent)
- `trainNumber: string`
- `advertised: number` (ms, timetabled time at this station)
- `estimated: number | null` (ms), `actual: number | null` (ms)
- `done: boolean` (departed or arrived; `actual !== null`)
- `delayMin: number | null` (whole minutes, `actual ?? estimated` minus advertised; null when cancelled or unknown)
- `platform: string | null` (track, e.g. `"3"`, `"17b"`)
- `platformChange: { from: string | null, at: number | null /*ms*/ } | null` (`from` null when only
  Trafikverket's "Spårändrat" note says it changed)
- `canceled: boolean`
- `deviations: string[]` (Trafikverket's Swedish deviation texts, "Spårändrat" removed)
- `endpoints: string[]` (destination names for departures, origin names for arrivals)
- `via: string[]` (up to 3 names)
- `operatorId: string | null` (brand id, e.g. `"sj"`, `"oresundstag"`)
- `productName: string | null` (Trafikverket's product text, e.g. "SJ Snabbtåg")
- `product: Product` (see §4)
- `trainType: string | null` (id into `/train-types`)
- `onboard: OnboardFacts | null` (null on arrivals)
- `trip: { key: string, serviceDate: string /*YYYY-MM-DD*/, seq: number } | null` (the timetable trip and this
  station's stop seq, for "Add to my trips" and `/trains/:number/:date?key=`)

#### `GET /api/stations/:id/board?type=<departures|arrivals>[&from=<ms>&to=<ms>]`
- `type` optional, default `departures`. `from` and `to` optional epoch ms; if either is given both must be finite,
  `to > from`, and `to - from <= 24 h`.
- Without `from`/`to`: the shared live board, window now − 1 h to now + 12 h (`boards/hub.ts:18-19`), served from
  memory if under 20 s old (`BOARD_POLL_MS`).
- 200 `Board`. 400 `{ error: "type must be departures or arrivals" }` or
  `{ error: "from/to must be epoch ms, at most 24 h apart" }`. 404 `{ error: "no board for this station" }`
  (unknown station or `hasBoard` false). 500 (Fastify shape) if Trafikverket or Entur fails.
- Web: `api.board(id, type, window?)` (`api.ts:458`): Board page "Show earlier" fetches
  `{ from: board.from − 3 h, to: board.from }` (`pages/BoardPage.tsx:126-134`); Live map station sheet loads
  departures and shows the next 4 not done and not cancelled (`pages/LiveMapPage.tsx:1275-1281`).

#### `GET /api/stations/:id/board/stream?type=<departures|arrivals>&u=<uuid>` (SSE): see §3.2.

### 2.5 Search and timetable (Add trip)

`StopRef` (`api.ts:69`; `search/timetable.ts:9`): `seq: number`, `stationId: string`, `name: string`,
`code: string | null`, `country: string`, `tz: string`, `time: number` (ms; departure for `from`, arrival for `to`).

`TripResult` (`api.ts:79`; `search/timetable.ts:20`):
- `key: string`: timetable trip key, e.g. `"se3:121120000383764838:ae68fcaa62"`,
  `"no:FLT:ServiceJourney:1-2614-3507-20261021:a8ed56a415"`. Contains colons: percent-encode it in paths.
- `serviceDate: string` (YYYY-MM-DD, GTFS service day; can be the day before the local departure date for
  after-midnight runs)
- `trainNumber: string | null`, `operatorId: string | null`
- `category: string` (`"intercity" | "regional" | "commuter" | "heritage" | "night"`; `night` is in the data though
  not in `CATEGORIES`)
- `product: Product`, `trainType: string | null`, `routeName: string | null`
- `from: StopRef`, `to: StopRef`
- `durationMin: number`, `stopsBetween: number`
- `alsoKnownAs: string[]` (other train numbers for the same physical train)

`Connection` (`api.ts:96`; `search/timetable.ts:189`): `first: TripResult`, `second: TripResult`,
`changeAt: { stationId: string, name: string }`, `changeMin: number`.

#### `GET /api/search?q=<text>&date=<YYYY-MM-DD>`
- `q` optional free text (train number, operator words, "A → B"; separators `→ -> => > – —`, ` - `, `to`,
  `till`; see `search/parse.ts`). `date` optional, default today in Europe/Stockholm; it is the **local date of
  boarding**.
- Response `SearchResponse` (`api.ts:103`; `search/smartSearch.ts:16`):
  - `date: string`
  - `interpretation: { operator?: { id: string, text: string }, trainNumber?: string, from?: StationHit,
    to?: StationHit, typing: "from" | "to" | null }`
  - `suggestions: StationHit[]` (station autocomplete for the part being typed; up to 6)
  - `results: TripResult[] | null` (null when the query isn't a search yet; `[]` when nothing found or outside the
    timetable)
  - `connections?: Connection[]` (only when a station-to-station search found no direct train; up to 12)
  - `outsideTimetable: boolean`
  - `history?: "ready" | "loading" | "failed" | "unavailable" | "norway"` (only for dates before yesterday;
    `"loading"` means try again shortly; `"norway"` means Norway has no archive)
- 400 `{ error: "date must be YYYY-MM-DD" }`.
- Web: `api.search(q, date, signal)` (`api.ts:445`), Add trip page, 150 ms debounce, cancels the previous one
  (`pages/AddTripPage.tsx:473-489`).

#### `GET /api/timetable/trips/:key?date=<YYYY-MM-DD>`
- `key` path-encoded trip key. `date` **required** (the trip's `serviceDate`).
- Response `TimetableTrip` (`api.ts:169`; `routes/search.ts:47-63`): `key`, `serviceDate`,
  `trainNumber: string | null`, `operatorId: string | null`, `category: string`, `product: Product`,
  `trainType: string | null`, `stops: TripStop[]`.
- `TripStop` (`api.ts:114`; `search/timetable.ts:38`): `seq: number`, `stationId`, `name`, `code: string | null`,
  `country`, `tz`, `lat: number`, `lon: number`, `arr: number | null` (ms), `dep: number | null` (ms),
  `noPickup: boolean`, `noDropoff: boolean`.
- 400 `{ error: "date must be YYYY-MM-DD" }`; 404 `{ error: "trip not found on that date" }`.
- Web: `api.timetableTrip(key, date)` (`api.ts:446`): Add trip confirm step ("Where did you get on and off?",
  `pages/AddTripPage.tsx:241`, `437`).

#### `GET /api/timetable/trips/:key/geometry?date=<YYYY-MM-DD>`
- Response `TripGeometry` (`api.ts:310`; `routes/search.ts:67-83`): `segments: { fromSeq: number, toSeq: number,
  polyline: string, lengthM: number /*metres, rounded*/, estimated: boolean }[]`, one per consecutive stop pair.
  `polyline` is Google encoded polyline, precision 5, points `[lat, lon]` (`packages/shared/src/polyline.ts`).
- Same 400/404 as above.
- Web: `api.timetableTripGeometry` (`api.ts:447`): Add trip mini map; Live map route of a selected train (segments
  decoded and concatenated, dropping each later segment's first point, `pages/LiveMapPage.tsx:613-617`).

#### `GET /api/alternatives?from=<stationId>&to=<stationId>&after=<ms>[&exclude=<tripKey>]`
- All but `exclude` required. Direct trains leaving `from` for `to` at or after `after`, today and tomorrow
  (Stockholm days), without trip `exclude`; up to 4. Only if none: one-change connections, up to 3.
- Response `{ direct: TripResult[], connections: Connection[] }` (`routes/search.ts:28-45`).
- 400 `{ error: "from, to and after (ms) are required" }`.
- Web: `api.alternatives(from, to, after, exclude)` (`api.ts:477`; `after` rounded to an integer), Disruption card
  on a trip (`components/Disruption.tsx`).

### 2.6 Legs (saved trips)

A "leg" is one saved train ride. Leg ids are UUIDs (`crypto.randomUUID()`); journey ids are `"j-<first leg id>"`.

`Leg` as sent by `GET /api/legs` (TS `Leg`, `api.ts:188`; built by `listLegs` + `attachRefs`,
`apps/server/src/legs/legs.ts:200-258`). Fields in send order:
- `id: string`
- `status: "planned" | "completed" | "snapshotted"`
- `dataQuality: "full" | "partial" | "scheduled_only" | "manual"`
- `trainNumber: string | null`
- `category: string | null` (see `TripResult.category`; manual trips may also hold `"high_speed"`)
- `serviceDate: string | null` (YYYY-MM-DD)
- `schedDep: string | null` (ISO), `schedArr: string | null` (ISO)
- `actualDep: string | null` (ISO), `actualArr: string | null` (ISO)
- `depDelayMin: number | null`, `arrDelayMin: number | null` (whole minutes, negative = early)
- `depPlatform: string | null`, `arrPlatform: string | null`
- `canceled: boolean`
- `distanceM: number | null` (metres, float; along the track once routed)
- `isEstimatedGeometry: boolean`
- `trainType: string | null`; `trainTypeSource: "typical" | "composition" | "user" | null`
- `onboard: OnboardFacts | null`
- `countryCodes: string[]` (countries of the ridden stops)
- `journeyId: string | null`
- `timetableTripKey: string | null` (null for trips added by hand)
- `operatorId: string | null` (**sent, not in the TS type**)
- `originStationId: string`, `destStationId: string` (**sent, not in the TS type**)
- `notes: string | null`
- `coach: string | null`, `seat: string | null`: where the owner sat, as they wrote it ("5", "12A"); null when not
  given. Set on create or with `PATCH /legs/:id`; also on the legs inside `GET /journeys/:id`.
- `ride: "pending" | "auto" | "confirmed" | "review" | "not_taken"`
- `rideReason: string | null` (see §4)
- `borderEvidence: { board?: { stationId: string, at: number /*ms*/ }, alight?: { stationId: string,
  at: number /*ms*/ } } | null`
- `operator: Operator | null`: the operators table row plus `logoUrl` (`withLogo`, `import/brands.ts:22`):
  `id: string`, `name: string`, `shortName: string`, `company: string | null`, `country: string`,
  `brandColor: string` (CSS hex, e.g. `"#1fb14f"`), `logoPath: string | null`, `logoUrl: string | null`.
  No `ticketUrl` here (only `/operators` has it).
- `origin: StationRef | null`, `destination: StationRef | null`, where `StationRef` (`api.ts:180`) is
  `{ id: string, name: string, code: string | null, country: string, tz: string }`
- `live: LiveStateRow | null` (REST form, below)

`LiveStateRow`, the REST form of live state (DB row `liveState`, `db/schema.ts:258`; TS `LiveState`,
`api.ts:246`, which types every time as `string | number`):
- `legId: string` (**sent, not in the TS type**)
- `updatedAt: string` (ISO): last server tick
- `status: LiveStatus` (§4)
- `lat: number | null`, `lon: number | null`, `bearing: number | null` (degrees), `speedKmh: number | null`
- `positionSource: "gps" | "estimated" | null`
- `positionAt: string | null` (ISO, when the GPS fix was taken)
- `progress: number | null` (0 to 1, share of the ridden route travelled)
- `prevStopId: string | null`, `nextStopId: string | null` (station ids)
- `eta: string | null` (ISO, expected time at the next stop)
- `arrivalEta: string | null` (ISO, expected arrival where you get off)
- `arrivalDelayMin: number | null`
- `reportedAt: string | null` (ISO, last time Trafikverket or Entur answered for this leg)

**The same state arrives with epoch-ms numbers over SSE** (§3.1). The web normalises both with
`ms(t) = t == null || t === '' ? null : typeof t === 'number' ? t : Date.parse(t)` (`api.ts:437`). Swift: decode these
time fields with a custom decoder that takes either an ISO string or a number.

`LegDetail` (`GET /api/legs/:id`; TS `api.ts:303`; server `getLeg`, `legs.ts:260-293`) = every `Leg` field above,
plus:
- `geometry: string | null` (encoded polyline of the ridden route along the track)
- `stops: LegStop[]` (the **whole** trip, ordered by `seq`, each with its `role`)
- `live: LiveStateRow | null`
- `events: LegEventRow[]` (newest first, at most 50)

`LegStop` (`api.ts:280`; `legs.ts:265-291`):
- `seq: number`, `role: "before" | "board" | "through" | "alight" | "after"`
- `stationId: string`, `name: string`, `code: string | null`, `country: string`, `tz: string`, `lat: number`,
  `lon: number`
- `schedArr: string | null`, `schedDep: string | null`, `actualArr: string | null`, `actualDep: string | null`,
  `estimatedArr: string | null`, `estimatedDep: string | null` (all ISO)
- `platform: string | null`, `canceled: boolean`
- `deviations: string[]` (Trafikverket's Swedish texts; `DELAY_REASONS` in `packages/shared/src/disruption.ts:98`
  maps the reason ones to en/sv)
- `reportSource: "trafikverket" | "entur" | null` (null: nobody reports this stop live, so its times are timetable)

`LegEventRow` (DB `legEvents`, `db/schema.ts:244`; TS `LegEvent`, `api.ts:267`):
- `id: number`, `legId: string` (not in the TS type), `ts: string` (ISO)
- `type: "delayed" | "platform_changed" | "cancelled" | "short_turned" | "departed" | "arrived"`
- `payload` per type (`apps/server/src/live/progress.ts:35-52`):
  - `cancelled`: `{}`
  - `short_turned`: `{ stationIds: string[] }`
  - `departed`: `{ at: number /*ms*/ }`
  - `arrived`: `{ at: number /*ms*/, delayMin: number | null }`
  - `delayed`: `{ delayMin: number, previousDelayMin: number | null }` (arrival delay; only changes of 3 min or more)
  - `platform_changed`: `{ which: "departure" | "arrival", from: string, to: string }`

#### `GET /api/legs`
- Response: `Leg[]`, all of this user's legs, **newest `schedDep` first** (`legs.ts:255`).
- Web: `api.legs()` (`api.ts:449`): Trips page (main list, featured card), Passport page, app shell landing-tab
  choice (`components/AppShell.tsx:41`). Offline-cached.

#### `GET /api/legs/:id`
- Response: `LegDetail`. 404 `{ error: "not found" }` (also for another user's leg).
- Web: `api.leg(id)` (`api.ts:450`): Trip detail page (reloaded after every live update for this leg,
  `pages/TripDetailPage.tsx:132-153`); Trips page featured card. Offline-cached.

#### `POST /api/legs`
- Body (`CreateLegInput`, `legs.ts:44`): `{ tripKey: string, serviceDate: string /*YYYY-MM-DD*/, fromSeq: integer,
  toSeq: integer, force?: boolean, coach?: string | null, seat?: string | null }`. `fromSeq`/`toSeq` are `TripStop.seq` / `StopRef.seq` values. `force: true`
  saves even if the same train number is already saved on that date.
- 201: `LegDetail`.
- 400 `{ error: "tripKey, serviceDate, fromSeq and toSeq are required" }`; 400
  `{ error: "Choose where you got on before where you got off" }`; 400
  `{ error: "The train doesn't take passengers at <name>" }`; 400
  `{ error: "The train doesn't let passengers off at <name>" }`; 404
  `{ error: "That train is not in the timetable for that date" }`; **409
  `{ error: "You already added this train on this date", duplicateOf: "<leg id>" }`** (`legs.ts:53-70`).
- After a create the server regroups journeys and fetches actual times in the background.
- Web: `api.createLeg(body)` (`api.ts:451`): Add trip confirm (`pages/AddTripPage.tsx:282`, 409 shows "already
  added" with an "add anyway" that resends with `force: true`); two-train connection save (`AddTripPage.tsx:166-190`,
  saves each leg, collects 409s); ticket-return prompt (`components/Tickets.tsx:137`).

#### `POST /api/legs/manual`
- Body (`ManualLegInput`, `legs.ts:124`): `{ fromStationId: string, toStationId: string, date: string
  /*YYYY-MM-DD, local where you board*/, dep: string /*"HH:MM", origin's tz*/, arr: string /*"HH:MM", destination's
  tz; earlier than dep means next day*/, operatorId?: string | null, trainNumber?: string | null,
  category?: string | null, coach?: string | null, seat?: string | null }`. The web always sends all eight keys (`api.ts:452`). `category` must be one of
  `high_speed, intercity, night, regional, commuter, heritage`, otherwise it becomes `regional`. `trainNumber` must
  match `^[\w-]{1,10}$` after trimming.
- 201: `LegDetail` (two stops, `dataQuality: "manual"`).
- 400 `{ error }` with one of: `"Choose both stations"`, `"Choose two different stations"`,
  `"Date must be YYYY-MM-DD and times HH:MM"`, `"That trip is longer than two days"`, `"Unknown operator"`,
  `"Train numbers are letters and digits only"` (`legs.ts:145-198`).
- Web: `api.createManualLeg` (`api.ts:452`), manual-trip form (`components/ManualTrip.tsx:78`).

#### `PATCH /api/legs/:id`
- Body: any of `{ trainType?: string | null, coach?: string | null, seat?: string | null }`. A key left out is
  unchanged; `null` clears (`trainType` null resets to the typical type; a string must be an id from `/train-types`).
  `coach` and `seat` are trimmed text of at most 8 characters each; a blank string clears too.
- Same `coach`/`seat` rules on `POST /legs` and `POST /legs/manual`: omitted or null means none.
- 200 `LegDetail`. 400 `{ error: "nothing to change" }` (none of the three keys present), 400
  `{ error: "unknown train type: <id>" }`, 400 `{ error: "coach must be text or null" }` / `"seat must be text or
  null"` / `"coach can be at most 8 characters"` / `"seat can be at most 8 characters"`, 404
  `{ error: "not found" }` (`routes/legs.ts`). Nothing is changed when any field is refused.
- Web: `api.setTrainType(id, trainType)` (`api.ts:472`), Train card picker (`components/TrainCard.tsx`).

#### `DELETE /api/legs/:id`
- 204, or 404 `{ error: "not found" }`. Regroups journeys.
- Web: `api.deleteLeg(id)` (`api.ts:482`), Trip detail page.

#### `POST /api/legs/:id/refresh`
- No body. Fetches actual times now (pull to refresh).
- 200 `LegDetail`; 404 `{ error: "not found" }`; 500 if Trafikverket fails (not caught, `legs/actuals.ts:195`).
- Web: `api.refreshLeg(id)` (`api.ts:454`), Trip detail page.

#### `POST /api/legs/:id/ride`
- Body `{ answer: "yes" | "no" | "undo" }`. yes sets `ride: "confirmed"`, no sets `"not_taken"` (both with
  `rideReason: "you"`), undo sets `"pending"` and lets the evidence decide again (`legs/recording.ts:90-98`).
- 200 `LegDetail`. 400 `{ error: "answer must be yes, no or undo" }`. 404 `{ error: "not found" }`.
- Web: `api.answerRide(id, answer)` (`api.ts:481`): Trips page review card, Trip detail, Add trip "Done" step.

#### `GET /api/legs/:id/risk`
- Response `LegRisk` (`api.ts:232`; server `legs/risk.ts:156`), cached 2 min per leg on the server:
  - `checkedAt: number` (ms)
  - `limits: ("too_far" | "abroad" | "no_live_data" | "no_history")[]` (what could not be checked)
  - `warnings: RiskWarning[]`, a union keyed by `kind` (`api.ts:227`; `legs/risk.ts:24`):
    - `{ kind: "route_now", trains: number, late: number, canceled: number, medianMin: number, windowMin: number }`
    - `{ kind: "station_now", station: string /*name*/, trains: number, late: number, medianMin: number,
      windowMin: number }`
    - `{ kind: "ahead", station: string, toward: string, trains: number, late: number, delays: number[],
      windowMin: number }`
    - `{ kind: "train_pattern", station: string, days: number, lateDays: number, medianMin: number }`
  - A trip that has arrived or is cancelled gets `{ checkedAt, limits: [], warnings: [] }`.
- 404 `{ error: "not found" }`.
- Web: `api.legRisk(id)` (`api.ts:480`), Risk card on Trip detail, **polled every 5 min** while shown
  (`components/Risk.tsx:17-24`).

#### `GET /api/legs/:id/progress`
- Response `TripProgress` (`api.ts:350`; server `stats/passport.ts:293`):
  - `{ counted: false }` (trip not counted yet, cancelled, **or the id is unknown**: no 404 here)
  - or `{ counted: true, unlocked: Milestone[], moved: { family: MilestoneFamily, before: number, after: number,
    target: number }[] /*up to 4*/, firsts: { stations: string[] /*names*/, operator: string | null /*operator id*/,
    countries: string[] } }`
- Web: `api.tripProgress(id)` (`api.ts:479`), `components/TripProgress.tsx` (after adding a past trip, after arrival).

### 2.7 Journeys

#### `GET /api/journeys/:id`
- Response `Journey` (`api.ts:238`; `getJourney`, `legs.ts:314-327`): `{ id: string, legs: (Leg & { geometry:
  string | null })[] }`, legs in **ascending** `schedDep` order. Each leg has the `Leg` fields (no `stops`, no
  `events`) plus `geometry`.
- 404 `{ error: "not found" }`.
- Web: `api.journey(id)` (`api.ts:471`): Journey page (reloads on a live update for one of its legs, at most every
  20 s, `pages/JourneyPage.tsx:23-31`); Connection, Disruption and Risk cards (to find the next leg). Offline-cached.

### 2.8 Reference data

#### `GET /api/operators`
- Response `Operator[]` (`api.ts:54`; `routes/legs.ts:83-88`): the operators table row plus
  - `id`, `name`, `shortName`, `company: string | null`, `country`, `brandColor` (hex), `logoPath: string | null`
  - `logoUrl: string | null`: a server path like `/api/operators/sj/logo?v=1729…`; fetch it with the base URL
    prepended (and `?u=` is harmless)
  - `ticketUrl: string | null`: the operator's own booking page (falls back to its website; null when its data says
    `tickets: null`)
  - `ticketDeepLink: string | null`: template with `{from}`, `{to}`, `{date}`, `{time}` placeholders
- Web: `api.operators()` (`api.ts:448`), cached once per app run (`data.ts:7`), and the manual-trip operator picker.
  Offline-cached.

#### `GET /api/operators/:id/logo`
- `id` must match `^[a-z0-9-]+$`. Binary image, `Content-Type` from the file extension, `Cache-Control:
  max-age=86400`. 404 `{ error: "no logo" }`.
- Web: `<img src={apiUrl(operator.logoUrl)}>` (`components/OperatorBadge.tsx:22`).

#### `GET /api/train-types`
- Response `TrainType[]` (`api.ts:314`; `data/train_types.json` `types`): `id: string`, `name: string`,
  `builder: string | null`, `max_kmh: number | null`, `since: number | null` (year), `art: string` (drawing id),
  `about: string`, `uncertain?: boolean`. Note snake_case `max_kmh`.
- Web: `api.trainTypes()` (`api.ts:473`), cached once (`data.ts:19`). Offline-cached.

#### `GET /api/amenities`
- Response `AmenityEntry[]` (`packages/shared/src/onboard.ts:31`): `{ match: { operator: string, type?: string },
  claims: { [key in AmenityKey]?: AmenityClaim } }`. `AmenityClaim` (`onboard.ts:22`): `value: boolean | string`
  (string is `"partial"` or a short text such as `"Bistro"`), `note?: string`, `source: string` (URL),
  `verified: string` (YYYY-MM-DD), `via?: "owner"`.
- Web: `api.amenities()` (`api.ts:474`), cached once (`data.ts:32`). Offline-cached.

### 2.9 Live map, single trains, follows

`LiveTrain`, one train on the live map (`apps/server/src/livemap/ingest.ts:21`; the web keeps a local copy at
`pages/LiveMapPage.tsx:27`, which leaves out `tripKey`):
- `id: string`: `"<number>|<YYYY-MM-DD>"` for Swedish trains, `"no:<number>|<YYYY-MM-DD>"` for Norwegian ones,
  `"S<i>|sim"` in simulation. Contains `|`: percent-encode it in paths (the web uses `encodeURIComponent`).
- `number: string`, `date: string` (YYYY-MM-DD, or `"sim"`)
- `lat: number`, `lon: number`, `bearing: number | null` (degrees), `speedKmh: number | null` (only from a fresh fix)
- `at: number` (ms, when the fix was taken)
- `estimated: boolean` (position worked out from the timetable, not GPS)
- `operatorId: string | null`, `productName: string | null`, `product: Product`, `trainType: string | null`
- `origin: string | null`, `destination: string | null`, `next: string | null` (station **names**)
- `nextEta: number | null` (ms), `delayMin: number | null`
- `mine: boolean`: one of **the asking user's** trips being tracked now. Set per request (and re-checked every 10 s on
  the stream) by `isMine` (`livemap/ingest.ts`) from the user's tracked legs (`myTrainKeys`, `app.ts`).
- `tripKey?: string | null` (present on Norwegian trains only)
- `crossBorder?: true` (Norwegian trains that also run in Sweden; absent otherwise)

#### `GET /api/live/trains?bbox=<w,s,e,n>`
- `bbox` optional, four comma-separated degrees (west, south, east, north); the server pads it by 20% each way. No
  bbox means all trains.
- Response `{ trains: LiveTrain[], total: number /*all trains on the map*/, upstreamAt: number /*ms, 0 = never*/,
  mode: "stream" | "poll" | "simulate" | "stopped" }` (`routes/livemap.ts:35-41`).
- Not called by the web (it uses the stream, §3.3). Handy for a Swift snapshot or a widget.

#### `GET /api/live/trains/:id`
- Response `{ train: LiveTrain, trip: { key: string, serviceDate: string, from: StopRef, to: StopRef } | null,
  legId: string | null }` (`routes/livemap.ts:93-106`). The web type (`api.ts:464`) only declares
  `trip: { key, serviceDate }`; `from`/`to` are sent too. `legId` is this user's leg on that train when `train.mine`
  is true, else null.
- 404 `{ error: "train not on the map any more" }`.
- Web: `api.liveTrain(id)` (`api.ts:464`), Live map when a train dot is tapped (`pages/LiveMapPage.tsx:597`).

#### `GET /api/live/trains/:id/stops`
- Response `{ stops: TrainStopView[] }` (`livemap/trainStops.ts:11`; TS `LiveTrainStop`, `api.ts:154`, which leaves
  out `source`): `seq: number`, `stationId: string`, `name: string`, `arr: number | null` (ms, timetable),
  `dep: number | null` (ms), `actualArr`, `actualDep`, `estimatedArr`, `estimatedDep` (all `number | null`, ms),
  `platform: string | null`, `canceled: boolean`, `passed: boolean` (left this stop, or arrived at the last),
  `source: "trafikverket" | "entur" | null`. Cached 30 s on the server.
- 404 `{ error: "train not on the map any more" }` or `{ error: "train not in the timetable" }`.
- Web: `api.liveTrainStops(id)` (`api.ts:470`), selected train's sheet, **polled every 30 s** while open
  (`pages/LiveMapPage.tsx:681-692`).

#### `GET /api/trains/:number/:date[?key=<tripKey>]`
- `number` must match `^\d{1,6}$`, `date` `^\d{4}-\d{2}-\d{2}$`. `key` optional: picks that timetable trip when
  several share the number.
- Response `TrainView` (`api.ts:140`; `routes/livemap.ts:121-152`):
  - `number: string`, `date: string`
  - `live: LiveTrain | null` (the full object; the TS type only declares `{ id }`)
  - `trip: { key: string, serviceDate: string, from: StopRef, to: StopRef } | null`
  - `operatorId: string | null`, `productName: string | null`, `product: string | null` (a `Product` value),
    `trainType: string | null`
  - `stops: TrainStopView[] | null` (same shape as above, with `source`)
  - `legId: string | null` (this user's saved leg for this train and day, if any)
- 400 `{ error: "train number and date (YYYY-MM-DD) are required" }`; 404 `{ error: "no such train on that day" }`.
- Web: `api.train(number, date, key)` (`api.ts:468`): opening a train from a board row, a follow, or a link
  (`pages/LiveMapPage.tsx:633`); if `live` is on the map it switches to the live view; otherwise it shows the
  scheduled sheet and **re-polls every 30 s** (`LiveMapPage.tsx:671-677`).

`Follow` (a watched train, not a trip; `api.ts:130`; `routes/livemap.ts:156-162`):
- `trainNumber: string`, `serviceDate: string`, `operatorId: string | null`, `label: string | null`
  (e.g. `"Göteborg C → Stockholm C"`)
- `train: LiveTrain | null` (full object while it's on the map; the TS type declares only `id, next, nextEta,
  delayMin, destination`)

#### `GET /api/follows`
- Response `Follow[]`. Follows older than yesterday (Stockholm date) are deleted on read.
- Web: `api.follows()` (`api.ts:465`): Trips page "Following" section, Live map.

#### `PUT /api/follows`
- Body `{ trainNumber: string /*^\d{1,6}$*/, serviceDate: string /*YYYY-MM-DD*/, operatorId?: string | null,
  label?: string | null }`. Following twice is one follow.
- 200 `{ following: true }`. 400 `{ error: "trainNumber and serviceDate (YYYY-MM-DD) are required" }`.
- Web: `api.follow(body)` (`api.ts:466`), Live map train sheet; label built as `"${origin} → ${destination}"` when
  both are known (`LiveMapPage.tsx:555`).

#### `DELETE /api/follows/:number/:date`
- 200 `{ following: false }` always (no validation).
- Web: `api.unfollow(number, date)` (`api.ts:467`), Live map.

#### `GET /api/live/status`
- Response `{ mode: "stream" | "poll" | "simulate" | "stopped", viewers: number, trains: number,
  upstreamAt: number /*ms*/, upstreamOpens: number, announcementRows: number, norwayAt: number /*ms, 0 = none*/ }`
  (`routes/livemap.ts:177`). Diagnostic; not used by the web.

### 2.10 Passport

`Milestone` (`api.ts:341`; `stats/passport.ts:214`): `family: MilestoneFamily`, `target: number`,
`at?: number` (ms, achieved only), `legId?: string` (achieved only), `value?: number` (upcoming only, one decimal).
Targets per family (`passport.ts:203`): `journeys` 1, 10, 25, 50, 100, 250; `distanceKm` 100, 500, 1000, 2500, 5000,
10000, 40075; `stations` 10, 25, 50, 100, 200; `operators` 3, 5, 10; `countries` 2, 3, 5; `borderCrossings` 1;
`nightTrains` 1.

`LegRef` (`api.ts:326`; `passport.ts:131`): `legId: string`, `from: string` (name), `to: string` (name),
`distanceM: number`, `minutes: number`, `dep: number` (ms), `arr: number` (ms), `delayMin: number | null`.

`CountRow` (`api.ts:336`): `key: string`, `count: number`, `distanceM: number`.

#### `GET /api/passport?year=<YYYY|all>&commuter=<true|false>[&comparison=<Co2Comparison>]`
- `year` optional (absent or `all` means all time; otherwise must be an integer). `commuter` optional: absent means
  the user's `includeCommuter` setting; **any value other than the string `true` means false**. `comparison`
  optional, default the user's `co2Comparison`.
- Response `Passport` (`api.ts:359`; `routes/passport.ts:11-24` = `computePassport` + `milestones` + `review` +
  `refs`):
  - `years: number[]` (years with counted trips, newest first, Stockholm time)
  - `scope: { year: number | null, includeCommuter: boolean }`
  - `totals: { distanceM: number, minutes: number, trains: number, journeys: number, stations: number,
    countries: number, borderCrossings: number, cancellations: number }`
  - `flavor: { earthLaps: number, swedenLengths: number, topRoute: { route: string, count: number } | null,
    busiestMonth: { month: string /*"YYYY-MM"*/, count: number } | null, lateMinutes: number }`
  - `records: { longestDistance: LegRef | null, longestDuration: LegRef | null, biggestDelay: LegRef | null,
    mostRiddenRoute: { route: string, count: number } | null, busiestStation: { id: string, name: string,
    country: string, lat: number, lon: number, count: number } | null, earliestDeparture: LegRef | null,
    latestArrival: LegRef | null }` (`route` text is `"A ⇄ B"`, names sorted; `busiestStation` has `country`, `lat`,
    `lon` beyond the TS type)
  - `operators: CountRow[]` (key = operator id), `products: CountRow[]` (key = Product), `trainTypes: CountRow[]`
    (key = train type id)
  - `delays: { basedOn: number, onTimePct: number | null, totalLateMin: number, averageMin: number | null
    /*one decimal*/, worst: LegRef | null, bands: { on_time: number, slight: number, late: number,
    very_late: number }, cancellations: number }`
  - `countries: { code: string, legs: number }[]`
  - `stations: { id: string, name: string, country: string, lat: number, lon: number, count: number }[]`
  - `co2: { comparison: string, trainKg: number, comparisonKg: number, savedKg: number }` (kg, floats)
  - `map: { legId: string, operatorId: string | null, geometry: string | null /*polyline*/,
    stops: [number, number][] /*[lat, lon] of first and last stop*/ }[]`
  - `milestones: { achieved: Milestone[] /*newest first*/, next: Milestone[] /*up to 3, closest first*/ }`
    (all-time, ignore `year` and `commuter`)
  - `review: { legId: string, reason: string | null, dep: number | null /*ms*/, from: string /*name*/,
    to: string /*name*/, trainNumber: string | null }[]` (trips waiting for "Did you take this train?")
  - `refs: { operators: { [id: string]: OperatorRow /*no ticket fields*/ }, trainTypes: { [id: string]: TrainType } }`
- Only trips with `ride` `auto` or `confirmed` whose arrival has passed count (`stats/passport.ts:336-343`).
- 400 `{ error: 'year must be a number or "all"' }`; 400 `{ error: "unknown comparison: <x>" }`.
- Web: `api.passport({ year, commuter, comparison })` (`api.ts:475`; always sends `year` and `commuter`), Passport
  page and the Share sheet (`share/ShareSheet.tsx`).

### 2.11 Map data

Also, for native map libraries (added 2026-10-23, `routes/map.ts`, test `mapTiles.test.ts`):
- `GET /api/map/tiles/:z/:x/:y.mvt`: the basemap as plain vector tiles (Mapbox Vector Tile, uncompressed),
  `Content-Type: application/vnd.mapbox-vector-tile`, `Cache-Control: max-age=86400`. 204 where there is no tile; 400
  for coordinates that aren't a tile; 404 `{ error: "basemap not downloaded yet" }`. Zoom 0 to 10.
- `GET /api/map/fonts/:fontstack/:range.pbf`: map label glyphs, fontstacks `Noto Sans Regular` and
  `Noto Sans Medium` (URL-encode the space), ranges as in the web's `public/map/fonts`.
- `/api/health`, `/api/map/*` and `/api/operators/:id/logo` work without a phone id even when the server requires one
  (`CLACK_REQUIRE_USER=1`; any other path then answers 401 `{ error: "missing or invalid X-Clack-User" }`).

#### `GET /api/map/status`
- Response `{ basemap: { bytes: number, modified: string /*ISO*/ } | null, railGraph: { generated: string,
  attribution: string } | null }` (`routes/map.ts:15-18`; `import/basemap.ts:350`).
- Web: raw `fetch(apiUrl('/api/map/status'))` once per app run (`map/RouteMap.tsx:44`); only `Boolean(basemap)` is
  used, to choose the basemap style. On failure treated as `{ basemap: null }`.

#### `GET /api/map/basemap.pmtiles` (removed)
- Removed with the web app, which read the archive with HTTP Range requests. The app uses `GET /api/map/tiles/{z}/{x}/{y}.mvt` (B2 of SWIFT_PORT.md).

#### `GET /api/map/rail-network.geojson`
- GeoJSON FeatureCollection, sent **gzip-encoded** (`Content-Encoding: gzip`, `Content-Type: application/geo+json`,
  `Cache-Control: max-age=3600`). Features (`geo/railNetwork.ts:61-63`): one `{ properties: { kind: "rail" },
  geometry: MultiLineString }`, then stations `{ properties: { kind: "station", id: string, name: string,
  dpd: number /*departures per day*/ }, geometry: Point }`. Coordinates `[lon, lat]`, 5 decimals.
- 404 `{ error: "rail graph missing (data/osm/rail-graph.json.gz)" }`.
- Web: `${apiOrigin()}/api/map/rail-network.geojson` (`map/style.ts:45`), the faint rail layer and the live map's
  station dots and labels.

### 2.12 Import status and audit (diagnostics, not used by the web)

#### `GET /api/import/status`
- Response `{ stations: number, trips: number, quota: { source: string, usedThisMonth: number,
  monthlyQuota: number }[], recent: { id: number, source: string, startedAt: string /*ISO*/,
  finishedAt: string | null /*ISO*/, status: string /*"ok" | "failed" | "skipped"*/, bytes: number | null,
  notes: string | null }[] /*last 10*/ }` (`routes/importStatus.ts`; `db/schema.ts:132`).

#### `GET /api/audit`
- Response from `summarize` (`apps/server/src/audit/audit.ts:212`): `{ legs: number, tracked: number,
  record: { checked, agree, disagree, missing: number }, predictions: { ["<h>min"]: { n, meanAbsMin, within1,
  within3, early, late } }, platforms: { stops, changedAfterShown, wrong10MinBefore: number }, position: { ticks,
  gpsTicks, enRouteTicks, failedTicks, rejectedFixes: number } }`. Prediction keys are `"60min"`, `"30min"`,
  `"15min"`, `"5min"` (`HORIZONS_MIN`, `audit.ts:14`). Last 7 days, **all users**.

---

## 3. Streaming

All three streams are Server-Sent Events: `Content-Type: text/event-stream`, `Cache-Control: no-cache,
no-transform`, `Connection: keep-alive`, `X-Accel-Buffering: no`. Each first writes `retry: 5000` (the browser
reconnects 5 s after a drop). Every frame is `event: <name>\ndata: <one-line JSON>\n\n`. The identity goes in `?u=`
because the browser's EventSource can't set headers; a Swift client using `URLSession` bytes can send the
`X-Clack-User` header instead (the server accepts either). Swift has no built-in EventSource: parse lines, handle
`retry:`, skip `:` comment lines, and reconnect yourself after 5 s.

### 3.1 Trip tracking: `GET /api/live/stream`

- Server: `routes/live.ts`. Heartbeat comment `: ping` every 20 s. No initial snapshot: the first event comes on the
  next tracker tick.
- Event `live`, data = `LiveUpdate` (server `live/tracker.ts:26`; TS `api.ts:274`):
  - `legId: string`
  - `live: { status: LiveStatus, prevStopId: string | null, nextStopId: string | null, eta: number | null,
    arrivalEta: number | null, arrivalDelayMin: number | null, progress: number | null, lat: number | null,
    lon: number | null, bearing: number | null, speedKmh: number | null, positionSource: "gps" | "estimated" | null,
    positionAt: number | null, updatedAt: number, reportedAt: number | null }` (`LiveView` from
    `packages/shared/src/progress.ts:45`, plus `updatedAt`/`reportedAt`). **All times are ms numbers here** (ISO
    strings in REST). No `legId` inside `live`.
  - `events: { type: LegEvent type, ts: number /*ms*/, payload: object }[]` (no `id`; payloads as in §2.6)
- Cadence: the tracker ticks every 20 s (`POLL_MS`, `tracker.ts:21`) and emits one `live` event per tracked leg per
  tick. A leg is tracked from 1 h before scheduled departure until 30 min after its (actual or expected) arrival
  (`trackedLegIds`, `tracker.ts:136`).
- **Per user**: each listener gets only updates for its own legs (`routes/live.ts` checks the owner of every update;
  test `perUser.test.ts`). Still match `legId` to the screen you're on: Trips page maps only matching ids
  (`pages/TripsPage.tsx:398`), Trip detail checks `u.legId !== id` (`TripDetailPage.tsx:148`), Journey page checks its
  legs (`JourneyPage.tsx:28`).
- Web client (`apps/web/src/live.ts`): one shared EventSource for the whole app, opened when the first listener
  mounts and closed when the last unmounts; relies on EventSource's own reconnect ("the server sends a full live
  state every tick, so nothing needs replaying"). On an update for the open trip the detail page sets `live` at once,
  then refetches `GET /legs/:id`, and shows a toast for the first event whose type isn't `departed`.
- No update for more than 60 s (`LOCAL_AFTER_MS`, `offline.ts:79`): the trip page computes the position itself
  (`localLive`, §5).

### 3.2 Station board: `GET /api/stations/:id/board/stream?type=<departures|arrivals>`

- Server: `routes/boards.ts:79-99`. 404 `{ error: "no board" }` (plain JSON, before the stream starts) if `type` is
  invalid or the station has no board source. Heartbeat `: ping` every 20 s.
- Event `board`, data = a full `Board` (§2.4). One right away (the current board), then a full board after every
  shared poll, every 20 s (`BOARD_POLL_MS`, `boards/hub.ts:13`). An upstream failure during polling is only logged;
  no event is sent that tick.
- Web (`pages/BoardPage.tsx:112-124`): opens when the station has `hasBoard`; replaces the whole board on each event;
  `onerror` shows an error state (EventSource keeps retrying); closes when leaving or switching type. The page calls
  the board "fresh" if `now − board.updatedAt < 2 min` (`BoardPage.tsx:164`).

### 3.3 Live map: `GET /api/live/trains/stream?bbox=<w,s,e,n>`

- Server: `routes/livemap.ts:43-74`. `bbox` as in `/live/trains` (padded 20% on the server; the web sends 3 decimals:
  `[west, south, east, north].map(v => v.toFixed(3)).join(',')`, `LiveMapPage.tsx:313-316`). No heartbeat comment,
  but a `delta` is sent every 2 s even when nothing changed (`FLUSH_MS`, `livemap/ingest.ts:68`).
- Event `snapshot` (once, first): `{ trains: LiveTrain[] /*inside bbox*/, total: number, upstreamAt: number /*ms*/,
  mode: "stream" | "poll" | "simulate" | "stopped" }`.
- Event `delta` (every 2 s): `{ changed: LiveTrain[], moved: MovedTuple[], removed: string[] /*train ids*/,
  total: number, upstreamAt: number /*ms*/, mode: string }`.
  - `changed`: trains new to this client or whose non-position fields changed (full objects).
  - `moved`: trains whose only change is position, as a 7-element JSON array
    `[id: string, lat: number, lon: number, bearing: number | null, speedKmh: number | null, at: number /*ms*/,
    estimated: boolean]` (`MovedTuple`, `routes/livemap.ts:29`; lat/lon rounded to 5 decimals). Apply over the train
    you already hold; ignore if unknown. Swift: decode with an `UnkeyedDecodingContainer`.
  - `removed`: ids that left the map or the bbox.
- Web (`pages/LiveMapPage.tsx:477-516`): (re)subscribes 400 ms after the map stops moving (a new bbox closes the old
  stream and opens a new one); `onerror` marks the stream down, `onopen` and any message mark it up; "Delayed data"
  shows when `upstreamAt > 0 && now − upstreamAt > 60 s` (`STALE_MS`, `LiveMapPage.tsx:58`, `707`). Positions older
  than 2 min (`GPS_FRESH_MS`) are labelled old; estimated ones are drawn hollow. Markers glide over 1.5 s
  (`GLIDE_MS`).
- The ingest only runs while someone has the map open and stops 60 s after the last viewer leaves
  (`IDLE_STOP_MS`); the first snapshot after a cold start may be empty.

### 3.4 Polling the web client does

| What | Interval | Where |
|---|---|---|
| `GET /legs/:id/risk` | 5 min | `components/Risk.tsx:20` |
| `GET /live/trains/:id/stops` (selected map train) | 30 s | `pages/LiveMapPage.tsx:687` |
| `GET /trains/:number/:date` (scheduled train sheet) | 30 s | `pages/LiveMapPage.tsx:675` |
| `GET /legs/:id` (trip detail) | after every `live` event for that leg | `pages/TripDetailPage.tsx:147-153` |
| `GET /journeys/:id` | after a `live` event for one of its legs, at most every 20 s | `pages/JourneyPage.tsx:23-31` |
| Clock re-render ("updated 12 s ago") | 1 s | `live.ts` `useNow` |
| Disruption card clock | 30 s | `components/Disruption.tsx` `useNow(30_000)` |

Debounces: Add trip search 150 ms (`AddTripPage.tsx:489`), live map station search 200 ms (`LiveMapPage.tsx:530`),
live map bbox re-subscribe 400 ms.

---

## 4. Enum-like values

- `Product` (`api.ts:67`; `search/timetable.ts:7`): `high_speed`, `intercity`, `night`, `regional`, `commuter`,
  `heritage`. (The live map filter offers `high_speed, intercity, regional, commuter, night`,
  `LiveMapPage.tsx:56`.)
- Timetable `category`: `intercity`, `regional`, `commuter`, `heritage` (`CATEGORIES`, `index.ts:12`), plus `night`
  seen in the data. Manual legs accept `high_speed, intercity, night, regional, commuter, heritage`. The product is
  `high_speed` for GTFS route_type 101, `night` for 105, otherwise the category (`productOf`, `timetable.ts:53`).
- Leg `status` (`LEG_STATUSES`, `index.ts:19`): `planned`, `completed`, `snapshotted`.
- Leg `dataQuality` (`DATA_QUALITIES`, `index.ts:16`): `full` (actual departure and arrival known), `partial`,
  `scheduled_only`, `manual`.
- Leg `trainTypeSource`: `typical`, `composition`, `user` (or null).
- Leg `ride` (`RIDES`, `legs/recording.ts:12`): `pending`, `auto`, `confirmed`, `review`, `not_taken`. Only `auto` and
  `confirmed` count in the Passport.
- `rideReason` (`legs/recording.ts:43-56`, schema comment `db/schema.ts:202`): `actual_times`, `border_reports`,
  `added_after`, `you`, `cancelled`, `partial_reports`, `no_reports`, `waiting_reports`, `not_arrived` (or null).
- `LegStop.role`: `before`, `board`, `through`, `alight`, `after`.
- `LegStop.reportSource` / `TrainStopView.source`: `trafikverket`, `entur`, null.
- `LiveStatus` (`packages/shared/src/progress.ts:18`): `scheduled`, `boarding`, `en_route`, `at_stop`, `arrived`,
  `cancelled`.
- `positionSource`: `gps`, `estimated`, null.
- Leg event `type`: `delayed`, `platform_changed`, `cancelled`, `short_turned`, `departed`, `arrived`.
  `platform_changed.which`: `departure`, `arrival`.
- `BoardType`: `departures`, `arrivals`.
- Live map `mode`: `stream`, `poll`, `simulate`, `stopped`.
- Search `interpretation.typing`: `from`, `to`, null. `history`: `ready`, `loading`, `failed`, `unavailable`,
  `norway`.
- `LegRisk.limits`: `too_far`, `abroad`, `no_live_data`, `no_history`. `RiskWarning.kind`: `route_now`,
  `station_now`, `ahead`, `train_pattern`.
- `Milestone.family`: `journeys`, `distanceKm`, `stations`, `operators`, `countries`, `borderCrossings`,
  `nightTrains`.
- Passport delay `bands` keys: `on_time`, `slight`, `late`, `very_late`.
- Settings: `language` `en | sv`; `distanceUnit` `km | mi`; `clock` `24h | 12h`; `theme` `system | dark | light`;
  `walkPace` `relaxed | normal | brisk`; `co2Comparison` `flight | car_1 | car_2 | car_3 | car_avg | ev_1 | coach`.
- `OnboardFacts` (`packages/shared/src/onboard.ts:43`): `catering: CateringKind | null`, `cateringCar: string | null`
  (e.g. `"B"`), `sleeper: boolean`, `notices: OnboardNotice[]`. `CateringKind`: `bistro`, `cafe`, `kiosk`,
  `refreshments`, `restaurant`. `OnboardNotice`: `no_catering`, `no_toilet`, `no_bikes`, `no_first_class`,
  `changed_type`.
- `AmenityKey` (`onboard.ts:6`): `catering`, `wifi`, `power`, `quiet_car`, `first_class`, `family_area`,
  `pets_area`, `bikes`, `wheelchair_space`, `step_free`, `accessible_toilet`, `sleeper`.
- Station `sizeClass`: `small`, `medium`, `large`. Station map enums (node types, edge kinds, POI categories
  `toilet, cafe, restaurant, kiosk, shop, ticket, locker, waiting, info, pharmacy, atm, taxi, bus, other`, shape
  kinds, quality, source types) in §2.3.
- Feed health `status`: `ok`, `degraded`, `down`, `unknown`.
- Client-side only (shared code): `DelayBand` `on_time | slight | late | very_late | cancelled | unknown`
  (`delay.ts:5`); `ConnectionStatus` `easy | tight | miss | unknown | broken | margin` (`station.ts:372`);
  `DisruptionKind` `canceled | skips_board | skips_alight | replacement | delayed | connection_missed |
  connection_at_risk` and `Urgency` `act_now | heads_up | info` (`disruption.ts:4`, `21`); `Rights.regime`
  `eu | se_short | operator` with claims `refund_or_reroute | compensation_25 | compensation_50 | price_reduction`
  (`disruption.ts:72`); `OpenState` `open | closing_soon | closed | unknown` (`hours.ts:126`); trip status chip
  `planned | boarding | live | completed | cancelled` (`live.ts` `statusKey`).
- Country codes seen: `SE`, `NO`, `DK` (others possible abroad).

---

## 5. What the client computes itself

These are pure functions the Swift app must port (or show less). Most live in `packages/shared/src`, which the
server uses too, so their rules are shared truth.

### Time and parsing
- `ms(t)`: ISO-string-or-number to epoch ms (`apps/web/src/api.ts:437`). Needed for every `Leg`, `LegStop`,
  `LiveState` and event time.
- Formatting in each station's own `tz` (`apps/web/src/format.ts`): `fmtTime` (honours `clock`), `fmtDay`,
  `localDate`, `dayOffset` (the "+1" on arrivals after midnight, origin tz vs destination tz), `fmtDuration`,
  `fmtDistance` (metres to km or mi by `distanceUnit`), `fmtDelay`, `todayIso` (Stockholm date, the default search
  and follow date), `addDaysIso`.
- Polyline decode (`packages/shared/src/polyline.ts:27`, Google format, precision 5, `[lat, lon]`). Used for
  `Leg.geometry`, `TripGeometry.segments[].polyline`, `Passport.map[].geometry`. Segment concatenation drops each
  later segment's first point (`LiveMapPage.tsx:613-617`).

### Status and freshness (`apps/web/src/live.ts`)
- `statusKey(leg, live, now)`: the status chip. Cancelled if `leg.canceled` or `live.status == cancelled`; with fresh
  live data (see below) `boarding`, `live` (en_route or at_stop) or `completed` (arrived); otherwise from times:
  completed if `leg.status != planned` or now ≥ arrival; live if now ≥ departure; boarding within 30 min of departure;
  else planned. Departure/arrival = actual ?? scheduled.
- `dataAt(live) = ms(reportedAt) ?? ms(updatedAt) ?? 0`; `isFresh` = under 2 min old (`STALE_MS`); `isLive` = status
  in boarding / en_route / at_stop; `SPEED_FRESH_MS` 60 s (hide older speeds); `agoKey` ("just now" under 5 s,
  seconds under 90 s, then minutes).
- Trips page (`pages/TripsPage.tsx`): `arrivalOf` (a late live train stays upcoming until `arrivalEta`), `countdown`
  ("departs in 2h 5m", boarding within 30 min), `expected` (best-known dep/arr: actual, else live `arrivalEta`, else
  scheduled + delay), `meets` (two legs connect: same station, gap between −2 h and 12 h), `nextInJourney`.
- Landing tab choice from the legs list (`apps/web/src/landing.ts` `resolveLanding`, called in
  `components/AppShell.tsx:43`; not read in detail).

### Offline position (`apps/web/src/offline.ts:86` `localLive`)
- When no live update has come for 60 s while a trip is being tracked, the phone recomputes `LiveState` from the
  cached `LegDetail` (ridden stops, geometry) and the last GPS fix using the shared `liveView`
  (`packages/shared/src/progress.ts:141`), and marks it `localEstimate: true`. `liveView` depends on
  `expectedTimes`, `cumulative`, `locate`, `pointAt` (same file) and the constants `BOARDING_MS` 30 min,
  `GPS_FRESH_MS` 2 min, `DEAD_RECKONING_MS` 5 min. Port all of it to keep the train moving through tunnels.

### Connections between legs (`apps/web/src/components/Connection.tsx`)
- `connectionTimes(a, b)`: expected arrival of A (actual, else live `arrivalEta`, else scheduled + `arrDelayMin`)
  and departure of B (actual, else live `eta` while B is scheduled or boarding, else scheduled + `depDelayMin`), and
  whether both are live.
- Walk time: from the arrival station's map, `routeTracks(map, a.arrPlatform, b.depPlatform, profile)`
  (`packages/shared/src/station.ts:261`, Dijkstra in `routeNodes`, per-edge `edgeSeconds` with pace factors
  relaxed 1.25 / normal 1 / brisk 0.8 and luggage penalties), profile from settings (`profileOf`).
- `connectionStatus` (`station.ts:402`): slack = layover − walk − 60 s deboard − 30 s board; miss < 0, tight < 5 min,
  margin when the walk is a size estimate (`SIZE_WALK_SECONDS` small 120 / medium 240 / large 420 s) or the times
  aren't live, else easy; broken if either train is cancelled; unknown without times or platforms. Fallback size:
  `StationInfo.sizeClass ?? (map ? 'large' : 'medium')`.
- Station map page also uses `resolveEndpoint`, `routeBetween`, `instructions`, `nearestNode`, `toLocal`,
  `secondsFrom` (`station.ts`) and the opening-hours evaluator `openState` / `parseHours` / Swedish holidays
  (`packages/shared/src/hours.ts`, times in Europe/Stockholm).

### Disruptions (`apps/web/src/components/Disruption.tsx`)
- `assessDisruption` (`packages/shared/src/disruption.ts:43`): kinds and urgency from the leg (cancelled,
  board/alight stop cancelled, replacement-bus deviation texts, ≥ 15 min late, connection status), urgency by how
  soon departure is (3 h, 48 h).
- `passengerRights` (`disruption.ts:77`): EU vs Swedish short-journey vs operator terms, from countries, journey km
  (sum of `distanceM` over the journey) and arrival delay; links in `RIGHTS_LINKS`.
- `delayReasons` (`disruption.ts:123`): reason texts from `LegStop.deviations` via the fixed `DELAY_REASONS` table.
- The "other ways" search parameters (`from`, `to`, `after`, `exclude`) for `/alternatives` are built here.

### Other
- Delay bands: `delayBand` (≤ 0 on time, ≤ 15 slight, ≤ 30 late, else very late), `isOnTime` (≤ 5 min),
  `delayMinutes` (minute-floored difference) (`packages/shared/src/delay.ts`).
- Typical amenities for a train: `typicalAmenities(table, operatorId, trainTypeId)` (`onboard.ts:58`): operator-wide
  claims overridden by type claims; claims whose `verified` date is over 365 days old are dropped.
- Ticket link: `ticketHref(ticketUrl, ticketDeepLink, trip)` (`components/Tickets.tsx:57`): fills `{from}`, `{to}`
  (URL-encoded station names), `{date}` (`YYYY-MM-DD`) and `{time}` (`HH:MM`) in the departure station's tz. A
  pending purchase is remembered for 3 h in `localStorage['clack.ticketPending']` to offer "Add this trip" on return.
- Board page filtering (`pages/BoardPage.tsx:137-151`): hides rows past a cutoff, window 3 h etc., commuter /
  operator / product filters, all client-side.
- Risk card: a planned change under 10 min with a "now" warning is flagged (`components/Risk.tsx:36-38`).
- Journey grouping is server-side (`legs/journeys.ts`); the client only reads `journeyId`.
- Live map: your own trains come marked by the server (`mine`, per user, §2.9). Followed trains are matched on the
  client by `number|date` keys (`followKeys` in `LiveMapPage.tsx`).

---

## 6. Gaps between the TS types and the wire (worth knowing when writing Codable)

- `Leg` also carries `operatorId`, `originStationId`, `destStationId`; `live` also carries `legId`; REST events carry
  `id` and `legId`.
- `StationInfo` also carries `countyNo` and `baseTracks`.
- `LiveTrainStop` on the wire also has `source`.
- `TrainView.live` and `Follow.train` are full `LiveTrain` objects; the TS types declare only a few fields.
- `/live/trains/:id` `trip` also has `from` and `to` (`StopRef`).
- `Passport.records.busiestStation` also has `country`, `lat`, `lon`.
- REST times on legs, stops, live state and events are ISO strings; SSE live times and everything on boards, the live
  map, search, timetable, passport, risk and progress are epoch-ms numbers.
- Make every optional or nullable field optional in Swift: the server adds keys over time, and old rows can miss
  keys (settings are merged with defaults, other objects aren't).
