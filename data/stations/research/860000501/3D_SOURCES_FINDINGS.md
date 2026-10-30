# Middelfart (`860000501`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **12.87** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **12.08** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 3.92 – 16.31 (median 9.30) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 12.87.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6150_546, scanned 2023-03-08. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 331.0 | 10.1 | None | 12.18 | 12.87 | 0.69 | 0.52 |  |
| perron 1 / track 3 | 3 | 55 (0.55) | 331.0 | 10.1 | None | 12.08 | 12.87 | 0.79 | 0.62 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 335.0 | 5.5 | None | 12.03 | 12.78 | 0.75 | 0.57 |  |

## Structures

`middelfart_structures_heights.geojson`, 12 features: 9 building, 3 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w220749281 | Middelfart Midtpunkt (retail) | 16.61 | 20.74 | 8.98 | 3.74 | 6453 |
| building | w327668260 | station building | 14.99 | 18.34 | 6.87 | 2.12 | 5249 |
| building | w409833300 | building | 13.61 | 13.94 | 10.03 | 0.74 | 230 |
| building | w409833308 | building | 14.48 | 14.59 | 10.42 | 1.61 | 578 |
| canopy_osm | w454743378 | roof | 15.82 | 15.89 | 12.86 | 2.95 | 2500 |
| canopy_osm | w454743379 | roof | 15.82 | 18.36 | 12.75 | 2.96 | 42 |
| canopy_osm | w669672924 | roof | 10.86 | 10.95 | 8.45 | -2.01 | 150 |
| building | w669673054 | building | 14.82 | 15.66 | 12.38 | 1.95 | 219 |
| building | w669673087 | building | 15.41 | 15.57 | 12.05 | 2.54 | 359 |
| building | w669673403 | building | 15.46 | 15.61 | 11.96 | 2.59 | 202 |
| building | w669674337 | building | 15.28 | 15.44 | 12.52 | 2.41 | 144 |
| building | w1083298807 | The Platform (building) | 19.99 | 21.78 | 12.01 | 7.12 | 4182 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w327668260 station building: p95 18.3 m is 3.3 m above the median 15.0 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-03-08: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6150_546). https://dataforsyningen.dk/data/3931 (scan 2023-03-08; 3,987,869 points in the box, 22.33 per m²; classes {'2': 2204097, '3': 58317, '4': 268754, '5': 786257, '6': 611192, '7': 1646, '8': 47690, '17': 9528, '18': 388}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=9.72872,55.49859,9.74308,55.50428, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
