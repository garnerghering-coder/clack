# Lahti (`fi:LH`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **103.73** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **103.03** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 89.34 – 110.76 (median 103.09) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 103.73.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_L4422H4, scanned 2022-07-01. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| LH L1 | 1 | korkea (0.55) | 451.0 | – | None | 102.97 | 103.59 | 0.62 | 0.45 |  |
| LH L4 | 4 | korkea (0.55) | 451.0 | – | None | 103.03 | 103.68 | 0.65 | 0.48 |  |
| LH L2 | 2 | korkea (0.55) | 270.0 | – | None | 103.04 | 103.78 | 0.74 | 0.56 |  |
| LH L3 | 3 | korkea (0.55) | 270.0 | – | None | 103.15 | 103.85 | 0.70 | 0.53 |  |

## Structures

`lahti_structures_heights.geojson`, 9 features: 5 building, 4 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w24057973 | Lahden rautatieasema (station building) | – | – | 99.32 | – | 2 |
| building | w46114845 | industrial | 115.46 | 118.53 | 102.84 | 11.73 | 9 |
| canopy_osm | w48767523 | roof | – | – | 102.88 | – | 1 |
| canopy_osm | w48767524 | roof | 108.41 | 108.43 | 103.10 | 4.68 | 7 |
| canopy_osm | w89209531 | roof | – | – | 103.26 | – | 2 |
| building | w543166740 | transportation | – | – | 104.23 | – | 4 |
| canopy_osm | w589490850 | roof | – | – | 104.73 | – | 4 |
| building | w1556036215 | building | – | – | 102.21 | – | 0 |
| building | w1556036216 | building | – | – | 102.11 | – | 0 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- none

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 52 files found (19 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2022-07-01: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_L4422H4), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned L4422H4 2022-07-01 (20220204_MGGP_Lahti_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2022-07-01; 108,344 points in the box, 0.57 per m²; classes {'1': 301, '2': 74064, '3': 310, '4': 3439, '5': 30230}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=25.652034,60.974265,25.666894,60.978216, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
