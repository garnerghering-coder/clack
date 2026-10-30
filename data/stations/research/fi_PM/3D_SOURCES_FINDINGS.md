# Pieksämäki (`fi:PM`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **122.32** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **121.65** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 119.25 – 129.77 (median 121.64) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 122.32.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_N5211C1, scanned 2025-06-14. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| PM L6 | 6 | korkea (0.55) | 180.0 | – | None | 121.62 | 122.25 | 0.64 | 0.46 |  |
| PM L4 | 4 | matala (0.27) | 350.0 | – | None | 121.67 | 122.38 | 0.70 | 0.53 |  |
| PM L1 | 1 | korkea (0.55) | 210.0 | – | None | 121.61 | 122.26 | 0.65 | 0.47 |  |
| PM L3 | 3 | korkea (0.55) | 350.0 | – | None | 121.71 | 122.40 | 0.69 | 0.51 |  |

## Structures

`pieksamaki_structures_heights.geojson`, 14 features: 7 building, 6 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w155269527 | Pieksämäen Matkakeskus (station building) | – | – | 121.89 | – | 0 |
| building | w155270277 | Savon radan museo (station building) | – | – | 121.91 | – | 0 |
| canopy_osm | w155336251 | roof | 126.42 | 126.49 | 121.57 | 4.10 | 11 |
| building | w200674514 | transportation | – | – | 121.24 | – | 0 |
| building | w200836384 | transportation | – | – | 121.13 | – | 0 |
| bridge | w1230324174 | bridge | 129.26 | 131.09 | 119.25 | 6.94 | 14 |
| canopy_osm | w1434884408 | roof | – | – | 122.16 | – | 0 |
| building | w1547012525 | transportation | – | – | 121.92 | – | 3 |
| building | w1547012537 | elevator | – | – | – | – | 0 |
| building | w1547012539 | elevator | – | – | 122.13 | – | 0 |
| canopy_osm | w1547012540 | shelter | – | – | 122.19 | – | 0 |
| canopy_osm | w1547012541 | shelter | – | – | 122.03 | – | 0 |
| canopy_osm | w1547012542 | shelter | – | – | 121.93 | – | 0 |
| canopy_osm | w1547043913 | roof | – | – | 121.75 | – | 2 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS PM L4 (track 4): laser gives 0.70 m above the track bed (≈0.53 m above rail after −0.15…0.2 m), register class matala = 0.265 m. Not decided; add to REVIEW.md.
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1230324174 (cycleway, tertiary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 38 files found (21 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-06-14: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_N5211C1), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned N5211C1 2025-06-14 (20250002_MML_Pieksamaki_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2025-06-14; 89,123 points in the box, 0.6 per m²; classes {'1': 153, '2': 62663, '3': 376, '4': 2075, '5': 23856}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=27.163432,62.298703,27.171173,62.305067, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
