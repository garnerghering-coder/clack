# Holbæk (`860000719`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **16.45** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **15.63** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 2.35 – 25.59 (median 15.27) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 16.45.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6177_669, PUNKTSKY_1km_6177_670, scanned 2024-04-30. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 311.0 | 7.9 | None | 15.55 | 16.36 | 0.81 | 0.63 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 423.0 | 6.6 | None | 15.69 | 16.55 | 0.86 | 0.69 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 280.0 | 6.6 | None | 15.66 | 16.58 | 0.92 | 0.75 |  |
| perron 2 / track 2a | 2a | 55 (0.55) | 130.0 | 19.3 | None | 15.60 | 16.34 | 0.74 | 0.57 |  |

## Structures

`holbaek_structures_heights.geojson`, 21 features: 16 building, 1 canopy_osm, 4 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w149908801 | building | 20.36 | 20.45 | 11.50 | 3.91 | 1372 |
| building | w157165577 | station building | 20.26 | 20.45 | 11.62 | 3.81 | 1967 |
| canopy_osm | w170988641 | roof | 12.22 | 12.37 | 6.92 | -4.23 | 411 |
| building | w691610645 | building | 18.94 | 19.33 | 14.24 | 2.49 | 556 |
| building | w691610751 | building | – | – | 15.82 | – | 0 |
| building | w691610868 | building | 19.51 | 19.55 | 10.73 | 3.06 | 110 |
| building | w691610908 | building | 19.08 | 19.14 | 16.48 | 2.63 | 170 |
| building | w691611007 | building | 13.75 | 13.93 | 11.41 | -2.70 | 77 |
| building | w691611013 | building | 20.25 | 20.29 | 15.59 | 3.80 | 1017 |
| building | w691611033 | building | 18.91 | 18.94 | 15.53 | 2.46 | 83 |
| building | w691611094 | building | 18.60 | 18.63 | 14.13 | 2.15 | 235 |
| building | w691909763 | building | 18.07 | 22.61 | 12.81 | 1.62 | 3479 |
| building | w691910154 | building | – | – | 10.61 | – | 0 |
| building | w691910713 | detached | 20.72 | 23.07 | 14.13 | 4.27 | 90 |
| building | w691910723 | building | 16.80 | 17.05 | 10.58 | 0.35 | 446 |
| building | w691910781 | building | 16.20 | 16.24 | 13.94 | -0.25 | 24 |
| building | w691910986 | building | 18.03 | 18.81 | 13.26 | 1.58 | 51 |
| train_in_scan | (laser) | train standing during the scan (16.0 m × 2.8 m) | 18.06 | – | – | 3.58 | 824 |
| train_in_scan | (laser) | train standing during the scan (39.0 m × 2.7 m) | 19.55 | – | – | 3.89 | 2548 |
| train_in_scan | (laser) | train standing during the scan (16.5 m × 2.8 m) | 18.09 | – | – | 3.56 | 1248 |
| train_in_scan | (laser) | train standing during the scan (30.3 m × 3.7 m) | 19.64 | – | – | 4.01 | 2440 |

## Trains in the scan

4 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Bilag row TIB 5 perron 1 track 0: no Banedanmark track 0 within 700 m; not placed
- Perron 2 track 3: the outline FOR_PERRONER_OD Hk 172 runs 424 m along the track, Bilag says 280 m; line drawn to the outline
- Platform BIS perron 2 / track 2 (track 2): laser gives 0.86 m above the track bed (≈0.69 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 2 / track 3 (track 3): laser gives 0.92 m above the track bed (≈0.75 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- w691909763 building: p95 22.6 m is 4.5 m above the median 18.1 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 68 files found (29 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-04-30: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6177_669, PUNKTSKY_1km_6177_670). https://dataforsyningen.dk/data/3931 (scan 2024-04-30; 6,042,958 points in the box, 17.23 per m²; classes {'2': 2881903, '3': 258953, '4': 232977, '5': 1219510, '6': 1262864, '7': 108716, '9': 2309, '14': 6028, '17': 59672, '18': 10026}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=11.69996,55.7114,11.71563,55.71939, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
