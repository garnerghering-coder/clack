# Station 3D research (Sweden): handoff for Claude Code

State at 2026-10-30 09:50. This continues the brief `STATION_3D_RESEARCH_BRIEF_SWEDEN.md` (33 hub/mid stations) with the
recipe in `STATION_3D_RESEARCH.md` (the playbook). **9 of 33 stations have finished packs; 2 more have raw bundles waiting;
22 are not started.** Nothing has been written into `scripts/stations/<id>.edits.json`, redrafted or committed to git.

## Where things are

| Path | What |
|---|---|
| `data/stations/research/<clack id>/` | One finished pack per station: `README.md`, `3D_SOURCES_FINDINGS.md`, `<slug>_structures_heights.geojson`, `<slug>_ground_1m.tif` (+ `_heightmap.png/.json`, `_preview.png`), `<slug>_laser_station_<year>.laz` (trains = class 64), `<slug>_platform_trafikverket.geojson`, `photos.json`, `_report.json` (machine-readable summary) |
| `data/stations/research/trafikverket_platforms_SE.csv` | Batch step 1: all 33 stations, one row per Bilaga 2A platform row joined to BanInfo (+ BanInfo-only rows). `README_platforms_SE.md` explains it and lists the flags. |
| `data/stations/research/bilaga2a_raw.txt`, `baninfo_platforms_raw.txt`, `stac_index_SE.txt` | Raw register rows, BanInfo objects, and the Lantmäteriet tile index (scan block, date, density, tiles, DTM tile) for all 33 stations |
| `scripts/stations/station3d/` | The pipeline (below) and `notes/<id>.md` (hand-written "unusual at this station" text that goes into each README) |
| `~/Downloads/clack3d_740000077_hallsberg.tar`, `~/Downloads/clack3d_740000210_gavle_c.tar` | Raw bundles already collected, not yet built: run step 2 on them |

## Finished stations

Levels are m RH 2000 from the laser. "Platforms measured" = BanInfo platform objects with a laser surface level.

| Station | Clack id | Laser scan | Platform surface | Track bed | Platforms measured | Trains in scan | Structures | Flags |
|---|---|---|---|---|---|---|---|---|
| Göteborg C | 740000002 | 2020-03-21 | 2.91 | 2.21 | 9/15 | 17 | 38 | 6 |
| Stockholm C | 740000001 | 2021-03-23 | 4.48 | 3.64 | 7/13 | 3 | 26 | 20 |
| Alvesta | 740000004 | 2026-03-08 | 145.31 | 144.59 | 2/3 | 6 | 7 | 1 |
| Arlanda C | 740000556 | 2021-04-17 | – (underground) | – | 0/3 | 0 | 37 (terminals above) | 10 |
| Burlöv | 740000937 | 2025-03-07 | 7.46 | 6.86 | 2/2 | 0 | 8 | 2 |
| Eskilstuna C | 740000170 | 2020-02-27 | 18.20 | 17.42 | 2/3 | 1 | 16 | 0 |
| Falköping C | 740000060 | 2022-03-07 | 217.31 | 216.46 | 2/3 | 3 | 14 | 0 |
| Flemingsberg | 740000031 | 2020-03-31 | 34.40 | 33.65 | 2/3 | 1 | 7 | 1 |
| Hässleholm C | 740000006 | 2025-02-19 | 53.81 | 53.13 | 4/11 | 6 | 5 | 4 |

Each station's `3D_SOURCES_FINDINGS.md` has the per-platform table, the structures table, the trains and the flags.

## Not done yet

- **22 stations not started:** Herrljunga C, Hyllie, Karlstad C, Katrineholm C, Kil, Kumla, Linköping C, Lund C, Malmö C,
  Norrköping C, Nässjö C, Skövde C, Södertälje Syd, Triangeln, Trollhättan, Uppsala C, Varberg C, Västerås C, Örebro C,
  Örebro S, Öxnered. (Jönköping C was done earlier.) Plus building the two raw bundles (Hallsberg, Gävle C).
