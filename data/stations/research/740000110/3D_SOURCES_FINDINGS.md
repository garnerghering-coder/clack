# Varberg C (`740000110`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **–** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **–** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -6.63 – 10.31 (median 2.27) | terrain model 633_33 (2022-09-30) |

Every height in the structures file becomes metres above the platform by subtracting –.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20a030, scanned 2020-01-20. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2613 | 5a,5b | mellan (0.58) | 350.0 | 9.3 | Skydd | – | – | – | – | platform of the new Varberg station in the railway tunnel (opened after the January 2020 scan): the laser shows only the ground of the old site on its line, not the platform or its track bed |
| 2611 | 2a,2b | mellan (0.58) | 333.0 | 6.2 | Skydd | – | – | – | – | platform of the new Varberg station in the railway tunnel (opened after the January 2020 scan): the laser shows only the ground of the old site on its line, not the platform or its track bed |
| 2612 | 4a,4b | mellan (0.58) | 350.0 | 9.3 | Skydd | – | – | – | – | platform of the new Varberg station in the railway tunnel (opened after the January 2020 scan): the laser shows only the ground of the old site on its line, not the platform or its track bed |
| 2610 | 1a,1b | mellan (0.58) | 193.0 | 6.2 | Skydd | – | – | – | – | platform of the new Varberg station in the railway tunnel (opened after the January 2020 scan): the laser shows only the ground of the old site on its line, not the platform or its track bed |

## Structures

`varberg_c_structures_heights.geojson`, 12 features: 1 building, 1 footbridge, 9 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w1414446572 | station building | 6.86 | 8.45 | 1.64 | – | 534 |
| bridge | w1463599003 | Linda Hanssons Bro (bridge) | 2.31 | 6.04 | -5.72 | – | 550 |
| footbridge | w1463599004 | Alida Svenssons gång- och cykelbro (bridge) | 3.19 | 6.22 | -6.22 | – | 859 |
| canopy_osm | w1463599038 | roof | 2.56 | 4.16 | -5.47 | – | 80 |
| canopy_osm | w1463599039 | roof | 3.51 | 3.55 | -5.65 | – | 61 |
| canopy_osm | w1463599048 | roof | 3.36 | 3.45 | -5.80 | – | 35 |
| canopy_osm | w1463602333 | roof | 2.27 | 6.02 | -6.22 | – | 420 |
| canopy_osm | w1463602334 | roof | 2.25 | 4.18 | -5.86 | – | 442 |
| canopy_osm | w1463602335 | roof | 3.05 | 6.18 | -6.21 | – | 778 |
| canopy_osm | w1463602336 | roof | 2.41 | 4.11 | -5.78 | – | 346 |
| canopy_osm | w1463602337 | roof | 2.32 | 2.48 | -5.55 | – | 168 |
| canopy_osm | w1463602338 | roof | 2.24 | 2.30 | -5.01 | – | 203 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w1463599004 Alida Svenssons gång- och cykelbro (bridge): p95 6.2 m is 3.0 m above the median 3.2 m (a taller neighbour or a mast inside the outline?).
- w1463602333 roof: p95 6.0 m is 3.8 m above the median 2.3 m (a taller neighbour or a mast inside the outline?).
- w1463602335 roof: p95 6.2 m is 3.1 m above the median 3.1 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1463599003 Linda Hanssons Bro (service).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 81 files found (47 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-01-20: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20a030-63325_3325_25.copc.laz
  (scan 2020-01-20, nominal 1.2 points/m², flight height 3000 m; 644,345 points in the box,
  3.07 per m²; classes {'1': 240749, '2': 403415, '7': 181}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 633_33 (2022-09-30), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.244822,57.108970,12.254672,57.116764, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
