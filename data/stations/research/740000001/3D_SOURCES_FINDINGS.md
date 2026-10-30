# Stockholm C (`740000001`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **4.48** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **3.64** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -3.31 – 29.32 (median 5.02) | terrain model 658_67 (2023-04-27) |

Every height in the structures file becomes metres above the platform by subtracting 4.48.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 21c031, scanned 2021-03-23. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1602 | E6n,E6s | mellan (0.58) | 357.0 | – | Tak | 2.53 | 3.37 | 0.84 | 0.66 |  |
| 2511 | 4 | mellan (0.58) | 460.0 | 6.6 | Tak | 11.37 | – | – | – | 'track bed' here is 11.37 m, +7.6 m from the station's median 3.75 m: the ground-class points over this track are a deck, roof or bridge, not the bed; values left out |
| 1450 | ? | ej norm (–) | 366.0 | – | Tak | – | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 2510 | 6 | mellan (0.58) | 396.0 | 7.0 | Tak | 11.48 | – | – | – | 'track bed' here is 11.48 m, +7.7 m from the station's median 3.75 m: the ground-class points over this track are a deck, roof or bridge, not the bed; values left out |
| 726 | 6 | hög (0.73) | 320.3 | – | Tak | 11.49 | – | – | – | 'track bed' here is 11.49 m, +7.7 m from the station's median 3.75 m: the ground-class points over this track are a deck, roof or bridge, not the bed; values left out |
| 729 | 10 | hög (0.73) | 414.0 | – | Tak | 3.54 | 4.36 | 0.82 | 0.65 |  |
| 731 | 11 | hög (0.73) | 288.0 | – | Tak | 3.55 | 4.39 | 0.84 | 0.66 |  |
| 736 | 17a | hög (0.73) | 354.0 | – | Tak | 10.78 | – | – | – | 'track bed' here is 10.78 m, +7.0 m from the station's median 3.75 m: the ground-class points over this track are a deck, roof or bridge, not the bed; values left out |
| 738 | 19a | mellan (0.58) | 210.0 | – | Tak | 3.75 | 4.72 | 0.97 | 0.80 |  |
| 733 | 14a | mellan (0.58) | 282.0 | – | Tak | 3.64 | 4.48 | 0.84 | 0.67 |  |
| 735 | 16a | mellan (0.58) | 268.0 | – | Skydd | 10.86 | – | – | – | 'track bed' here is 10.86 m, +7.1 m from the station's median 3.75 m: the ground-class points over this track are a deck, roof or bridge, not the bed; values left out |
| 2009 | 10 | låg (0.35) | 30.0 | 4.0 | Tak | 3.73 | 4.53 | 0.80 | 0.63 |  |
| 2010 | 11 | låg (0.35) | 40.0 | 5.0 | Tak | 3.75 | 4.55 | 0.80 | 0.63 |  |

## Structures

`stockholm_c_structures_heights.geojson`, 38 features: 19 building, 1 footbridge, 5 canopy_osm, 1 canopy_laser, 3 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w24210274 | Åhléns (retail) | 32.52 | 35.36 | 5.82 | 28.04 | 8024 |
| building | w24210353 | Vårdcentralen Serafen (building) | 20.77 | 26.29 | 3.26 | 16.29 | 3406 |
| building | w27590873 | office | 30.73 | 34.31 | 5.57 | 26.25 | 6860 |
| building | w34510971 | office | 32.20 | 38.58 | 2.51 | 27.72 | 5278 |
| building | w35105930 | Kulturstation (building) | 20.66 | 23.20 | 3.26 | 16.18 | 531 |
| building | w35140092 | Cityterminalen (transportation) | 34.36 | 40.81 | 2.63 | 29.88 | 24874 |
| building | w35473137 | Stockholms centralstation (station building) | 18.51 | 26.82 | 1.83 | 14.03 | 32389 |
| building | w205673186 | office | 27.11 | 27.25 | 5.42 | 22.63 | 284 |
| building | w232363414 | Stockholm Waterfront (hotel) | 34.05 | 55.53 | 2.20 | 29.57 | 12405 |
| canopy_osm | w238753105 | roof | 17.36 | 18.26 | 2.98 | 12.88 | 1071 |
| building | w246582963 | station building | 20.83 | 29.36 | 10.39 | 16.35 | 259 |
| canopy_osm | w367551885 | roof | 10.38 | 10.88 | 2.56 | 5.90 | 2201 |
| bridge | w379709843 | Centralbron (bridge) | 5.97 | 13.58 | 0.83 | 1.49 | 275 |
| bridge | w379709844 | Norra Järnvägsbron (bridge) | 5.96 | 13.72 | 0.83 | 1.48 | 460 |
| footbridge | w379709845 | bridge | 3.31 | 4.93 | 0.89 | -1.18 | 138 |
| building | w382519364 | transportation | 7.24 | 7.60 | 3.93 | 2.76 | 37 |
| bridge | w427926627 | bridge | 14.68 | 38.43 | 0.89 | 10.20 | 4802 |
| bridge | w431979873 | bridge | 19.13 | 20.59 | -0.36 | 14.65 | 123 |
| building | w550463199 | retail | 34.76 | 37.93 | 4.04 | 30.28 | 8339 |
| bridge | w587808099 | Kungsbron (bridge) | 16.62 | 34.99 | 0.89 | 12.14 | 1518 |
| bridge | w633436996 | Stadshusbron (bridge) | 6.81 | 7.61 | 0.89 | 2.33 | 79 |
| bridge | w906374987 | bridge | 31.23 | 35.05 | 2.96 | 26.75 | 1684 |
| building | w1242589614 | building | 54.83 | 55.85 | 2.20 | 50.35 | 3172 |
| building | w1242589615 | building | 34.06 | 55.54 | 2.20 | 29.58 | 12422 |
| building | w1242589616 | building | 54.75 | 55.69 | 2.67 | 50.27 | 2067 |
| building | w1242589617 | building | 33.69 | 36.97 | 3.62 | 29.21 | 2512 |
| building | w1347816851 | building | 35.22 | 42.30 | 6.28 | 30.74 | 19882 |
| building | w1347816852 | office | 35.22 | 42.30 | 6.28 | 30.74 | 19882 |
| canopy_osm | w1420764456 | roof | 10.92 | 19.13 | 3.51 | 6.44 | 468 |
| canopy_osm | w1420764468 | roof | 9.19 | 9.34 | 2.54 | 4.71 | 1274 |
| canopy_osm | w1469194602 | roof | 17.00 | 29.60 | 3.46 | 12.52 | 445 |
| bridge | w1469194608 | bridge | 18.52 | 30.38 | 2.38 | 14.04 | 3645 |
| bridge | w1469194609 | bridge | 15.55 | 35.06 | 0.50 | 11.07 | 1494 |
| building | w1469207745 | office | 37.56 | 37.90 | 11.44 | 33.08 | 109 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 10.20 | 11.01 | 3.54 | 5.72 | 98 |
| train_in_scan | (laser) | train standing during the scan (35.3 m × 2.6 m) | 7.79 | – | – | 4.37 | 63 |
| train_in_scan | (laser) | train standing during the scan (57.8 m × 3.2 m) | 7.73 | – | – | 4.40 | 112 |
| train_in_scan | (laser) | train standing during the scan (37.7 m × 3.4 m) | 8.14 | – | – | 4.12 | 185 |