- **Playbook step 10** (edits files, redraft, validate, 3D view) for all stations.
- **Photos:** `photos.json` lists Commons files near each station with author/licence, marked `station_related` by title;
  none were viewed (`viewed: false`). Labels come from OSM tags + the laser. **Mapillary was not searched.**
- **`data/stations/REVIEW.md`:** the platform-height flags below have not been added to it yet.
- **CSV refresh:** `trafikverket_platforms_SE.csv` came from a coarser BanInfo sweep. Rebuild it at the end from the
  per-station `_platform_trafikverket.geojson` files (e.g. Eskilstuna Bilaga row 161 now has its BanInfo object, BIS 1208).

## Pipeline

**1. Collect (browser, Claude in Chrome).** Open `https://api.lantmateriet.se/stac-hojd/v1` in a tab where the Geotorget
login is active (a Range fetch of a laser file must return 206). Paste `scripts/stations/station3d/clack3d_collector.js`
into the page (javascript tool), then set `QUEUE = ['740000040', ...]` and call `runQueue()`. Per station it:
- harvests BanInfo `Plattform` + `Sparnummer` (GetFeatureInfo; the service has CORS, so it works from this origin);
- builds the station box = BanInfo platforms within 600 m of the station point + 120 m;
- STAC search → newest laser campaign's 2.5 km `_25` tiles + the `dtm-cog` tile(s);
- reads the 1 m terrain-model window straight out of the COG (range requests, deflate + float predictor);
- OSM via Overpass (`overpass-api.de`, then `overpass.private.coffee`), falling back to the OSM API `map` call;
- Commons geosearch (400 m) + name search with imageinfo/licence;
- downloads the laser tiles with the login;
- packs everything into one tar.

Each finished station shows as a yellow **SAVE** link at the top of the page. Click it with a real click (computer tool),
which keeps Chrome's repeated-download block away, then call `saved()`. `resave('name')` brings back one of the last three.
Bundles land in `~/Downloads/clack3d_<id>_<slug>.tar` (75–265 MB). If Overpass failed, `osm.json` holds an `error`: refetch
OSM alone and save as `clack3d_<id>_osm.tar`, then pass it after the main bundle in step 2.

**2. Build (Python, from the repo root).**
```
pip install "laspy[lazrs]" numpy shapely rasterio pyproj pillow scipy
scripts/stations/station3d/run_station.sh 740000040 "Herrljunga C" ~/Downloads/clack3d_740000040_herrljunga_c.tar
```
It writes `data/stations/research/<id>/` and prints platforms, trains, structures and flags. Read the flags, write
`scripts/stations/station3d/notes/<id>.md` (what is unusual), and re-run to put the notes into the README.
`profile.py <id> [bis…]` prints the ground profile across each platform (1 m bins, ±12 m): use it when a platform level
looks wrong (set `STATION3D_BUNDLES` to where the bundle was unpacked).

## What the build does (rules carried from the playbook)

