# Helsingør (`860000669`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **4.28** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **3.45** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -0.29 – 6.25 (median 2.91) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 4.28.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6215_724, PUNKTSKY_1km_6215_725, scanned 2024-03-27. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 247.0 | 6.8 | None | 3.45 | 4.29 | 0.84 | 0.66 |  |
| perron 1 / track 13 | 13 | 72 (0.72) | 165.0 | 10.3 | None | 3.45 | 4.28 | 0.83 | 0.66 |  |
| perron 2 / track 2 | 2 | 50 (0.50) | 249.0 | 5.6 | None | 3.45 | 4.24 | 0.79 | 0.61 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 249.0 | 5.2 | None | 3.55 | 4.29 | 0.74 | 0.56 |  |
| perron 3 / track 3 | 3 | 55 (0.55) | 248.0 | 5.8 | None | 3.55 | 4.28 | 0.73 | 0.55 |  |
| perron 3 / track 4 | 4 | 55 (0.55) | 150.0 | 8.7 | None | 3.07 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`helsingor_structures_heights.geojson`, 22 features: 10 building, 3 footbridge, 2 canopy_osm, 2 canopy_laser, 5 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w88749480 | building | 12.67 | 21.22 | 2.81 | 8.39 | 383 |
| building | w88749481 | building | 8.07 | 9.16 | 3.11 | 3.79 | 64 |
| building | w88749485 | transportation | 10.45 | 15.70 | 2.39 | 6.17 | 529 |
| building | w88749486 | station building | 12.60 | 22.60 | 1.97 | 8.32 | 948 |
| building | w113512834 | Toldkammeret (building) | 10.97 | 11.35 | 1.98 | 6.69 | 372 |
| building | w631960909 | building | 5.87 | 5.94 | 2.62 | 1.59 | 45 |
| canopy_osm | w631961192 | roof | 5.79 | 6.04 | 3.36 | 1.51 | 48 |
| canopy_osm | w631964005 | roof | 5.87 | 6.09 | 3.30 | 1.59 | 57 |
| building | w631965431 | building | 5.95 | 6.00 | 2.65 | 1.67 | 45 |
| building | w631966216 | building | 5.92 | 5.96 | 2.62 | 1.64 | 43 |
| building | w631966296 | building | 6.02 | 6.08 | 2.68 | 1.74 | 54 |
| footbridge | w1165076609 | bridge | 12.32 | 12.39 | 1.92 | 8.04 | 2510 |
| building | r8790430 | building | 9.75 | 16.61 | 0.12 | 5.47 | 1570 |
| footbridge | r16691101 | bridge | 11.65 | 12.37 | 2.33 | 7.37 | 51 |
| footbridge | r16691102 | bridge | 12.32 | 12.38 | 2.10 | 8.04 | 344 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 9.17 | 9.35 | 3.37 | 4.89 | 4292 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 7.45 | 8.16 | 3.12 | 3.17 | 229 |
| train_in_scan | (laser) | train standing during the scan (151.9 m × 2.5 m) | 8.08 | – | – | 4.59 | 3277 |
| train_in_scan | (laser) | train standing during the scan (21.9 m × 1.9 m) | 7.60 | – | – | 4.15 | 101 |
| train_in_scan | (laser) | train standing during the scan (39.4 m × 2.6 m) | 7.41 | – | – | 3.91 | 1072 |
| train_in_scan | (laser) | train standing during the scan (27.4 m × 2.6 m) | 7.29 | – | – | 3.80 | 713 |
| train_in_scan | (laser) | train standing during the scan (125.2 m × 2.6 m) | 7.82 | – | – | 4.36 | 2983 |

## Trains in the scan

5 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w88749480 building: p95 21.2 m is 8.5 m above the median 12.7 m (a taller neighbour or a mast inside the outline?).
- w88749485 transportation: p95 15.7 m is 5.2 m above the median 10.5 m (a taller neighbour or a mast inside the outline?).
- w88749486 station building: p95 22.6 m is 10.0 m above the median 12.6 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (33 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-03-27: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6215_724, PUNKTSKY_1km_6215_725). https://dataforsyningen.dk/data/3931 (scan 2024-03-27; 1,718,081 points in the box, 8.64 per m²; classes {'2': 924723, '3': 36818, '4': 49933, '5': 150699, '6': 494069, '7': 35317, '9': 11167, '14': 3522, '17': 3785, '18': 8048}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.60631,56.02918,12.61894,56.03589, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
