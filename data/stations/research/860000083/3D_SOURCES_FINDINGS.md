# Kolding (`860000083`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **3.39** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **2.70** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -0.33 – 12.23 (median 2.47) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 3.39.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6149_530, scanned 2025-03-05. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 50 (0.50) | 301.0 | 6.1 | None | 2.65 | 3.36 | 0.71 | 0.53 |  |
| perron 2 / track 2 | 2 | 50 (0.50) | 250.0 | 10.5 | None | 2.70 | 3.39 | 0.69 | 0.51 |  |
| perron 2 / track 3 | 3 | 50 (0.50) | 250.0 | 10.5 | None | 2.70 | 3.39 | 0.69 | 0.51 |  |

## Structures

`kolding_structures_heights.geojson`, 18 features: 8 building, 3 canopy_osm, 6 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w105967752 | building | 5.63 | 5.84 | 2.79 | 2.24 | 955 |
| building | w105995462 | building | 4.22 | 5.47 | 2.03 | 0.83 | 172 |
| building | w106001604 | elevator | 7.34 | 7.39 | 3.40 | 3.95 | 214 |
| building | w106024677 | building | – | – | 2.54 | – | 0 |
| canopy_osm | w106026332 | roof | 7.65 | 7.82 | 2.74 | 4.26 | 2119 |
| building | w106033436 | building | 14.04 | 21.39 | 2.44 | 10.65 | 653 |
| building | w106041802 | elevator | 7.43 | 7.50 | 3.42 | 4.04 | 251 |
| building | w369175437 | building | 5.09 | 6.42 | 1.90 | 1.70 | 177 |
| canopy_osm | w1474781946 | roof | 4.59 | 4.70 | 2.14 | 1.20 | 268 |
| canopy_osm | w1474781947 | roof | 4.42 | 4.53 | 1.97 | 1.03 | 165 |
| bridge | w1493609150 | bridge | 10.95 | 11.13 | 1.83 | 7.56 | 21 |
| building | r1513288 | civic | 8.95 | 14.49 | 0.76 | 5.56 | 27456 |
| train_in_scan | (laser) | train standing during the scan (68.0 m × 2.5 m) | 6.33 | – | – | 3.70 | 3547 |
| train_in_scan | (laser) | train standing during the scan (256.1 m × 3.2 m) | 6.55 | – | – | 3.98 | 21388 |
| train_in_scan | (laser) | train standing during the scan (20.7 m × 3.8 m) | 5.29 | – | – | 3.91 | 437 |
| train_in_scan | (laser) | train standing during the scan (59.1 m × 2.8 m) | 6.73 | – | – | 3.96 | 3481 |
| train_in_scan | (laser) | train standing during the scan (19.5 m × 2.9 m) | 6.71 | – | – | 3.96 | 1262 |
| train_in_scan | (laser) | train standing during the scan (78.7 m × 2.5 m) | 6.28 | – | – | 3.99 | 3049 |

## Trains in the scan

6 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w106033436 building: p95 21.4 m is 7.3 m above the median 14.0 m (a taller neighbour or a mast inside the outline?).
- r1513288 civic: p95 14.5 m is 5.5 m above the median 9.0 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1493609150 (secondary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-05: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6149_530). https://dataforsyningen.dk/data/3931 (scan 2025-03-05; 4,204,008 points in the box, 18.67 per m²; classes {'2': 2072767, '3': 247462, '4': 126130, '5': 627795, '6': 988817, '7': 97028, '9': 21592, '14': 1583, '17': 14331, '18': 6503}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=9.47548,55.4874,9.4882,55.49455, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