- **Track bed:** median of ground-class (2) points within 0.8 m of the BanInfo track line.
- **Platform surface:** median of ground points 1.8 m to 1.8 m + width (6 m if BanInfo has none) beside the line. A side counts only if half its points are > 0.3 m above the bed and there are ≥ 30.
  - If only one side is raised, that side is the platform.
  - If both are raised, BanInfo `SIDE` decides (1 = left of the line's direction, 2 = right, checked at Göteborg C). At Hässleholm some lines run the other way, so SIDE alone is not trusted.
- **Station level:** median of the platform levels.
- **Cross-check:** surface − bed − 0.175 m vs the class height. A difference > 0.125 m is flagged ("not decided; add to REVIEW.md").
- **Deck-level beds:** a "bed" more than 1.5 m from the station median is a deck or roof over the track (Stockholm C). Those values are dropped and flagged.
- **Platforms newer than the scan:** BanInfo record ≥ scan year + 2 and no matching Bilaga row (by BIS, or by track + class) means probably built after the scan. Those are left out of the level (Göteborg tracks 22/23).
- **Underground platforms are never measured** (`UNDERGROUND` in `station_pack.py`): Arlanda C, Triangeln, Malmö C Citytunneln (BIS 2092/2093). Add any others there.
- **Trains:**
  - Which points: unclassified points 2.6–5.0 m above the terrain model, within 2.2 m of a surface OSM rail (tunnels and negative layers excluded), along one track.
  - Accepted as a train if: median offset ≤ 1.0 m, p90 ≤ 1.9 m, ≥ 15 m long, ≥ 1.5 points/m, 3.0–4.8 m above the bed.
  - Result: kind `train_in_scan`; their points are class 64 in the LAZ.
- **Structures:**
  - Which ones: OSM buildings / `building=roof` / canopies / shelters / bridges touching the platforms (track line + width + 12 m) or tagged as the station.
  - Roof top: median and p95 of unclassified points > 2 m above the terrain inside the outline.
  - Ground: terrain model on a 0.3–1.5 m ring outside the outline.
  - `man_made=bridge` is `footbridge` only if every bridge way on it is foot/cycle; otherwise kind `bridge` (an extra kind, flagged).
  - p95 − median > 3 m is flagged for station-related features.
- **Laser-traced roofs:**
  - Which cells: 1 m cells over the platforms (track line + width + 4 m) with unclassified points 2.4–14 m above the platform, outside OSM outlines, trains removed.
  - Kept if: ≥ 40 cells, multi-return share ≤ 0.35, z spread ≤ 1.2 m.
  - Kind: `canopy_laser`, or `hall_roof_laser` if > 6 m above the platform (flagged as maybe a building).
  - Partly over a track: flagged (maybe a train, or a bridge/gantry if > 5.2 m above the bed).
- **Flat terrain:** exactly equal terrain values over > 1500 m² are noted as a water surface.
- **Heightmap:** 16-bit PNG, height = `base_m + value/scale` (scale 1000, or 100 if the box spans > 65 m). The `_heightmap.json` says so.

## Known issues to keep in mind

- **BanInfo was being re-issued on 2026-10-28…30.** Some platform objects changed track link (REFLINK_OID), side and
  track number between queries on the same morning. Levels don't depend on it; **track numbers in the BanInfo-derived files
  are provisional**. Bilaga 2A's track lists are stable.
- `hall_roof_laser` and "over a track" flags need a look in a cross-section or a photo before the app uses them.
- Hub boxes include city blocks: the structures files have some ordinary buildings beside the platforms (kept, labelled).

## Flags worth a decision now

- **Burlöv:** both platforms measure ≈0.41–0.45 m above rail vs mellan 0.58 (4.3 points/m², well supported).
- **Stockholm C:** track 19a (BIS 738) is ≈0.80 above rail vs mellan 0.58. The short låg ends on tracks 10/11 measure the
  adjacent hög surface. Decks hide tracks 4–6 and 16–17.
- **Göteborg C:** track 1 short platform (BIS 2018) is low. One laser roof over a track may be a double-deck train.
- **Arlanda C:** underground, nothing measurable. BanInfo track numbers for it changed during the day.
- **Hässleholm C:** the southern platforms (BIS 2538–2543, 2041) did not exist in the Feb 2025 scan.

## Licences and attribution

- **Laser and terrain:** Lantmäteriet, CC BY 4.0 + GDPR terms. In the app, credit: "Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0".
- **Platforms:** Trafikverket BanInfo / JNB Bilaga 2A, CC0.
- **Outlines:** OSM, ODbL.
- **Photos:** each file's own licence, listed in `photos.json`.
- Never upload Lantmäteriet-derived values to OSM.
