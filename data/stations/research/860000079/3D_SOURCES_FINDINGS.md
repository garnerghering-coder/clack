# Fredericia (`860000079`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **11.98** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **11.16** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.24 – 22.04 (median 7.33) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 11.98.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6157_546, PUNKTSKY_1km_6158_546, scanned 2025-02-20. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 2 | 2 | 55 (0.55) | 299.0 | 5.8 | None | 11.17 | 12.06 | 0.89 | 0.72 |  |
| perron 1 / track 1 | 1 | 55 (0.55) | 170.0 | 5.7 | None | 11.31 | 12.14 | 0.83 | 0.66 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 351.0 | 10.1 | None | 11.14 | 11.90 | 0.76 | 0.58 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 351.0 | 10.2 | None | 11.11 | 11.90 | 0.79 | 0.62 |  |
| perron 3 / track 6 | 6 | 55 (0.55) | 317.0 | 8.7 | None | 10.97 | 11.85 | 0.88 | 0.70 |  |
| perron 3 / track 7 | 7 | 55 (0.55) | 452.0 | 8.7 | None | 10.97 | 11.83 | 0.86 | 0.68 |  |
| perron 3 / track 16 | 16 | 55 (0.55) | 129.0 | 31.3 | None | 10.76 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| perron 4 / track 9 | 9 | 55 (0.55) | 348.0 | 10.0 | None | 11.02 | 11.79 | 0.77 | 0.60 |  |
| perron 4 / track 10 | 10 | 55 (0.55) | 341.0 | 10.0 | None | 10.93 | 11.79 | 0.86 | 0.69 |  |
| perron 5 / track 31 | 31 | 26 (0.26) | 73.0 | 7.9 | None | 11.73 | 12.32 | 0.59 | 0.41 |  |
| perron 5 / track 32 | 32 | 26 (0.26) | 169.0 | 9.5 | None | 11.78 | 12.41 | 0.63 | 0.46 |  |
| perron 5 / track 33 | 33 | 26 (0.26) | 192.0 | 8.3 | None | 11.83 | 12.40 | 0.57 | 0.40 |  |
| perron 5 / track 7 | 7 | 26 (0.26) | 58.0 | 10.1 | None | 11.77 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| perron 6 / track 9 | 9 | 26 (0.26) | 58.0 | 4.2 | None | 11.65 | 12.15 | 0.50 | 0.33 |  |

## Structures

`fredericia_structures_heights.geojson`, 24 features: 6 building, 13 canopy_osm, 5 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w110588778 | roof | 18.46 | 26.70 | 10.62 | 6.48 | 2735 |
| building | w117677322 | building | 15.91 | 16.14 | 7.70 | 3.93 | 432 |
| building | w117683592 | building | 11.70 | 14.78 | 7.67 | -0.28 | 886 |
| building | w134938393 | station building | 16.16 | 18.51 | 7.45 | 4.18 | 3180 |
| building | w136729443 | building | 19.03 | 19.44 | 9.15 | 7.05 | 3343 |
| canopy_osm | w294854531 | shelter | 10.20 | 10.33 | 7.89 | -1.78 | 25 |
| canopy_osm | w294854532 | shelter | 10.06 | 11.38 | 7.74 | -1.92 | 223 |
| canopy_osm | w294854533 | shelter | 14.56 | 16.33 | 7.84 | 2.58 | 184 |
| canopy_osm | w294854536 | shelter | 13.34 | 15.29 | 7.86 | 1.36 | 327 |
| canopy_osm | w294854537 | shelter | 10.08 | 16.14 | 7.68 | -1.90 | 168 |
| canopy_osm | w294854538 | shelter | 10.20 | 13.72 | 7.81 | -1.79 | 184 |
| canopy_osm | w405817950 | building | 6.58 | 8.26 | 3.34 | -5.40 | 147 |
| building | w670251060 | building | 10.62 | 10.67 | 8.35 | -1.36 | 150 |
| canopy_osm | w670251337 | roof | 10.22 | 10.70 | 7.87 | -1.76 | 188 |
| canopy_osm | w752003503 | roof | 6.50 | 6.70 | 4.26 | -5.48 | 39 |
| canopy_osm | w752003504 | roof | 6.93 | 7.08 | 4.34 | -5.05 | 39 |
| canopy_osm | w1158782915 | Madsbytoget (roof) | 8.34 | 11.72 | 4.21 | -3.64 | 112 |
| canopy_osm | w1173705658 | roof | 12.32 | 12.92 | 6.83 | 0.34 | 325 |
| building | w1394590514 | building | 14.96 | 15.23 | 7.72 | 2.98 | 788 |
| train_in_scan | (laser) | train standing during the scan (19.6 m × 2.6 m) | 14.71 | – | – | 3.69 | 537 |
| train_in_scan | (laser) | train standing during the scan (39.2 m × 2.7 m) | 15.66 | – | – | 3.91 | 1178 |
| train_in_scan | (laser) | train standing during the scan (41.9 m × 2.8 m) | 15.44 | – | – | 3.83 | 1547 |
| train_in_scan | (laser) | train standing during the scan (20.8 m × 2.8 m) | 17.99 | – | – | 3.30 | 217 |
| train_in_scan | (laser) | train standing during the scan (112.1 m × 2.8 m) | 14.45 | – | – | 3.22 | 6481 |

