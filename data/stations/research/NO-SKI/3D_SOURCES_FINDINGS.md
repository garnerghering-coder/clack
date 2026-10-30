# Ski (`NO-SKI`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **129.36** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **128.89** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 115.40 – 153.73 (median 134.77) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 129.36.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-s-/ski/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Follo 2014, scanned 2014-12-08. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 2 | 1,2 | 760 (0.76) | 350.0 | 7.0 | None | 128.89 | 129.15 | 0.26 | 0.08 | platform surface from unclassified (class 1) laser points: this scan left the platform deck unclassified; flat band bed+0.2…+1.6 m |
| track 3 | 3,4 | 760 (0.76) | 350.0 | 7.0 | None | 128.87 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| track 6 | 5,6 | 760 (0.76) | 288.0 | 5.0 | None | 128.94 | 129.57 | 0.63 | 0.45 |  |

## Structures

`ski_structures_heights.geojson`, 29 features: 10 building, 9 canopy_osm, 1 canopy_laser, 8 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w137138948 | office | 143.26 | 145.09 | 128.72 | 13.90 | 534 |
| canopy_osm | w183273665 | roof | – | – | – | – | 0 |
| building | w317072776 | apartments | 127.95 | 128.33 | 118.71 | -1.41 | 573 |
| building | w343900873 | transportation | 134.37 | 135.39 | 126.71 | 5.01 | 278 |
| bridge | w404613778 | Nordbyveien bru (bridge) | 136.78 | 138.82 | 129.23 | 7.41 | 76 |
| building | w813679132 | transportation | – | – | 130.63 | – | 0 |
| canopy_osm | w819953900 | roof | 132.33 | 132.61 | 128.69 | 2.97 | 65 |
| canopy_osm | w819953901 | roof | 131.20 | 131.29 | 128.65 | 1.84 | 9 |
| building | w893278733 | garage | 150.99 | 152.20 | 147.47 | 21.63 | 118 |
| canopy_osm | w967829063 | Truckdiesel (roof) | 128.37 | 128.79 | 123.25 | -0.99 | 107 |
| canopy_osm | w979890522 | roof | – | – | 151.61 | – | 0 |
| building | w979890531 | service | 146.92 | 146.98 | 143.34 | 17.56 | 72 |
| building | w1084938960 | transportation | 131.13 | 131.61 | 128.40 | 1.77 | 39 |
| building | w1084938976 | transportation | 149.54 | 154.48 | 130.56 | 20.18 | 628 |
| canopy_osm | w1253429592 | shelter | – | – | 129.06 | – | 0 |
| canopy_osm | w1253429593 | shelter | – | – | 128.97 | – | 0 |
| canopy_osm | w1253429594 | shelter | – | – | 128.92 | – | 0 |
| canopy_osm | w1253429595 | roof | 133.82 | 136.42 | 128.75 | 4.46 | 580 |
| building | w1253429599 | building | – | – | – | – | 0 |
| building | w1285861906 | building | 132.09 | 132.12 | 128.72 | 2.73 | 6 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 132.86 | 132.92 | 129.26 | 3.50 | 952 |
| train_in_scan | (laser) | train standing during the scan (40.8 m × 2.9 m) | 131.60 | – | – | 3.57 | 553 |
| train_in_scan | (laser) | train standing during the scan (22.1 m × 1.5 m) | 131.15 | – | – | 3.78 | 38 |
| train_in_scan | (laser) | train standing during the scan (76.0 m × 2.9 m) | 131.04 | – | – | 3.88 | 650 |
| train_in_scan | (laser) | train standing during the scan (17.3 m × 2.0 m) | 137.12 | – | – | 3.33 | 46 |
| train_in_scan | (laser) | train standing during the scan (17.1 m × 3.1 m) | 133.78 | – | – | 3.25 | 54 |
| train_in_scan | (laser) | train standing during the scan (80.2 m × 3.7 m) | 132.88 | – | – | 3.88 | 698 |
| train_in_scan | (laser) | train standing during the scan (74.4 m × 3.0 m) | 132.76 | – | – | 3.86 | 738 |
| train_in_scan | (laser) | train standing during the scan (20.3 m × 3.8 m) | 135.96 | – | – | 3.17 | 87 |

## Trains in the scan

8 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS track 2 (track 1,2): laser gives 0.26 m above the track bed (≈0.08 m above rail after −0.15…0.2 m), register class 760 = 0.76 m. Not decided; add to REVIEW.md.
- Platform BIS track 6 (track 5,6): laser gives 0.63 m above the track bed (≈0.45 m above rail after −0.15…0.2 m), register class 760 = 0.76 m. Not decided; add to REVIEW.md.
- w1084938976 transportation: p95 154.5 m is 4.9 m above the median 149.5 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w404613778 Nordbyveien bru (footway, secondary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 7 files found (3 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2014-12-08: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Follo 2014" (id 119, FKB-Laser 2.0, nominal 5 points/m², supplier Blom Geomatics), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2014-12-08; 6,561,757 points in the box, 7.12 per m²; classes {'1': 3061055, '2': 3484892, '7': 7000, '10': 8810}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-s-/ski/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.824792,59.713536,10.842792,59.723536, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
