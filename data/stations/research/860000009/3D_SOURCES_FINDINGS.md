# Hjørring (`860000009`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **34.52** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **33.77** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 24.05 – 37.77 (median 33.84) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 34.52.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6368_558, PUNKTSKY_1km_6368_559, scanned 2022-03-19. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 226.0 | 6.5 | None | 33.73 | 34.50 | 0.77 | 0.59 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 305.0 | 4.9 | None | 33.81 | 34.54 | 0.73 | 0.55 |  |

## Structures

`hjorring_structures_heights.geojson`, 16 features: 3 building, 10 canopy_osm, 1 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w121981333 | station building | 41.97 | 44.06 | 34.08 | 7.45 | 493 |
| building | w238985005 | commercial | 39.16 | 42.47 | 34.26 | 4.64 | 209 |
| building | w302380925 | building | 38.21 | 44.68 | 33.96 | 3.69 | 594 |
| canopy_osm | w511352529 | roof | 37.27 | 37.35 | 33.97 | 2.75 | 1308 |
| canopy_osm | w578003246 | roof | 37.05 | 37.07 | 34.52 | 2.53 | 75 |
| canopy_osm | w578003281 | roof | 37.16 | 37.19 | 34.18 | 2.64 | 304 |
| canopy_osm | w578003464 | roof | 37.15 | 37.18 | 34.24 | 2.63 | 329 |
| canopy_osm | w578003621 | roof | 37.04 | 37.06 | 34.42 | 2.52 | 67 |
| canopy_osm | w578003664 | roof | 37.14 | 37.17 | 34.22 | 2.62 | 335 |
| canopy_osm | w578003696 | roof | 37.16 | 37.18 | 34.23 | 2.64 | 104 |
| canopy_osm | w578003699 | roof | 36.92 | 36.94 | 34.23 | 2.40 | 78 |
| canopy_osm | w578003773 | roof | 37.17 | 37.21 | 34.28 | 2.65 | 119 |
| canopy_osm | w578003937 | roof | 36.88 | 36.90 | 34.29 | 2.36 | 146 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 38.20 | 38.24 | 33.79 | 3.68 | 301 |
| train_in_scan | (laser) | train standing during the scan (39.7 m × 2.6 m) | 37.72 | – | – | 3.93 | 1372 |
| train_in_scan | (laser) | train standing during the scan (39.6 m × 2.6 m) | 37.61 | – | – | 3.83 | 1336 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 1 track 1: the outline FOR_PERRONER_OD Hj 171 runs 354 m along the track, Bilag says 226 m; line drawn to the outline

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 21 files found (4 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2022-03-19: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6368_558, PUNKTSKY_1km_6368_559). https://dataforsyningen.dk/data/3931 (scan 2022-03-19; 3,247,232 points in the box, 20.74 per m²; classes {'2': 1465319, '3': 19576, '4': 104421, '5': 1140415, '6': 486988, '7': 353, '8': 26819, '9': 2152, '17': 929, '18': 260}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=9.97869,57.45376,9.99419,57.45906, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
