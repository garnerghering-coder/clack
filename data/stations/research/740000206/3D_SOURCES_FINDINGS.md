# Kil (`740000206`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **98.99** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **98.53** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 95.47 – 103.34 (median 98.46) | terrain model 659_40 (2022-08-02) |

Every height in the structures file becomes metres above the platform by subtracting 98.99.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 19b030, scanned 2019-10-29. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 456 | 4 | mellan (0.58) | 218.0 | 6.5 | Skydd | 99.21 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 457 | 6 | låg (0.35) | 121.0 | 6.0 | Skydd | 98.50 | 98.99 | 0.49 | 0.32 |  |
| 454 | 2 | mellan (0.58) | 197.0 | 5.0 | Skydd | 98.57 | 99.28 | 0.71 | 0.53 |  |
| 455 | ? | låg (0.35) | 108.0 | 6.0 | Tak | 98.46 | 98.98 | 0.52 | 0.34 |  |

## Structures

`kil_structures_heights.geojson`, 18 features: 5 building, 1 canopy_osm, 1 canopy_laser, 11 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w100310623 | Kils järnvägsstation (station building) | 108.33 | 110.04 | 98.39 | 9.34 | 295 |
| building | w296354973 | building | 103.73 | 103.82 | 98.34 | 4.74 | 107 |
| building | w296469998 | building | 103.95 | 105.54 | 98.54 | 4.96 | 528 |
| building | w985188746 | building | 103.83 | 104.06 | 98.42 | 4.84 | 224 |
| building | w1190455488 | residential | 103.27 | 106.93 | 98.59 | 4.28 | 165 |
| canopy_osm | w1356244031 | roof | 100.79 | 101.83 | 96.71 | 1.80 | 278 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 103.93 | 104.17 | 98.45 | 4.94 | 1573 |
| train_in_scan | (laser) | train standing during the scan (56.4 m × 3.5 m) | 102.43 | – | – | 3.59 | 306 |
| train_in_scan | (laser) | train standing during the scan (51.6 m × 3.5 m) | 102.42 | – | – | 3.62 | 311 |
| train_in_scan | (laser) | train standing during the scan (314.2 m × 2.5 m) | 102.71 | – | – | 4.20 | 1994 |
| train_in_scan | (laser) | train standing during the scan (15.2 m × 3.0 m) | 102.31 | – | – | 3.96 | 81 |
| train_in_scan | (laser) | train standing during the scan (38.6 m × 3.3 m) | 102.34 | – | – | 3.88 | 222 |
| train_in_scan | (laser) | train standing during the scan (49.0 m × 3.3 m) | 102.30 | – | – | 3.82 | 259 |
| train_in_scan | (laser) | train standing during the scan (22.3 m × 1.3 m) | 102.76 | – | – | 4.15 | 45 |
| train_in_scan | (laser) | train standing during the scan (203.0 m × 2.5 m) | 102.68 | – | – | 4.19 | 1474 |
| train_in_scan | (laser) | train standing during the scan (330.0 m × 2.6 m) | 102.61 | – | – | 4.12 | 2060 |
| train_in_scan | (laser) | train standing during the scan (29.7 m × 2.6 m) | 102.57 | – | – | 4.04 | 135 |
| train_in_scan | (laser) | train standing during the scan (27.1 m × 2.2 m) | 102.12 | – | – | 3.60 | 160 |

## Trains in the scan

11 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w1190455488 residential: p95 106.9 m is 3.7 m above the median 103.3 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 53 files found (25 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2019-10-29: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y19b030-65950_4025_25.copc.laz, y19b030-65950_4050_25.copc.laz, y19b030-65975_4025_25.copc.laz, y19b030-65975_4050_25.copc.laz
  (scan 2019-10-29, nominal 1.2 points/m², flight height 3000 m; 548,528 points in the box,
  2.73 per m²; classes {'1': 167433, '2': 381028, '7': 67}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 659_40 (2022-08-02), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=13.308627,59.502293,13.324135,59.507422, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
