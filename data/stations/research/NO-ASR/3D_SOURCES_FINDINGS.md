# Asker (`NO-ASR`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **105.44** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **104.38** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 85.89 – 169.95 (median 110.48) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 105.44.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-a-/asker/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Asker 2012, scanned 2012-08-21. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 1 | 1 | 700 (0.70) | 354.0 | 10.0 | None | 104.21 | 105.00 | 0.79 | 0.61 |  |
| track 3 | 2,3 | 700 (0.70) | 365.0 | 8.5 | None | 104.36 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| track 4 | 4,5 | 700 (0.70) | 261.0 | 10.0 | None | 104.41 | 105.46 | 1.05 | 0.87 | platform surface from unclassified (class 1) laser points: this scan left the platform deck unclassified; flat band bed+0.2…+1.6 m |
| track 6 | 6 | 700 (0.70) | 259.0 | 5.0 | None | 104.46 | 105.44 | 0.98 | 0.80 |  |

## Structures

`asker_structures_heights.geojson`, 19 features: 12 building, 3 canopy_osm, 2 hall_roof_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w87870849 | parking | 116.38 | 116.49 | 103.17 | 10.94 | 3904 |
| building | w92350484 | Galleri Trafo (civic) | 120.07 | 123.97 | 108.50 | 14.63 | 1897 |
| building | w92350485 | apartments | 120.09 | 120.62 | 110.90 | 14.65 | 1503 |
| building | w92351813 | station building | 111.98 | 113.30 | 103.77 | 6.54 | 2720 |
| building | w126671122 | parking | 111.01 | 113.06 | 105.35 | 5.57 | 1112 |
| building | w152904610 | Asker brannstasjon (fire_station) | 126.53 | 130.27 | 119.66 | 21.09 | 1595 |
| building | w306981117 | transportation | 107.97 | 108.06 | 104.06 | 2.53 | 369 |
| building | w306981118 | transportation | 109.01 | 109.52 | 104.08 | 3.57 | 34 |
| canopy_osm | w306981119 | roof | 109.00 | 112.81 | 104.34 | 3.56 | 18 |
| canopy_osm | w306981121 | roof | 109.49 | 109.73 | 103.89 | 4.05 | 375 |
| building | w521781827 | Prehospital Divisjon Asker Ambulansene (ambulance_station) | – | – | 119.89 | – | 0 |
| building | w565834708 | building | 108.07 | 108.18 | 104.17 | 2.63 | 379 |
| building | w1014090512 | service | 107.37 | 112.99 | 104.98 | 1.93 | 103 |
| building | w1014164180 | religious | – | – | 103.74 | – | 0 |
| canopy_osm | w1234302109 | roof | – | – | 122.11 | – | 0 |
| bridge | w1550572574 | bridge | 105.32 | 106.45 | 102.45 | -0.12 | 62 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 112.87 | 113.23 | 104.16 | 7.43 | 7084 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 112.20 | 112.77 | 103.70 | 6.76 | 18258 |
| train_in_scan | (laser) | train standing during the scan (85.7 m × 2.9 m) | 108.39 | – | – | 3.87 | 2063 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS track 4 (track 4,5): laser gives 1.05 m above the track bed (≈0.87 m above rail after −0.15…0.2 m), register class 700 = 0.7 m. Not decided; add to REVIEW.md.
- w152904610 Asker brannstasjon (fire_station): p95 130.3 m is 3.7 m above the median 126.5 m (a taller neighbour or a mast inside the outline?).
- w306981119 roof: p95 112.8 m is 3.8 m above the median 109.0 m (a taller neighbour or a mast inside the outline?).
- w1014090512 service: p95 113.0 m is 5.6 m above the median 107.4 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1550572574 (footway, unclassified).
- Laser-traced roof (776 m², top 7.4 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (1330 m², top 6.8 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (1330 m², top 6.8 m above the platform, 7.8 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 15 files found (4 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2012-08-21: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Asker 2012" (id 123, FKB-Laser 2.0, nominal 10 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2012-08-21; 15,868,733 points in the box, 16.62 per m²; classes {'1': 13447772, '2': 2371843, '7': 7261, '10': 41857}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-a-/asker/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.426492,59.829343,10.442492,59.837343, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
