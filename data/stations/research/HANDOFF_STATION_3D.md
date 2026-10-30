# Station 3D research (Sweden, Finland, Norway, Denmark): handoff for Claude Code

State at 2026-10-30 (updated 11:00: Part 2 "what is at the station" added, see the end). This continues the brief `STATION_3D_RESEARCH_BRIEF_SWEDEN.md` (33 hub/mid stations) with the
recipe in `STATION_3D_RESEARCH.md` (the playbook). **All 33 stations are done** (32 in this pass + Jönköping C earlier). Nothing has been written into `scripts/stations/<id>.edits.json`, redrafted or committed to git.

## Where things are

| Path | What |
|---|---|
| `data/stations/research/<clack id>/` | One finished pack per station: `README.md`, `3D_SOURCES_FINDINGS.md`, `<slug>_structures_heights.geojson`, `<slug>_ground_1m.tif` (+ `_heightmap.png/.json`, `_preview.png`), `<slug>_laser_station_<year>.laz` (trains = class 64), `<slug>_platform_trafikverket.geojson`, `photos.json`, `_report.json` (machine-readable summary) |
| `data/stations/research/trafikverket_platforms_SE.csv` | Batch step 1: all 33 stations, one row per Bilaga 2A platform row joined to BanInfo (+ BanInfo-only rows). `README_platforms_SE.md` explains it and lists the flags. |
| `data/stations/research/bilaga2a_raw.txt`, `baninfo_platforms_raw.txt`, `stac_index_SE.txt` | Raw register rows, BanInfo objects, and the Lantmäteriet tile index (scan block, date, density, tiles, DTM tile) for all 33 stations |
| `scripts/stations/station3d/` | The pipeline (below) and `notes/<id>.md` (hand-written "unusual at this station" text that goes into each README) |
| `~/Downloads/clack_station3d/raw_bundles/` (on the owner's Mac) | The browser's raw bundle per station (laser tiles, terrain window, BanInfo, OSM, Commons): rebuild any pack from it |
| `REVIEW_platform_heights_SE.md` | All laser-vs-register platform disagreements and every station's levels, in one table |

## Finished stations

**All 33 stations are done**: 32 packs from this pass plus Jönköping C from the earlier one. Every pack has the 3D files
and `station_facts.json`. Levels per station and every laser-vs-register disagreement are gathered in
**`REVIEW_platform_heights_SE.md`** (26 flagged platforms, not decided). Each station's `3D_SOURCES_FINDINGS.md` has the
details, its `README.md` what is unusual there.

Special cases:
- **No laser level** (underground or built after the scan): Arlanda C, Triangeln, Malmö C's City Tunnel platforms,
  Varberg (the new tunnel station opened after the January 2020 scan).
- **Rebuilt after the scan:** Örebro S (new track-30 platform 2026), Karlstad C (tracks 3–4), Hässleholm C (southern
  platforms), Göteborg C tracks 22–23.
- **Södertälje Syd has two levels**: övre ≈41.2 m on the bridge (read from bridge-deck laser points, class 17) and
  undre ≈16.6 m. Don't use its single median (28.95 m).
- **Nässjö C**: the terrain model has no data over part of the box; filled from the laser's ground points (noted in the
  GeoTIFF tags and README).

## Not done yet

- **Playbook step 10** (edits files, redraft, validate) for the new packs — Claude Code's `to_edits.py` does this.
- **`data/stations/REVIEW.md`**: copy the flags from `REVIEW_platform_heights_SE.md` once decided how.
- **Photos:** `photos.json` lists Commons files with author/licence; none were viewed one by one. **Mapillary not searched.**
- **Floor heights** of halls, footbridges and tunnels: no open source measures them.

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
- **Platforms on bridges:** where laser class 17 (bridge) outnumbers ground within 0.8 m of the track, bed and surface come from class 17 (Södertälje Syd övre).
- **Terrain gaps:** exact 0.00 cells far above sea level are no-data; any no-data cell with laser ground points gets their median (noted).
- **Underground platforms are never measured** (`UNDERGROUND` in `station_pack.py`): Arlanda C, Triangeln, Malmö C Citytunneln (BIS 2092/2093), Varberg (tunnel opened after the scan). Add any others there.
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


