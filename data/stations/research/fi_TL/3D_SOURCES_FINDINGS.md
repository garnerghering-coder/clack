# Toijala (`fi:TL`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **90.58** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **89.70** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 83.34 – 101.07 (median 89.92) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 90.58.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_M4112H4, clack_fi_mml05_M4121G3, scanned 2026-06-29. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| TL L1 | 1 | korkea (0.55) | 450.0 | – | None | 89.69 | 90.58 | 0.89 | 0.72 |  |
| TL L2 | 2 | korkea (0.55) | 450.0 | – | None | 89.69 | 90.58 | 0.89 | 0.71 |  |
| TL L3 | 3 | korkea (0.55) | 450.0 | – | None | 89.75 | 90.58 | 0.83 | 0.66 |  |
| TL L4 | 4 | korkea (0.55) | 450.0 | – | None | 89.72 | 90.58 | 0.86 | 0.68 |  |

## Structures

`toijala_structures_heights.geojson`, 6 features: 1 building, 4 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w34388054 | Toijalan rautatieasema (station building) | – | – | 90.18 | – | 0 |
| canopy_osm | w719368884 | roof | – | – | 90.43 | – | 1 |
| canopy_osm | w719368886 | roof | – | – | 90.44 | – | 0 |
| canopy_osm | w719370390 | roof | – | – | 89.58 | – | 1 |
| canopy_osm | w719370476 | roof | – | – | 89.18 | – | 2 |
| train_in_scan | (laser) | train standing during the scan (52.0 m × 3.0 m) | 94.30 | – | – | 4.59 | 80 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS TL L1 (track 1): laser gives 0.89 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS TL L2 (track 2): laser gives 0.89 m above the track bed (≈0.71 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS TL L4 (track 4): laser gives 0.86 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 4 files found (3 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2026-06-29: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_M4112H4, clack_fi_mml05_M4121G3), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned M4112H4 2026-06-29 (20260301_Opegieka_Akaa_20p_kesa), M4121G3 2026-06-30 (20260301_Opegieka_Akaa_20p_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2026-06-29; 183,406 points in the box, 0.62 per m²; classes {'1': 44, '2': 112951, '3': 959, '4': 7392, '5': 62059, '16': 1}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=23.854291,61.167699,23.867873,61.173519, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
