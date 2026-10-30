# Odense (`860000512`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **14.90** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **14.09** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 6.78 – 20.11 (median 13.91) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 14.90.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6140_587, scanned 2025-02-20. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 3 | 3 | 55 (0.55) | 427.0 | 8.5 | None | 14.02 | 14.85 | 0.83 | 0.66 |  |
| perron 1 / track 4 | 4 | 55 (0.55) | 427.0 | 8.5 | None | 14.06 | 14.85 | 0.79 | 0.61 |  |
| perron 2 / track 5 | 5 | 55 (0.55) | 427.0 | 9.6 | None | 14.06 | 14.90 | 0.84 | 0.66 |  |
| perron 2 / track 6 | 6 | 55 (0.55) | 427.0 | 9.6 | None | 14.19 | 14.91 | 0.72 | 0.55 |  |
| perron 3 / track 7 | 7 | 55 (0.55) | 231.0 | 8.9 | None | 14.13 | 14.90 | 0.77 | 0.59 |  |
| perron 3 / track 8 | 8 | 55 (0.55) | 122.0 | 16.6 | None | 14.12 | 14.90 | 0.78 | 0.60 |  |

## Structures

`odense_structures_heights.geojson`, 33 features: 11 building, 2 footbridge, 5 canopy_osm, 2 canopy_laser, 1 hall_roof_laser, 12 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w27862489 | Odense Banegård Center (station building) | 27.66 | 32.71 | 12.61 | 12.76 | 5368 |
| building | w37135323 | Danmarks Jernbanemuseum (building) | 20.98 | 27.04 | 13.99 | 6.08 | 1916 |
| building | w99884016 | Dronning Louises Station (building) | 18.77 | 20.44 | 13.84 | 3.87 | 789 |
| building | w119578000 | Odenses Gamle Banegård (station building) | 21.27 | 27.13 | 11.16 | 6.37 | 1217 |
| building | w148133805 | apartments | 23.95 | 27.25 | 13.09 | 9.05 | 312 |
| building | w197567451 | upper level (building) | 30.21 | 31.54 | 13.01 | 15.31 | 1383 |
| building | w398018001 | Odense (building) | 23.80 | 24.02 | 14.16 | 8.90 | 343 |
| canopy_osm | w432556983 | roof | 19.30 | 19.38 | 14.08 | 4.40 | 1495 |
| canopy_osm | w432556987 | roof | 19.25 | 19.38 | 14.05 | 4.35 | 860 |
| canopy_osm | w432556991 | roof | 19.38 | 19.54 | 14.05 | 4.48 | 446 |
| building | w454507019 | For Jernbanemuseet (warehouse) | 18.60 | 18.72 | 14.20 | 3.70 | 439 |
| footbridge | w591537479 | Byens Bro (bridge) | 21.44 | 27.36 | 13.31 | 6.54 | 2957 |
| building | w592641356 | transportation | 20.34 | 20.74 | 14.12 | 5.44 | 7 |
| building | w592641357 | transportation | 20.68 | 27.01 | 14.91 | 5.78 | 79 |
| building | w592641358 | transportation | 20.77 | 27.04 | 14.81 | 5.87 | 92 |
| canopy_osm | w963727699 | Miniature train (roof) | 16.65 | 17.84 | 14.17 | 1.75 | 77 |
| footbridge | w1205560940 | bridge | 13.82 | 13.90 | 11.34 | -1.08 | 77 |
| canopy_osm | w1346969859 | roof | 18.00 | 18.01 | 14.74 | 3.10 | 9 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 17.71 | 17.91 | 14.06 | 2.81 | 536 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 17.75 | 17.92 | 14.50 | 2.85 | 168 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 22.44 | 22.75 | 13.85 | 7.54 | 1782 |
| train_in_scan | (laser) | train standing during the scan (99.8 m × 3.1 m) | 17.92 | – | – | 3.83 | 5509 |
| train_in_scan | (laser) | train standing during the scan (19.0 m × 2.9 m) | 17.83 | – | – | 3.81 | 1363 |
| train_in_scan | (laser) | train standing during the scan (20.8 m × 2.8 m) | 17.62 | – | – | 3.67 | 1081 |
| train_in_scan | (laser) | train standing during the scan (86.5 m × 2.7 m) | 18.09 | – | – | 4.08 | 4791 |
| train_in_scan | (laser) | train standing during the scan (76.5 m × 2.8 m) | 17.81 | – | – | 3.80 | 4819 |
| train_in_scan | (laser) | train standing during the scan (169.7 m × 2.7 m) | 18.09 | – | – | 4.11 | 8843 |
| train_in_scan | (laser) | train standing during the scan (33.7 m × 2.8 m) | 17.81 | – | – | 3.77 | 1925 |
| train_in_scan | (laser) | train standing during the scan (58.5 m × 2.8 m) | 17.80 | – | – | 3.78 | 3294 |
| train_in_scan | (laser) | train standing during the scan (79.4 m × 2.8 m) | 17.83 | – | – | 3.80 | 4639 |
| train_in_scan | (laser) | train standing during the scan (51.4 m × 2.9 m) | 17.96 | – | – | 3.83 | 2954 |
| train_in_scan | (laser) | train standing during the scan (25.4 m × 3.0 m) | 17.85 | – | – | 3.77 | 1535 |
| train_in_scan | (laser) | train standing during the scan (41.0 m × 2.7 m) | 17.97 | – | – | 3.83 | 2548 |

## Trains in the scan

12 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w27862489 Odense Banegård Center (station building): p95 32.7 m is 5.1 m above the median 27.7 m (a taller neighbour or a mast inside the outline?).
- w119578000 Odenses Gamle Banegård (station building): p95 27.1 m is 5.9 m above the median 21.3 m (a taller neighbour or a mast inside the outline?).
- w591537479 Byens Bro (bridge): p95 27.4 m is 5.9 m above the median 21.4 m (a taller neighbour or a mast inside the outline?).
- w592641357 transportation: p95 27.0 m is 6.3 m above the median 20.7 m (a taller neighbour or a mast inside the outline?).
- w592641358 transportation: p95 27.0 m is 6.3 m above the median 20.8 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (170 m², top 7.5 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (170 m², top 7.5 m above the platform, 8.4 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (58 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-02-20: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6140_587). https://dataforsyningen.dk/data/3931 (scan 2025-02-20; 3,812,063 points in the box, 19.15 per m²; classes {'2': 2195329, '3': 200433, '4': 63415, '5': 413338, '6': 765985, '7': 94936, '14': 10396, '17': 61412, '18': 6819}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.37623,55.39891,10.39197,55.40461, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
