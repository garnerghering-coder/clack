# Clack

Log every train you ride, see it on the real tracks, and build a passport of your rail history.
It is a native SwiftUI iPhone app (`apps/Clack`) and a server it talks to (`apps/server`), which holds the trips and
fetches the train data. See [`SPEC.md`](SPEC.md) for what it does, [`DESIGN.md`](DESIGN.md) for how it looks,
[`DATA_FINDINGS.md`](DATA_FINDINGS.md) for what Phase 0 learned about Sweden's data and
[`NORWAY_DATA_FINDINGS.md`](NORWAY_DATA_FINDINGS.md) for Norway's and
[`FINLAND_DATA_FINDINGS.md`](FINLAND_DATA_FINDINGS.md) for Finland's.

## Run it (macOS)

The app needs Xcode (26 or later). The server runs on the Mac for development; the app uses the hosted server
(`docs/SERVER.md`) unless it is a debug build in the simulator, which uses the one on this Mac.

**One-time setup**

1. Open **Terminal** (Cmd+Space, type "Terminal").
2. Install Node.js 22 or newer: download the LTS installer from [nodejs.org](https://nodejs.org), run it, reopen Terminal, check `node -v`.
3. Get the code (if macOS offers to install the "command line developer tools", accept, then repeat this step):
   ```sh
   git clone https://github.com/garnerghering-coder/clack
   cd clack
   ```
4. Add your API keys. Use `nano` (not TextEdit, which can save rich text and break the file):
   ```sh
   cp .env.example .env
   nano .env        # paste each key after the "=", then Ctrl+O, Enter, Ctrl+X
   ```
5. `npm install`

**Every time**

```sh
cd clack
npm run dev
```

Wait for the green **✓ Clack server is ready** box in Terminal. The server listens on <http://localhost:3001>
(`/api/health` shows it is up). Stop with Ctrl+C. Then open `apps/Clack/Clack.xcodeproj` in Xcode, choose an iPhone
simulator and press Cmd+R: a debug build in the simulator talks to this server.

- **First start is slow.** The server downloads the timetable (~800 MB, one use of the monthly GTFS Sweden 3 quota)
  and imports it. Station search stays empty until the Terminal prints `imported in … s`. It then downloads the map
  background once (~470 MB from Protomaps' free map build, kept as ~80 MB in `data/cache/basemap/`; the Terminal prints
  `Basemap: wrote …` when done). The app's maps still draw your routes before that, just on a plain background. Later
  starts are quick. To fetch the map background by hand: `npm run import -- basemap`. It also downloads each train
  operator's logo (their website's app icon) into `data/cache/logos/`; operators without one show coloured initials.
- **On your iPhone:** a build on a phone uses the hosted server, not your Mac. To point a debug build at another
  server, pass `-apiBase https://…` as a launch argument. Putting the server online and updating it: `docs/SERVER.md`.
- **Norway** needs no key. Entur's rail timetables (~100 MB for Vy, Go-Ahead, SJ Nord and Flytoget) download on
  first start and at most once a day after that. Every request to Entur names the app (`ENTUR_CLIENT_NAME`, default
  `garner-clack`), as Entur asks.
- **Finland** needs no key either: data from Digitraffic (Fintraffic), licensed CC BY 4.0, credit `Source: Fintraffic / digitraffic.fi, license CC 4.0 BY` (shown on the About screen).
- **Delay data:** Trafikverket keeps actual times for only ~4 days, and Entur only for the day the train runs. The server saves them for your trips while it's
  running and catches up when it starts, so start the app at least every few days.
- **Updating:** `git pull`, then `npm ci` if dependencies changed (the hosted server: `docs/SERVER.md`).
- **If something goes wrong** the server restarts itself: after a crash, or if it stops answering for five minutes
  (Terminal shows a yellow `[supervisor]` line saying which). `http://localhost:3001/api/health` shows how Trafikverket
  and Entur are answering.
- **Accuracy audit:** every hour the server checks trips that finished at least an hour ago against Trafikverket's
  final record and writes `data/audit/latest.md` (numbers at `/api/audit`; by hand: `npm run import -- audit`). To
  have numbers from the first day, it also follows two real trains an hour, 05–22, as a hidden user you never see
  (`AUDIT_SAMPLE_PER_HOUR=0` in `.env` turns that off). See [`docs/RELIABILITY_PLAN.md`](docs/RELIABILITY_PLAN.md).
- **No connection on the train:** trips you've opened are kept on the phone, and the train keeps moving from its last
  report, marked as an estimate, until the connection is back.

## How often it asks Trafikverket and Entur

Everything is shared on the server: two phones looking at the same thing cost the same
as one. Nothing polls while nobody is looking, except your own trips.

