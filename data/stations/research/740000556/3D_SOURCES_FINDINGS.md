# Arlanda C (`740000556`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **–** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **–** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 26.96 – 34.96 (median 31.34) | terrain model 661_66 (2023-05-16) |

Every height in the structures file becomes metres above the platform by subtracting –.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 21c038, scanned 2021-04-17. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2306 | 7 | hög (0.73) | – | – | ? | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| 2307 | 2 | hög (0.73) | – | – | ? | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| 2305 | 5 | hög (0.73) | – | – | ? | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |

## Structures

`arlanda_c_structures_heights.geojson`, 37 features: 12 building, 25 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w4967023 | Terminal 2 (International) (building) | 50.21 | 54.49 | 30.53 | – | 16207 |
| building | w24478711 | Terminal 4 (building) | 44.32 | 48.03 | 31.64 | – | 8168 |
| building | w24478732 | Skycity (retail) | 49.82 | 50.21 | 30.64 | – | 21849 |
| building | w51990808 | transportation | 37.68 | 41.25 | 31.02 | – | 413 |
| building | w104015759 | building | 40.05 | 44.13 | 29.89 | – | 5780 |
| building | w104015817 | P22 (building) | 42.47 | 47.78 | 30.45 | – | 916 |
| canopy_osm | w227007943 | roof | 35.26 | 35.66 | 31.22 | – | 116 |
| canopy_osm | w227007945 | roof | 35.25 | 35.65 | 31.27 | – | 112 |
| building | w227068741 | building | 42.21 | 46.44 | 28.63 | – | 5095 |
| canopy_osm | w415833741 | roof | 35.00 | 35.20 | 30.93 | – | 13 |
| canopy_osm | w415833742 | roof | 36.18 | 36.42 | 31.92 | – | 228 |
| building | w487787893 | transportation | 39.50 | 43.29 | 30.61 | – | 109 |
| building | w681332703 | construction | 36.90 | 37.21 | 31.32 | – | 114 |
| canopy_osm | w713952882 | roof | 35.03 | 35.36 | 31.04 | – | 106 |
| canopy_osm | w713952883 | building | 34.36 | 35.58 | 31.53 | – | 111 |
| canopy_osm | w713952886 | roof | 34.71 | 34.93 | 30.84 | – | 92 |
| canopy_osm | w713952887 | roof | 35.14 | 35.28 | 31.61 | – | 315 |
| building | w727421425 | Terminal 5 (International) (building) | 45.45 | 50.23 | 30.60 | – | 30855 |
| building | w727421426 | building | 46.94 | 50.41 | 30.58 | – | 10753 |
| canopy_osm | w1415784685 | roof | 34.95 | 35.95 | 29.89 | – | 745 |
| canopy_osm | w1415784686 | roof | 35.26 | 35.96 | 31.53 | – | 992 |
| canopy_osm | w1415784688 | shelter | 40.40 | 40.46 | 31.04 | – | 7 |
| canopy_osm | w1415784689 | shelter | 40.36 | 40.51 | 31.13 | – | 5 |
| canopy_osm | w1415784690 | shelter | 40.45 | 40.48 | 31.16 | – | 6 |
| canopy_osm | w1415784696 | shelter | 40.28 | 40.33 | 31.08 | – | 8 |
| canopy_osm | w1415784712 | shelter | 34.32 | 34.36 | 31.62 | – | 11 |
| canopy_osm | w1415784713 | shelter | 34.11 | 34.15 | 31.55 | – | 8 |
| canopy_osm | w1415784714 | shelter | 34.01 | 34.08 | 31.56 | – | 7 |
| canopy_osm | w1415784715 | shelter | 34.25 | 34.28 | 31.83 | – | 8 |
| canopy_osm | w1415784716 | shelter | 34.52 | 34.55 | 31.89 | – | 11 |
| canopy_osm | w1415784717 | shelter | 34.40 | 34.44 | 31.65 | – | 9 |
| canopy_osm | w1415784740 | shelter | 40.30 | 40.84 | 30.94 | – | 13 |
| canopy_osm | w1415784741 | shelter | 40.30 | 40.34 | 30.92 | – | 12 |
| canopy_osm | w1415784742 | shelter | 40.23 | 40.34 | 31.08 | – | 9 |
| canopy_osm | w1415784743 | shelter | 40.25 | 40.37 | 31.03 | – | 13 |
| canopy_osm | w1415784744 | shelter | 40.17 | 40.36 | 30.98 | – | 16 |
| building | w1415784760 | transportation | 43.68 | 68.51 | 30.52 | – | 2265 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w4967023 Terminal 2 (International) (building): p95 54.5 m is 4.3 m above the median 50.2 m (a taller neighbour or a mast inside the outline?).
- w24478711 Terminal 4 (building): p95 48.0 m is 3.7 m above the median 44.3 m (a taller neighbour or a mast inside the outline?).
- w51990808 transportation: p95 41.3 m is 3.6 m above the median 37.7 m (a taller neighbour or a mast inside the outline?).
- w104015759 building: p95 44.1 m is 4.1 m above the median 40.0 m (a taller neighbour or a mast inside the outline?).
- w104015817 P22 (building): p95 47.8 m is 5.3 m above the median 42.5 m (a taller neighbour or a mast inside the outline?).
- w227068741 building: p95 46.4 m is 4.2 m above the median 42.2 m (a taller neighbour or a mast inside the outline?).
- w487787893 transportation: p95 43.3 m is 3.8 m above the median 39.5 m (a taller neighbour or a mast inside the outline?).
- w727421425 Terminal 5 (International) (building): p95 50.2 m is 4.8 m above the median 45.5 m (a taller neighbour or a mast inside the outline?).
- w727421426 building: p95 50.4 m is 3.5 m above the median 46.9 m (a taller neighbour or a mast inside the outline?).
- w1415784760 transportation: p95 68.5 m is 24.8 m above the median 43.7 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 149 files found (36 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-04-17: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y21c038-66150_6625_25.copc.laz, y21c038-66150_6650_25.copc.laz
  (scan 2021-04-17, nominal 1.2 points/m², flight height 3000 m; 545,984 points in the box,
  1.63 per m²; classes {'1': 196594, '2': 320676, '7': 377, '17': 28337}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 661_66 (2023-05-16), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
