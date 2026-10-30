# København Syd (`860000783`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **5.47** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **5.38** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -4.80 – 13.70 (median 5.07) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 5.47.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6172_720, PUNKTSKY_1km_6172_721, PUNKTSKY_1km_6173_720, PUNKTSKY_1km_6173_721, scanned 2025-03-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 4 / track 2 | 2 | 55 (0.55) | 332.0 | 17.8 | None | 5.38 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| perron 4 / track 1 | 1 | 55 (0.55) | 332.0 | 20.0 | None | 5.51 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| perron 2 / track 2 | 2 | 92 (0.92) | 180.0 | 17.8 | None | 5.38 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| perron 3 / track 1 | 1 | 92 (0.92) | 180.0 | 20.0 | None | 5.51 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| perron 1 / track 11 | 11 | 92 (0.92) | 115.0 | 7.4 | None | 4.37 | 5.48 | 1.11 | 0.94 |  |
| perron 1 / track 12 | 12 | 92 (0.92) | 115.0 | 7.3 | None | 4.37 | 5.47 | 1.10 | 0.92 |  |

## Structures

`kobenhavn_syd_structures_heights.geojson`, 11 features: 1 building, 6 canopy_osm, 1 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w572933169 | roof | 16.87 | 16.89 | 4.95 | 11.40 | 7 |
| canopy_osm | w572933170 | roof | 16.94 | 17.04 | 4.29 | 11.47 | 22 |
| canopy_osm | w572933171 | roof | 15.68 | 17.25 | 5.03 | 10.21 | 142 |
| canopy_osm | w572933175 | roof | 15.73 | 17.51 | 4.90 | 10.27 | 16 |
| building | w572933177 | building | – | – | 4.89 | – | 0 |
| bridge | w572934355 | bridge | 14.25 | 16.89 | -0.42 | 8.79 | 888 |
| canopy_osm | w644299880 | roof | 8.59 | 8.64 | 6.03 | 3.12 | 28 |
| canopy_osm | w1165945577 | building | 8.44 | 8.49 | 5.88 | 2.97 | 233 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 7.99 | 8.67 | 4.35 | 2.52 | 194 |
| train_in_scan | (laser) | train standing during the scan (48.9 m × 2.9 m) | 15.65 | – | – | 4.05 | 716 |
| train_in_scan | (laser) | train standing during the scan (89.5 m × 3.0 m) | 8.43 | – | – | 3.47 | 2702 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 4 track 2: the outline FOR_PERRONER_OD Nel172 runs 90 m along the track, Bilag says 332 m; line drawn to the outline
- Perron 4 track 1: the outline FOR_PERRONER_OD Nel172 runs 80 m along the track, Bilag says 332 m; line drawn to the outline
- Perron 2 (TIB 85) and perron 4 (TIB 6) were matched to the same outline FOR_PERRONER_OD Nel172: track numbers repeat between lines here; check which outline is which
- Perron 2 track 2: the outline FOR_PERRONER_OD Nel172 runs 90 m along the track, Bilag says 180 m; line drawn to the outline
- Perron 3 (TIB 85) and perron 2 (TIB 85) were matched to the same outline FOR_PERRONER_OD Nel172: track numbers repeat between lines here; check which outline is which
- Perron 3 track 1: the outline FOR_PERRONER_OD Nel172 runs 80 m along the track, Bilag says 180 m; line drawn to the outline
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w572934355 (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (82 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-10: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6172_720, PUNKTSKY_1km_6172_721, PUNKTSKY_1km_6173_720, PUNKTSKY_1km_6173_721). https://dataforsyningen.dk/data/3931 (scan 2025-03-10; 1,910,398 points in the box, 13.52 per m²; classes {'2': 964060, '3': 91112, '4': 51635, '5': 265085, '6': 464556, '7': 32868, '14': 1186, '17': 30335, '18': 9561}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.50715,55.64963,12.52204,55.65724, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
