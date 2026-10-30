# København Nørreport (`860000646`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **–** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **–** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 3.49 – 10.92 (median 8.78) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting –.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6176_724, scanned 2025-03-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 203.0 | 3.7 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| perron 1 / track 2 | 2 | 55 (0.55) | 203.0 | 3.7 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| perron 2 / track 3 | 3 | 92 (0.92) | 177.0 | 8.9 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| perron 2 / track 4 | 4 | 92 (0.92) | 177.0 | 8.9 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |

## Structures

`kobenhavn_norreport_structures_heights.geojson`, 21 features: 15 building, 6 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w47119785 | building | 22.63 | 27.24 | 8.96 | – | 452 |
| building | w47119792 | building | 30.49 | 31.88 | 8.60 | – | 471 |
| building | w176082635 | building | 23.39 | 27.99 | 8.56 | – | 328 |
| canopy_osm | w225625921 | roof | 14.63 | 14.69 | 10.08 | – | 225 |
| canopy_osm | w225625922 | roof | 15.19 | 15.24 | 10.01 | – | 269 |
| canopy_osm | w288367148 | roof | 15.19 | 15.25 | 9.61 | – | 825 |
| canopy_osm | w486296251 | roof | 12.73 | 12.79 | 8.28 | – | 483 |
| canopy_osm | w501114636 | roof | 12.95 | 13.01 | 7.84 | – | 342 |
| building | w642561015 | retail | – | – | 9.54 | – | 0 |
| building | w642561049 | station building | – | – | – | – | 0 |
| building | w642561053 | toilets | – | – | – | – | 0 |
| building | w642816846 | station building | 12.44 | 12.81 | 9.62 | – | 14 |
| building | w642816847 | station building | – | – | 9.60 | – | 1 |
| building | w642816853 | station building | – | – | 8.57 | – | 0 |
| building | w642816859 | station building | – | – | 9.99 | – | 0 |
| building | w642818720 | station building | – | – | – | – | 0 |
| building | w1007124147 | building | 31.23 | 51.08 | 9.45 | – | 1377 |
| building | w1571069920 | toilet | 11.28 | 11.35 | 8.67 | – | 180 |
| building | r165391 | apartments | 23.14 | 34.70 | 5.74 | – | 11726 |
| canopy_osm | r8904639 | roof | 14.79 | 14.85 | 9.04 | – | 57 |
| building | r13732243 | apartments | 21.50 | 29.16 | 4.43 | – | 12943 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 1 track 1: the outline FOR_PERRONER_OD Kn 171 runs 94 m along the track, Bilag says 203 m; line drawn to the outline
- Perron 1 track 2: the outline FOR_PERRONER_OD Kn 171 runs 94 m along the track, Bilag says 203 m; line drawn to the outline
- Perron 2 track 3: the outline FOR_PERRONER_OD Kn 172 runs 116 m along the track, Bilag says 177 m; line drawn to the outline
- Perron 2 track 4: the outline FOR_PERRONER_OD Kn 172 runs 116 m along the track, Bilag says 177 m; line drawn to the outline
- Underground (Boulevardbanen tunnel): the outlines and track lines are Banedanmark's; the laser will not see these platforms
- w47119785 building: p95 27.2 m is 4.6 m above the median 22.6 m (a taller neighbour or a mast inside the outline?).
- w176082635 building: p95 28.0 m is 4.6 m above the median 23.4 m (a taller neighbour or a mast inside the outline?).
- r13732243 apartments: p95 29.2 m is 7.7 m above the median 21.5 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (55 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-10: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6176_724). https://dataforsyningen.dk/data/3931 (scan 2025-03-10; 3,139,120 points in the box, 21.57 per m²; classes {'2': 1012309, '3': 162042, '4': 55494, '5': 470252, '6': 1374278, '7': 51084, '14': 1183, '18': 12478}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.56623,55.68025,12.57847,55.68717, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
