# Hallsberg (`740000077`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **52.99** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **52.14** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 47.14 – 56.82 (median 51.53) | terrain model 654_50 (2024-05-14) |

Every height in the structures file becomes metres above the platform by subtracting 52.99.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 23c016, scanned 2023-04-16. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1386 | 5a | mellan (0.58) | 593.0 | 7.5 | Tak | 52.14 | 52.99 | 0.85 | 0.68 |  |
| 1400 | ? | mellan (0.58) | 523.0 | – | Tak | – | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`hallsberg_structures_heights.geojson`, 8 features: 2 building, 5 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w201201715 | station building | 60.36 | 65.78 | 52.21 | 7.37 | 1047 |
| building | w201201716 | retail | 60.51 | 64.59 | 52.43 | 7.52 | 756 |
| bridge | w1110730278 | bridge | 60.58 | 61.38 | 50.06 | 7.59 | 322 |
| train_in_scan | (laser) | train standing during the scan (102.5 m × 3.0 m) | 56.47 | – | – | 4.12 | 399 |
| train_in_scan | (laser) | train standing during the scan (15.0 m × 2.8 m) | 55.85 | – | – | 3.89 | 56 |
| train_in_scan | (laser) | train standing during the scan (52.9 m × 3.1 m) | 56.58 | – | – | 4.25 | 221 |
| train_in_scan | (laser) | train standing during the scan (201.4 m × 3.0 m) | 56.64 | – | – | 4.32 | 782 |
| train_in_scan | (laser) | train standing during the scan (27.7 m × 2.9 m) | 56.14 | – | – | 3.96 | 100 |

## Trains in the scan

5 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w201201715 station building: p95 65.8 m is 5.4 m above the median 60.4 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1110730278 (cycleway, secondary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 136 files found (66 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-04-16: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y23c016-65450_5050_25.copc.laz, y23c016-65475_5050_25.copc.laz
  (scan 2023-04-16, nominal 1.1 points/m², flight height 3200 m; 291,312 points in the box,
  1.43 per m²; classes {'1': 110229, '2': 177133, '7': 339, '17': 3565, '18': 46}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 654_50 (2024-05-14), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
