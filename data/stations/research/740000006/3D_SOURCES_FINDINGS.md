# Hässleholm C (`740000006`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **53.81** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **53.13** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 46.99 – 60.47 (median 53.04) | terrain model 622_42 (2025-09-20) |

Every height in the structures file becomes metres above the platform by subtracting 53.81.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 25a009, scanned 2025-02-19. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1228 | 4b | mellan (0.58) | 182.0 | 5.6 | Tak | 53.03 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1227 | 1b | mellan (0.58) | 166.0 | 5.5 | Tak | 53.03 | 53.81 | 0.78 | 0.61 |  |
| 499 | 1b | mellan (0.58) | 160.1 | – | Tak | 53.05 | 53.82 | 0.77 | 0.59 |  |
| 2041 | 7a | mellan (0.58) | 414.0 | 7.0 | Saknas | 53.17 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2538 | 4b | hög (0.73) | 50.0 | 8.3 | Tak | 53.17 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2541 | 1b | hög (0.73) | 52.0 | 8.1 | Tak | 53.12 | 53.85 | 0.73 | 0.55 |  |
| 2540 | 6a | mellan (0.58) | 286.0 | 7.3 | Tak | 53.14 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2539 | 5 | mellan (0.58) | 286.0 | 7.3 | Tak | 53.21 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1224 | 15 | låg (0.35) | 115.6 | 3.0 | Saknas | 53.13 | 53.74 | 0.61 | 0.43 |  |
| 2543 | 3a | mellan (0.58) | 286.0 | 9.0 | Tak | 53.24 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2542 | 1a | mellan (0.58) | 285.0 | 9.0 | Tak | 53.11 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`hassleholm_structures_heights.geojson`, 12 features: 4 building, 1 canopy_laser, 6 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| bridge | w415312097 | bridge | 56.99 | 57.17 | 47.03 | 3.18 | 196 |
| building | w419690632 | Hässleholm C (station building) | 64.06 | 67.44 | 53.08 | 10.25 | 1512 |
| building | w424033194 | Vårdcentral Vänhem (civic) | 55.37 | 57.31 | 48.37 | 1.56 | 1770 |
| building | w424096588 | building | 57.57 | 62.27 | 52.30 | 3.76 | 907 |
| building | w424096644 | apartments | 68.50 | 71.18 | 52.17 | 14.69 | 1172 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 58.42 | 59.04 | 53.03 | 4.61 | 1091 |
| train_in_scan | (laser) | train standing during the scan (16.2 m × 2.7 m) | 57.10 | – | – | 3.95 | 73 |
| train_in_scan | (laser) | train standing during the scan (145.2 m × 3.1 m) | 56.84 | – | – | 3.75 | 667 |
| train_in_scan | (laser) | train standing during the scan (71.2 m × 3.0 m) | 56.78 | – | – | 3.69 | 375 |
| train_in_scan | (laser) | train standing during the scan (70.9 m × 3.0 m) | 56.78 | – | – | 3.69 | 350 |
| train_in_scan | (laser) | train standing during the scan (26.3 m × 2.4 m) | 56.78 | – | – | 3.92 | 90 |
| train_in_scan | (laser) | train standing during the scan (51.1 m × 3.1 m) | 56.70 | – | – | 3.59 | 260 |

## Trains in the scan

6 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 2541 (track 1b): laser gives 0.73 m above the track bed (≈0.55 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- w419690632 Hässleholm C (station building): p95 67.4 m is 3.4 m above the median 64.1 m (a taller neighbour or a mast inside the outline?).
- w424096588 building: p95 62.3 m is 4.7 m above the median 57.6 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w415312097 (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 53 files found (27 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-02-19: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y25a009-62225_4225_25.copc.laz
  (scan 2025-02-19, nominal 1.5 points/m², flight height 2300 m; 525,677 points in the box,
  1.66 per m²; classes {'1': 234297, '2': 286760, '7': 285, '17': 4325, '18': 10}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 622_42 (2025-09-20), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
