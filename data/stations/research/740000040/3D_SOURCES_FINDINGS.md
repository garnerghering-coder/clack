# Herrljunga C (`740000040`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **108.40** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **107.61** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 99.76 – 111.36 (median 104.90) | terrain model 643_38 (2024-03-30) |

Every height in the structures file becomes metres above the platform by subtracting 108.40.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 22b011, scanned 2022-03-04. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2478 | 7 | mellan (0.58) | 177.0 | 6.8 | Tak | 107.61 | 108.33 | 0.72 | 0.54 |  |
| 2477 | 6 | mellan (0.58) | 250.0 | 6.8 | Tak | 107.61 | 108.33 | 0.72 | 0.54 |  |
| 1756 | 4 | hög (0.73) | 353.0 | 5.1 | Tak | 107.67 | 108.54 | 0.87 | 0.70 |  |
| 1458 | 1 | mellan (0.58) | 270.0 | 4.9 | Tak | 107.60 | 108.47 | 0.87 | 0.69 |  |

## Structures

`herrljunga_c_structures_heights.geojson`, 17 features: 2 building, 13 canopy_osm, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w307774929 | Herrljunga (station building) | 114.28 | 117.41 | 107.78 | 5.88 | 1255 |
| canopy_osm | w419517885 | roof | 109.37 | 109.70 | 103.86 | 0.97 | 97 |
| canopy_osm | w1105572432 | roof | 110.05 | 110.14 | 107.78 | 1.65 | 7 |
| canopy_osm | w1105572433 | roof | 109.90 | 109.97 | 107.61 | 1.50 | 20 |
| canopy_osm | w1105572447 | roof | 112.80 | 112.97 | 107.53 | 4.40 | 220 |
| canopy_osm | w1105572448 | roof | 111.00 | 111.08 | 108.36 | 2.60 | 20 |
| canopy_osm | w1105572449 | roof | 110.89 | 110.93 | 108.29 | 2.49 | 19 |
| building | w1105572450 | building | 111.60 | 111.83 | 108.07 | 3.20 | 66 |
| canopy_osm | w1105572451 | roof | 110.79 | 110.94 | 108.28 | 2.39 | 9 |
| canopy_osm | w1105572452 | roof | 110.78 | 110.85 | 108.28 | 2.38 | 8 |
| canopy_osm | w1105572453 | roof | 110.96 | 111.05 | 108.34 | 2.56 | 16 |
| canopy_osm | w1105572454 | roof | 111.58 | 111.76 | 107.93 | 3.17 | 66 |
| canopy_osm | w1105572455 | roof | 111.54 | 112.90 | 103.28 | 3.14 | 139 |
| canopy_osm | w1105572456 | roof | 112.53 | 112.75 | 103.24 | 4.13 | 78 |
| canopy_osm | w1105572457 | roof | 112.55 | 112.74 | 103.42 | 4.15 | 76 |
| train_in_scan | (laser) | train standing during the scan (48.0 m × 3.2 m) | 111.46 | – | – | 3.36 | 188 |
| train_in_scan | (laser) | train standing during the scan (59.5 m × 3.8 m) | 111.50 | – | – | 3.64 | 260 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w307774929 Herrljunga (station building): p95 117.4 m is 3.1 m above the median 114.3 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 52 files found (36 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2022-03-04: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y22b011-64375_3825_25.copc.laz
  (scan 2022-03-04, nominal 1.1 points/m², flight height 3200 m; 411,389 points in the box,
  1.57 per m²; classes {'1': 148946, '2': 261179, '7': 248, '17': 1009, '18': 7}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 643_38 (2024-03-30), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=13.011696,58.075890,13.026916,58.081861, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
