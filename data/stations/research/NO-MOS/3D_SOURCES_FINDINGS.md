# Moss (`NO-MOS`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **4.55** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **3.91** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -0.46 – 35.06 (median 8.34) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 4.55.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-m-/moss/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Moss Done FOU 2020, scanned 2020. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 1 | 1 | 470 (0.47) | 254.0 | 6.4 | None | 3.91 | 4.51 | 0.61 | 0.43 |  |
| track 2 | 2,3 | 600 (0.60) | 238.0 | 5.4 | None | 3.91 | 4.59 | 0.68 | 0.51 |  |

## Structures

`moss_structures_heights.geojson`, 13 features: 4 building, 5 canopy_osm, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w437723021 | Moss (station building) | 12.43 | 16.71 | 4.20 | 7.88 | 7063 |
| building | w437723023 | transportation | 8.90 | 13.41 | 3.02 | 4.35 | 2909 |
| bridge | w476289098 | Kanalbrua (bridge) | 8.45 | 12.84 | -0.20 | 3.90 | 1144 |
| canopy_osm | w485824964 | roof | – | – | – | – | 0 |
| building | w975316217 | building | 11.37 | 15.68 | 3.70 | 6.82 | 1513 |
| building | w975317823 | transportation | 7.45 | 9.38 | 2.37 | 2.90 | 1425 |
| bridge | w1058592682 | Rådhusbrua (bridge) | 10.21 | 13.08 | 3.22 | 5.66 | 21510 |
| canopy_osm | w1090144086 | roof | 8.67 | 8.74 | 2.44 | 4.12 | 5051 |
| canopy_osm | w1207616096 | building | 18.01 | 18.29 | 14.97 | 13.46 | 1131 |
| canopy_osm | w1219631351 | building | 13.56 | 20.85 | 4.50 | 9.01 | 192 |
| canopy_osm | w1219890829 | building | 7.09 | 13.81 | 4.56 | 2.54 | 176 |
| train_in_scan | (laser) | train standing during the scan (142.5 m × 2.9 m) | 7.91 | – | – | 4.04 | 12804 |
| train_in_scan | (laser) | train standing during the scan (88.3 m × 2.7 m) | 7.90 | – | – | 4.04 | 2646 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w437723021 Moss (station building): p95 16.7 m is 4.3 m above the median 12.4 m (a taller neighbour or a mast inside the outline?).
- w437723023 transportation: p95 13.4 m is 4.5 m above the median 8.9 m (a taller neighbour or a mast inside the outline?).
- w975316217 building: p95 15.7 m is 4.3 m above the median 11.4 m (a taller neighbour or a mast inside the outline?).
- w1219631351 building: p95 20.9 m is 7.3 m above the median 13.6 m (a taller neighbour or a mast inside the outline?).
- w1219890829 building: p95 13.8 m is 6.7 m above the median 7.1 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w476289098 Kanalbrua (footway, primary); w1058592682 Rådhusbrua (footway, trunk).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (18 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Moss Done FOU 2020" (id 4249, FKB-Laser 3.0, nominal 5 points/m², supplier Statens Kartverk), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2020; 18,700,717 points in the box, 17.63 per m²; classes {'1': 5660978, '2': 5750917, '5': 4138354, '6': 3150468}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-m-/moss/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.648334,59.426850,10.666334,59.436850, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
