# Triangeln (`740001587`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **–** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **–** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.38 – 9.24 (median 6.84) | terrain model 616_37 (2025-09-28) |

Every height in the structures file becomes metres above the platform by subtracting –.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 25a003, scanned 2025-03-07. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2089 | 71 | mellan (0.58) | 250.0 | 14.5 | Tak | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |

## Structures

`triangeln_structures_heights.geojson`, 13 features: 10 building, 3 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w51459022 | apartments | 23.72 | 27.16 | 5.56 | – | 636 |
| building | w51459023 | office | 22.04 | 24.61 | 5.76 | – | 1036 |
| building | w53862960 | school | 25.26 | 29.29 | 6.10 | – | 4366 |
| building | w53862961 | school | 16.28 | 16.48 | 6.71 | – | 2090 |
| building | w53862964 | building | 22.53 | 25.96 | 4.65 | – | 3947 |
| building | w89370174 | school | 21.22 | 23.51 | 6.07 | – | 866 |
| building | w158755488 | Station Triangeln (station building) | 12.32 | 13.32 | 7.77 | – | 886 |
| building | w158755489 | Station Triangeln (station building) | 10.87 | 11.84 | 6.11 | – | 207 |
| building | w189510000 | Coffee Square (building) | 11.79 | 11.95 | 7.74 | – | 754 |
| canopy_osm | w232462620 | roof | 10.85 | 11.18 | 6.95 | – | 4513 |
| building | w1032365215 | building | 9.07 | 9.13 | 6.16 | – | 55 |
| canopy_osm | w1032365223 | shelter | 8.02 | 8.05 | 5.57 | – | 46 |
| canopy_osm | w1032365224 | shelter | 8.20 | 8.23 | 5.77 | – | 48 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w53862960 school: p95 29.3 m is 4.0 m above the median 25.3 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 144 files found (61 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-07: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y25a003-61600_3725_25.copc.laz, y25a003-61625_3725_25.copc.laz
  (scan 2025-03-07, nominal 1.8 points/m², flight height 2400 m; 514,623 points in the box,
  3.29 per m²; classes {'1': 249025, '2': 265157, '7': 416, '18': 25}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 616_37 (2025-09-28), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.996096,55.589844,13.005832,55.596480, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
