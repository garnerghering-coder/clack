# Södertälje Syd (`740000055`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **28.95** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **27.75** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.11 – 45.95 (median 8.89) | terrain model 656_65 (2022-11-04) |

Every height in the structures file becomes metres above the platform by subtracting 28.95.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20c029, scanned 2020-03-31. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 821 | 6 | mellan (0.58) | 377.0 | 11.2 | Tak | 40.07 | 41.17 | 1.10 | 0.93 |  |
| 820 | 8 | mellan (0.58) | 382.0 | 7.0 | Tak | 40.09 | 41.16 | 1.07 | 0.90 |  |
| 1331 | 4 | hög (0.73) | 120.0 | 6.0 | Tak | 15.43 | 16.73 | 1.30 | 1.12 |  |
| 1332 | 3 | hög (0.73) | 120.0 | 7.0 | Tak | 15.32 | 16.56 | 1.24 | 1.06 |  |

## Structures

`sodertalje_syd_structures_heights.geojson`, 12 features: 1 building, 9 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w41644048 | roof | 7.94 | 8.69 | 3.29 | -21.01 | 548 |
| canopy_osm | w41644064 | roof | 7.78 | 8.52 | 3.20 | -21.17 | 797 |
| canopy_osm | w41644068 | roof | 7.78 | 8.60 | 2.99 | -21.17 | 893 |
| canopy_osm | w41644073 | roof | 7.61 | 8.52 | 2.73 | -21.34 | 995 |
| canopy_osm | w41644083 | roof | 7.09 | 7.96 | 2.11 | -21.86 | 1001 |
| canopy_osm | w41644151 | roof | 7.90 | 8.83 | 2.62 | -21.05 | 807 |
| building | w89673915 | station building | 43.86 | 44.43 | 12.45 | 14.91 | 2562 |
| canopy_osm | w339577117 | roof | 7.14 | 7.18 | 3.88 | -21.81 | 5 |
| canopy_osm | w339577118 | roof | 7.04 | 7.10 | 3.81 | -21.91 | 5 |
| canopy_osm | w339577119 | roof | 7.01 | 7.06 | 3.70 | -21.94 | 11 |
| bridge | w1266209056 | Igelstabron (bridge) | 44.41 | 45.34 | 0.16 | 15.46 | 6200 |
| train_in_scan | (laser) | train standing during the scan (96.4 m × 3.0 m) | 42.70 | – | – | 4.18 | 440 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Two levels: use ≈41.2 m (övre, on the bridge) and ≈16.6 m (undre) as the references, not the station median 28.95 m.
- Platform BIS 821 (track 6): laser gives 1.10 m above the track bed (≈0.93 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- Platform BIS 820 (track 8): laser gives 1.07 m above the track bed (≈0.90 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- Platform BIS 1331 (track 4): laser gives 1.30 m above the track bed (≈1.12 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- Platform BIS 1332 (track 3): laser gives 1.24 m above the track bed (≈1.06 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 24.61 m across the station (16.56–41.17 m); the station reference above is their median — check which level the app should use.
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1266209056 Igelstabron (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 50 files found (8 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-03-31: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20c029-65600_6500_25.copc.laz
  (scan 2020-03-31, nominal 1.2 points/m², flight height 3000 m; 580,373 points in the box,
  1.89 per m²; classes {'1': 181953, '2': 356702, '7': 659, '9': 4944, '17': 36115}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 656_65 (2022-11-04), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=17.639430,59.160054,17.655342,59.166354, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
