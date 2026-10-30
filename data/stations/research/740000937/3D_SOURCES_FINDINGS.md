# Burlöv (`740000937`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **7.46** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **6.86** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 1.72 – 13.32 (median 6.72) | terrain model 616_37 (2025-09-28) |

Every height in the structures file becomes metres above the platform by subtracting 7.46.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 25a003, scanned 2025-03-07. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2522 | 64 | mellan (0.58) | 330.0 | 11.6 | Tak | 6.83 | 7.42 | 0.59 | 0.41 |  |
| 2601 | 62 | mellan (0.58) | 330.0 | – | Tak | 6.88 | 7.51 | 0.63 | 0.45 |  |

## Structures

`burlov_structures_heights.geojson`, 8 features: 1 building, 6 canopy_osm, 1 canopy_laser.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w127000069 | NCC / OHLA Sverige (building) | 11.64 | 14.88 | 6.65 | 4.18 | 8972 |
| canopy_osm | w1028750295 | building | 10.70 | 10.76 | 7.05 | 3.24 | 122 |
| canopy_osm | w1028750296 | building | 10.74 | 10.79 | 7.89 | 3.28 | 108 |
| canopy_osm | w1028750297 | roof | 12.45 | 12.60 | 6.85 | 4.99 | 2327 |
| canopy_osm | w1108049669 | roof | 12.46 | 12.61 | 6.84 | 5.00 | 2263 |
| canopy_osm | w1346176846 | roof | – | – | 7.90 | – | 0 |
| canopy_osm | w1346176847 | roof | – | – | 7.56 | – | 1 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 11.05 | 14.06 | 1.96 | 3.59 | 226 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 2522 (track 64): laser gives 0.59 m above the track bed (≈0.41 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- Platform BIS 2601 (track 62): laser gives 0.63 m above the track bed (≈0.45 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 19 files found (14 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-07: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y25a003-61650_3775_25.copc.laz, y25a003-61675_3775_25.copc.laz
  (scan 2025-03-07, nominal 1.8 points/m², flight height 2400 m; 1,027,689 points in the box,
  4.33 per m²; classes {'1': 421652, '2': 601557, '7': 189, '17': 4015, '18': 276}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 616_37 (2025-09-28), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
