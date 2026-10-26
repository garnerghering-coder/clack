# Mobility Database: what it offers Clack (recorded 2026-10-26, not used yet)

MobilityData's Mobility Database (mobilitydatabase.org) catalogues transit feeds worldwide and keeps copies of them.
Clack doesn't use it today: Norway's past comes from Entur's BigQuery archive instead (NORWAY_DATA_FINDINGS.md), which
goes further back. It's here for later: as a fallback for downloads, and for expanding beyond the Nordics.

## Access

- **Catalog:** `https://files.mobilitydatabase.org/feeds_v2.csv`, public, no account, CC0 (6,686 feeds: 4,646 GTFS,
  2,040 GTFS-RT). Columns include licence URL, bounding box, status, `redirect.id` (a deprecated feed's successor),
  `static_reference` (a realtime feed's timetable feed) and `urls.latest` (the hosted copy). There is **no rail
  column**: filter by provider name or bounding box. Multi-country feeds have odd country codes (Entur's is listed
  as CZ), so don't filter on country alone.
- **Hosted copies:** `https://files.mobilitydatabase.org/<id>/latest.zip`, and versions at
  `…/<id>/<id>-<yyyymmddhhmm>/<id>-<yyyymmddhhmm>.zip`, downloadable without an account.
- **API:** `https://api.mobilitydatabase.org/v1/`. Needs the refresh token from a free account (**Account details**
  on the website), exchanged for a 1-hour token with `POST /v1/tokens {"refresh_token": …}`. Only the API lists a
  feed's versions (`/v1/gtfs_feeds/{id}/datasets`, said to go back to 2024-02-08; older ones came from TransitFeeds).
  No published rate limit: back off on 429.
- **Terms:** catalog data CC0; each feed keeps its own licence (ODbL is share-alike; NLOD and CC-BY need
  attribution; many feeds list none: treat as unknown).

## Useful now

- **GTFS Sweden 3** (`mdb-2939`, CC0, ~800 MB) is hosted publicly: a fallback if Trafiklab's key or its 50-calls-a-month
  limit ever fails us. Not wired in.
- **Norway** (`mdb-1078`, Entur national, 530 MB): daily copies, confirmed from May 2025.
- **Finland's VR feed** (`mdb-1102`) is listed but **not** copied. Digitraffic keeps its own history.

## Rail feeds for later (Europe)

| Where | Id | Notes |
|---|---|---|
| Denmark | mdb-1292 | Rejseplanen, all modes, ~56 MB |
| Germany | mdb-768 / mdb-1089, mdb-3215 | gtfs.de long-distance / regional; DELFI national (CC-BY) |
| France | tdg-83582 | SNCF TGV, Intercités, TER (ODbL) |
| Switzerland | mdb-2898 | opentransportdata.swiss |
| Netherlands | mdb-1077 | OVapi |
| Belgium | mdb-686 | SNCB (iRail) |
| Poland | mdb-3191 | merged national rail |
| Ireland | mdb-2637 | Irish Rail |
| Estonia / Latvia | mdb-3153 / mdb-3385 | Elron / Vivi |
| Europe-wide | tdg-82199, European Sleeper (Transitous) | Eurostar; night trains |

No national rail feed was found for Great Britain, Czechia or (current) Austria.
