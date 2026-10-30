# Køge (`860000803`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **3.08** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **2.23** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -1.26 – 9.87 (median 2.47) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 3.08.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6150_701, scanned 2025-03-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 2 | 2 | 35 (0.35) | 260.0 | 8.8 | None | 2.26 | 3.08 | 0.82 | 0.64 |  |
| perron 1 / track 3 | 3 | 55 (0.55) | 260.0 | 8.8 | None | 2.36 | 3.08 | 0.72 | 0.55 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 260.0 | 3.8 | None | 2.36 | 3.08 | 0.72 | 0.55 |  |
| perron 4 / track 5 | 5 | 55 (0.55) | 129.0 | 3.3 | None | 2.21 | 2.94 | 0.73 | 0.55 |  |
| perron 2 / track 6 | 6 | 92 (0.92) | 260.0 | 3.9 | None | 2.06 | 3.17 | 1.11 | 0.93 |  |
| perron 3 / track 7 | 7 | 92 (0.92) | 185.0 | 4.8 | None | 2.06 | 3.17 | 1.11 | 0.93 |  |

## Structures

`koge_structures_heights.geojson`, 18 features: 9 building, 1 footbridge, 1 canopy_osm, 7 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w554088122 | roof | 4.82 | 4.86 | 2.13 | 1.74 | 126 |
| building | w591100751 | building | 6.04 | 10.89 | 3.13 | 2.96 | 50 |
| building | w652260438 | building | 6.70 | 6.77 | 2.23 | 3.62 | 262 |
| building | w652260439 | building | 5.25 | 5.34 | 2.43 | 2.17 | 30 |
| building | w652260440 | building | 5.31 | 5.40 | 2.42 | 2.23 | 84 |
| building | w652260441 | building | 5.32 | 5.38 | 2.41 | 2.24 | 50 |
| building | w652260445 | building | 4.94 | 9.94 | 2.04 | 1.86 | 272 |
| building | w652260447 | building | 5.79 | 8.23 | 2.26 | 2.71 | 388 |
| footbridge | w652260450 | bridge | 9.69 | 12.12 | 1.97 | 6.61 | 7819 |
| building | w652261257 | building | 14.08 | 14.36 | -1.24 | 11.00 | 24 |
| building | w1163103520 | building | 5.88 | 5.97 | 2.88 | 2.80 | 254 |
| train_in_scan | (laser) | train standing during the scan (18.2 m × 1.1 m) | 5.95 | – | – | 3.83 | 42 |
| train_in_scan | (laser) | train standing during the scan (26.7 m × 2.0 m) | 5.89 | – | – | 3.73 | 118 |
| train_in_scan | (laser) | train standing during the scan (71.4 m × 1.6 m) | 6.76 | – | – | 4.62 | 325 |
| train_in_scan | (laser) | train standing during the scan (114.5 m × 2.1 m) | 6.67 | – | – | 4.41 | 998 |
| train_in_scan | (laser) | train standing during the scan (38.7 m × 2.6 m) | 6.14 | – | – | 3.88 | 1103 |
| train_in_scan | (laser) | train standing during the scan (82.6 m × 2.8 m) | 6.14 | – | – | 3.90 | 2438 |
| train_in_scan | (laser) | train standing during the scan (31.6 m × 2.1 m) | 6.40 | – | – | 4.02 | 256 |

## Trains in the scan

7 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS perron 1 / track 2 (track 2): laser gives 0.82 m above the track bed (≈0.64 m above rail after −0.15…0.2 m), register class 35 = 0.35 m. Not decided; add to REVIEW.md.
- w591100751 building: p95 10.9 m is 4.8 m above the median 6.0 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (68 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-10: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6150_701). https://dataforsyningen.dk/data/3931 (scan 2025-03-10; 2,964,643 points in the box, 14.44 per m²; classes {'2': 1586817, '3': 137513, '4': 78263, '5': 445882, '6': 651943, '7': 56234, '9': 41, '14': 2262, '18': 5688}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.18133,55.4536,12.19185,55.46687, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
