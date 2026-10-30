# Lillestrøm (`NO-LLS`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **110.00** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **109.22** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 102.34 – 137.47 (median 106.94) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 110.00.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-l-/lillestrom/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Romerike 2013, scanned 2013-07-06. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 2 | 1,2 | 700 (0.70) | 350.0 | 10.3 | None | 109.22 | 110.16 | 0.94 | 0.76 | platform surface from unclassified (class 1) laser points: this scan left the platform deck unclassified; flat band bed+0.2…+1.6 m |
| track 3 | 3,4 | 700 (0.70) | 350.0 | 9.0 | None | 109.24 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| track 6 | 6,7 | 560 (0.56) | 350.0 | 11.7 | None | 109.22 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| track 8 | 8,9 | 560 (0.56) | 250.0 | 11.0 | None | 109.15 | 109.83 | 0.68 | 0.50 | platform surface from unclassified (class 1) laser points: this scan left the platform deck unclassified; flat band bed+0.2…+1.6 m |

## Structures

`lillestrom_structures_heights.geojson`, 26 features: 6 building, 1 footbridge, 11 canopy_osm, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w108333263 | Lillestrøm bussterminal (transportation) | 110.52 | 110.88 | 106.31 | 0.52 | 331 |
| building | w115788728 | station building | 113.20 | 117.74 | 105.81 | 3.20 | 203 |
| canopy_osm | w195999517 | roof | 111.75 | 112.21 | 105.98 | 1.75 | 172 |
| canopy_osm | w299869119 | roof | 109.19 | 110.84 | 105.93 | -0.81 | 171 |
| bridge | w343472117 | Lillestrømbrua (bridge) | 108.17 | 109.28 | 102.47 | -1.83 | 31 |
| bridge | w343761147 | bridge | – | – | – | – | 0 |
| bridge | w343761148 | Rælingsbrua (bridge) | 114.19 | 115.93 | 106.20 | 4.19 | 90 |
| bridge | w343761149 | bridge | – | – | – | – | 0 |
| bridge | w344123432 | bridge | – | – | 103.23 | – | 0 |
| bridge | w344123433 | bridge | – | – | 103.18 | – | 0 |
| canopy_osm | w482568151 | roof | 114.40 | 114.47 | 109.04 | 4.40 | 27 |
| canopy_osm | w482568152 | roof | – | – | 109.03 | – | 2 |
| canopy_osm | w482568153 | roof | – | – | 109.32 | – | 0 |
| canopy_osm | w482568154 | roof | – | – | 109.24 | – | 3 |
| canopy_osm | w732214187 | roof | 110.60 | 110.65 | 105.76 | 0.60 | 112 |
| canopy_osm | w732214188 | roof | 109.49 | 109.57 | 104.67 | -0.51 | 129 |
| canopy_osm | w819984461 | roof | – | – | 107.83 | – | 0 |
| footbridge | w820363247 | bridge | – | – | – | – | 0 |
| canopy_osm | w905630504 | roof | – | – | 106.85 | – | 4 |
| building | w992072013 | Ekko (office) | 114.45 | 115.99 | 106.30 | 4.45 | 39 |
| building | w992072014 | building | 115.14 | 116.05 | 106.21 | 5.14 | 21 |
| canopy_osm | w997574371 | roof | 121.87 | 121.92 | 107.32 | 11.87 | 43 |
| building | w1002255542 | building | 111.15 | 112.77 | 105.81 | 1.15 | 79 |
| building | w1059055240 | building | 114.22 | 116.62 | 106.27 | 4.22 | 19 |
| train_in_scan | (laser) | train standing during the scan (152.8 m × 2.9 m) | 113.25 | – | – | 4.01 | 1950 |
| train_in_scan | (laser) | train standing during the scan (124.9 m × 2.8 m) | 113.20 | – | – | 3.98 | 1564 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform at track 8: OSM outline r7105815 runs 331 m along the track, Bane NOR length 250 m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline
- w115788728 station building: p95 117.7 m is 4.5 m above the median 113.2 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w343472117 Lillestrømbrua (footway, trunk); w343761147 (footway, secondary); w343761148 Rælingsbrua (footway, secondary); w343761149 (footway, secondary); w344123432 (no mapped ways); w344123433 (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 11 files found (2 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2013-07-06: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Romerike 2013" (id 121, FKB-Laser 2.0, nominal 2 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2013-07-06; 1,835,389 points in the box, 2.2 per m²; classes {'1': 1058739, '2': 757952, '7': 6150, '10': 12548}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-l-/lillestrom/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=11.036680,59.949210,11.052680,59.957210, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
