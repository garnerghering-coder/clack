# Oslo lufthavn (`NO-GAR`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **196.00** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **194.95** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 194.39 – 209.71 (median 202.36) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 196.00.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-o-/oslo-airport/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project NDH Akershus 5pkt 2015, scanned 2015-11-15. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 1 | 1,2 | 760 (0.76) | 360.0 | 12.0 | None | 194.95 | 195.93 | 0.98 | 0.80 |  |
| track 2 | 2,3 | 760 (0.76) | 250.0 | 8.0 | None | – | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| track 4 | 3,4 | 760 (0.76) | 360.0 | 12.0 | None | 194.95 | 196.07 | 1.12 | 0.94 |  |

## Structures

`oslo_lufthavn_structures_heights.geojson`, 21 features: 8 building, 8 canopy_osm, 2 canopy_laser.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w136859266 | roof | 202.78 | 202.85 | 194.90 | 6.78 | 1732 |
| building | w173527308 | Oslo Airport (building) | 225.52 | 230.77 | 203.91 | 29.52 | 2741 |
| building | w173693809 | transportation | 205.38 | 209.49 | 201.24 | 9.38 | 456 |
| building | w173693810 | Gardermoen kontrolltårn (transportation) | 287.29 | 293.19 | 201.28 | 91.29 | 4090 |
| building | w430590069 | transportation | – | – | – | – | 0 |
| building | w643883062 | Radisson RED Oslo Airport (hotel) | 225.25 | 225.49 | 202.33 | 29.25 | 852 |
| canopy_osm | w643883066 | roof | 208.92 | 211.50 | 202.82 | 12.92 | 582 |
| building | w653448993 | transportation | 212.55 | 212.68 | 204.31 | 16.55 | 250 |
| canopy_osm | w653567972 | roof | 208.58 | 208.89 | 204.52 | 12.58 | 1660 |
| canopy_osm | w653567974 | roof | 206.96 | 208.10 | 202.91 | 10.96 | 1095 |
| canopy_osm | w661039549 | roof | 206.64 | 206.87 | 203.83 | 10.64 | 367 |
| bridge | w661039573 | bridge | – | – | – | – | 0 |
| bridge | w661039574 | bridge | 215.36 | 223.57 | 194.56 | 19.36 | 305 |
| bridge | w661039577 | bridge | 209.39 | 220.99 | 201.50 | 13.39 | 10 |
| building | w661039610 | Starbucks (building) | – | – | – | – | 0 |
| canopy_osm | w668746731 | building | 223.74 | 223.84 | 203.99 | 27.74 | 702 |
| canopy_osm | w919872414 | roof | 223.87 | 223.97 | 203.70 | 27.87 | 342 |
| canopy_osm | w1446588999 | roof | 206.22 | 206.41 | 202.26 | 10.22 | 139 |
| building | r13488100 | Radisson Blu Airport Hotel, Oslo Gardermoen (hotel) | 220.18 | 223.17 | 199.05 | 24.18 | 2791 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 200.17 | 200.88 | 194.67 | 4.17 | 6992 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 201.02 | 201.13 | 194.89 | 5.02 | 6745 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS track 4 (track 3,4): laser gives 1.12 m above the track bed (≈0.94 m above rail after −0.15…0.2 m), register class 760 = 0.76 m. Not decided; add to REVIEW.md.
- w173527308 Oslo Airport (building): p95 230.8 m is 5.2 m above the median 225.5 m (a taller neighbour or a mast inside the outline?).
- w173693809 transportation: p95 209.5 m is 4.1 m above the median 205.4 m (a taller neighbour or a mast inside the outline?).
- w173693810 Gardermoen kontrolltårn (transportation): p95 293.2 m is 5.9 m above the median 287.3 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w661039573 (cycleway, service); w661039574 (footway, service, trunk, trunk_link); w661039577 (trunk).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (7 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2015-11-15: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "NDH Akershus 5pkt 2015" (id 417, FKB-Laser 2.0, nominal 5 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2015-11-15; 4,664,174 points in the box, 6.25 per m²; classes {'1': 3393470, '2': 852108, '7': 1573, '10': 417023}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-o-/oslo-airport/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=11.088735,60.188981,11.104735,60.196981, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
