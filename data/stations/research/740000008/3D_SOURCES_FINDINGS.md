# Skövde C (`740000008`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **140.25** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **139.42** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 126.67 – 143.87 (median 139.12) | terrain model 647_43 (2024-04-05) |

Every height in the structures file becomes metres above the platform by subtracting 140.25.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 22b020, scanned 2022-03-11. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 391 | 151-152 | mellan (0.58) | 389.0 | – | Tak | 139.51 | 140.44 | 0.93 | 0.76 |  |
| 392 | 1 | mellan (0.58) | 386.0 | 4.5 | Tak | 139.33 | 140.06 | 0.73 | 0.55 |  |

## Structures

`skovde_c_structures_heights.geojson`, 26 features: 8 building, 1 footbridge, 10 canopy_osm, 3 canopy_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w89660660 | transportation | 144.00 | 144.46 | 139.66 | 3.75 | 1478 |
| building | w89660669 | Skövde Central (station building) | 150.52 | 151.58 | 139.87 | 10.27 | 1650 |
| canopy_osm | w312826159 | roof | 138.78 | 138.93 | 136.10 | -1.47 | 21 |
| canopy_osm | w312826160 | roof | 138.48 | 138.68 | 136.06 | -1.77 | 11 |
| canopy_osm | w312826161 | roof | 138.49 | 138.75 | 135.50 | -1.76 | 29 |
| building | w535289859 | Mode (parking) | 155.56 | 158.37 | 133.77 | 15.31 | 5409 |
| canopy_osm | w846907576 | building | 142.12 | 142.23 | 139.73 | 1.87 | 20 |
| canopy_osm | w846907577 | building | 141.97 | 142.03 | 139.61 | 1.72 | 16 |
| canopy_osm | w846907578 | building | 141.72 | 141.80 | 139.34 | 1.47 | 23 |
| canopy_osm | w846907579 | building | 142.05 | 142.09 | 139.51 | 1.80 | 22 |
| canopy_osm | w846907580 | building | 142.14 | 142.20 | 139.64 | 1.89 | 23 |
| bridge | w869747977 | bridge | 141.40 | 141.77 | 134.86 | 1.15 | 23 |
| bridge | w869749029 | bridge | 139.64 | 145.70 | 134.64 | -0.61 | 13 |
| building | w1018745072 | station building | 150.04 | 151.94 | 139.08 | 9.79 | 121 |
| canopy_osm | w1044410775 | roof | 142.60 | 142.78 | 140.02 | 2.35 | 22 |
| canopy_osm | w1044410776 | roof | 142.29 | 146.89 | 134.78 | 2.04 | 274 |
| bridge | w1080044505 | bridge | 139.02 | 148.06 | 132.33 | -1.23 | 16 |
| building | w1235549204 | transportation | 147.40 | 151.19 | 140.15 | 7.15 | 174 |
| building | w1235549205 | bridge | 148.31 | 150.16 | 139.25 | 8.06 | 212 |
| building | w1235549206 | bridge | 147.19 | 150.14 | 139.03 | 6.94 | 502 |
| footbridge | w1248821191 | bridge | 138.75 | 142.62 | 127.48 | -1.50 | 104 |
| building | w1493434047 | building | 155.29 | 155.71 | 134.72 | 15.04 | 2803 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 143.60 | 143.66 | 139.19 | 3.35 | 834 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 144.51 | 144.66 | 139.29 | 4.26 | 103 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 143.59 | 143.65 | 139.53 | 3.34 | 686 |
| train_in_scan | (laser) | train standing during the scan (149.8 m × 2.8 m) | 143.30 | – | – | 3.71 | 582 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 391 (track 151-152): laser gives 0.93 m above the track bed (≈0.76 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- w1044410776 roof: p95 146.9 m is 4.6 m above the median 142.3 m (a taller neighbour or a mast inside the outline?).
- w1235549204 transportation: p95 151.2 m is 3.8 m above the median 147.4 m (a taller neighbour or a mast inside the outline?).
- w1248821191 bridge: p95 142.6 m is 3.9 m above the median 138.8 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w869747977 (path, tertiary); w869749029 (no mapped ways); w1080044505 (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (44 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2022-03-11: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y22b020-64700_4325_25.copc.laz, y22b020-64725_4325_25.copc.laz
  (scan 2022-03-11, nominal 1.1 points/m², flight height 3200 m; 439,298 points in the box,
  1.78 per m²; classes {'1': 210192, '2': 225752, '7': 315, '17': 2999, '18': 40}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 647_43 (2024-04-05), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=13.846826,58.385931,13.858055,58.393562, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
