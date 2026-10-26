# The hosted server

The iPhone app talks to one Clack server on the internet (`Config.apiBase` in `apps/Clack/Clack/API/Config.swift`:
`https://getclack.app`). This file says where it runs, how to reach it, what it needs and how to update it.
Anything not written down in the repository is marked **Owner:** for Garner to fill in or confirm.

## Where it runs

- A Hetzner Cloud VM (Ubuntu 24.04, ARM, 2 vCPU, 4 GB), set up on 2026-10-23 after Oracle Cloud Free Tier had no
  capacity.
- Public names `getclack.app` (bought on Namecheap, 2026-10-25; A records `@` and `www` to the VM's IP address) and the older free `clack-garner.duckdns.org` (DuckDNS, same IP), both served; `www.getclack.app` redirects to `getclack.app`. Caddy gets and renews the https
  certificate by itself.
- **Log in** from the Mac that made the key: `ssh -i ~/.ssh/clack_oracle root@clack-garner.duckdns.org` (the key is
  called `clack_oracle` because it was first made for the Oracle attempt). **Owner:** keep a second copy of that key
  somewhere safe; if the Mac is lost, the Hetzner console is the only way back in.
- The code is in `/home/clack/clack`, on branch **`main`** (the repository's GitHub default branch is the older
  `phase0-data-findings`, so a fresh clone must `git checkout main`). It runs as the systemd service **`clack`**, as
  the user **`clack`**, with `npm start` (which runs `scripts/supervise.mjs`: restart after a crash or a hung server).
- Fastify listens on `127.0.0.1:3001` only; Caddy is the only thing the internet reaches (ports 80 and 443).

## What Fastify serves

- `/api/*`: everything the app calls. `/api/health` shows the version, uptime and how Trafikverket and Entur are
  answering.
- `/privacy` and `/privacy/sv`: the privacy page (plain HTML in `apps/server/public/privacy`), which is the privacy
  policy URL for App Store Connect (`https://getclack.app/privacy`).
- `/j/<token>`: a shared journey's page, for people without the app (`apps/server/public/share`, the MapLibre library
  from the `maplibre-gl` npm package, the app's fonts). The page reads `/api/shared/<token>`, a cut-down copy that never
  has the traveller's id, seat, ticket or other trips. `/share-assets/*` are its files.
- `/.well-known/apple-app-site-association`: tells iOS that links to `/j/*` open the app (team `HJTCN7QR8M`, bundle
  `com.garnerghering.Clack`). The app needs the Associated Domains capability (`applinks:getclack.app` and the old `applinks:clack-garner.duckdns.org`).
- Nothing else. There is no web app, so Caddy serves no files itself (it sends every path to Fastify, so these pages
  need no Caddy change).

## Watching the alerts

Every alert and Live Activity update goes through the server, so if it stops, it stops for everyone. With the admin token,
`GET /api/health` has a `push` part: pushes Apple accepted since the server started, when the last one went through, when the
last one failed and the failures counted by Apple's reason (`BadDeviceToken` is one phone gone; a run of anything else,
or `lastOkAt` falling far behind while people have trips, means look at the log lines starting `push:`). Nothing pages
anyone: it has to be looked at.

## `.env`

`/home/clack/clack/.env` is read at start-up (not in git; never paste the values anywhere). The names:

