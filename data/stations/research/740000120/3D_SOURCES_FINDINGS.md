# Lund C (`740000120`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **41.47** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **40.63** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 35.26 – 46.66 (median 41.64) | terrain model 617_38 (2025-09-29) |

Every height in the structures file becomes metres above the platform by subtracting 41.47.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 25a003, scanned 2025-03-08. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1031 | 6 | mellan (0.58) | 374.0 | – | Tak | 40.62 | 41.42 | 0.80 | 0.63 |  |
| 1022 | 3 | mellan (0.58) | 390.0 | 10.0 | Tak | 40.64 | 41.51 | 0.87 | 0.69 |  |
| 2097 | 4 | mellan (0.58) | 380.0 | 10.0 | Tak | 40.61 | 41.51 | 0.90 | 0.72 |  |
| 1060 | 1 | mellan (0.58) | 357.0 | – | Saknas | 40.67 | 41.38 | 0.71 | 0.54 |  |

## Structures

`lund_c_structures_heights.geojson`, 59 features: 22 building, 1 footbridge, 32 canopy_osm, 4 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w39440938 | Tullkammaren (warehouse) | 50.13 | 52.46 | 41.15 | 8.66 | 445 |
| building | w70887898 | station building | 46.97 | 54.88 | 40.42 | 5.50 | 2422 |
| canopy_osm | w70887899 | roof | 45.95 | 50.94 | 41.06 | 4.48 | 1224 |
| building | w97559711 | retail | 44.06 | 45.02 | 40.67 | 2.59 | 135 |
| building | w97574148 | Västra station (station building) | 48.87 | 50.25 | 41.28 | 7.40 | 1723 |
| building | w108118781 | building | 55.70 | 58.00 | 40.55 | 14.23 | 2757 |
| building | w108118788 | building | 58.44 | 59.76 | 40.76 | 16.97 | 2433 |
| canopy_osm | w334180475 | roof | 45.39 | 45.86 | 40.45 | 3.92 | 1090 |
| building | w334180476 | building | 50.06 | 51.52 | 40.67 | 8.59 | 73 |
| canopy_osm | w334180477 | roof | 45.98 | 46.36 | 40.42 | 4.51 | 1633 |
| building | w334180478 | building | 51.01 | 51.72 | 40.86 | 9.54 | 64 |
| building | w334180479 | bridge | 51.83 | 52.01 | 40.68 | 10.36 | 797 |
| building | w334180480 | building | 49.49 | 51.60 | 40.80 | 8.02 | 79 |
| building | w334180481 | building | 50.53 | 51.64 | 40.73 | 9.06 | 68 |
| canopy_osm | w334180482 | roof | 46.08 | 46.47 | 40.59 | 4.61 | 680 |
| canopy_osm | w334180483 | roof | 44.29 | 44.50 | 40.44 | 2.82 | 61 |
| canopy_osm | w334180484 | roof | 46.09 | 46.52 | 40.60 | 4.62 | 734 |
| canopy_osm | w334180485 | roof | 45.64 | 46.01 | 40.58 | 4.17 | 443 |
| canopy_osm | w334180486 | roof | 44.17 | 44.38 | 40.40 | 2.70 | 46 |
| canopy_osm | w334180487 | roof | 44.21 | 44.42 | 40.43 | 2.74 | 53 |
| canopy_osm | w334180489 | roof | 45.95 | 49.50 | 41.37 | 4.48 | 28 |
| building | w334180490 | building | 45.02 | 46.02 | 41.24 | 3.55 | 19 |
| building | w334180491 | elevator | 51.72 | 51.76 | 40.94 | 10.25 | 17 |
| building | w334180495 | elevator | 51.70 | 51.75 | 40.99 | 10.23 | 20 |
| canopy_osm | w334180496 | roof | 45.16 | 49.70 | 41.50 | 3.70 | 24 |
| building | w334180497 | elevator | 51.71 | 51.75 | 41.10 | 10.24 | 15 |
| canopy_osm | w334180498 | roof | 45.59 | 50.33 | 41.49 | 4.12 | 14 |
| footbridge | w334180499 | bridge | 50.28 | 51.03 | 40.58 | 8.81 | 743 |
| canopy_osm | w334180500 | roof | 45.98 | 46.35 | 40.47 | 4.51 | 1786 |
| canopy_osm | w334190491 | roof | 48.61 | 50.44 | 41.32 | 7.14 | 92 |
| canopy_osm | w334190492 | roof | 51.37 | 51.48 | 40.81 | 9.90 | 11 |
| building | w334190493 | building | 46.10 | 46.86 | 41.35 | 4.63 | 8 |
| canopy_osm | w334190494 | roof | 51.38 | 51.46 | 41.39 | 9.91 | 13 |
| canopy_osm | w334190495 | roof | 48.76 | 50.40 | 41.42 | 7.29 | 82 |
| canopy_osm | w334190496 | roof | 51.37 | 51.48 | 41.38 | 9.90 | 14 |
| canopy_osm | w334190497 | roof | 48.56 | 50.41 | 41.37 | 7.09 | 79 |
| building | w334190498 | station building | 45.70 | 46.48 | 41.41 | 4.23 | 8 |
| building | w334190499 | station building | 46.01 | 47.48 | 41.43 | 4.54 | 13 |
| canopy_osm | w334190500 | roof | 44.60 | 44.66 | 41.17 | 3.13 | 49 |
| canopy_osm | w334190501 | roof | 50.33 | 51.36 | 40.91 | 8.86 | 54 |
| canopy_osm | w334190502 | roof | 44.72 | 44.84 | 41.38 | 3.25 | 39 |
| canopy_osm | w334190503 | roof | 50.33 | 50.42 | 41.34 | 8.86 | 42 |
| canopy_osm | w334190504 | roof | 44.73 | 46.31 | 41.19 | 3.26 | 40 |
| canopy_osm | w334190505 | roof | 50.31 | 51.02 | 41.34 | 8.84 | 48 |
| canopy_osm | w334199093 | roof | 44.38 | 44.42 | 40.46 | 2.91 | 9 |
| building | w342030683 | retail | 55.66 | 57.98 | 40.55 | 14.19 | 4343 |
| building | w342030684 | retail | 50.60 | 59.46 | 40.70 | 9.13 | 5307 |
| building | w540759429 | commercial | 47.52 | 50.54 | 41.40 | 6.05 | 858 |
| building | w540759431 | Godsmagasinet (station building) | 48.26 | 49.89 | 40.97 | 6.79 | 1951 |
| canopy_osm | w540759433 | roof | 45.50 | 46.10 | 40.97 | 4.03 | 163 |
| canopy_osm | w540759437 | roof | 46.16 | 47.16 | 40.90 | 4.69 | 246 |
| canopy_osm | w1122920513 | building | 46.55 | 46.59 | 43.29 | 5.08 | 61 |
| canopy_osm | w1339991785 | roof | 45.80 | 45.99 | 41.94 | 4.33 | 16 |
| canopy_osm | w1347948521 | roof | 45.71 | 46.22 | 41.06 | 4.24 | 19 |
| canopy_osm | w1557733803 | building | 42.98 | 43.11 | 40.37 | 1.51 | 12 |
| train_in_scan | (laser) | train standing during the scan (70.5 m × 2.9 m) | 44.21 | – | – | 3.48 | 413 |
| train_in_scan | (laser) | train standing during the scan (27.8 m × 2.6 m) | 44.58 | – | – | 3.73 | 139 |
| train_in_scan | (laser) | train standing during the scan (121.3 m × 2.7 m) | 44.47 | – | – | 3.67 | 669 |
| train_in_scan | (laser) | train standing during the scan (71.3 m × 3.1 m) | 44.23 | – | – | 3.49 | 421 |

## Trains in the scan

4 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 2097 (track 4): laser gives 0.90 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- w70887898 station building: p95 54.9 m is 7.9 m above the median 47.0 m (a taller neighbour or a mast inside the outline?).
- w70887899 roof: p95 50.9 m is 5.0 m above the median 46.0 m (a taller neighbour or a mast inside the outline?).
- w334180489 roof: p95 49.5 m is 3.6 m above the median 45.9 m (a taller neighbour or a mast inside the outline?).
- w334180496 roof: p95 49.7 m is 4.5 m above the median 45.2 m (a taller neighbour or a mast inside the outline?).
- w334180498 roof: p95 50.3 m is 4.7 m above the median 45.6 m (a taller neighbour or a mast inside the outline?).
- w540759429 commercial: p95 50.5 m is 3.0 m above the median 47.5 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 134 files found (63 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-08: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y25a003-61725_3850_25.copc.laz, y25a005-61750_3850_25.copc.laz
  (scan 2025-03-08, nominal 1.8 points/m², flight height 2400 m; 429,179 points in the box,
  2.2 per m²; classes {'1': 197221, '2': 230196, '7': 310, '17': 1143, '18': 309}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 617_38 (2025-09-29), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=13.181589,55.703299,13.191220,55.711138, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
