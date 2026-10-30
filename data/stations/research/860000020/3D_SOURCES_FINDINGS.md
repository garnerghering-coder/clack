# Aalborg (`860000020`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **4.78** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **4.02** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.76 – 11.19 (median 3.95) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 4.78.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6322_555, scanned 2022-03-06. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 0 | 0 | 50 (0.50) | 109.0 | 23.1 | None | 4.08 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| perron 1 / track 1 | 1 | 50 (0.50) | 367.0 | 7.4 | None | 4.07 | 4.78 | 0.71 | 0.53 |  |
| perron 2 / track 3 | 3 | 50 (0.50) | 367.0 | 8.5 | None | 3.92 | 4.78 | 0.86 | 0.69 |  |
| perron 2 / track 4 | 4 | 50 (0.50) | 367.0 | 8.6 | None | 3.97 | 4.78 | 0.81 | 0.64 |  |

## Structures

`aalborg_structures_heights.geojson`, 29 features: 13 building, 3 canopy_osm, 2 canopy_laser, 1 hall_roof_laser, 6 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w7975017 | Kennedy Arkaden (parking) | 16.02 | 19.96 | 3.84 | 11.24 | 607 |
| building | w89752311 | station building | 11.00 | 22.62 | 2.41 | 6.22 | 374 |
| building | w91641394 | commercial | 22.05 | 24.36 | 2.37 | 17.27 | 4992 |
| building | w285634242 | building | 8.18 | 8.50 | 4.26 | 3.40 | 397 |
| building | w285634245 | retail | 9.02 | 9.07 | 4.35 | 4.24 | 35 |
| building | w308132562 | building | 26.29 | 29.10 | 3.96 | 21.51 | 4774 |
| canopy_osm | w334830152 | roof | 8.23 | 8.29 | 3.93 | 3.45 | 3002 |
| canopy_osm | w334830155 | roof | 9.31 | 9.41 | 4.03 | 4.53 | 2879 |
| bridge | w369146365 | bridge | 12.07 | 12.87 | 3.83 | 7.29 | 8213 |
| bridge | w369148898 | bridge | 12.09 | 12.97 | 3.87 | 7.31 | 1277 |
| bridge | w369148899 | bridge | 11.12 | 13.00 | 3.96 | 6.33 | 1870 |
| bridge | w402575915 | bridge | 12.46 | 13.40 | 3.72 | 7.68 | 492 |
| building | w826572002 | station building | – | – | – | – | 0 |
| building | w826572004 | retail | 8.10 | 8.30 | 4.19 | 3.32 | 157 |
| building | w826572014 | building | – | – | 4.28 | – | 0 |
| building | w826572015 | building | 10.85 | 11.82 | 4.24 | 6.07 | 185 |
| building | w826572019 | building | – | – | 4.25 | – | 0 |
| canopy_osm | w844491854 | roof | 9.22 | 9.33 | 2.91 | 4.44 | 2085 |
| building | w1312400857 | Kennedy Arkaden (retail) | 19.94 | 33.04 | 0.77 | 15.16 | 17402 |
| building | w1312400866 | roof | 8.22 | 18.95 | 3.96 | 3.44 | 2478 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 7.91 | 7.95 | 3.90 | 3.13 | 248 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 7.30 | 7.34 | 4.01 | 2.52 | 776 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 12.26 | 12.98 | 4.04 | 7.48 | 796 |
| train_in_scan | (laser) | train standing during the scan (39.6 m × 2.5 m) | 7.90 | – | – | 3.95 | 1151 |
| train_in_scan | (laser) | train standing during the scan (83.9 m × 2.7 m) | 8.39 | – | – | 4.37 | 4759 |
| train_in_scan | (laser) | train standing during the scan (83.4 m × 2.6 m) | 8.35 | – | – | 4.26 | 2456 |
| train_in_scan | (laser) | train standing during the scan (58.5 m × 2.7 m) | 8.02 | – | – | 3.97 | 3468 |
| train_in_scan | (laser) | train standing during the scan (81.9 m × 2.6 m) | 8.03 | – | – | 3.97 | 4474 |
| train_in_scan | (laser) | train standing during the scan (50.8 m × 2.7 m) | 7.91 | – | – | 3.96 | 1563 |

## Trains in the scan

6 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS perron 2 / track 3 (track 3): laser gives 0.86 m above the track bed (≈0.69 m above rail after −0.15…0.2 m), register class 50 = 0.5 m. Not decided; add to REVIEW.md.
- Platform BIS perron 2 / track 4 (track 4): laser gives 0.81 m above the track bed (≈0.64 m above rail after −0.15…0.2 m), register class 50 = 0.5 m. Not decided; add to REVIEW.md.
- w89752311 station building: p95 22.6 m is 11.6 m above the median 11.0 m (a taller neighbour or a mast inside the outline?).
- w1312400857 Kennedy Arkaden (retail): p95 33.0 m is 13.1 m above the median 19.9 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w369146365 (service); w369148898 (busway); w369148899 (busway, cycleway); w402575915 (busway, cycleway, footway, service, tertiary).
- Laser-traced roof (47 m², top 3.1 m above the platform, 3.9 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.
- Laser-traced roof (94 m², top 7.5 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (25 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2022-03-06: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6322_555). https://dataforsyningen.dk/data/3931 (scan 2022-03-06; 5,999,280 points in the box, 26.66 per m²; classes {'2': 2814134, '3': 425575, '4': 231395, '5': 1457869, '6': 1014404, '7': 1695, '8': 31589, '17': 21864, '18': 755}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=9.90954,57.03231,9.92256,57.04716, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
