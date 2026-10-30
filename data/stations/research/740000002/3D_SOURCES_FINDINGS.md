# Göteborg C (`740000002`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **2.91** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **2.21** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -3.64 – 8.24 (median 2.18) | terrain model 640_32 (2023-02-10), 640_31 (2023-02-09) |

Every height in the structures file becomes metres above the platform by subtracting 2.91.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20b008, scanned 2020-03-21. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2622 | 22 | mellan (0.58) | 250.0 | 14.2 | Saknas | 2.36 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2623 | 23 | mellan (0.58) | 250.0 | 14.2 | Saknas | 2.35 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1621 | 15 | mellan (0.58) | 235.0 | – | Tak | 2.13 | 2.86 | 0.73 | 0.55 |  |
| 1622 | 7 | mellan (0.58) | 421.0 | – | Tak | 2.23 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2485 | 14 | mellan (0.58) | 22.0 | – | Saknas | – | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1616 | 4 | mellan (0.58) | 375.0 | – | Tak | 2.28 | 3.00 | 0.72 | 0.54 |  |
| 1627 | 13 | mellan (0.58) | 161.0 | – | Tak | 2.13 | 2.89 | 0.76 | 0.59 |  |
| 1961 | 8 | låg (0.35) | 288.0 | – | Saknas | 2.20 | 2.75 | 0.55 | 0.37 |  |
| 1626 | 12 | mellan (0.58) | 169.0 | – | Tak | 2.14 | 2.99 | 0.85 | 0.68 |  |
| 1623 | 9 | mellan (0.58) | 233.0 | – | Tak | 2.18 | 2.91 | 0.73 | 0.55 |  |
| 1962 | 10 | låg (0.35) | 169.0 | – | Tak | 2.19 | 2.75 | 0.56 | 0.39 |  |
| 2593 | 11 | mellan (0.58) | 172.0 | 7.1 | Tak | 2.13 | 2.98 | 0.85 | 0.68 |  |
| 1618 | 5 | mellan (0.58) | 309.0 | – | Tak | 2.22 | 2.92 | 0.70 | 0.52 |  |
| 1614 | 1 | mellan (0.58) | 279.0 | – | Tak | 2.36 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2018 | 1 | mellan (0.58) | 113.0 | – | Saknas | 2.32 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`goteborg_c_structures_heights.geojson`, 57 features: 17 building, 20 canopy_osm, 1 canopy_laser, 17 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w13704175 | station building | 10.76 | 15.42 | 2.41 | 7.85 | 5124 |
| building | w13704178 | Centralhuset (station building) | 23.98 | 27.35 | 2.01 | 21.07 | 10930 |
| building | w13704190 | office | 18.23 | 20.93 | 2.22 | 15.32 | 1408 |
| bridge | w374053019 | Bananbron (bridge) | 3.65 | 5.22 | -3.59 | 0.73 | 290 |
| building | w490573738 | transportation | 9.27 | 9.43 | 2.50 | 6.36 | 211 |
| building | w490573739 | transportation | 6.08 | 6.52 | 2.65 | 3.17 | 144 |
| bridge | w725288025 | Hisingsbron (bridge) | 11.16 | 13.78 | -3.53 | 8.25 | 1350 |
| building | w1013465729 | Franks (retail) | 6.11 | 8.79 | 2.66 | 3.20 | 44 |
| canopy_osm | w1023939822 | building | – | – | 3.00 | – | 4 |
| canopy_osm | w1023942994 | building | 5.40 | 5.46 | 2.74 | 2.49 | 10 |
| canopy_osm | w1023942995 | building | 5.41 | 5.48 | 2.73 | 2.50 | 10 |
| canopy_osm | w1023942996 | building | – | – | 2.79 | – | 4 |
| canopy_osm | w1023942997 | building | 5.42 | 5.47 | 2.45 | 2.51 | 7 |
| canopy_osm | w1096834912 | roof | 7.60 | 8.04 | 2.04 | 4.69 | 904 |
| canopy_osm | w1096834913 | roof | 7.50 | 7.88 | 2.05 | 4.59 | 628 |
| canopy_osm | w1096834914 | roof | 7.41 | 7.85 | 2.03 | 4.50 | 925 |
| canopy_osm | w1096834915 | roof | 7.86 | 8.24 | 2.08 | 4.95 | 1432 |
| canopy_osm | w1096834916 | roof | 7.49 | 7.96 | 2.03 | 4.58 | 1527 |
| canopy_osm | w1096834917 | roof | 8.08 | 8.82 | 2.11 | 5.17 | 6812 |
| canopy_osm | w1096834918 | roof | 6.44 | 6.99 | 2.43 | 3.53 | 207 |
| canopy_osm | w1180021070 | roof | 5.87 | 6.16 | 2.90 | 2.96 | 13 |
| canopy_osm | w1180021071 | roof | 5.85 | 6.10 | 2.98 | 2.94 | 36 |
| canopy_osm | w1180021072 | roof | 9.86 | 12.77 | 3.03 | 6.95 | 12 |
| canopy_osm | w1180021073 | roof | – | – | 2.89 | – | 2 |
| building | w1374501612 | Park Central (construction) | 4.47 | 28.08 | 0.10 | 1.56 | 1042 |
| building | w1374501613 | Göteborg Grand Central (construction) | 8.23 | 11.07 | -0.21 | 5.32 | 292 |
| building | w1430170872 | Hyatt Place Gothenburg Central (building) | 21.80 | 27.71 | 2.41 | 18.89 | 2922 |
| building | w1561674700 | building | 9.38 | 11.11 | 0.14 | 6.47 | 3265 |
| building | w1561674713 | building | 8.63 | 9.00 | 2.67 | 5.72 | 161 |
| building | w1561674714 | building | 8.07 | 8.60 | 2.11 | 5.16 | 6588 |
| building | w1561674715 | building | 9.00 | 9.58 | 2.35 | 6.09 | 224 |
| building | w1561674716 | building | 20.60 | 27.64 | 2.21 | 17.69 | 6611 |
| building | w1561674717 | building | 25.09 | 27.34 | 2.01 | 22.18 | 4319 |
| building | w1561674718 | building | 27.32 | 27.38 | 2.78 | 24.41 | 305 |
| building | w1561674719 | building | 27.33 | 27.38 | 2.70 | 24.42 | 269 |
| canopy_osm | w1567433670 | building | – | – | 0.65 | – | 0 |
| canopy_osm | w1567433671 | building | – | – | 1.03 | – | 0 |
| canopy_osm | w1567433672 | building | – | – | 1.83 | – | 0 |
| canopy_osm | w1567433674 | building | – | – | 1.41 | – | 0 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 6.63 | 6.74 | 2.24 | 3.72 | 560 |
| train_in_scan | (laser) | train standing during the scan (71.1 m × 2.7 m) | 6.15 | – | – | 3.80 | 258 |
| train_in_scan | (laser) | train standing during the scan (77.9 m × 3.4 m) | 5.88 | – | – | 3.70 | 168 |
| train_in_scan | (laser) | train standing during the scan (73.3 m × 3.2 m) | 5.91 | – | – | 3.71 | 165 |
| train_in_scan | (laser) | train standing during the scan (78.1 m × 2.5 m) | 6.28 | – | – | 3.97 | 255 |
| train_in_scan | (laser) | train standing during the scan (77.1 m × 3.4 m) | 5.81 | – | – | 3.52 | 331 |
| train_in_scan | (laser) | train standing during the scan (132.8 m × 3.0 m) | 6.20 | – | – | 4.27 | 366 |
| train_in_scan | (laser) | train standing during the scan (161.1 m × 2.9 m) | 5.89 | – | – | 3.89 | 604 |
| train_in_scan | (laser) | train standing during the scan (75.4 m × 2.9 m) | 5.80 | – | – | 3.92 | 277 |
| train_in_scan | (laser) | train standing during the scan (144.6 m × 2.7 m) | 6.28 | – | – | 4.34 | 369 |
| train_in_scan | (laser) | train standing during the scan (77.9 m × 3.5 m) | 5.94 | – | – | 3.95 | 370 |
| train_in_scan | (laser) | train standing during the scan (136.5 m × 2.5 m) | 6.75 | – | – | 4.27 | 426 |
| train_in_scan | (laser) | train standing during the scan (98.0 m × 3.5 m) | 6.04 | – | – | 3.64 | 467 |
| train_in_scan | (laser) | train standing during the scan (156.8 m × 3.0 m) | 5.89 | – | – | 3.86 | 617 |
| train_in_scan | (laser) | train standing during the scan (78.0 m × 3.5 m) | 5.95 | – | – | 3.98 | 369 |
| train_in_scan | (laser) | train standing during the scan (161.5 m × 2.4 m) | 6.10 | – | – | 3.82 | 519 |
| train_in_scan | (laser) | train standing during the scan (77.0 m × 3.2 m) | 6.09 | – | – | 3.75 | 299 |
| train_in_scan | (laser) | train standing during the scan (153.0 m × 3.1 m) | 6.00 | – | – | 3.69 | 637 |

## Trains in the scan

17 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w13704175 station building: p95 15.4 m is 4.7 m above the median 10.8 m (a taller neighbour or a mast inside the outline?).
- w13704178 Centralhuset (station building): p95 27.4 m is 3.4 m above the median 24.0 m (a taller neighbour or a mast inside the outline?).
- w1374501612 Park Central (construction): p95 28.1 m is 23.6 m above the median 4.5 m (a taller neighbour or a mast inside the outline?).
- w1430170872 Hyatt Place Gothenburg Central (building): p95 27.7 m is 5.9 m above the median 21.8 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w374053019 Bananbron (secondary); w725288025 Hisingsbron (service).
- Laser-traced roof (480 m², top 3.7 m above the platform, 4.4 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 230 files found (201 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-03-21: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20b008-64000_3175_25.copc.laz, y20b008-64000_3200_25.copc.laz
  (scan 2020-03-21, nominal 1.2 points/m², flight height 3200 m; 613,327 points in the box,
  1.4 per m²; classes {'1': 252084, '2': 349060, '7': 1034, '17': 11023, '18': 126}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 640_32 (2023-02-10), 640_31 (2023-02-09), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
