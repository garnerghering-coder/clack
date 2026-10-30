# Örebro C (`740000133`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **28.16** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **27.37** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 21.95 – 34.51 (median 27.31) | terrain model 657_51 (2024-10-02) |

Every height in the structures file becomes metres above the platform by subtracting 28.16.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 23c023, scanned 2023-07-11. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1217 | ? | mellan (0.58) | 457.0 | – | Tak | 27.39 | 28.23 | 0.84 | 0.66 |  |
| 1220 | 1a | mellan (0.58) | 393.0 | – | Tak | 27.35 | 28.10 | 0.75 | 0.57 |  |

## Structures

`orebro_c_structures_heights.geojson`, 7 features: 1 building, 4 canopy_osm, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w180241375 | roof | 33.03 | 33.23 | 27.49 | 4.87 | 2043 |
| canopy_osm | w383771873 | roof | 31.72 | 31.92 | 26.47 | 3.56 | 365 |
| canopy_osm | w383771874 | roof | 33.03 | 33.29 | 27.40 | 4.87 | 381 |
| canopy_osm | w525673338 | roof | 32.82 | 38.77 | 28.14 | 4.66 | 45 |
| building | r7584983 | Örebro Central (station building) | 34.42 | 39.18 | 27.78 | 6.26 | 938 |
| train_in_scan | (laser) | train standing during the scan (39.0 m × 3.1 m) | 31.43 | – | – | 4.14 | 151 |
| train_in_scan | (laser) | train standing during the scan (51.4 m × 3.1 m) | 31.44 | – | – | 3.63 | 200 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w525673338 roof: p95 38.8 m is 5.9 m above the median 32.8 m (a taller neighbour or a mast inside the outline?).
- r7584983 Örebro Central (station building): p95 39.2 m is 4.8 m above the median 34.4 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 119 files found (51 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-07-11: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y23c023-65700_5100_25.copc.laz
  (scan 2023-07-11, nominal 1.1 points/m², flight height 3200 m; 369,620 points in the box,
  1.33 per m²; classes {'1': 173369, '2': 192093, '7': 510, '17': 3572, '18': 76}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 657_51 (2024-10-02), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=15.205219,59.274322,15.216591,59.282654, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
