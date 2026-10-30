# Riihimäki (`fi:RI`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **92.09** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **91.40** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 87.93 – 100.97 (median 91.02) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 92.09.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_L4232H4, scanned 2023-06-11. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| RI L1 | 1 | korkea (0.55) | 472.0 | – | None | 91.39 | 92.06 | 0.67 | 0.50 |  |
| RI L4 | 4 | korkea (0.55) | 446.0 | – | None | 91.38 | 92.09 | 0.71 | 0.54 |  |
| RI L5 | 5 | korkea (0.55) | 443.0 | – | None | 91.36 | 92.09 | 0.73 | 0.56 |  |
| RI L7 | 7 | korkea (0.55) | 300.0 | – | None | 91.42 | 92.10 | 0.68 | 0.51 |  |
| RI L8 | 8 | korkea (0.55) | 300.0 | – | None | 91.41 | 92.09 | 0.68 | 0.51 |  |
| RI L11 | 11 | korkea (0.55) | 80.0 | – | None | 91.41 | 92.09 | 0.69 | 0.51 |  |

## Structures

`riihimaki_structures_heights.geojson`, 24 features: 6 building, 9 canopy_osm, 8 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w37761031 | Riihimäen rautatieasema (station building) | – | – | 90.77 | – | 1 |
| canopy_osm | w100084332 | roof | 96.22 | 96.39 | 91.38 | 4.13 | 21 |
| building | w100420380 | Matkakeskus Liikerata (retail) | 100.12 | 104.01 | 89.75 | 8.03 | 5 |
| canopy_osm | w119527381 | roof | – | – | 91.65 | – | 0 |
| canopy_osm | w683559372 | canopy | 95.57 | 95.64 | 90.10 | 3.48 | 17 |
| building | w766620305 | building | – | – | 89.75 | – | 0 |
| canopy_osm | w1416700003 | canopy | – | – | 91.31 | – | 0 |
| bridge | w1420882453 | Peltosaaren ylikulkusilta (bridge) | 99.07 | 102.65 | 89.85 | 6.98 | 11 |
| canopy_osm | w1421892828 | roof | – | – | 90.56 | – | 2 |
| canopy_osm | w1421892836 | building | – | – | 90.45 | – | 0 |
| canopy_osm | w1421892837 | building | – | – | 90.38 | – | 0 |
| building | w1497720234 | building | – | – | 90.48 | – | 1 |
| building | w1497720235 | building | – | – | 90.68 | – | 1 |
| building | w1497720236 | building | – | – | 90.64 | – | 0 |
| canopy_osm | w1563661661 | roof | 96.57 | 96.59 | 91.38 | 4.48 | 6 |
| canopy_osm | w1563661662 | roof | – | – | 91.35 | – | 2 |
| train_in_scan | (laser) | train standing during the scan (48.6 m × 3.0 m) | 96.01 | – | – | 4.61 | 87 |
| train_in_scan | (laser) | train standing during the scan (74.8 m × 3.0 m) | 95.06 | – | – | 3.67 | 122 |
| train_in_scan | (laser) | train standing during the scan (55.5 m × 3.0 m) | 95.14 | – | – | 3.75 | 89 |
| train_in_scan | (laser) | train standing during the scan (104.4 m × 2.8 m) | 95.19 | – | – | 3.79 | 165 |
| train_in_scan | (laser) | train standing during the scan (16.3 m × 2.8 m) | 95.07 | – | – | 3.67 | 28 |
| train_in_scan | (laser) | train standing during the scan (15.1 m × 2.5 m) | 95.03 | – | – | 3.63 | 25 |
| train_in_scan | (laser) | train standing during the scan (55.9 m × 3.0 m) | 95.92 | – | – | 4.52 | 94 |
| train_in_scan | (laser) | train standing during the scan (44.4 m × 2.7 m) | 95.43 | – | – | 4.03 | 70 |

## Trains in the scan

8 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1420882453 Peltosaaren ylikulkusilta (cycleway, tertiary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 43 files found (13 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-06-11: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_L4232H4), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned L4232H4 2023-06-11 (20230207_Swissphoto_Riihimaki_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2023-06-11; 123,081 points in the box, 0.55 per m²; classes {'1': 173, '2': 88486, '3': 256, '4': 2287, '5': 31879}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=24.777587,60.731683,24.785497,60.739402, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
