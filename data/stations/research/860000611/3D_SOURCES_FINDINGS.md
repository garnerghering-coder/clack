# Ringsted (`860000611`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **37.93** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **37.20** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 29.14 – 45.88 (median 37.50) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 37.93.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6146_675, PUNKTSKY_1km_6146_676, PUNKTSKY_1km_6147_675, PUNKTSKY_1km_6147_676, scanned 2024-05-01. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 321.0 | 5.5 | None | 37.24 | 37.94 | 0.70 | 0.52 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 321.0 | 8.0 | None | 37.27 | 37.94 | 0.67 | 0.49 |  |
| perron 2 / track 3 | 3 | 72 (0.72) | 321.0 | 8.0 | None | 37.20 | 37.93 | 0.73 | 0.55 |  |
| perron 3 / track 4 | 4 | 55 (0.55) | 321.0 | 8.5 | None | 37.16 | 37.90 | 0.74 | 0.56 |  |
| perron 3 / track 5 | 5 | 55 (0.55) | 321.0 | 8.5 | None | 37.12 | 37.82 | 0.70 | 0.53 |  |

## Structures

`ringsted_structures_heights.geojson`, 32 features: 2 building, 20 canopy_osm, 1 canopy_laser, 8 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w115490124 | station building | 43.02 | 47.85 | 37.80 | 5.09 | 2466 |
| bridge | w503577201 | bridge | – | – | 38.88 | – | 0 |
| canopy_osm | w622278862 | roof | 40.13 | 41.65 | 37.31 | 2.20 | 305 |
| canopy_osm | w622278998 | roof | 42.58 | 46.07 | 38.01 | 4.65 | 54 |
| canopy_osm | w622279981 | roof | 40.39 | 45.28 | 37.93 | 2.46 | 42 |
| canopy_osm | w622280654 | roof | 40.38 | 40.51 | 38.05 | 2.45 | 59 |
| canopy_osm | w622281326 | roof | 40.16 | 40.62 | 37.83 | 2.23 | 100 |
| canopy_osm | w622281414 | roof | 40.41 | 42.03 | 38.01 | 2.48 | 12 |
| canopy_osm | w622282115 | roof | 41.69 | 45.62 | 37.88 | 3.76 | 90 |
| canopy_osm | w622282618 | roof | 41.92 | 46.35 | 37.79 | 3.99 | 374 |
| canopy_osm | w795897522 | roof | 41.39 | 41.46 | 37.22 | 3.46 | 498 |
| canopy_osm | w795897523 | roof | 41.37 | 41.48 | 37.18 | 3.44 | 456 |
| canopy_osm | w1164277505 | building | 40.24 | 43.55 | 37.71 | 2.31 | 369 |
| canopy_osm | w1164277506 | building | 40.39 | 40.44 | 37.87 | 2.46 | 65 |
| canopy_osm | w1164277507 | building | 40.32 | 43.27 | 37.79 | 2.39 | 374 |
| canopy_osm | w1164277508 | building | 40.38 | 40.42 | 37.90 | 2.45 | 73 |
| canopy_osm | w1164277509 | building | 40.29 | 40.32 | 37.92 | 2.36 | 148 |
| canopy_osm | w1164277510 | building | 40.41 | 40.45 | 38.05 | 2.48 | 210 |
| canopy_osm | w1164277511 | building | 40.43 | 43.49 | 37.90 | 2.50 | 288 |
| canopy_osm | w1164277512 | building | 40.58 | 40.63 | 38.13 | 2.65 | 73 |
| canopy_osm | w1164277513 | building | 40.46 | 40.50 | 37.93 | 2.53 | 117 |
| canopy_osm | w1164277514 | roof | 42.92 | 43.00 | 37.83 | 4.99 | 114 |
| building | w1164277516 | service | 41.87 | 46.03 | 37.82 | 3.94 | 629 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 42.84 | 42.92 | 37.83 | 4.91 | 957 |
| train_in_scan | (laser) | train standing during the scan (121.4 m × 2.8 m) | 41.19 | – | – | 3.92 | 3893 |
| train_in_scan | (laser) | train standing during the scan (15.1 m × 2.9 m) | 41.16 | – | – | 3.72 | 393 |
| train_in_scan | (laser) | train standing during the scan (21.2 m × 2.7 m) | 40.53 | – | – | 3.30 | 1085 |
| train_in_scan | (laser) | train standing during the scan (43.4 m × 2.8 m) | 40.79 | – | – | 3.65 | 3068 |
| train_in_scan | (laser) | train standing during the scan (24.6 m × 2.5 m) | 41.84 | – | – | 4.17 | 397 |
| train_in_scan | (laser) | train standing during the scan (37.9 m × 2.6 m) | 41.33 | – | – | 4.22 | 1224 |
| train_in_scan | (laser) | train standing during the scan (107.8 m × 2.6 m) | 41.41 | – | – | 4.32 | 3179 |
| train_in_scan | (laser) | train standing during the scan (75.6 m × 2.4 m) | 41.92 | – | – | 4.23 | 1186 |

## Trains in the scan

8 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS perron 2 / track 3 (track 3): laser gives 0.73 m above the track bed (≈0.55 m above rail after −0.15…0.2 m), register class 72 = 0.72 m. Not decided; add to REVIEW.md.
- w115490124 station building: p95 47.9 m is 4.8 m above the median 43.0 m (a taller neighbour or a mast inside the outline?).
- w622278998 roof: p95 46.1 m is 3.5 m above the median 42.6 m (a taller neighbour or a mast inside the outline?).
- w622279981 roof: p95 45.3 m is 4.9 m above the median 40.4 m (a taller neighbour or a mast inside the outline?).
- w622282115 roof: p95 45.6 m is 3.9 m above the median 41.7 m (a taller neighbour or a mast inside the outline?).
- w622282618 roof: p95 46.4 m is 4.4 m above the median 41.9 m (a taller neighbour or a mast inside the outline?).
- w1164277505 building: p95 43.6 m is 3.3 m above the median 40.2 m (a taller neighbour or a mast inside the outline?).
- w1164277511 building: p95 43.5 m is 3.1 m above the median 40.4 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w503577201 (cycleway, secondary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 95 files found (87 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-05-01: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6146_675, PUNKTSKY_1km_6146_676, PUNKTSKY_1km_6147_675, PUNKTSKY_1km_6147_676). https://dataforsyningen.dk/data/3931 (scan 2024-05-01; 3,438,038 points in the box, 16.84 per m²; classes {'2': 2028302, '3': 150677, '4': 149536, '5': 730682, '6': 322891, '7': 37253, '14': 7096, '17': 6710, '18': 4891}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=11.77921,55.43528,11.79461,55.44087, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