## Part 2: what is at the station (`station_facts.json`)

The brief now also asks, per station, for the walking-map facts (levels and their signposted names, platform sides,
stairs/lifts/escalators and what they reach, entrances, amenities with opening hours, published plans), starting from
`STATION_OPEN_QUESTIONS_SWEDEN.md`. Each finished pack now has `station_facts.json` in the brief's format, plus:
`answers` (the station's open questions, answered or marked open, with sources), `_open_questions_in` (the questions as
listed), and `_sources`.

**Sources used, all read 2026-10-30:**
- **Jernhusen "Hitta din station"** (`https://www.jernhusen.se/hitta-din-station/<station>/` and its sub-pages: mat-och-butiker,
  toalett, tillgänglighet, förvaringsboxar, trafik-och-biljetter, lounge, karta-över-stationen…), 28 of the 33 stations
  (not Arlanda C, Burlöv, Hyllie, Triangeln, Örebro S). Gives hall opening hours, every shop's hours (sometimes per
  unit/hall), toilets with fee and hours, lockers, ticket offices, plans. Saved raw as
  `data/stations/research/_sources/clack_jernhusen_pages_SE*.json` (page HTML). Facts only, not copied.
  Note: jernhusen.se went down (Cloudflare 521) for ~20 minutes after the first full sweep: fetch slowly (≥ 1 s between pages).
- **Owner/authority plans** (PDF): Jernhusen's Stockholm C hall plans (Centralhallen, Nedre hallen, Övre hallen, overview)
  and Malmö C plan; Länstrafiken Kronoberg's Alvesta map; links to SL, Skånetrafiken, UL, JLT, VL, Hallandstrafiken and
  Länstrafiken Örebro maps are in each `plans` list (those sites block cross-site fetches: open them on their own site).
  Read as pictures for facts (what is where); never traced. Licence: not open, facts only.
- **OSM** via the API 0.6 `map` call (Overpass was overloaded all morning): `scripts/stations/station3d/osm_station.py`
  picks rail platforms, lifts/escalators/stairs/footbridges/underpasses and the platforms each reaches (within 6–10 m),
  entrances (with nearest named street), and toilets/lockers/ticket machines. These are marked `confirmed_by: "OSM only"`.
- **Platform sides** come from the 3D pass: the laser's raised ground beside each BanInfo track line, turned into a compass
  side ("the platform lies on the north side of track 2").

