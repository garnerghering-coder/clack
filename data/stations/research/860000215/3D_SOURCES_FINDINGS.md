# Esbjerg (`860000215`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **12.78** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **12.20** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 6.85 – 19.74 (median 12.80) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 12.78.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6146_465, PUNKTSKY_1km_6146_466, PUNKTSKY_1km_6147_465, PUNKTSKY_1km_6147_466, scanned 2025-02-17. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 0 | 0 | 26 (0.26) | 117.0 | 12.5 | None | 12.10 | 12.90 | 0.80 | 0.63 |  |
| perron 1 / track 1 | 1 | 55 (0.55) | 195.0 | 6.5 | None | 12.21 | 12.78 | 0.57 | 0.40 |  |
| perron 2 / track 2 | 2 | 26 (0.26) | 218.0 | – | None | 12.18 | 12.78 | 0.60 | 0.43 |  |
| perron 2 / track 3 | 3 | 26 (0.26) | 336.0 | – | None | 12.56 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`esbjerg_structures_heights.geojson`, 11 features: 5 building, 3 canopy_osm, 3 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w87806407 | station building | 18.33 | 20.74 | 10.47 | 5.55 | 287 |
| building | w95632178 | parking | 17.59 | 17.98 | 12.29 | 4.81 | 1609 |
| building | w95632189 | building | 21.55 | 23.08 | 11.13 | 8.77 | 1537 |
| building | w184020984 | Esbjerg Rutebilstation (building) | 20.71 | 20.75 | 12.12 | 7.93 | 53 |
| building | w184020986 | building | 15.39 | 21.37 | 12.17 | 2.61 | 182 |
| canopy_osm | w335432974 | roof | 16.62 | 17.60 | 12.14 | 3.84 | 178 |
| canopy_osm | w510362121 | roof | 16.84 | 20.47 | 12.18 | 4.06 | 588 |
| canopy_osm | w546896414 | shelter | 15.32 | 15.38 | 12.73 | 2.54 | 95 |
| train_in_scan | (laser) | train standing during the scan (25.5 m × 2.7 m) | 16.17 | – | – | 3.93 | 1616 |
| train_in_scan | (laser) | train standing during the scan (73.6 m × 2.9 m) | 16.15 | – | – | 3.78 | 4512 |
| train_in_scan | (laser) | train standing during the scan (38.7 m × 2.7 m) | 16.11 | – | – | 3.75 | 2778 |

## Trains in the scan

3 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 2 track 2: no Banedanmark platform outline beside the track; placed by length around the station point: ends uncertain
- Perron 2 track 3: no Banedanmark platform outline beside the track; placed by length around the station point: ends uncertain
- Platform BIS perron 1 / track 0 (track 0): laser gives 0.80 m above the track bed (≈0.63 m above rail after −0.15…0.2 m), register class 26 = 0.26 m. Not decided; add to REVIEW.md.
- Platform BIS perron 1 / track 1 (track 1): laser gives 0.57 m above the track bed (≈0.40 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 2 / track 2 (track 2): laser gives 0.60 m above the track bed (≈0.43 m above rail after −0.15…0.2 m), register class 26 = 0.26 m. Not decided; add to REVIEW.md.
- w510362121 roof: p95 20.5 m is 3.6 m above the median 16.8 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (48 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-02-17: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6146_465, PUNKTSKY_1km_6146_466, PUNKTSKY_1km_6147_465, PUNKTSKY_1km_6147_466). https://dataforsyningen.dk/data/3931 (scan 2025-02-17; 4,545,529 points in the box, 15.78 per m²; classes {'2': 2312173, '3': 154151, '4': 138929, '5': 639791, '6': 1152747, '7': 117442, '14': 4423, '17': 16645, '18': 9228}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=8.45366,55.46417,8.46824,55.47622, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
