# Västerås C (`740000099`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **3.85** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **3.10** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -1.11 – 8.15 (median 3.06) | terrain model 660_58 (2023-04-07) |

Every height in the structures file becomes metres above the platform by subtracting 3.85.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 21c035, scanned 2021-04-05. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1309 | 2 | hög (0.73) | 392.0 | 13.0 | Skydd | – | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1306 | 1b | hög (0.73) | 504.0 | 5.7 | Tak | 3.12 | 3.80 | 0.68 | 0.51 |  |
| 1311 | 5 | hög (0.73) | 381.0 | 10.5 | Skydd | 3.09 | 3.90 | 0.81 | 0.64 |  |

## Structures

`vasteras_c_structures_heights.geojson`, 11 features: 3 building, 4 canopy_osm, 1 hall_roof_laser, 3 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w1029363807 | station building | 13.86 | 15.41 | 3.45 | 10.01 | 1191 |
| building | w1129096975 | building | 13.41 | 14.83 | 2.68 | 9.56 | 764 |
| building | w1174153913 | service | 8.04 | 9.03 | 3.38 | 4.19 | 1694 |
| canopy_osm | w1192514152 | roof | 5.53 | 5.60 | 2.26 | 1.68 | 34 |
| canopy_osm | w1192514153 | roof | – | – | 2.00 | – | 0 |
| canopy_osm | w1192754020 | roof | 6.77 | 6.90 | 3.48 | 2.92 | 385 |
| canopy_osm | w1424625004 | roof | 8.25 | 37.87 | 3.56 | 4.40 | 104 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 13.47 | 13.64 | 3.07 | 9.62 | 71 |
| train_in_scan | (laser) | train standing during the scan (48.6 m × 3.1 m) | 7.00 | – | – | 3.84 | 505 |
| train_in_scan | (laser) | train standing during the scan (22.6 m × 2.6 m) | 7.50 | – | – | 4.41 | 93 |
| train_in_scan | (laser) | train standing during the scan (25.2 m × 2.9 m) | 7.48 | – | – | 4.45 | 105 |

## Trains in the scan

3 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 1306 (track 1b): laser gives 0.68 m above the track bed (≈0.51 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- w1424625004 roof: p95 37.9 m is 29.6 m above the median 8.2 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (53 m², top 9.6 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (53 m², top 9.6 m above the platform, 10.4 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 108 files found (42 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-04-05: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y21c035-66075_5850_25.copc.laz, y21c035-66075_5875_25.copc.laz
  (scan 2021-04-05, nominal 1.2 points/m², flight height 3000 m; 773,458 points in the box,
  2.11 per m²; classes {'1': 293878, '2': 474398, '7': 231, '9': 577, '17': 4374}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 660_58 (2023-04-07), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=16.544330,59.603565,16.559850,59.610906, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
