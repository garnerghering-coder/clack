# Kuopio (`fi:KUO`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **96.38** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **95.35** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 82.79 – 106.90 (median 93.24) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 96.38.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_P5114D3, scanned 2021-07-05. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| KUO L1 | 1 | korkea (0.55) | 324.0 | – | None | 95.46 | 96.38 | 0.92 | 0.74 |  |
| KUO L3 | 3 | korkea (0.55) | 320.0 | – | None | 95.25 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| KUO L2 | 2 | korkea (0.55) | 320.0 | – | None | 95.41 | 96.20 | 0.79 | 0.62 | not in Bilaga 2A (report 2026-02-04) and the BanInfo record is from 2023-11-17: probably built or rebuilt after the scan, so the laser value is not this platform; left out of the station level |

## Structures

`kuopio_structures_heights.geojson`, 16 features: 9 building, 1 footbridge, 5 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w87777888 | building | – | – | 95.23 | – | 0 |
| building | w87807952 | Kuopion rautatieasema (station building) | 95.67 | 100.16 | 90.41 | -0.71 | 6 |
| building | w770688424 | office | – | – | 89.58 | – | 1 |
| building | w770688432 | apartments | – | – | 89.88 | – | 1 |
| building | w810700766 | Kuopion matkakeskus (transportation) | 104.34 | 104.44 | 89.97 | 7.96 | 22 |
| canopy_osm | w967754515 | roof | – | – | 95.01 | – | 0 |
| building | w967754518 | building | – | – | 95.50 | – | 0 |
| building | w967754519 | building | – | – | 95.91 | – | 0 |
| bridge | w1044169166 | bridge | 97.56 | 106.25 | 89.72 | 1.18 | 22 |
| footbridge | w1044169167 | bridge | – | – | 89.70 | – | 4 |
| building | w1174442640 | commercial | – | – | 89.58 | – | 0 |
| canopy_osm | w1174748001 | roof | – | – | 89.33 | – | 4 |
| canopy_osm | w1174748006 | roof | – | – | 91.36 | – | 2 |
| canopy_osm | w1454975015 | roof | – | – | 94.91 | – | 1 |
| building | w1550510974 | shelter | – | – | 89.83 | – | 0 |
| canopy_osm | w1561412912 | building | – | – | 88.43 | – | 0 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS KUO L1 (track 1): laser gives 0.92 m above the track bed (≈0.74 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS KUO L2 (track 2): register korkea, laser 0.79 m above the bed; record valid from 2023-11-17, not in Bilaga 2A; the scan is from 2021-07-05: probably built after the scan.
- w87807952 Kuopion rautatieasema (station building): p95 100.2 m is 4.5 m above the median 95.7 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1044169166 (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 34 files found (3 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-07-05: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_P5114D3), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned P5114D3 2021-07-05 (20210102_Swissphoto_Kuopio_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2021-07-05; 83,379 points in the box, 0.61 per m²; classes {'1': 381, '2': 49465, '3': 238, '4': 1962, '5': 31333}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=27.673632,62.895608,27.687283,62.899039, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
