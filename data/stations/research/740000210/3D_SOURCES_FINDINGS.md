# Gävle C (`740000210`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **5.75** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **4.96** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.23 – 11.83 (median 4.13) | terrain model 672_61 (2023-05-07) |

Every height in the structures file becomes metres above the platform by subtracting 5.75.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 21c051, scanned 2021-04-11. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1585 | 5 | mellan (0.58) | 85.0 | 9.0 | Saknas | 4.73 | 5.38 | 0.65 | 0.47 |  |
| 1978 | 3 | mellan (0.58) | 411.0 | 6.7 | Tak | 4.96 | 5.89 | 0.93 | 0.75 |  |
| 1980 | 4 | mellan (0.58) | 384.0 | 6.0 | Saknas | 5.03 | 5.75 | 0.72 | 0.54 |  |
| 1800 | ? | låg (0.35) | 123.0 | 6.0 | Tak | 4.81 | 5.49 | 0.68 | 0.50 |  |
| 1977 | 1s | mellan (0.58) | 300.0 | – | Saknas | 5.19 | 5.83 | 0.64 | 0.46 |  |

## Structures

`gavle_c_structures_heights.geojson`, 59 features: 4 building, 50 canopy_osm, 1 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w32615693 | Södra Station MAXIM (station building) | 16.68 | 18.36 | 5.50 | 10.93 | 643 |
| canopy_osm | w96964467 | roof | 7.87 | 15.77 | 3.58 | 2.12 | 163 |
| building | w141054585 | Gävle brandstation (building) | 9.26 | 13.05 | 3.91 | 3.51 | 4839 |
| canopy_osm | w141054594 | roof | – | – | 3.58 | – | 0 |
| building | w219151077 | retail | 9.59 | 12.35 | 2.29 | 3.84 | 105 |
| bridge | w499890259 | Islandsbron (bridge) | 9.99 | 13.99 | 0.24 | 4.24 | 33 |
| bridge | w499890262 | Murénbron (bridge) | – | – | 1.53 | – | 1 |
| canopy_osm | w720417460 | roof | 10.28 | 20.78 | 4.64 | 4.53 | 35 |
| canopy_osm | w1346766967 | roof | 12.48 | 12.58 | 3.42 | 6.73 | 12 |
| canopy_osm | w1346766973 | roof | 6.81 | 7.46 | 3.65 | 1.06 | 35 |
| canopy_osm | w1346766983 | roof | 6.89 | 8.06 | 4.06 | 1.14 | 75 |
| canopy_osm | w1347410249 | roof | – | – | 4.14 | – | 4 |
| canopy_osm | w1347410250 | roof | 9.00 | 9.05 | 3.86 | 3.25 | 128 |
| canopy_osm | w1347410259 | roof | 7.31 | 7.56 | 2.96 | 1.56 | 160 |
| canopy_osm | w1347410267 | roof | 8.00 | 8.10 | 3.38 | 2.25 | 86 |
| canopy_osm | w1387848716 | roof | 15.15 | 15.20 | 4.79 | 9.40 | 13 |
| canopy_osm | w1387859851 | roof | – | – | 2.85 | – | 3 |
| canopy_osm | w1387859854 | roof | 6.52 | 18.53 | 2.71 | 0.77 | 24 |
| canopy_osm | w1387859857 | roof | 7.40 | 11.73 | 3.77 | 1.65 | 14 |
| canopy_osm | w1388314299 | roof | 6.18 | 10.33 | 3.33 | 0.43 | 15 |
| canopy_osm | w1388314323 | roof | 11.00 | 19.52 | 5.42 | 5.25 | 27 |
| canopy_osm | w1388314333 | roof | 8.66 | 19.11 | 4.66 | 2.91 | 12 |
| building | w1388314339 | building | 8.44 | 8.73 | 2.22 | 2.69 | 47 |
| canopy_osm | w1388314346 | roof | 8.88 | 9.30 | 4.87 | 3.13 | 9 |
| canopy_osm | w1388314348 | roof | 20.90 | 23.90 | 4.43 | 15.15 | 18 |
| canopy_osm | w1388314349 | roof | 23.66 | 23.73 | 4.29 | 17.91 | 6 |
| canopy_osm | w1388314364 | roof | 7.77 | 7.93 | 5.02 | 2.02 | 7 |
| canopy_osm | w1388863115 | roof | 9.84 | 10.16 | 5.55 | 4.09 | 19 |
| canopy_osm | w1388863126 | roof | 10.52 | 14.49 | 6.37 | 4.77 | 44 |
| canopy_osm | w1388863127 | roof | 15.30 | 20.04 | 7.88 | 9.55 | 18 |
| canopy_osm | w1388863134 | roof | 10.32 | 15.53 | 4.89 | 4.57 | 39 |
| canopy_osm | w1388863137 | roof | 8.57 | 8.70 | 6.22 | 2.82 | 30 |
| canopy_osm | w1388863138 | roof | 17.52 | 18.50 | 5.93 | 11.77 | 32 |
| canopy_osm | w1388863142 | roof | 11.00 | 11.61 | 7.09 | 5.25 | 33 |
| canopy_osm | w1388863153 | roof | 7.71 | 11.71 | 4.65 | 1.96 | 16 |
| canopy_osm | w1388863154 | roof | – | – | 6.65 | – | 3 |
| canopy_osm | w1388863158 | roof | 7.66 | 10.09 | 3.14 | 1.91 | 477 |
| canopy_osm | w1388869071 | roof | 10.81 | 11.92 | 5.49 | 5.06 | 426 |
| canopy_osm | w1388869100 | roof | 10.06 | 17.80 | 5.23 | 4.31 | 153 |
| canopy_osm | w1388869122 | roof | 11.87 | 11.91 | 5.52 | 6.12 | 9 |
| canopy_osm | w1389176425 | roof | 11.29 | 11.72 | 8.32 | 5.54 | 17 |
| canopy_osm | w1389176447 | roof | 11.50 | 14.48 | 8.57 | 5.75 | 14 |
| canopy_osm | w1389176474 | roof | 8.25 | 9.20 | 5.76 | 2.50 | 10 |
| canopy_osm | w1389176492 | roof | – | – | 5.68 | – | 2 |
| canopy_osm | w1389176521 | roof | 14.76 | 23.89 | 5.21 | 9.01 | 13 |
| canopy_osm | w1389176522 | roof | 15.66 | 22.40 | 5.09 | 9.91 | 33 |
| canopy_osm | w1389176523 | roof | 8.24 | 21.54 | 5.19 | 2.49 | 69 |
| canopy_osm | w1389176524 | roof | 13.61 | 24.90 | 8.63 | 7.86 | 186 |
| canopy_osm | w1389444720 | roof | 6.59 | 11.44 | 2.84 | 0.84 | 53 |
| canopy_osm | w1389444726 | roof | 7.08 | 7.43 | 3.29 | 1.33 | 42 |
| canopy_osm | w1389444727 | roof | 8.71 | 9.49 | 2.64 | 2.96 | 189 |
| canopy_osm | w1389444728 | roof | 9.16 | 9.29 | 3.04 | 3.41 | 5 |
| canopy_osm | w1389444731 | roof | 10.32 | 20.87 | 2.90 | 4.57 | 155 |
| canopy_osm | w1389444733 | roof | 9.07 | 11.50 | 3.72 | 3.32 | 40 |
| canopy_osm | w1389444744 | roof | 8.23 | 13.19 | 4.80 | 2.48 | 36 |
| canopy_osm | w1389444752 | roof | 7.05 | 7.11 | 4.41 | 1.30 | 33 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 9.84 | 10.23 | 4.70 | 4.09 | 1040 |
| train_in_scan | (laser) | train standing during the scan (19.4 m × 2.8 m) | 10.07 | – | – | 4.19 | 87 |
| train_in_scan | (laser) | train standing during the scan (51.5 m × 3.4 m) | 8.75 | – | – | 3.65 | 260 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 1978 (track 3): laser gives 0.93 m above the track bed (≈0.75 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- Platform BIS 1800 (track None): laser gives 0.68 m above the track bed (≈0.50 m above rail after −0.15…0.2 m), register class låg = 0.35 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 0.51 m across the station (5.38–5.89 m); the station reference above is their median — check which level the app should use.
- w96964467 roof: p95 15.8 m is 7.9 m above the median 7.9 m (a taller neighbour or a mast inside the outline?).
- w141054585 Gävle brandstation (building): p95 13.1 m is 3.8 m above the median 9.3 m (a taller neighbour or a mast inside the outline?).
- w720417460 roof: p95 20.8 m is 10.5 m above the median 10.3 m (a taller neighbour or a mast inside the outline?).
- w1387859854 roof: p95 18.5 m is 12.0 m above the median 6.5 m (a taller neighbour or a mast inside the outline?).
- w1387859857 roof: p95 11.7 m is 4.3 m above the median 7.4 m (a taller neighbour or a mast inside the outline?).
- w1388314299 roof: p95 10.3 m is 4.2 m above the median 6.2 m (a taller neighbour or a mast inside the outline?).
- w1388314323 roof: p95 19.5 m is 8.5 m above the median 11.0 m (a taller neighbour or a mast inside the outline?).
- w1388314333 roof: p95 19.1 m is 10.4 m above the median 8.7 m (a taller neighbour or a mast inside the outline?).
- w1388314348 roof: p95 23.9 m is 3.0 m above the median 20.9 m (a taller neighbour or a mast inside the outline?).
- w1388863126 roof: p95 14.5 m is 4.0 m above the median 10.5 m (a taller neighbour or a mast inside the outline?).
- w1388863127 roof: p95 20.0 m is 4.7 m above the median 15.3 m (a taller neighbour or a mast inside the outline?).
- w1388863134 roof: p95 15.5 m is 5.2 m above the median 10.3 m (a taller neighbour or a mast inside the outline?).
- w1388863153 roof: p95 11.7 m is 4.0 m above the median 7.7 m (a taller neighbour or a mast inside the outline?).
- w1388869100 roof: p95 17.8 m is 7.7 m above the median 10.1 m (a taller neighbour or a mast inside the outline?).
- w1389176521 roof: p95 23.9 m is 9.1 m above the median 14.8 m (a taller neighbour or a mast inside the outline?).
- w1389176522 roof: p95 22.4 m is 6.7 m above the median 15.7 m (a taller neighbour or a mast inside the outline?).
- w1389176523 roof: p95 21.5 m is 13.3 m above the median 8.2 m (a taller neighbour or a mast inside the outline?).
- w1389176524 roof: p95 24.9 m is 11.3 m above the median 13.6 m (a taller neighbour or a mast inside the outline?).
- w1389444720 roof: p95 11.4 m is 4.9 m above the median 6.6 m (a taller neighbour or a mast inside the outline?).
- w1389444731 roof: p95 20.9 m is 10.5 m above the median 10.3 m (a taller neighbour or a mast inside the outline?).
- w1389444744 roof: p95 13.2 m is 5.0 m above the median 8.2 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w499890259 Islandsbron (cycleway, secondary); w499890262 Murénbron (cycleway, footway, tertiary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 138 files found (73 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-04-11: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y21c051-67275_6150_25.copc.laz, y21c051-67275_6175_25.copc.laz
  (scan 2021-04-11, nominal 1.2 points/m², flight height 3000 m; 676,846 points in the box,
  1.9 per m²; classes {'1': 252436, '2': 416594, '7': 364, '9': 1525, '17': 5926, '18': 1}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 672_61 (2023-05-07), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