## Trains in the scan

3 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 738 (track 19a): laser gives 0.97 m above the track bed (≈0.80 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- Platform BIS 2009 (track 10): laser gives 0.80 m above the track bed (≈0.63 m above rail after −0.15…0.2 m), register class låg = 0.35 m. Not decided; add to REVIEW.md.
- Platform BIS 2010 (track 11): laser gives 0.80 m above the track bed (≈0.63 m above rail after −0.15…0.2 m), register class låg = 0.35 m. Not decided; add to REVIEW.md.
- Platform BIS 2511 (track 4): the laser 'ground' over the track is +7.6 m from the other tracks (deck or roof over the tracks?): not measured.
- Platform BIS 2510 (track 6): the laser 'ground' over the track is +7.7 m from the other tracks (deck or roof over the tracks?): not measured.
- Platform BIS 726 (track 6): the laser 'ground' over the track is +7.7 m from the other tracks (deck or roof over the tracks?): not measured.
- Platform BIS 736 (track 17a): the laser 'ground' over the track is +7.0 m from the other tracks (deck or roof over the tracks?): not measured.
- Platform BIS 735 (track 16a): the laser 'ground' over the track is +7.1 m from the other tracks (deck or roof over the tracks?): not measured.
- Platform surfaces differ by 1.35 m across the station (3.37–4.72 m); the station reference above is their median — check which level the app should use.
- w24210353 Vårdcentralen Serafen (building): p95 26.3 m is 5.5 m above the median 20.8 m (a taller neighbour or a mast inside the outline?).
- w35140092 Cityterminalen (transportation): p95 40.8 m is 6.5 m above the median 34.4 m (a taller neighbour or a mast inside the outline?).
- w35473137 Stockholms centralstation (station building): p95 26.8 m is 8.3 m above the median 18.5 m (a taller neighbour or a mast inside the outline?).
- w232363414 Stockholm Waterfront (hotel): p95 55.5 m is 21.5 m above the median 34.0 m (a taller neighbour or a mast inside the outline?).
- w246582963 station building: p95 29.4 m is 8.5 m above the median 20.8 m (a taller neighbour or a mast inside the outline?).
- w1242589615 building: p95 55.5 m is 21.5 m above the median 34.1 m (a taller neighbour or a mast inside the outline?).
- w1242589617 building: p95 37.0 m is 3.3 m above the median 33.7 m (a taller neighbour or a mast inside the outline?).
- w1420764456 roof: p95 19.1 m is 8.2 m above the median 10.9 m (a taller neighbour or a mast inside the outline?).
- w1469194602 roof: p95 29.6 m is 12.6 m above the median 17.0 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w379709843 Centralbron (trunk); w379709844 Norra Järnvägsbron (no mapped ways); w427926627 (cycleway, footway, platform, residential, service, trunk_link, unclassified); w431979873 (cycleway, footway, tertiary); w587808099 Kungsbron (footway, residential, secondary, secondary_link, service, tertiary); w633436996 Stadshusbron (cycleway, footway, tertiary); w906374987 (unclassified); w1469194608 (footway, service); w1469194609 (pedestrian, service).
- Laser-traced roof (50 m², top 5.7 m above the platform, 6.6 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 148 files found (124 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-03-23: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y21c031-65800_6725_25.copc.laz
  (scan 2021-03-23, nominal 1.2 points/m², flight height 3200 m; 1,440,368 points in the box,
  1.88 per m²; classes {'1': 877618, '2': 479917, '7': 3860, '9': 1149, '17': 76585, '18': 1239}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 658_67 (2023-04-27), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
