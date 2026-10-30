# Karlstad C (`740000070`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **48.64** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **47.88** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 43.55 – 50.36 (median 47.58) | terrain model 658_41 (2023-01-22) |

Every height in the structures file becomes metres above the platform by subtracting 48.64.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 19b030, scanned 2019-10-29. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2608 | 1a | mellan (0.58) | 500.0 | 6.0 | Tak | 47.75 | 48.64 | 0.89 | 0.72 |  |
| 2615 | 4a | mellan (0.58) | 500.0 | 9.0 | Tak | 48.00 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`karlstad_c_structures_heights.geojson`, 30 features: 10 building, 4 footbridge, 9 canopy_osm, 3 canopy_laser, 4 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w100636350 | roof | 53.09 | 53.57 | 47.72 | 4.45 | 348 |
| canopy_osm | w100636376 | roof | 53.15 | 53.41 | 47.51 | 4.51 | 206 |
| building | w107041961 | detached | 54.44 | 56.05 | 48.00 | 5.80 | 202 |
| building | w356121937 | Karlstads central (station building) | 56.05 | 57.88 | 47.49 | 7.41 | 194 |
| footbridge | w1274171384 | bridge | 53.90 | 54.87 | 47.92 | 5.26 | 138 |
| footbridge | w1274171385 | bridge | 53.88 | 55.13 | 47.95 | 5.24 | 132 |
| building | w1287469464 | service | 50.45 | 50.61 | 47.54 | 1.81 | 36 |
| footbridge | w1327214098 | bridge | 64.63 | 70.22 | 47.57 | 15.99 | 129 |
| building | w1331120046 | Pressbyrån (building) | 51.25 | 52.13 | 47.47 | 2.61 | 90 |
| footbridge | w1331120624 | bridge | – | – | 48.03 | – | 0 |
| building | w1344878978 | elevator | – | – | 47.82 | – | 0 |
| building | w1344878981 | elevator | 55.00 | 55.13 | 48.20 | 6.36 | 12 |
| building | w1344878982 | elevator | – | – | 48.08 | – | 0 |
| canopy_osm | w1384459964 | roof | 53.28 | 53.41 | 47.83 | 4.64 | 154 |
| canopy_osm | w1445795992 | roof | 50.52 | 52.41 | 47.09 | 1.88 | 63 |
| canopy_osm | w1445795994 | roof | 53.27 | 66.38 | 47.24 | 4.63 | 193 |
| canopy_osm | w1458513818 | roof | 53.16 | 53.42 | 47.64 | 4.52 | 125 |
| building | w1458519969 | service | 53.80 | 54.53 | 47.57 | 5.16 | 12 |
| canopy_osm | w1459852526 | roof | 51.18 | 62.55 | 47.57 | 2.54 | 99 |
| building | w1483480663 | elevator | – | – | 48.22 | – | 0 |
| canopy_osm | w1483480664 | roof | 51.86 | 52.24 | 47.59 | 3.22 | 993 |
| building | w1483483695 | elevator | – | – | 47.76 | – | 0 |
| canopy_osm | w1558495911 | roof | – | – | 47.46 | – | 0 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 51.90 | 53.40 | 47.77 | 3.26 | 243 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 53.70 | 53.92 | 48.05 | 5.06 | 498 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 53.82 | 53.91 | 48.11 | 5.18 | 137 |
| train_in_scan | (laser) | train standing during the scan (30.4 m × 1.9 m) | 51.80 | – | – | 4.10 | 77 |
| train_in_scan | (laser) | train standing during the scan (221.7 m × 2.8 m) | 52.10 | – | – | 4.19 | 855 |
| train_in_scan | (laser) | train standing during the scan (71.0 m × 3.6 m) | 52.00 | – | – | 3.80 | 298 |
| train_in_scan | (laser) | train standing during the scan (121.1 m × 2.7 m) | 51.84 | – | – | 4.20 | 414 |

## Trains in the scan

4 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 2608 (track 1a): laser gives 0.89 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- w1327214098 bridge: p95 70.2 m is 5.6 m above the median 64.6 m (a taller neighbour or a mast inside the outline?).
- w1445795994 roof: p95 66.4 m is 13.1 m above the median 53.3 m (a taller neighbour or a mast inside the outline?).
- w1459852526 roof: p95 62.6 m is 11.4 m above the median 51.2 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (407 m², top 5.1 m above the platform, 5.8 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (120 m², top 5.2 m above the platform, 5.9 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 138 files found (42 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2019-10-29: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y19b030-65825_4125_25.copc.laz, y19b030-65825_4150_25.copc.laz
  (scan 2019-10-29, nominal 1.2 points/m², flight height 3000 m; 223,523 points in the box,
  1.46 per m²; classes {'1': 109670, '2': 113762, '7': 91}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 658_41 (2023-01-22), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=13.492598,59.375466,13.506524,59.380150, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
