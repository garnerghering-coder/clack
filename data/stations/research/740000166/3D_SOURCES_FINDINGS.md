# Katrineholm C (`740000166`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **46.67** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **45.95** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 42.08 – 54.02 (median 46.38) | terrain model 654_56 (2023-08-11) |

Every height in the structures file becomes metres above the platform by subtracting 46.67.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20c018, scanned 2020-11-20. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1297 | 1 | hög (0.73) | 364.0 | – | Skydd | 45.93 | 46.64 | 0.71 | 0.54 |  |
| 1296 | 4 | hög (0.73) | 365.0 | – | Tak | 45.96 | 46.79 | 0.83 | 0.65 |  |
| 1295 | 5 | hög (0.73) | 367.0 | – | Tak | 45.95 | 46.67 | 0.72 | 0.54 |  |

## Structures

`katrineholm_c_structures_heights.geojson`, 6 features: 3 building, 1 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w301655859 | Katrineholms centralstation (station building) | 54.93 | 57.24 | 45.70 | 8.26 | 3326 |
| building | w479773850 | retail | 53.76 | 56.42 | 45.54 | 7.09 | 24 |
| canopy_osm | w558598114 | roof | 52.60 | 53.02 | 47.38 | 5.93 | 149 |
| bridge | w1223482268 | bridge | 53.99 | 56.84 | 45.71 | 7.32 | 248 |
| building | w1419984735 | building | 55.52 | 56.22 | 45.85 | 8.85 | 1667 |
| train_in_scan | (laser) | train standing during the scan (101.6 m × 3.0 m) | 50.54 | – | – | 4.43 | 507 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 1297 (track 1): laser gives 0.71 m above the track bed (≈0.54 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- Platform BIS 1295 (track 5): laser gives 0.72 m above the track bed (≈0.54 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1223482268 (cycleway, primary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 103 files found (43 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-11-20: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20c018-65400_5675_25.copc.laz
  (scan 2020-11-20, nominal 1.2 points/m², flight height 3000 m; 460,153 points in the box,
  2.19 per m²; classes {'1': 178751, '2': 275879, '7': 695, '17': 4828}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 654_56 (2023-08-11), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=16.200899,58.994011,16.216626,58.999156, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
