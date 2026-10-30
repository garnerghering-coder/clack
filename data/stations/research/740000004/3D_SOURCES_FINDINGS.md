# Alvesta (`740000004`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **145.31** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **144.59** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 142.09 – 153.42 (median 144.70) | terrain model 630_47 (2024-03-08) |

Every height in the structures file becomes metres above the platform by subtracting 145.31.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 26a022, scanned 2026-03-08. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 703 | 4b | mellan (0.58) | 610.1 | – | Tak | 144.75 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 700 | 1a,1b | låg (0.35) | 139.0 | – | Saknas | 144.59 | 145.23 | 0.64 | 0.46 |  |
| 698 | 2 | mellan (0.58) | 414.0 | – | Tak | 144.58 | 145.40 | 0.82 | 0.64 |  |

## Structures

`alvesta_structures_heights.geojson`, 13 features: 3 building, 1 footbridge, 2 canopy_osm, 1 canopy_laser, 6 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w39352040 | Alvesta järnvägsstation (station building) | 157.25 | 160.55 | 144.82 | 11.94 | 1191 |
| building | w309948281 | Alvesta Brevterminal (building) | 153.19 | 155.58 | 144.48 | 7.88 | 24930 |
| building | w940158739 | building | 150.57 | 153.00 | 144.96 | 5.26 | 337 |
| canopy_osm | w1481453634 | roof | 150.26 | 150.54 | 144.52 | 4.95 | 739 |
| canopy_osm | w1497350294 | roof | 163.95 | 164.37 | 145.19 | 18.64 | 41 |
| footbridge | w1565102356 | bridge | 155.91 | 156.97 | 144.56 | 10.60 | 956 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 149.71 | 149.89 | 144.53 | 4.40 | 275 |
| train_in_scan | (laser) | train standing during the scan (22.3 m × 2.4 m) | 148.50 | – | – | 3.80 | 109 |
| train_in_scan | (laser) | train standing during the scan (56.4 m × 2.7 m) | 148.78 | – | – | 4.21 | 520 |
| train_in_scan | (laser) | train standing during the scan (31.1 m × 3.3 m) | 148.72 | – | – | 4.09 | 313 |
| train_in_scan | (laser) | train standing during the scan (150.3 m × 2.7 m) | 148.19 | – | – | 3.38 | 645 |
| train_in_scan | (laser) | train standing during the scan (46.7 m × 2.7 m) | 148.13 | – | – | 3.41 | 199 |
| train_in_scan | (laser) | train standing during the scan (229.7 m × 2.8 m) | 148.39 | – | – | 3.65 | 950 |

## Trains in the scan

6 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w39352040 Alvesta järnvägsstation (station building): p95 160.5 m is 3.3 m above the median 157.2 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 83 files found (62 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2026-03-08: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y26a022-63050_4725_25.copc.laz
  (scan 2026-03-08, nominal 1.8 points/m², flight height 2000 m; 669,086 points in the box,
  2.51 per m²; classes {'1': 221330, '2': 348302, '7': 279, '9': 99175}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 630_47 (2024-03-08), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
