# Nationaltheatret (`NO-NTH`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **–** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **–** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -1.35 – 36.98 (median 21.76) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting –.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/reise-og-trafikk/stasjoner/-n-/nationaltheatret/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Oslo kommune tynnet laserskanning 2019, scanned 2019-09-14. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track N1 | N1,N2 | 700 (0.70) | 244.0 | 11.0 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| track N3 | N3,N4 | 700 (0.70) | 251.0 | 11.0 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |

## Structures

`nationaltheatret_structures_heights.geojson`, 21 features: 17 building, 2 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w5042466 | hotel | – | – | 19.02 | – | 3 |
| building | w44278259 | office | 33.81 | 33.88 | 5.78 | – | 14 |
| building | w44278268 | office | – | – | 6.33 | – | 4 |
| building | w44278278 | building | 30.12 | 30.20 | 6.72 | – | 14 |
| building | w44278280 | office | 34.76 | 35.86 | 5.11 | – | 14 |
| building | w89541284 | Oslo ingeniørhøgskole (school) | 33.37 | 33.54 | 12.39 | – | 21 |
| building | w90768977 | office | 34.73 | 39.73 | 21.16 | – | 6 |
| building | w90768997 | retail | 39.37 | 42.54 | 21.38 | – | 35 |
| building | w90967640 | office | – | – | 1.76 | – | 2 |
| building | w101782993 | station | – | – | 11.25 | – | 1 |
| building | w118749662 | office | 29.17 | 29.47 | 24.81 | – | 5 |
| building | w118749690 | office | – | – | 25.75 | – | 2 |
| building | w669303852 | retail | 30.85 | 31.04 | 6.01 | – | 6 |
| building | w1040907079 | building | – | – | 2.17 | – | 0 |
| building | w1040907081 | House of Oslo (building) | – | – | -1.33 | – | 3 |
| building | w1040907082 | office | – | – | -1.33 | – | 3 |
| canopy_osm | w1040907160 | building | – | – | 30.95 | – | 2 |
| building | w1041214399 | office | – | – | 5.81 | – | 2 |
| canopy_osm | w1298205656 | roof | – | – | 6.94 | – | 0 |
| bridge | w1523490311 | bridge | – | – | 26.88 | – | 1 |
| bridge | r14170557 | bridge | – | – | 2.60 | – | 4 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- OSM platform outline w312826116 (ref 1, 412 m²) beside the tracks has no Bane NOR Sportabell row matched to it: check the table (https://www.banenor.no/reise-og-trafikk/stasjoner/-n-/nationaltheatret/)
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1523490311 (no mapped ways); r14170557 (footway, tertiary, trunk, trunk_link).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (1 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2019-09-14: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Oslo kommune tynnet laserskanning 2019" (id 1175, FKB-Laser 3.0, nominal 0.5 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2019-09-14; 558,998 points in the box, 1.32 per m²; classes {'1': 200888, '2': 357316, '17': 794}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/reise-og-trafikk/stasjoner/-n-/nationaltheatret/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.721133,59.911390,10.735133,59.919390, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
