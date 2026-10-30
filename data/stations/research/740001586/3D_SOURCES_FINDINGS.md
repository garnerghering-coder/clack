# Hyllie (`740001586`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **16.96** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **16.24** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 14.86 – 29.09 (median 23.63) | terrain model 615_37 (2025-09-18) |

Every height in the structures file becomes metres above the platform by subtracting 16.96.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 25a003, scanned 2025-03-07. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2090 | 72N | mellan (0.58) | 355.0 | 10.7 | Tak | 16.22 | 16.97 | 0.75 | 0.57 |  |
| 2091 | 74 | mellan (0.58) | 355.0 | 10.7 | Tak | 16.26 | 16.95 | 0.69 | 0.51 |  |

## Structures

`hyllie_structures_heights.geojson`, 12 features: 10 building, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w94780041 | P-huset Hyllie (garage) | 45.70 | 46.97 | 23.36 | 28.74 | 9398 |
| building | w95298037 | Point Hyllie Hus E (building) | 47.99 | 49.45 | 24.39 | 31.03 | 2618 |
| building | w147530552 | station building | 31.29 | 31.74 | 24.19 | 14.33 | 3308 |
| building | w157598209 | building | 56.27 | 57.66 | 24.22 | 39.31 | 1985 |
| building | w332190868 | Point Hyllie (hotel) | 39.81 | 132.84 | 23.92 | 22.85 | 8101 |
| building | w339183847 | building | 39.16 | 39.84 | 23.92 | 22.20 | 3750 |
| building | w342710057 | Isblocket (office) | 49.95 | 50.29 | 23.71 | 32.99 | 1984 |
| building | w590869570 | The Point (building) | 131.38 | 134.17 | 23.92 | 114.41 | 1636 |
| building | w630767184 | building | 52.94 | 54.58 | 23.84 | 35.98 | 1004 |
| building | w1305913895 | building | 69.33 | 74.97 | 17.06 | 52.37 | 1587 |
| train_in_scan | (laser) | train standing during the scan (38.0 m × 3.0 m) | 19.90 | – | – | 3.53 | 228 |
| train_in_scan | (laser) | train standing during the scan (18.5 m × 2.8 m) | 20.15 | – | – | 3.72 | 112 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w332190868 Point Hyllie (hotel): p95 132.8 m is 93.0 m above the median 39.8 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 146 files found (52 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-07: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y25a003-61575_3700_25.copc.laz, y25a003-61575_3725_25.copc.laz
  (scan 2025-03-07, nominal 1.8 points/m², flight height 2400 m; 632,251 points in the box,
  2.56 per m²; classes {'1': 325739, '2': 305363, '7': 1014, '18': 135}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 615_37 (2025-09-18), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.969902,55.559738,12.982939,55.566169, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