**How it is built:** `facts.py <id> <pack dir>` merges Jernhusen (parsed by `jernhusen.py`, Swedish hours → OSM syntax;
lines it can't read stay in `hours_raw`), the app's own map (`data/stations/<id>.json`, to match its POIs by name and
level: a brand with several units gets the unit whose hall matches the POI's level via `hall_aliases`), OSM, the laser
sides, and the hand-read facts in `scripts/stations/station3d/facts_manual/<id>.json` (plans, photos, answers, open).
Stockholm C and Alvesta have full hand-read plan facts; the others have answers where a source settled them.

**Still open across the batch:** floor heights (no open source measures them; the laser sees roofs only), hours for shops
the owner's page doesn't list (aggregators such as Thatsup were not used), Göteborg C's platform access (no plan
published), Mapillary and photo checks.

## Finland (17 stations, brief `STATION_3D_RESEARCH_BRIEF_DK_FI.md`): done

- Folders `data/stations/research/fi_<CODE>/` (ids `fi:<CODE>`, `_` for `:`), same files as Sweden, register file
  `<slug>_platform_vayla.geojson`. Country CSV `vayla_platforms_FI.csv` (Swedish columns; `bandel` = ratanumero, `tracks` =
  commercial track number), `README_platforms_FI.md`, `REVIEW_platform_heights_FI.md` (25 of 95 platforms differ by > 0.125 m).
- Laser: Helsinki and Pasila from the City of Helsinki 2021 lidar (CC BY 4.0, ~40 pts/m²); the other 15 from the NLS open
  0.5 p laser (CC BY 4.0), ordered free through the NLS file service (MapSite, order 0599290996; the owner's email, no API key).
  The ground grid is made from each laser's class 2 (no DTM download). **No account or key was used for Finland.**
- Register: Digitraffic infra-api `laiturit` (CC BY 4.0); class heights korkea 0.55 / matala 0.265 m.
- Flags: Helsinki platforms read 0.80–0.96 m above the bed (likely slab track / larger ballast step); Turku's Logomo
  platforms postdate the scan.
- Rebuild: `make_fi_bundle.py` → `station_pack.py` → `finish_fi.sh` (facts + docs). Facts hand-read in `facts_manual_fi/`.

## Norway (11 stations): 5 of 11 packs built, 6 waiting for Kartverket's exports

- Folders `data/stations/research/NO-<CODE>/` (no Clack ids were given for Norway; the brief says Norway comes after DK/FI).
  Built: NO-OSL_S, NO-NTH (underground: surface only), NO-SKØ, NO-LYS, NO-SV. Waiting: NO-ASR, NO-DRM, NO-LLS, NO-MOS,
  NO-SKI (exports running), NO-GAR (queued; Kartverket allows 4 open exports per user).
- Laser: Kartverket høydedata.no point-cloud exports (LAZ, EPSG:25832, NN2000, © Kartverket CC BY 4.0), one rectangle
  per station (`_sources/NO/no_orders.json`), best open project per station (Oslo kommune tynnet 2019 for OSL_S/NTH/SKØ —
  thinned, ~1 pt/m²; Bærum 2013, Asker 2012, Drammen Eiker 2015, Romerike 2013, Follo 2014, Moss Done FOU 2020, NDH
  Akershus 2015). Exports are emailed as links (`leveranse.hoydedata.no`, valid 6 days). Bærum 2013 leaves platform decks
  in class 1: `platform_from_unclassified` lets the pack take a flat class-1 band (marked `surface_from_class1`).
- Register: Bane NOR's station pages, track table (per track: platform length, height mm above rail, width, which tracks the
  platform serves), read 2026-10-30 (`_sources/NO/banenor_station_pages.json`; facts only). The English page is used where
  it is newer (Ski after Follobanen). No coordinates in Bane NOR's table: each platform is drawn on the OSM track centreline
  (`railway:track_ref`), cut to the OSM platform outline beside it; every feature says how in `x_geometry`. Stabling and
  service platforms are listed in the README, not drawn.
- Facts: `facts_manual_no/` (Oslo S has all 46 oslo-s.no outlets with hours and hall/level).
- Rebuild: `run_no.sh <CODE> <export job id>` then `finish_no.sh <CODE>`.

## Denmark (27 stations): register, OSM and facts in progress; 3D needs the owner's laser decision

- Ids from the brief (`860000626` …, `gtfs:72888` → folder `gtfs_72888`).
- Register: `banedanmark_platforms_DK.csv` (Swedish columns, `height_class` = cm) from Banedanmark Netredegørelse 2027
  Bilag 3.6 (all 27 stations, 144 rows; København Syd = "Ny Ellebjerg", CPH Airport = "Kastrup") placed on Banedanmark Open
  Data (CC BY 4.0) track centrelines (`Sporforløb`, SPORNUMMER) and platform outlines (`FOR_PERRONER_OD`). Per-station lists
  in `_sources/DK/dk_register/`; flags there (e.g. København Syd's regional and S-tog tracks share numbers).
- **Laser (Danmarks Højdemodel punktsky, CC BY 4.0) is not downloaded.** It needs either a Dataforsyningen token (the owner
  creates it in their Dataforsyningen profile; never commit it) for 1 km tiles via the API, or the website's 10 km block
  order (several GB per block). `make_dk_register.py` output is ready to feed a DK bundle once tiles exist (same shape as
  `make_no_bundle.py`; EPSG:25832, DVR90).
- OSM + Commons per station: `_sources/DK/clack_dk_osm_commons.json` (from the owner's Downloads) and `_sources/osm/<id>.json`.

## Accounts used
- Sweden: Lantmäteriet Geotorget login (laser download). Finland: NLS free file-service order (owner's email). Norway:
  høydedata.no exports to the owner's email. Denmark: none yet. No token or key is stored anywhere in the repo.
