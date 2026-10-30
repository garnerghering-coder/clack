# Öxnered (`740000173`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **62.46** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **61.72** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 58.79 – 68.75 (median 61.64) | terrain model 647_34 (2023-02-08) |

Every height in the structures file becomes metres above the platform by subtracting 62.46.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20b016, scanned 2020-03-21. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2472 | 3 | mellan (0.58) | 44.0 | 4.0 | Saknas | 61.72 | 62.46 | 0.74 | 0.57 |  |
| 2471 | 4 | mellan (0.58) | 54.0 | 4.0 | Saknas | 61.72 | 62.46 | 0.74 | 0.57 |  |
| 920 | 2 | mellan (0.58) | 172.0 | 2.4 | Tak | 61.69 | 62.46 | 0.77 | 0.59 |  |
| 918 | 1 | mellan (0.58) | 172.0 | 5.6 | Skydd | 61.69 | 62.44 | 0.75 | 0.57 |  |
| 2029 | 3 | mellan (0.58) | 129.0 | 3.0 | Skydd | 61.73 | 62.49 | 0.76 | 0.58 |  |
| 924 | 4 | mellan (0.58) | 129.0 | 3.0 | Skydd | 61.73 | 62.48 | 0.75 | 0.57 |  |

## Structures

`oxnered_structures_heights.geojson`, 6 features: 3 building, 2 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w45583779 | Öxnered (station building) | 66.29 | 67.78 | 62.36 | 3.83 | 192 |
| building | w328918898 | station building | 70.29 | 72.01 | 61.30 | 7.83 | 419 |
| canopy_osm | w689133765 | roof | 66.04 | 66.11 | 62.14 | 3.58 | 95 |
| canopy_osm | w689133767 | roof | 65.63 | 65.69 | 61.96 | 3.17 | 101 |
| building | w1504345135 | building | 66.19 | 67.60 | 61.41 | 3.73 | 145 |
| train_in_scan | (laser) | train standing during the scan (78.9 m × 3.4 m) | 65.55 | – | – | 3.79 | 648 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- none

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 50 files found (37 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-03-21: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20b016-64700_3400_25.copc.laz
  (scan 2020-03-21, nominal 1.2 points/m², flight height 3200 m; 469,394 points in the box,
  2.36 per m²; classes {'1': 220913, '2': 245120, '9': 3357, '18': 4}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 647_34 (2023-02-08), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.269114,58.356061,12.280918,58.362308, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