| What | Requests | When |
|---|---|---|
| Your trips (live tracking) | 1 TrainAnnouncement + 1 TrainPosition per live trip every 20 s | An hour before departure until 30 min after arrival |
| Accuracy audit sample | The same, for 2 sample trains an hour; 1 TrainAnnouncement per finished trip | 05–22 |
| Delay catch-up | 1 TrainAnnouncement per trip | At start, for trips of the last 4 days |
| Station board | 1 TrainAnnouncement per station and direction every `BOARD_POLL_MS` | While the board is open, plus 60 s |
| Live map: positions | 1 TrainPosition stream (Trafikverket SSE) for the whole country; 1 catch-up query per reconnect. After 3 failed streams in a row it polls every `LIVE_MAP_POLL_MS` instead | While the map is open, plus 60 s |
| Live map: delays and destinations | 1 TrainAnnouncement change query every `LIVE_MAP_ANNOUNCE_MS`; a full reload of the window (an hour back to two ahead, ~10,000 rows) every 20 min | Same |
| Live map: Norway | Entur GTFS-RT vehicle positions + trip updates for the 4 rail operators (8 requests) every `LIVE_MAP_NORWAY_POLL_MS` | Same |
| Norwegian trips | 1 Journey Planner query per live trip (cached 30 s) + 1 vehicle-positions request per operator, every 20 s | Same window as Swedish trips |
| Norwegian station board | 1 Journey Planner query per station and direction every `BOARD_POLL_MS` | While the board is open, plus 60 s |
| Live map: Finland | Digitraffic `/train-locations/latest` (all running trains, about 100) every `LIVE_MAP_FINLAND_POLL_MS`; `/live-trains` once in full, then only what changed since the highest `version` seen, every 30 s (a full reload every 30 min); `/compositions/{date}` for unit types every 15 min. About 9 requests a minute | Same |
| Finnish trips | 1 `/trains/{date}/{number}` per live trip (cached 30 s) + the shared `/train-locations/latest`, every 20 s | Same window as Swedish trips |
| Finnish station board | 1 `/live-trains/station/{code}` per station (cached 30 s, shared by departures and arrivals) | While the board is open, plus 60 s |

Digitraffic allows 60 requests a minute per client; the client in `digitraffic/client.ts` keeps to 40 with a token bucket.

Entur allows 1,000 requests a minute with the client name; if it ever answers "too many", nothing is sent to it again
until the reset time it gives.

Optional settings in `.env` (defaults shown):

```sh
BOARD_POLL_MS=20000           # station boards
LIVE_MAP_ANNOUNCE_MS=30000    # live map delay/destination refresh
LIVE_MAP_POLL_MS=20000        # live map positions, only if the stream keeps failing
LIVE_MAP_INCLUDE_ESTIMATED=1  # 0: live map shows GPS positions only, no estimates
LIVE_MAP_SIMULATE=0           # e.g. 1000: fake trains along real track instead of Trafikverket (demo, load test)
LIVE_MAP_NORWAY=1             # 0: no Norwegian trains on the live map
LIVE_MAP_NORWAY_POLL_MS=20000 # Norway's live map feeds (Entur refreshes them every 15 s)
LIVE_MAP_FINLAND=1            # 0: no Finnish trains on the live map
LIVE_MAP_FINLAND_POLL_MS=10000 # Finland's train locations (Digitraffic updates each train about every 8 s)
ENTUR_CLIENT_NAME=garner-clack
```

The live map shows passenger trains that are running. Freight, empty runs and trains that have parked are left out.
About 1 in 7 trains sends no GPS (Phase 0); those are drawn hollow, at a position worked out from their last stop,
next stop and delay, along the track. For the first minute after the server starts, while the announcements load,
trains show without destination or delay, and no estimated trains appear yet.

## Layout

| Path | What |
|---|---|
| `apps/Clack` | The SwiftUI iPhone app (`Clack.xcodeproj`; the Swift package `ClackKit` with ClackCore and ClackDesign is being split out of it) |
| `apps/server` | Fastify + TypeScript API, SQLite via Drizzle (`data/app.db`); also serves the privacy page |
| `packages/shared` | Types and constants the server and its tests use, and the strings (`locales/en.json`, `sv.json`) the app copies |
| `assets/trains` | The train drawings (SVG), made by `scripts/trains` |
| `scripts/` | Data tools (`phase0/`, `fixtures/`, `stations/`), the train drawings (`trains/`) and what feeds the app (`ios/`) |
| `data/` | Hand-maintained config (category rules, station overrides), test fixtures; downloads go to `data/cache/` |
| `docs/` | Plans and notes: the app (`IOS.md`, `SWIFT_PORT.md`), the hosted server (`SERVER.md`), App Review (`APP_STORE.md`) |

## Other commands

```sh
npm test              # server and shared tests
npm run typecheck
npm run db:generate   # after changing apps/server/src/db/schema.ts, create a migration
python3 scripts/ios/sync_assets.py   # copy the strings and train drawings into the app
```

Migrations run automatically when the server starts.
