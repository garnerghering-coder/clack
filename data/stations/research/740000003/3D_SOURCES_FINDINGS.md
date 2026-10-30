# Malmö C (`740000003`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **3.20** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **2.49** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -4.37 – 4.92 (median 2.82) | terrain model 616_37 (2025-09-28) |

Every height in the structures file becomes metres above the platform by subtracting 3.20.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 25a003, scanned 2025-03-07. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2093 | 2a,2b | mellan (0.58) | 330.0 | 10.5 | Tak | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| 2092 | 4a,4b | mellan (0.58) | 321.0 | 10.5 | Tak | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| 2082 | 5 | mellan (0.58) | 427.0 | – | Tak | 2.50 | 3.20 | 0.70 | 0.53 |  |
| 2083 | 7 | mellan (0.58) | 282.0 | – | Tak | 2.51 | 3.22 | 0.71 | 0.53 |  |
| 2084 | 9 | mellan (0.58) | 282.0 | – | Tak | 2.47 | 3.20 | 0.73 | 0.55 |  |
| 2482 | 10 | mellan (0.58) | 407.0 | – | Tak | 2.50 | 3.19 | 0.69 | 0.51 |  |
| 2602 | 11 | mellan (0.58) | 275.0 | 6.5 | Saknas | 2.46 | 3.20 | 0.74 | 0.57 |  |
| 2603 | 11 | mellan (0.58) | 18.0 | 2.3 | Tak | 2.45 | 3.18 | 0.73 | 0.55 |  |

## Structures

