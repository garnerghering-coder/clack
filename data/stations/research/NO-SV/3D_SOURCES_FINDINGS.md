# Sandvika (`NO-SV`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **12.87** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **12.10** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -0.64 – 74.97 (median 8.86) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 12.87.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-s-/sandvika/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Bærum 2013, scanned 2013-04-27. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 1 | 1,2 | 700 (0.70) | 268.0 | 10.0 | None | 12.10 | 12.87 | 0.77 | 0.60 | platform surface from unclassified (class 1) laser points: this scan left the platform deck unclassified; flat band bed+0.2…+1.6 m |
| track 4 | 3,4 | 700 (0.70) | 268.0 | 10.0 | None | 12.10 | 12.87 | 0.77 | 0.60 | platform surface from unclassified (class 1) laser points: this scan left the platform deck unclassified; flat band bed+0.2…+1.6 m |

## Structures

`sandvika_structures_heights.geojson`, 12 features: 8 building, 1 footbridge, 1 canopy_osm, 1 canopy_laser.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w103142988 | office | 32.85 | 35.25 | 10.18 | 19.98 | 112 |
| building | w133659769 | station building | 16.27 | 24.28 | 12.10 | 3.40 | 35 |
| building | w187993308 | office | 18.72 | 20.63 | 11.94 | 5.85 | 131 |
| canopy_osm | w187993309 | roof | 9.90 | 10.27 | 6.33 | -2.97 | 2501 |
| building | w188026781 | transportation | 16.90 | 18.19 | 11.75 | 4.03 | 60 |
| building | w188026793 | transportation | 16.19 | 16.39 | 11.95 | 3.32 | 222 |
| footbridge | w328019637 | bridge | 12.38 | 13.66 | -0.30 | -0.49 | 6589 |
| building | w1033730390 | transportation | 16.99 | 17.07 | 12.09 | 4.12 | 157 |
| building | w1033730393 | transportation | 17.07 | 17.15 | 12.01 | 4.20 | 54 |
| building | w1033730394 | transportation | 17.02 | 17.11 | 12.05 | 4.15 | 96 |
| bridge | r10367706 | bridge | 5.72 | 11.89 | -0.41 | -7.15 | 1178 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 16.30 | 16.90 | 11.96 | 3.43 | 846 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w133659769 station building: p95 24.3 m is 8.0 m above the median 16.3 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): r10367706 (motorway).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 59 files found (3 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2013-04-27: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Bærum 2013" (id 122, FKB-Laser 2.0, nominal 5 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2013-04-27; 5,470,870 points in the box, 8.48 per m²; classes {'1': 3876461, '2': 1530580, '7': 3826, '10': 60003}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-s-/sandvika/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.517746,59.888903,10.533746,59.896903, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
