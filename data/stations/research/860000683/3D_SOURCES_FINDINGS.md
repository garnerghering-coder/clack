# Hillerød (`860000683`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **36.98** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **35.92** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 26.92 – 39.35 (median 35.45) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 36.98.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6202_706, PUNKTSKY_1km_6202_707, PUNKTSKY_1km_6203_706, PUNKTSKY_1km_6203_707, scanned 2024-04-28. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 92 (0.92) | 187.0 | 8.4 | None | 35.90 | 36.88 | 0.98 | 0.81 |  |
| perron 1 / track 11 | 11 | 92 (0.92) | 144.0 | 10.6 | None | 36.08 | 36.86 | 0.78 | 0.61 |  |
| perron 2 / track 3 | 3 | 92 (0.92) | 199.0 | 7.8 | None | 35.81 | 37.08 | 1.27 | 1.09 |  |
| perron 2 / track 4 | 4 | 92 (0.92) | 218.0 | 7.7 | None | 35.94 | 37.08 | 1.14 | 0.97 |  |

## Structures

`hillerod_structures_heights.geojson`, 16 features: 6 building, 1 footbridge, 3 canopy_osm, 1 canopy_laser, 5 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w26380515 | station building | 45.00 | 50.38 | 36.19 | 8.02 | 313 |
| building | w26380516 | building | 40.42 | 44.46 | 33.24 | 3.44 | 1446 |
| building | w167871729 | building | 40.83 | 41.43 | 36.48 | 3.85 | 64 |
| canopy_osm | w167871731 | roof | 40.81 | 41.39 | 35.90 | 3.84 | 144 |
| building | w256612166 | service | 41.89 | 42.20 | 36.22 | 4.91 | 48 |
| canopy_osm | w339442561 | roof | 39.91 | 40.03 | 36.80 | 2.93 | 420 |
| footbridge | w598442302 | bridge | 35.54 | 42.71 | 30.12 | -1.44 | 30 |
| building | w1165106318 | building | 40.25 | 40.37 | 36.04 | 3.27 | 38 |
| canopy_osm | w1165106320 | roof | 40.30 | 40.57 | 35.94 | 3.33 | 24 |
| building | w1165106324 | building | – | – | 37.22 | – | 0 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 40.79 | 40.86 | 36.17 | 3.81 | 610 |
| train_in_scan | (laser) | train standing during the scan (82.8 m × 3.7 m) | 40.11 | – | – | 4.16 | 3207 |
| train_in_scan | (laser) | train standing during the scan (44.0 m × 2.8 m) | 40.19 | – | – | 4.23 | 1448 |
| train_in_scan | (laser) | train standing during the scan (82.8 m × 2.9 m) | 39.88 | – | – | 3.98 | 2986 |
| train_in_scan | (laser) | train standing during the scan (134.8 m × 3.2 m) | 40.36 | – | – | 4.13 | 5905 |
| train_in_scan | (laser) | train standing during the scan (39.0 m × 2.6 m) | 40.63 | – | – | 3.90 | 1106 |

## Trains in the scan

5 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Station rebuilt Feb 2026–Sep 2027 (new footbridge opened 12 Oct 2026, Banedanmark): platform outlines may change
- Platform BIS perron 1 / track 11 (track 11): laser gives 0.78 m above the track bed (≈0.61 m above rail after −0.15…0.2 m), register class 92 = 0.92 m. Not decided; add to REVIEW.md.
- Platform BIS perron 2 / track 3 (track 3): laser gives 1.27 m above the track bed (≈1.09 m above rail after −0.15…0.2 m), register class 92 = 0.92 m. Not decided; add to REVIEW.md.
- w26380515 station building: p95 50.4 m is 5.4 m above the median 45.0 m (a taller neighbour or a mast inside the outline?).
- w598442302 bridge: p95 42.7 m is 7.2 m above the median 35.5 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (81 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-04-28: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6202_706, PUNKTSKY_1km_6202_707, PUNKTSKY_1km_6203_706, PUNKTSKY_1km_6203_707). https://dataforsyningen.dk/data/3931 (scan 2024-04-28; 2,394,028 points in the box, 16.64 per m²; classes {'2': 1168951, '3': 94439, '4': 80190, '5': 542945, '6': 429922, '7': 39122, '9': 13193, '14': 3892, '17': 17705, '18': 3669}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.30562,55.92288,12.31647,55.93289, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
