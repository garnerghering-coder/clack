# Uppsala C (`740000005`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **7.47** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **6.62** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 1.51 – 13.37 (median 6.58) | terrain model 663_64 (2023-04-26) |

Every height in the structures file becomes metres above the platform by subtracting 7.47.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 21c037, scanned 2021-03-19. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2100 | 5 | hög (0.73) | 96.0 | – | Tak | 6.53 | 7.32 | 0.79 | 0.61 |  |
| 2126 | 1a,1b | mellan (0.58) | 463.0 | 5.0 | Tak | 6.54 | 7.24 | 0.70 | 0.53 |  |
| 2000 | 8a,8b | mellan (0.58) | 480.0 | 6.0 | Tak | 6.62 | 7.42 | 0.80 | 0.62 |  |
| 2014 | 7a,7b | mellan (0.58) | 401.0 | 6.0 | Tak | 6.64 | 7.53 | 0.89 | 0.71 |  |
| 2127 | 2a,2b | mellan (0.58) | 388.0 | 10.5 | Tak | 6.55 | 7.55 | 1.00 | 0.82 |  |
| 2052 | 3 | hög (0.73) | 353.0 | 4.0 | Tak | 7.13 | 7.83 | 0.70 | 0.52 |  |
| 2051 | 4 | mellan (0.58) | 348.0 | 5.0 | Tak | 7.69 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |

## Structures

`uppsala_c_structures_heights.geojson`, 26 features: 17 building, 2 canopy_osm, 5 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w55897474 | Gamla stationshuset (station building) | 11.95 | 18.37 | 6.08 | 4.48 | 1032 |
| building | w55897475 | Uppsala centralstation (station building) | 12.17 | 13.72 | 2.76 | 4.70 | 1780 |
| building | w207791536 | Stationsgallerian (office) | 30.96 | 34.59 | 4.52 | 23.49 | 4429 |
| building | w207791538 | building | 13.30 | 14.00 | 3.01 | 5.83 | 14 |
| building | w207791539 | building | 13.99 | 14.02 | 3.05 | 6.52 | 8 |
| building | w207791540 | building | 10.68 | 11.48 | 2.64 | 3.21 | 16 |
| building | w207791542 | building | 12.59 | 12.62 | 2.73 | 5.12 | 11 |
| canopy_osm | w207791544 | roof | 15.44 | 16.47 | 2.29 | 7.97 | 760 |
| building | w207793358 | Uppsala Östra (station building) | 10.79 | 11.04 | 7.16 | 3.32 | 135 |
| canopy_osm | w208490022 | roof | 15.44 | 16.48 | 7.09 | 7.97 | 191 |
| building | w210282806 | building | 15.33 | 17.48 | 5.77 | 7.86 | 161 |
| building | w210282807 | service | 10.14 | 10.20 | 7.46 | 2.67 | 23 |
| building | w238497079 | building | 14.75 | 17.10 | 5.57 | 7.28 | 674 |
| building | w288244870 | Centralgaraget (shed) | 12.05 | 12.11 | 7.36 | 4.58 | 62 |
| building | w444022997 | building | 12.44 | 12.48 | 2.29 | 4.97 | 22 |
| building | w815720304 | building | 13.44 | 13.59 | 5.20 | 5.97 | 1721 |
| building | w1337809283 | building | 11.09 | 11.12 | 7.71 | 3.62 | 14 |
| building | w1337809284 | building | 10.35 | 10.39 | 7.51 | 2.88 | 12 |
| building | w1337809285 | building | 11.18 | 11.21 | 7.49 | 3.71 | 76 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 11.97 | 12.31 | 6.53 | 4.50 | 211 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 12.45 | 12.50 | 2.09 | 4.98 | 1899 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 10.53 | 10.63 | 6.44 | 3.06 | 291 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 12.45 | 12.50 | 2.39 | 4.98 | 1778 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 12.47 | 12.52 | 2.25 | 5.00 | 6701 |
| train_in_scan | (laser) | train standing during the scan (210.4 m × 2.8 m) | 10.14 | – | – | 3.35 | 992 |
| train_in_scan | (laser) | train standing during the scan (218.4 m × 2.7 m) | 11.01 | – | – | 4.03 | 843 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 2014 (track 7a,7b): laser gives 0.89 m above the track bed (≈0.71 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- Platform BIS 2127 (track 2a,2b): laser gives 1.00 m above the track bed (≈0.82 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- Platform BIS 2052 (track 3): laser gives 0.70 m above the track bed (≈0.52 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 0.59 m across the station (7.24–7.83 m); the station reference above is their median — check which level the app should use.
- w55897474 Gamla stationshuset (station building): p95 18.4 m is 6.4 m above the median 12.0 m (a taller neighbour or a mast inside the outline?).
- w207791536 Stationsgallerian (office): p95 34.6 m is 3.6 m above the median 31.0 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (197 m², top 3.1 m above the platform, 3.9 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 140 files found (68 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-03-19: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y21c037-66375_6475_25.copc.laz
  (scan 2021-03-19, nominal 1.2 points/m², flight height 3000 m; 692,348 points in the box,
  1.75 per m²; classes {'1': 274281, '2': 412077, '7': 368, '17': 5617, '18': 5}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 663_64 (2023-04-26), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=17.641506,59.853327,17.656721,59.861247, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
