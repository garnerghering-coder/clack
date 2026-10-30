# Falköping C (`740000060`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **217.31** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **216.46** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 211.31 – 232.10 (median 216.38) | terrain model 644_41 (2023-04-11) |

Every height in the structures file becomes metres above the platform by subtracting 217.31.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 22b012, scanned 2022-03-07. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 315 | 3 | mellan (0.58) | 392.0 | 8.4 | Tak | 216.46 | 217.31 | 0.85 | 0.67 |  |
| 317 | 2 | mellan (0.58) | 395.0 | 6.5 | Tak | 216.47 | 217.32 | 0.85 | 0.67 |  |
| 1138 | 21 | mellan (0.58) | 40.0 | 2.9 | Saknas | 216.18 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`falkoping_c_structures_heights.geojson`, 17 features: 4 building, 7 canopy_osm, 3 canopy_laser, 3 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w61186565 | Falköping (station building) | 220.59 | 223.04 | 215.90 | 3.28 | 1374 |
| canopy_osm | w61186566 | roof | 220.32 | 220.54 | 216.48 | 3.01 | 528 |
| building | w259159334 | building | 223.25 | 226.44 | 216.20 | 5.94 | 1587 |
| building | w279318370 | apartments | – | – | 214.90 | – | 0 |
| building | w281530071 | garage | – | – | 230.40 | – | 0 |
| canopy_osm | w1552406451 | building | 218.20 | 218.27 | 215.66 | 0.89 | 15 |
| canopy_osm | w1552406452 | building | 217.48 | 217.55 | 215.00 | 0.17 | 12 |
| canopy_osm | w1552406453 | building | 217.94 | 218.03 | 214.98 | 0.63 | 13 |
| canopy_osm | w1552406454 | building | – | – | 214.99 | – | 4 |
| canopy_osm | w1552406456 | building | 217.77 | 217.81 | 215.01 | 0.46 | 17 |
| canopy_osm | w1552406457 | building | – | – | 214.94 | – | 4 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 220.99 | 221.22 | 216.33 | 3.68 | 2154 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 220.99 | 221.19 | 216.35 | 3.68 | 990 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 221.00 | 221.19 | 216.42 | 3.69 | 776 |
| train_in_scan | (laser) | train standing during the scan (140.5 m × 2.8 m) | 220.57 | – | – | 4.26 | 506 |
| train_in_scan | (laser) | train standing during the scan (99.2 m × 3.5 m) | 220.47 | – | – | 4.01 | 227 |
| train_in_scan | (laser) | train standing during the scan (44.8 m × 3.5 m) | 220.47 | – | – | 3.98 | 214 |

## Trains in the scan

3 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- none

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 109 files found (40 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2022-03-07: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y22b012-64475_4125_25.copc.laz, y22b012-64475_4150_25.copc.laz
  (scan 2022-03-07, nominal 1.1 points/m², flight height 3200 m; 1,016,780 points in the box,
  3.08 per m²; classes {'1': 412386, '2': 601351, '7': 491, '17': 2526, '18': 26}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 644_41 (2023-04-11), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
