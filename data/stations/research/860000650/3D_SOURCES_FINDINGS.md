# København Østerport (`860000650`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **2.30** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **1.57** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.27 – 14.06 (median 4.81) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 2.30.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6177_725, PUNKTSKY_1km_6178_725, scanned 2025-03-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 324.0 | 11.2 | None | 1.43 | 2.19 | 0.76 | 0.58 |  |
| perron 1 / track 2 | 2 | 55 (0.55) | 324.0 | 11.3 | None | 1.41 | 2.19 | 0.78 | 0.60 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 334.0 | 8.8 | None | 1.45 | 2.19 | 0.74 | 0.56 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 334.0 | 8.8 | None | 1.41 | 2.19 | 0.78 | 0.60 |  |
| perron 4 / track 12 | 12 | 55 (0.55) | 219.0 | 4.4 | None | 1.69 | 2.42 | 0.73 | 0.55 |  |
| perron 3 / track 5 | 5 | 92 (0.92) | 225.0 | 11.9 | None | 1.81 | 2.84 | 1.03 | 0.85 |  |
| perron 3 / track 6 | 6 | 92 (0.92) | 225.0 | 11.9 | None | 1.70 | 2.84 | 1.14 | 0.96 |  |
| perron 5 / track 13 | 13 | 92 (0.92) | 181.0 | 4.5 | None | 1.74 | 2.94 | 1.20 | 1.02 |  |

## Structures

`kobenhavn_osterport_structures_heights.geojson`, 38 features: 16 building, 2 footbridge, 6 canopy_osm, 3 canopy_laser, 11 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w113974100 | Go Hotel Østerport (building) | 11.11 | 11.94 | 1.69 | 8.81 | 592 |
| building | w134472040 | Østerport omformerstation (service) | 9.87 | 17.82 | 1.31 | 7.57 | 253 |
| canopy_osm | w590686154 | roof | 17.94 | 20.11 | 6.76 | 15.64 | 57 |
| building | w653269136 | building | 5.42 | 5.47 | 1.86 | 3.12 | 34 |
| canopy_osm | w653269140 | roof | 6.80 | 6.88 | 4.12 | 4.50 | 41 |
| canopy_osm | w653269143 | roof | 7.06 | 7.14 | 4.86 | 4.76 | 17 |
| building | w653269144 | building | 6.70 | 15.02 | 2.24 | 4.40 | 71 |
| canopy_osm | w653269145 | roof | 6.98 | 7.25 | 4.46 | 4.68 | 16 |
| canopy_osm | w653269151 | roof | 12.43 | 17.38 | 4.48 | 10.13 | 36 |
| canopy_osm | w653269152 | roof | 7.63 | 9.10 | 3.49 | 5.33 | 13 |
| building | w653269153 | industrial | 5.41 | 5.54 | 1.91 | 3.11 | 46 |
| building | w653270349 | shed | 8.39 | 9.19 | 1.55 | 6.09 | 6 |
| building | w653270350 | building | – | – | 1.86 | – | 0 |
| building | w653270352 | building | 5.32 | 5.50 | 1.69 | 3.02 | 32 |
| building | w653270353 | shed | 4.50 | 11.30 | 1.77 | 2.20 | 22 |
| building | w653270370 | building | – | – | 1.74 | – | 0 |
| building | w724683394 | station building | 12.00 | 12.47 | 1.37 | 9.70 | 125 |
| building | w1144536983 | building | – | – | 6.48 | – | 3 |
| building | w1144536984 | building | – | – | 6.66 | – | 0 |
| building | w1144536985 | building | – | – | 6.88 | – | 0 |
| footbridge | w1145447677 | bridge | 8.05 | 9.31 | 1.36 | 5.75 | 61 |
| building | w1173399938 | building | 14.06 | 14.52 | 4.05 | 11.76 | 25 |
| footbridge | w1341496014 | bridge | 5.74 | 6.56 | 0.58 | 3.44 | 29 |
| building | r10998289 | building | 14.78 | 23.25 | 1.29 | 12.48 | 1159 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 5.91 | 5.95 | 2.78 | 3.61 | 330 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 5.99 | 6.09 | 1.48 | 3.69 | 8612 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 7.95 | 8.96 | 6.96 | 5.65 | 60 |
| train_in_scan | (laser) | train standing during the scan (16.6 m × 2.9 m) | 5.88 | – | – | 3.99 | 228 |
| train_in_scan | (laser) | train standing during the scan (73.5 m × 2.9 m) | 5.84 | – | – | 4.02 | 865 |
| train_in_scan | (laser) | train standing during the scan (157.8 m × 2.6 m) | 5.92 | – | – | 4.28 | 3307 |
| train_in_scan | (laser) | train standing during the scan (127.2 m × 2.6 m) | 6.21 | – | – | 4.10 | 2877 |
| train_in_scan | (laser) | train standing during the scan (22.9 m × 2.6 m) | 6.39 | – | – | 3.91 | 496 |
| train_in_scan | (laser) | train standing during the scan (116.9 m × 2.8 m) | 5.43 | – | – | 3.86 | 2575 |
| train_in_scan | (laser) | train standing during the scan (17.7 m × 1.5 m) | 5.84 | – | – | 4.04 | 83 |
| train_in_scan | (laser) | train standing during the scan (83.4 m × 2.6 m) | 5.30 | – | – | 3.76 | 1872 |
| train_in_scan | (laser) | train standing during the scan (74.3 m × 2.5 m) | 5.31 | – | – | 3.76 | 1659 |
| train_in_scan | (laser) | train standing during the scan (115.3 m × 2.9 m) | 5.77 | – | – | 4.07 | 1726 |
| train_in_scan | (laser) | train standing during the scan (77.7 m × 2.7 m) | 5.39 | – | – | 3.84 | 1818 |

## Trains in the scan

11 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 3 track 5: the outline FOR_PERRONER_OD Kk 173 runs 330 m along the track, Bilag says 225 m; line drawn to the outline
- Perron 3 track 6: the outline FOR_PERRONER_OD Kk 173 runs 330 m along the track, Bilag says 225 m; line drawn to the outline
- Platform surfaces differ by 0.75 m across the station (2.19–2.94 m); the station reference above is their median — check which level the app should use.
- w134472040 Østerport omformerstation (service): p95 17.8 m is 7.9 m above the median 9.9 m (a taller neighbour or a mast inside the outline?).
- w653269144 building: p95 15.0 m is 8.3 m above the median 6.7 m (a taller neighbour or a mast inside the outline?).
- w653269151 roof: p95 17.4 m is 4.9 m above the median 12.4 m (a taller neighbour or a mast inside the outline?).
- w653270353 shed: p95 11.3 m is 6.8 m above the median 4.5 m (a taller neighbour or a mast inside the outline?).
- r10998289 building: p95 23.2 m is 8.5 m above the median 14.8 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-10: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6177_725, PUNKTSKY_1km_6178_725). https://dataforsyningen.dk/data/3931 (scan 2025-03-10; 5,509,625 points in the box, 10.84 per m²; classes {'2': 2632758, '3': 143869, '4': 134190, '5': 1606824, '6': 847482, '7': 40872, '9': 39159, '14': 2445, '17': 41813, '18': 20213}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.57961,55.68792,12.59584,55.69736, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
