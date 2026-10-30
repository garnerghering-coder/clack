# Lysaker (`NO-LYS`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **13.82** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **12.97** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -0.62 – 43.91 (median 13.88) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 13.82.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-l-/lysaker/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Bærum 2013, scanned 2013-04-27. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 2 | 1,2 | 700 (0.70) | 280.0 | 13.0 | None | 12.88 | 13.63 | 0.75 | 0.57 |  |
| track 3 | 3,4 | 700 (0.70) | 266.0 | 13.0 | None | 13.06 | 14.00 | 0.94 | 0.76 |  |

## Structures

`lysaker_structures_heights.geojson`, 28 features: 6 building, 3 footbridge, 11 canopy_osm, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w87337531 | office | 16.08 | 26.63 | 2.05 | 2.26 | 1437 |
| building | w132005661 | service | 7.94 | 10.54 | 0.39 | -5.88 | 616 |
| canopy_osm | w133662619 | roof | 19.10 | 20.05 | 12.79 | 5.28 | 1225 |
| canopy_osm | w134146574 | roof | 19.76 | 20.49 | 12.84 | 5.94 | 1472 |
| building | w151379087 | Lysaker Mølle (office) | 12.79 | 16.21 | 1.10 | -1.03 | 263 |
| building | w151379097 | residential | 14.81 | 15.29 | 7.65 | 0.99 | 236 |
| building | w151379098 | residential | 14.73 | 16.62 | 7.19 | 0.91 | 269 |
| bridge | w385726720 | bridge | 25.71 | 27.61 | 13.80 | 11.89 | 43 |
| bridge | w462374406 | bridge | – | – | -0.42 | – | 0 |
| bridge | w816331430 | Lysaker bru (bridge) | 12.37 | 14.21 | -0.24 | -1.45 | 94 |
| bridge | w816331431 | bridge | 19.73 | 21.91 | -0.33 | 5.91 | 553 |
| bridge | w1112574629 | bridge | – | – | -0.23 | – | 0 |
| canopy_osm | w1449640469 | roof | 10.50 | 10.58 | 7.98 | -3.32 | 20 |
| canopy_osm | w1449640470 | roof | 10.57 | 10.88 | 7.76 | -3.25 | 34 |
| canopy_osm | w1449640471 | roof | 9.59 | 9.68 | 6.94 | -4.23 | 23 |
| canopy_osm | w1449640472 | roof | 9.35 | 9.41 | 6.73 | -4.47 | 22 |
| canopy_osm | w1449640473 | roof | 10.78 | 10.98 | 7.45 | -3.04 | 40 |
| canopy_osm | w1449640474 | roof | 11.29 | 11.59 | 7.95 | -2.54 | 50 |
| canopy_osm | w1454354947 | roof | 4.36 | 4.53 | 1.19 | -9.46 | 76 |
| canopy_osm | w1454354948 | building | 4.12 | 4.30 | 1.19 | -9.70 | 107 |
| building | w1455526748 | building | 22.85 | 40.21 | 8.25 | 9.03 | 94 |
| canopy_osm | w1461438200 | roof | – | – | 37.87 | – | 0 |
| footbridge | w1567953577 | bridge | 16.96 | 17.20 | 6.11 | 3.14 | 6 |
| footbridge | w1567953578 | Møllefossen bro (bridge) | 11.20 | 11.81 | 5.23 | -2.62 | 54 |
| footbridge | w1567953579 | bridge | – | – | – | – | 0 |
| bridge | w1568184890 | bridge | 14.04 | 18.98 | -0.38 | 0.22 | 1026 |
| train_in_scan | (laser) | train standing during the scan (75.6 m × 3.0 m) | 17.06 | – | – | 4.07 | 1777 |
| train_in_scan | (laser) | train standing during the scan (76.0 m × 2.9 m) | 17.12 | – | – | 4.14 | 1849 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w385726720 (cycleway, residential, secondary); w462374406 (footway, secondary); w816331430 Lysaker bru (trunk); w816331431 (no mapped ways); w1112574629 (footway, secondary, tertiary); w1568184890 (service).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (2 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2013-04-27: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Bærum 2013" (id 122, FKB-Laser 2.0, nominal 5 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2013-04-27; 3,972,073 points in the box, 6.16 per m²; classes {'1': 2656356, '2': 1251875, '7': 5410, '10': 58432}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-l-/lysaker/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.630247,59.909446,10.644247,59.917446, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