`malmo_c_structures_heights.geojson`, 48 features: 20 building, 4 footbridge, 13 canopy_osm, 2 canopy_laser, 5 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w28415330 | roof | 12.88 | 15.77 | 2.49 | 9.68 | 19671 |
| building | w52200890 | Orkanen (university) | 27.76 | 30.59 | 2.29 | 24.56 | 2379 |
| building | w52201121 | Malmö börshus (building) | 19.91 | 23.87 | 0.89 | 16.71 | 5793 |
| building | w81391559 | station building | 7.63 | 11.85 | 2.63 | 4.43 | 294 |
| building | w81391563 | station building | 7.63 | 11.83 | 2.12 | 4.43 | 293 |
| building | w89355624 | building | 19.18 | 21.21 | 3.29 | 15.98 | 6521 |
| canopy_osm | w189255289 | roof | 6.27 | 6.34 | 2.60 | 3.07 | 509 |
| canopy_osm | w189255290 | roof | 6.32 | 6.37 | 2.62 | 3.12 | 653 |
| building | w189255291 | MENYn Grill & Sallad (building) | 7.08 | 7.83 | 3.45 | 3.88 | 132 |
| canopy_osm | w191082399 | roof | 4.16 | 5.84 | 0.14 | 0.96 | 186 |
| canopy_osm | w191082401 | roof | 5.28 | 5.32 | 2.44 | 2.08 | 11 |
| canopy_osm | w328037285 | roof | 8.38 | 8.75 | 1.49 | 5.18 | 2052 |
| building | w330653386 | Malmö centralstation (station building) | 11.96 | 24.12 | 2.42 | 8.76 | 15561 |
| canopy_osm | w330709334 | roof | 7.53 | 7.70 | 3.15 | 4.33 | 114 |
| canopy_osm | w330709335 | roof | 7.53 | 7.66 | 3.04 | 4.33 | 121 |
| bridge | w394896504 | Petribron (bridge) | 4.04 | 8.18 | 0.14 | 0.84 | 43 |
| bridge | w394897889 | Skeppsbron (bridge) | 4.25 | 5.56 | 0.14 | 1.05 | 104 |
| bridge | w554649178 | Centralbron (bridge) | 7.66 | 7.76 | 0.13 | 4.46 | 86 |
| building | w941081386 | building | 11.92 | 13.02 | 2.92 | 8.72 | 501 |
| building | w941081387 | building | 17.01 | 17.87 | 2.71 | 13.81 | 769 |
| building | w941081393 | building | 12.27 | 12.47 | 2.86 | 9.07 | 340 |
| building | w941081394 | building | 12.93 | 17.09 | 2.68 | 9.73 | 1896 |
| building | w941081398 | building | 15.31 | 16.43 | 2.67 | 12.11 | 253 |
| building | w941081399 | building | 15.33 | 16.27 | 2.63 | 12.13 | 235 |
| building | w941081401 | building | 8.62 | 9.23 | 3.13 | 5.42 | 555 |
| building | w941081403 | building | 9.66 | 10.78 | 2.67 | 6.46 | 261 |
| building | w941081405 | building | 15.19 | 16.16 | 2.61 | 11.99 | 811 |
| building | w941081406 | roof | 8.92 | 9.35 | 2.82 | 5.72 | 1446 |
| building | w941081407 | building | 10.83 | 12.97 | 2.76 | 7.63 | 1208 |
| building | w941081408 | building | 14.76 | 17.62 | 2.67 | 11.56 | 2345 |
| building | w941081411 | building | 9.18 | 12.43 | 2.73 | 5.98 | 1006 |
| canopy_osm | w1035166396 | building | – | – | 2.54 | – | 4 |
| canopy_osm | w1035166397 | building | 5.28 | 5.30 | 2.80 | 2.08 | 15 |
| canopy_osm | w1035166398 | building | 5.39 | 5.41 | 2.90 | 2.19 | 15 |
| canopy_osm | w1156564026 | roof | 6.12 | 6.39 | 0.14 | 2.92 | 53 |
| canopy_osm | w1281927624 | building | 5.40 | 5.43 | 2.34 | 2.20 | 16 |
| footbridge | w1352062484 | bridge | 3.34 | 4.47 | 0.03 | 0.14 | 124 |
| bridge | w1352062485 | Suellsbron (bridge) | 4.24 | 4.70 | 0.10 | 1.04 | 65 |
| footbridge | w1352062486 | bridge | 3.37 | 4.50 | 0.13 | 0.17 | 55 |
| footbridge | w1352062488 | bridge | – | – | 0.14 | – | 1 |
| footbridge | w1352062489 | bridge | 4.91 | 5.20 | 0.14 | 1.71 | 31 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 6.11 | 6.22 | 2.77 | 2.91 | 97 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 9.13 | 9.20 | 2.29 | 5.93 | 541 |
| train_in_scan | (laser) | train standing during the scan (45.2 m × 2.9 m) | 6.71 | – | – | 4.21 | 244 |
| train_in_scan | (laser) | train standing during the scan (15.2 m × 2.7 m) | 6.41 | – | – | 3.59 | 80 |
| train_in_scan | (laser) | train standing during the scan (20.5 m × 2.9 m) | 6.62 | – | – | 4.07 | 123 |
| train_in_scan | (laser) | train standing during the scan (24.1 m × 2.6 m) | 6.64 | – | – | 4.06 | 127 |
| train_in_scan | (laser) | train standing during the scan (21.2 m × 2.9 m) | 6.41 | – | – | 3.68 | 124 |

## Trains in the scan

5 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w81391559 station building: p95 11.9 m is 4.2 m above the median 7.6 m (a taller neighbour or a mast inside the outline?).
- w81391563 station building: p95 11.8 m is 4.2 m above the median 7.6 m (a taller neighbour or a mast inside the outline?).
- w330653386 Malmö centralstation (station building): p95 24.1 m is 12.2 m above the median 12.0 m (a taller neighbour or a mast inside the outline?).
- w941081394 building: p95 17.1 m is 4.2 m above the median 12.9 m (a taller neighbour or a mast inside the outline?).
- w941081411 building: p95 12.4 m is 3.2 m above the median 9.2 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w394896504 Petribron (cycleway, footway, service); w394897889 Skeppsbron (footway, tertiary); w554649178 Centralbron (footway, service); w1352062485 Suellsbron (tertiary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 143 files found (119 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-07: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y25a003-61625_3725_25.copc.laz
  (scan 2025-03-07, nominal 1.8 points/m², flight height 2400 m; 548,540 points in the box,
  1.72 per m²; classes {'1': 233859, '2': 292879, '7': 615, '9': 14932, '17': 6210, '18': 45}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 616_37 (2025-09-28), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.993496,55.606580,13.011276,55.612291, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
