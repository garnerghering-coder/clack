# Vejle (`860000073`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **5.01** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **4.27** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -1.01 – 6.02 (median 2.03) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 5.01.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6173_533, scanned 2025-03-06. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 3 | 3 | 50 (0.50) | 338.0 | 6.5 | None | 4.24 | 5.02 | 0.78 | 0.61 |  |
| perron 1 / track 4 | 4 | 35 (0.35) | 338.0 | 6.5 | None | 4.34 | 5.02 | 0.68 | 0.51 |  |
| perron 2 / track 5 | 5 | 50 (0.50) | 338.0 | 6.9 | None | 4.24 | 5.01 | 0.77 | 0.59 |  |
| perron 2 / track 6 | 6 | 35 (0.35) | 338.0 | 7.0 | None | 4.29 | 5.00 | 0.71 | 0.53 |  |

## Structures

`vejle_structures_heights.geojson`, 26 features: 13 building, 5 canopy_osm, 1 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w88288481 | retail | 10.08 | 14.16 | 0.94 | 5.07 | 1323 |
| building | w88288498 | station building | 6.95 | 7.47 | 2.08 | 1.94 | 2645 |
| building | w156178919 | house | 7.87 | 9.17 | 1.23 | 2.86 | 88 |
| bridge | w260028532 | bridge | 11.82 | 13.40 | -0.63 | 6.81 | 192 |
| bridge | w260028533 | bridge | 4.94 | 9.32 | 0.17 | -0.07 | 184 |
| bridge | w260029393 | bridge | 5.18 | 11.21 | 0.18 | 0.17 | 125 |
| building | w324299746 | commercial | 6.72 | 9.82 | 0.99 | 1.71 | 460 |
| canopy_osm | w752166641 | roof | 5.26 | 12.29 | 1.92 | 0.25 | 16 |
| canopy_osm | w752338057 | roof | 3.85 | 3.94 | 1.29 | -1.16 | 35 |
| building | w759073080 | building | 7.04 | 11.84 | 3.15 | 2.03 | 241 |
| canopy_osm | w854269472 | roof | 5.92 | 5.97 | 2.50 | 0.91 | 331 |
| building | w1033416994 | station building | 8.93 | 13.72 | 4.26 | 3.92 | 2033 |
| building | w1033416996 | building | 5.26 | 7.17 | 0.92 | 0.25 | 519 |
| building | w1033416997 | building | 7.96 | 8.47 | 1.09 | 2.95 | 974 |
| building | w1033416998 | house | 7.96 | 10.65 | 1.23 | 2.95 | 375 |
| building | w1033417008 | station building | 7.93 | 8.00 | 5.28 | 2.92 | 147 |
| building | w1033417014 | service | 4.39 | 4.49 | 1.06 | -0.62 | 93 |
| canopy_osm | w1033417027 | roof | 7.57 | 13.70 | 4.89 | 2.56 | 168 |
| building | w1033417029 | station building | 8.96 | 9.23 | 4.26 | 3.95 | 1189 |
| canopy_osm | w1033417032 | roof | 7.63 | 7.67 | 4.95 | 2.62 | 124 |
| building | w1033417034 | service | 7.65 | 7.91 | 4.87 | 2.64 | 122 |
| bridge | w1059470200 | bridge | 3.61 | 7.50 | 0.09 | -1.40 | 160 |
| bridge | r6504079 | bridge | 5.29 | 11.82 | 0.02 | 0.28 | 961 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 8.55 | 10.27 | 3.40 | 3.54 | 1279 |
| train_in_scan | (laser) | train standing during the scan (61.5 m × 2.9 m) | 8.98 | – | – | 3.93 | 4085 |
| train_in_scan | (laser) | train standing during the scan (32.4 m × 3.5 m) | 8.70 | – | – | 3.95 | 1424 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS perron 1 / track 4 (track 4): laser gives 0.68 m above the track bed (≈0.51 m above rail after −0.15…0.2 m), register class 35 = 0.35 m. Not decided; add to REVIEW.md.
- Platform BIS perron 2 / track 6 (track 6): laser gives 0.71 m above the track bed (≈0.53 m above rail after −0.15…0.2 m), register class 35 = 0.35 m. Not decided; add to REVIEW.md.
- w752166641 roof: p95 12.3 m is 7.0 m above the median 5.3 m (a taller neighbour or a mast inside the outline?).
- w1033416994 station building: p95 13.7 m is 4.8 m above the median 8.9 m (a taller neighbour or a mast inside the outline?).
- w1033417027 roof: p95 13.7 m is 6.1 m above the median 7.6 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w260028532 (no mapped ways); w260028533 (cycleway, secondary, tertiary); w260029393 (no mapped ways); w1059470200 (unclassified); r6504079 (no mapped ways).
- Laser-traced roof (140 m², top 3.5 m above the platform, 4.3 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-06: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6173_533). https://dataforsyningen.dk/data/3931 (scan 2025-03-06; 3,232,426 points in the box, 18.03 per m²; classes {'2': 1458020, '3': 189824, '4': 95995, '5': 375798, '6': 932678, '7': 78070, '14': 14008, '17': 81036, '18': 6997}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=9.53191,55.70164,9.54192,55.70972, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