| Name | What |
|---|---|
| `TRAFIKVERKET_API_KEY` | Trafikverket Open API: actual times, delays, platforms, live positions |
| `TRAFIKLAB_GTFS_SWEDEN3_KEY` | GTFS Sweden 3 (timetables; 50 downloads a month) |
| `TRAFIKLAB_GTFS_SVERIGE2_KEY` | GTFS Sverige 2 (history) |
| `CLACK_REQUIRE_USER=1` | Refuse `/api` requests that don't say which phone they come from, so nobody can read the local user's trips |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH`, `APNS_TOPIC` | Apple Push: the key id, the team id, the path to the `.p8` key file (kept like a password, outside git) and the app's bundle id `com.garnerghering.Clack`. Without all four, alerts and Live Activity updates stay off (the server logs `push: alerts off`) |

Optional for sharing: `CLACK_APP_DOWNLOAD_URL` (where the page's "Get Clack" button goes: the TestFlight public link now,
the App Store address later; unset, the button is shown but goes nowhere) and `CLACK_PUBLIC_URL` (the address put in share
links when the server can't tell it from the request).

Optional: `PORT` (3001), `HOST` (127.0.0.1), `DATABASE_PATH` (`data/app.db`), `ENTUR_CLIENT_NAME`, and the polling
settings in the README. `CLACK_ALLOWED_ORIGINS` was for the old web wrapper and is no longer read; delete it from the
server's `.env` if it is there.

## Caddy

`/etc/caddy/Caddyfile` is exactly this (everything goes to Fastify; the live streams are not compressed, because
iOS asks for gzip and Caddy then holds events back until a block fills, so the live map took about ten seconds to show
its trains):

```
clack-garner.duckdns.org, getclack.app {
  @streams path /api/live/stream /api/live/trains/stream /api/stations/*/board/stream
  handle @streams {
    reverse_proxy 127.0.0.1:3001 {
      flush_interval -1
    }
  }
  handle {
    encode gzip
    reverse_proxy 127.0.0.1:3001 {
      flush_interval -1
    }
  }
}

www.getclack.app {
  redir https://getclack.app{uri} permanent
}
```

Apply it with `systemctl reload caddy`. The three stream paths are the server's three event streams
(`routes/live.ts`, `routes/livemap.ts`, `routes/boards.ts`); a new stream needs adding to the matcher. Backups of
earlier Caddyfiles: `/etc/caddy/Caddyfile.bak` (the one that also served the web app) and `Caddyfile.before-getclack`.

## Updating

After the owner pushes to `main`, on the server:

```
cd /home/clack/clack
sudo -u clack git pull && sudo -u clack npm ci
systemctl restart clack
```

That is `git pull && npm ci && systemctl restart clack`, with git and npm run as the `clack` user and the restart as
root. Migrations run when the server starts. Then check `https://getclack.app/api/health` (its `version` is the commit the server runs; Settings in the
app shows the same).

## Backups

The server's database, `/home/clack/clack/data/app.db` (SQLite, with `app.db-wal` and `app.db-shm` beside it), holds
every user's trips, follows, settings and push addresses, and the observed record (SPEC §5.6). The raw archive in
`data/observed/` (and the raw timetable copies in `data/archive/`) is the full record of what every train did. None
of it can be downloaded again; the timetables and maps in `data/cache/` can.

Backups go to the owner's Mac (his choice, 2026-10-26), free and with plenty of room:

- **On the server**, every night at 03:30 Stockholm, `clack-backup.timer` runs `scripts/backup/backup-db.mjs`. That
  is SQLite's online backup (safe while the server writes), compressed with zstd, into `/home/clack/backups/`.
  It keeps 7 daily copies and 4 weekly ones (Sundays). Install or update it as root:
  ```
  cp /home/clack/clack/scripts/backup/clack-backup.{service,timer} /etc/systemd/system/
  install -d -o clack -g clack /home/clack/backups
  systemctl daemon-reload && systemctl enable --now clack-backup.timer
  ```
- **On the Mac**, `scripts/backup/pull.sh` copies what's new into `~/ClackBackups/`: the database copies, the
  observed record and the raw timetable copies. Those archives are written once and never changed, so only new files
  move. It runs once a day at 13:00 through launchd (if the Mac is asleep then, when it next wakes). Install it once:
  ```
  mkdir -p ~/Library/Application\ Support/ClackBackup
  cp ~/Documents/GitHub/clack/scripts/backup/pull.sh ~/Library/Application\ Support/ClackBackup/
  cp ~/Documents/GitHub/clack/scripts/backup/app.clack.backup.plist ~/Library/LaunchAgents/
  launchctl load ~/Library/LaunchAgents/app.clack.backup.plist
  ```
  The script is copied out of `~/Documents` because macOS doesn't let background jobs read that folder. Copy it
  again after changing `pull.sh`.
  It uses the same SSH key as logging in (`~/.ssh/clack_oracle`), and it logs to `~/ClackBackups/pull.log`.
  FileVault encrypts the copies on the Mac's disk.
- **Checking it:** `/api/health` (admin) reports `observed.backup`. Its `status` is `behind` when the Mac hasn't pulled
  for 3 days.
- **Restoring:** `zstd -d app-<date>.db.zst`, then put the file in place of `data/app.db` with the server stopped.
  Delete the old `app.db-wal`/`app.db-shm` first.

Hetzner's own VM backups are a paid option and are off.

## First set-up, in short

For a new VM: install Node 22 and Caddy (`apt install nodejs git caddy`), make the user `clack`, clone the repository
into `/home/clack/clack` and `git checkout main`, `npm ci`, write `.env`, put the service file below in
`/etc/systemd/system/clack.service`, the Caddyfile above in `/etc/caddy/Caddyfile`, then
`systemctl enable --now clack` and `systemctl reload caddy`. Open ports 80 and 443 only. The first start downloads
timetables and the map (several GB) and takes a while.

```
[Unit]
Description=Clack server
After=network-online.target
[Service]
User=clack
WorkingDirectory=/home/clack/clack
ExecStart=/usr/bin/npm start
Restart=always
[Install]
WantedBy=multi-user.target
```

**Owner:** this unit file is the one from the old guide with the user changed to `clack`; check it against
`systemctl cat clack` on the server, which is the truth.
