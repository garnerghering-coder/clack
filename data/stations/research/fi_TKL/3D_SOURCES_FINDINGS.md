# Tikkurila (`fi:TKL`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **20.01** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **19.23** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 8.41 – 28.78 (median 19.09) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 20.01.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_L4134D3, clack_fi_mml05_L4134F1, scanned 2024-06-15. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| TKL L6 | 6 | korkea (0.55) | 320.0 | – | None | 19.21 | 20.01 | 0.80 | 0.63 |  |
| TKL L5 | 5 | korkea (0.55) | 338.0 | – | None | 19.23 | 19.99 | 0.76 | 0.59 |  |
| TKL L4 | 4 | korkea (0.55) | 320.0 | – | None | 19.09 | 19.95 | 0.86 | 0.68 |  |
| TKL L3 | 3 | korkea (0.55) | 423.0 | – | None | 19.24 | 20.00 | 0.76 | 0.58 |  |
| TKL L2 | 2 | korkea (0.55) | 461.0 | – | None | 19.29 | 20.01 | 0.72 | 0.55 |  |
| TKL L1 | 1 | korkea (0.55) | 415.0 | – | None | 19.36 | 20.19 | 0.83 | 0.66 |  |

## Structures

`tikkurila_structures_heights.geojson`, 35 features: 26 building, 7 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w30741359 | school | – | – | 18.61 | – | 4 |
| building | w41143470 | Tikkurilan vanha rautatieasema (station building) | – | – | 17.94 | – | 2 |
| building | w320920450 | apartments | – | – | 18.00 | – | 4 |
| canopy_osm | w322098855 | roof | – | – | – | – | 0 |
| canopy_osm | w322534933 | roof | 23.78 | 24.43 | 18.94 | 3.77 | 24 |
| canopy_osm | w322534936 | roof | 23.76 | 23.95 | 18.92 | 3.75 | 30 |
| building | w369130582 | Tikkurilan rautatieasema (station building) | – | – | 19.02 | – | 4 |
| canopy_osm | w384000586 | roof | 23.69 | 24.04 | 18.89 | 3.68 | 24 |
| building | w395601806 | building | – | – | 19.09 | – | 0 |
| building | w395601987 | building | – | – | 19.87 | – | 0 |
| building | w395602364 | building | – | – | 19.13 | – | 0 |
| building | w395602460 | transportation | – | – | 19.50 | – | 0 |
| building | w395602461 | building | – | – | 19.80 | – | 0 |
| building | w395603388 | transportation | – | – | 19.55 | – | 1 |
| building | w395603389 | transportation | – | – | 19.66 | – | 0 |
| building | w395603615 | transportation | – | – | 19.74 | – | 1 |
| building | w395603617 | transportation | – | – | 19.65 | – | 1 |
| building | w395603805 | building | – | – | – | – | 0 |
| building | w395603996 | Dixi (retail) | 37.50 | 67.64 | 18.62 | 17.49 | 22 |
| building | w395604698 | Dixi (building) | – | – | – | – | 0 |
| building | w395611858 | building | – | – | – | – | 0 |
| building | w395613145 | building | – | – | – | – | 0 |
| building | w395613156 | building | 38.69 | 42.91 | 19.08 | 18.68 | 8 |
| building | w395613192 | building | 35.60 | 36.22 | 19.31 | 15.59 | 7 |
| building | w395613727 | bridge | – | – | 19.73 | – | 4 |
| building | w395613728 | transportation | – | – | 19.79 | – | 0 |
| building | w395613730 | transportation | – | – | 19.77 | – | 0 |
| building | w445291692 | building | – | – | 19.41 | – | 0 |
| building | w445292038 | building | – | – | 19.11 | – | 4 |
| building | w445703134 | building | – | – | 18.90 | – | 0 |
| bridge | w888214611 | bridge | – | – | 19.32 | – | 0 |
| canopy_osm | w918183677 | roof | – | – | 18.45 | – | 0 |
| canopy_osm | w921222106 | roof | – | – | 18.70 | – | 1 |
| canopy_osm | w1528999292 | roof | – | – | 18.28 | – | 0 |
| train_in_scan | (laser) | train standing during the scan (72.7 m × 3.1 m) | 22.78 | – | – | 3.55 | 134 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS TKL L4 (track 4): laser gives 0.86 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- w395603996 Dixi (retail): p95 67.6 m is 30.1 m above the median 37.5 m (a taller neighbour or a mast inside the outline?).
- w395613156 building: p95 42.9 m is 4.2 m above the median 38.7 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w888214611 (cycleway, residential).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (56 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-06-15: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_L4134D3, clack_fi_mml05_L4134F1), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned L4134D3 2024-06-15 (20240003_MML_Helsinki-Vantaa_kesa), L4134F1 2024-06-15 (20240003_MML_Helsinki-Vantaa_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2024-06-15; 154,034 points in the box, 0.6 per m²; classes {'1': 14, '2': 84351, '3': 732, '4': 4682, '5': 64255}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=25.040498,60.289656,25.049027,60.297540, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
