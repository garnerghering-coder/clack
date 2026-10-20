# Clack

Log every train you ride, see it on the real tracks, and build a passport of your rail history.
Phase 1 is a single-user demo for Sweden that runs on your laptop. See [`SPEC.md`](SPEC.md) for the plan
and [`DATA_FINDINGS.md`](DATA_FINDINGS.md) for what Phase 0 learned about the data.

## Run it

You need [Node.js](https://nodejs.org) 22 or newer.

```sh
cp .env.example .env      # then paste your three API keys into .env
npm install
npm run dev               # server + web app together
```

Open <http://localhost:5173>. Stop with Ctrl+C.

- **On your phone:** run `npm run dev:phone` instead, then open the "Network" address Vite prints
  (e.g. `http://192.168.1.20:5173`) on a phone on the same Wi-Fi. Installing it as a home-screen app
  needs HTTPS, which comes later.
- **Delay data:** Trafikverket keeps actual times for only ~4 days. The server saves them for your trips
  while it's running, and catches up when it starts, so start the app at least every few days.

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
