# Clack

Log every train you ride, see it on the real tracks, and build a passport of your rail history.
Phase 1 is a single-user demo for Sweden that runs on your laptop. See [`SPEC.md`](SPEC.md) for the plan
and [`DATA_FINDINGS.md`](DATA_FINDINGS.md) for what Phase 0 learned about the data.

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

Open <http://localhost:5173>. Stop with Ctrl+C.

- **First start is slow.** The server downloads the timetable (~800 MB, one use of the monthly GTFS Sweden 3 quota)
  and imports it. Station search stays empty until the Terminal prints `imported in … s`. Later starts are quick.
- **On your iPhone:** run `npm run dev:phone`, click **Allow** if the Mac asks about incoming connections, and open the
  "Network" address Vite prints (e.g. `http://192.168.1.20:5173`) in Safari on the same Wi-Fi. Installing it as a
  home-screen app needs HTTPS, which comes later.
- **Delay data:** Trafikverket keeps actual times for only ~4 days. The server saves them for your trips while it's
  running and catches up when it starts, so start the app at least every few days.
- **Updating:** `git pull`, then `npm install` if dependencies changed.

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
