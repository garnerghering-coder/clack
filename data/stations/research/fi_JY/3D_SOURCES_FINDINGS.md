# Jyväskylä (`fi:JY`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **82.00** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **81.19** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 77.41 – 99.52 (median 81.47) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 82.00.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_N4324D1, scanned 2023-06-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| JY L1 | 1 | korkea (0.55) | 449.0 | – | None | 81.21 | 81.95 | 0.74 | 0.56 |  |
| JY L3 | 3 | korkea (0.55) | 186.0 | – | None | 81.18 | 82.01 | 0.83 | 0.65 |  |
| JY L24 | 24 | korkea (0.55) | 58.0 | – | None | 81.29 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| JY L4 | 4 | korkea (0.55) | 160.0 | – | None | 81.16 | 81.98 | 0.82 | 0.65 |  |
| JY L23 | 23 | korkea (0.55) | 57.0 | – | None | 81.25 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| JY L2 | 2 | korkea (0.55) | 433.0 | – | None | 81.18 | 82.01 | 0.83 | 0.65 |  |

## Structures

`jyvaskyla_structures_heights.geojson`, 25 features: 9 building, 3 footbridge, 11 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w13235730 | Jyväskylän matkakeskus (station building) | – | – | 98.88 | – | 2 |
| building | w52916189 | commercial | – | – | 86.69 | – | 0 |
| building | w119294895 | Kauppakeskus Forum (building) | 98.08 | 100.52 | 86.03 | 16.08 | 19 |
| building | w121549519 | Jyväskylän rautatieasema (station building) | 87.25 | 88.40 | 81.93 | 5.25 | 6 |
| building | w121549524 | building | 90.23 | 91.38 | 81.15 | 8.23 | 6 |
| building | w121549527 | retail | – | – | 82.22 | – | 1 |
| building | w121549540 | building | – | – | 81.37 | – | 4 |
| building | w122141263 | office | – | – | 86.60 | – | 1 |
| canopy_osm | w122158733 | roof | – | – | 82.50 | – | 2 |
| canopy_osm | w439373188 | roof | 85.66 | 86.20 | 81.73 | 3.66 | 37 |
| canopy_osm | w439373190 | roof | 85.69 | 86.15 | 81.16 | 3.69 | 26 |
| canopy_osm | w772254846 | roof | – | – | 80.30 | – | 0 |
| canopy_osm | w1057098071 | roof | – | – | 80.62 | – | 0 |
| footbridge | w1057626890 | Kilpisen silta (bridge) | 89.32 | 91.18 | 80.48 | 7.32 | 21 |
| footbridge | w1057626892 | bridge | 86.66 | 89.30 | 81.44 | 4.66 | 40 |
| footbridge | w1057626893 | bridge | – | – | 80.36 | – | 3 |
| canopy_osm | w1082148030 | roof | – | – | 86.32 | – | 0 |
| canopy_osm | w1082148031 | roof | – | – | 86.35 | – | 1 |
| canopy_osm | w1082148032 | roof | – | – | 86.01 | – | 0 |
| canopy_osm | w1082148033 | building | – | – | 85.26 | – | 2 |
| canopy_osm | w1082149324 | building | – | – | 81.87 | – | 2 |
| bridge | w1107068872 | bridge | 87.18 | 87.75 | 82.25 | 5.18 | 7 |
| building | w1126980916 | building | – | – | 81.68 | – | 1 |
| canopy_osm | r2065832 | roof | – | – | 81.17 | – | 4 |
| train_in_scan | (laser) | train standing during the scan (56.5 m × 2.7 m) | 85.19 | – | – | 4.00 | 85 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1107068872 (footway, service).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (55 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-06-10: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_N4324D1), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned N4324D1 2023-06-10 (20230202_Swissphoto_Jyvaskyla_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2023-06-10; 186,379 points in the box, 0.54 per m²; classes {'1': 924, '2': 109244, '3': 384, '4': 4895, '5': 70932}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=25.746788,62.237407,25.760451,62.244045, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
