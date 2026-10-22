# Clack

Log every train you ride, see it on the real tracks, and build a passport of your rail history.
Phase 1 is a single-user demo for Sweden and Norway that runs on your laptop. See [`SPEC.md`](SPEC.md) for the plan,
[`DATA_FINDINGS.md`](DATA_FINDINGS.md) for what Phase 0 learned about Sweden's data and
[`NORWAY_DATA_FINDINGS.md`](NORWAY_DATA_FINDINGS.md) for Norway's.

## Run it (macOS)

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

Wait for the green **✓ Clack is ready** box in Terminal, then open <http://localhost:5173>. Stop with Ctrl+C.

- **First start is slow.** The server downloads the timetable (~800 MB, one use of the monthly GTFS Sweden 3 quota)
  and imports it. Station search stays empty until the Terminal prints `imported in … s`. It then downloads the map
  background once (~470 MB from Protomaps' free map build, kept as ~80 MB in `data/cache/basemap/`; the Terminal prints
  `Basemap: wrote …` when done). Maps still draw your routes before that, just on a plain dark background. Later
  starts are quick. To fetch the map background by hand: `npm run import -- basemap`. It also downloads each train
  operator's logo (their website's app icon) into `data/cache/logos/`; operators without one show coloured initials.
- **On your iPhone:** run `npm run dev:phone`, click **Allow** if the Mac asks about incoming connections, and open the
  "Network" address Vite prints (e.g. `http://192.168.1.20:5173`) in Safari on the same Wi-Fi. Installing it as a
  home-screen app needs HTTPS, which comes later.
- **Norway** needs no key. Entur's rail timetables (~100 MB for Vy, Go-Ahead, SJ Nord and Flytoget) download on
  first start and at most once a day after that. Every request to Entur names the app (`ENTUR_CLIENT_NAME`, default
  `garner-clack`), as Entur asks.
- **Delay data:** Trafikverket keeps actual times for only ~4 days, and Entur only for the day the train runs. The server saves them for your trips while it's
  running and catches up when it starts, so start the app at least every few days.
- **Updating:** `git pull`, then `npm install` if dependencies changed.
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

Everything is shared on the server: two browser tabs (or, later, two people) looking at the same thing cost the same
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
ENTUR_CLIENT_NAME=garner-clack
```

The live map shows passenger trains that are running. Freight, empty runs and trains that have parked are left out.
About 1 in 7 trains sends no GPS (Phase 0); those are drawn hollow, at a position worked out from their last stop,
next stop and delay, along the track. For the first minute after the server starts, while the announcements load,
trains show without destination or delay, and no estimated trains appear yet.

## Layout

| Path | What |
|---|---|
| `apps/web` | React + TypeScript + Vite PWA (MapLibre maps come in a later step) |
| `apps/server` | Fastify + TypeScript API, SQLite via Drizzle (`data/app.db`) |
| `packages/shared` | Types shared by both |
| `scripts/` | One-off data tools (`phase0/` = data verification, `fixtures/` = saving test data) |
| `data/` | Hand-maintained config (category rules, station overrides), test fixtures; downloads go to `data/cache/` |

## Other commands

```sh
npm test              # all tests
npm run typecheck
npm run build         # production build of the web app
npm run db:generate   # after changing apps/server/src/db/schema.ts, create a migration
```

Migrations run automatically when the server starts.