## Trains in the scan

5 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 1 track 1: the outline FOR_PERRONER_OD Fa 171 runs 305 m along the track, Bilag says 170 m; line drawn to the outline
- Perron 3 track 6: the outline FOR_PERRONER_OD Fa 173 runs 458 m along the track, Bilag says 317 m; line drawn to the outline
- Perron 5 track 31: the outline FOR_PERRONER_OD Fa 175 runs 209 m along the track, Bilag says 73 m; line drawn to the outline
- Perron 5 track 7: the outline FOR_PERRONER_OD Fa 175 runs 164 m along the track, Bilag says 58 m; line drawn to the outline
- Platform BIS perron 1 / track 2 (track 2): laser gives 0.89 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 3 / track 6 (track 6): laser gives 0.88 m above the track bed (≈0.70 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 3 / track 7 (track 7): laser gives 0.86 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 4 / track 10 (track 10): laser gives 0.86 m above the track bed (≈0.69 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 5 / track 31 (track 31): laser gives 0.59 m above the track bed (≈0.41 m above rail after −0.15…0.2 m), register class 26 = 0.26 m. Not decided; add to REVIEW.md.
- Platform BIS perron 5 / track 32 (track 32): laser gives 0.63 m above the track bed (≈0.46 m above rail after −0.15…0.2 m), register class 26 = 0.26 m. Not decided; add to REVIEW.md.
- Platform BIS perron 5 / track 33 (track 33): laser gives 0.57 m above the track bed (≈0.40 m above rail after −0.15…0.2 m), register class 26 = 0.26 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 0.62 m across the station (11.79–12.41 m); the station reference above is their median — check which level the app should use.
- w110588778 roof: p95 26.7 m is 8.2 m above the median 18.5 m (a taller neighbour or a mast inside the outline?).
- w117683592 building: p95 14.8 m is 3.1 m above the median 11.7 m (a taller neighbour or a mast inside the outline?).
- w294854537 shelter: p95 16.1 m is 6.1 m above the median 10.1 m (a taller neighbour or a mast inside the outline?).
- w294854538 shelter: p95 13.7 m is 3.5 m above the median 10.2 m (a taller neighbour or a mast inside the outline?).
- w1158782915 Madsbytoget (roof): p95 11.7 m is 3.4 m above the median 8.3 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-02-20: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6157_546, PUNKTSKY_1km_6158_546). https://dataforsyningen.dk/data/3931 (scan 2025-02-20; 8,439,049 points in the box, 21.24 per m²; classes {'2': 3773914, '3': 420674, '4': 195798, '5': 3199252, '6': 645897, '7': 71175, '9': 80224, '14': 7964, '17': 35532, '18': 8619}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=9.73346,55.56325,9.74543,55.57445, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
