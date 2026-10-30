# Eskilstuna C (`740000170`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **18.20** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **17.42** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 11.99 – 28.61 (median 17.37) | terrain model 658_58 (2023-03-23) |

Every height in the structures file becomes metres above the platform by subtracting 18.20.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20c026, scanned 2020-02-27. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 686 | 3 | mellan (0.58) | 338.0 | 9.0 | Skydd | 18.27 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 687 | 1 | mellan (0.58) | 326.0 | 3.5 | Skydd | 17.42 | 18.16 | 0.74 | 0.56 |  |
| 1208 | 4 | mellan (0.58) | 142.0 | – | Tak | 17.40 | 18.23 | 0.83 | 0.65 |  |

## Structures

`eskilstuna_c_structures_heights.geojson`, 17 features: 1 building, 15 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w127582192 | Eskilstuna Central (station building) | 26.33 | 28.82 | 17.49 | 8.13 | 1424 |
| canopy_osm | w609037662 | roof | 19.72 | 19.82 | 17.23 | 1.52 | 18 |
| canopy_osm | w609037663 | roof | 19.89 | 19.97 | 17.34 | 1.69 | 20 |
| canopy_osm | w609037664 | roof | 20.08 | 20.13 | 17.48 | 1.88 | 24 |
| canopy_osm | w609037665 | roof | 20.20 | 20.28 | 17.56 | 2.00 | 20 |
| canopy_osm | w609037666 | roof | 20.31 | 20.39 | 17.63 | 2.11 | 24 |
| canopy_osm | w609037671 | roof | 20.70 | 20.82 | 17.96 | 2.50 | 22 |
| canopy_osm | w609037672 | roof | 20.78 | 20.89 | 18.00 | 2.58 | 25 |
| canopy_osm | w609037673 | roof | 20.72 | 20.83 | 18.00 | 2.52 | 25 |
| canopy_osm | w609037674 | roof | 20.67 | 20.75 | 17.87 | 2.47 | 24 |
| canopy_osm | w609037675 | roof | 20.52 | 20.59 | 17.74 | 2.32 | 24 |
| canopy_osm | w609037676 | roof | 20.35 | 20.47 | 17.59 | 2.15 | 23 |
| canopy_osm | w609037677 | roof | 20.22 | 20.30 | 17.47 | 2.02 | 23 |
| canopy_osm | w609037678 | roof | 20.10 | 20.17 | 17.34 | 1.90 | 20 |
| canopy_osm | w609037679 | roof | 19.99 | 20.07 | 17.22 | 1.79 | 24 |
| canopy_osm | w1347333691 | roof | 23.07 | 23.47 | 17.38 | 4.87 | 589 |
| train_in_scan | (laser) | train standing during the scan (16.6 m × 3.3 m) | 21.23 | – | – | 3.88 | 110 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- none

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 29 files found (8 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-02-27: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20c026-65800_5850_25.copc.laz
  (scan 2020-02-27, nominal 1.2 points/m², flight height 3000 m; 461,806 points in the box,
  2.05 per m²; classes {'1': 209072, '2': 252305, '7': 100, '17': 329}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 658_58 (2023-03-23), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=16.498676,59.366295,16.512070,59.372415, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
