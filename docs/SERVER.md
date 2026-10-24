# The hosted server

The iPhone app talks to one Clack server on the internet (`Config.apiBase` in `apps/Clack/Clack/API/Config.swift`:
`https://clack-garner.duckdns.org`). This file says where it runs, how to reach it, what it needs and how to update it.
Anything not written down in the repository is marked **Owner:** for Garner to fill in or confirm.

## Where it runs

- A Hetzner Cloud VM (Ubuntu 24.04, ARM, 2 vCPU, 4 GB), set up on 2026-10-23 after Oracle Cloud Free Tier had no
  capacity.
- Public name `clack-garner.duckdns.org` (DuckDNS, pointing at the VM's IP address). Caddy gets and renews the https
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
  policy URL for App Store Connect (`https://clack-garner.duckdns.org/privacy`).
- Nothing else. There is no web app, so Caddy serves no files itself.

## `.env`

`/home/clack/clack/.env` is read at start-up (not in git; never paste the values anywhere). The names:

| Name | What |
|---|---|
| `TRAFIKVERKET_API_KEY` | Trafikverket Open API: actual times, delays, platforms, live positions |
| `TRAFIKLAB_GTFS_SWEDEN3_KEY` | GTFS Sweden 3 (timetables; 50 downloads a month) |
| `TRAFIKLAB_GTFS_SVERIGE2_KEY` | GTFS Sverige 2 (history) |
| `CLACK_REQUIRE_USER=1` | Refuse `/api` requests that don't say which phone they come from, so nobody can read the local user's trips |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_KEY_PATH`, `APNS_TOPIC` | Apple Push: the key id, the team id, the path to the `.p8` key file (kept like a password, outside git) and the app's bundle id `com.garnerghering.Clack`. Without all four, alerts and Live Activity updates stay off (the server logs `push: alerts off`) |

Optional: `PORT` (3001), `HOST` (127.0.0.1), `DATABASE_PATH` (`data/app.db`), `ENTUR_CLIENT_NAME`, and the polling
settings in the README. `CLACK_ALLOWED_ORIGINS` was for the old web wrapper and is no longer read; delete it from the
server's `.env` if it is there.

## Caddy

`/etc/caddy/Caddyfile` is exactly this (everything goes to Fastify; the live streams are not compressed, because
iOS asks for gzip and Caddy then holds events back until a block fills, so the live map took about ten seconds to show
its trains):

```
clack-garner.duckdns.org {
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
```

Apply it with `systemctl reload caddy`. The three stream paths are the server's three event streams
(`routes/live.ts`, `routes/livemap.ts`, `routes/boards.ts`); a new stream needs adding to the matcher. A backup of the
previous Caddyfile (the one that also served the web app) is at `/etc/caddy/Caddyfile.bak`.

## Updating

After the owner pushes to `main`, on the server:

```
cd /home/clack/clack
sudo -u clack git pull && sudo -u clack npm ci
systemctl restart clack
```

That is `git pull && npm ci && systemctl restart clack`, with git and npm run as the `clack` user and the restart as
root. Migrations run when the server starts. Then check `https://clack-garner.duckdns.org/api/health` (its `version` is the commit the server runs; Settings in the
app shows the same).

## Backups

The server's database, `/home/clack/clack/data/app.db` (SQLite, with `app.db-wal` and `app.db-shm` beside it), holds
every user's trips, follows, settings and push addresses. The timetables and maps in `data/cache/` can be downloaded
again; the database cannot.

**Owner:** no automatic backup is set up in the repository, and none is known to be set up on the VM. Until one is:
copy the database now and then with SQLite's own backup, which is safe while the server runs:

```
sqlite3 /home/clack/clack/data/app.db ".backup '/home/clack/app-$(date +%F).db'"
```

then pull the file to the Mac with `scp`. (Unverified: the VM may not have the `sqlite3` command installed; `apt install
sqlite3`.) Hetzner's own VM backups are a paid option and are off unless the owner turned them on.

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
