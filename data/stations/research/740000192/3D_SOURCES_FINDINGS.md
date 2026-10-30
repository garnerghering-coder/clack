# Kumla (`740000192`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **52.42** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **51.76** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 46.56 – 53.95 (median 51.73) | terrain model 655_50 (2024-09-29) |

Every height in the structures file becomes metres above the platform by subtracting 52.42.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 23c023, scanned 2023-07-11. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1146 | 1 | mellan (0.58) | 197.0 | 6.0 | Skydd | 51.74 | 52.56 | 0.82 | 0.65 |  |
| 1148 | 2 | låg (0.35) | 38.0 | 6.0 | Skydd | 51.77 | 52.28 | 0.51 | 0.33 |  |

## Structures

`kumla_structures_heights.geojson`, 4 features: 1 building, 1 canopy_laser.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w292266414 | station building | 60.09 | 65.53 | 51.89 | 7.67 | 689 |
| bridge | w1104909311 | bridge | 61.59 | 67.56 | 46.82 | 9.17 | 127 |
| bridge | w1104909312 | bridge | 59.62 | 60.13 | 46.59 | 7.20 | 30 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 56.66 | 56.89 | 47.74 | 4.24 | 238 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w292266414 station building: p95 65.5 m is 5.4 m above the median 60.1 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1104909311 (cycleway, residential); w1104909312 (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 61 files found (27 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-07-11: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y23c023-65525_5075_25.copc.laz
  (scan 2023-07-11, nominal 1.1 points/m², flight height 3200 m; 197,673 points in the box,
  1.35 per m²; classes {'1': 78838, '2': 116998, '7': 149, '17': 1655, '18': 33}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 655_50 (2024-09-29), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=15.135980,59.124060,15.145360,59.130731, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
