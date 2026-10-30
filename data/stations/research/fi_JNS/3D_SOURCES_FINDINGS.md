# Joensuu (`fi:JNS`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **81.26** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **80.59** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 74.72 – 85.99 (median 80.21) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 81.26.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_N5424G3, scanned 2024-08-06. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| JNS L1 | 1 | korkea (0.55) | 265.0 | – | None | 80.68 | 81.26 | 0.58 | 0.40 |  |
| JNS L2 | 2 | korkea (0.55) | 320.0 | – | None | 80.59 | 81.24 | 0.65 | 0.47 |  |
| JNS L3 | 3 | korkea (0.55) | 320.0 | – | None | 80.58 | 81.26 | 0.68 | 0.51 |  |

## Structures

`joensuu_structures_heights.geojson`, 5 features: 1 building, 1 footbridge, 1 canopy_osm, 1 canopy_laser, 1 hall_roof_laser.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w88270416 | Joensuun rautatieasema (station building) | – | – | 80.14 | – | 3 |
| canopy_osm | w891035422 | roof | – | – | 79.82 | – | 3 |
| footbridge | w1216893303 | bridge | – | – | 74.83 | – | 0 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 92.18 | 92.25 | 80.66 | 10.92 | 37 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 85.89 | 85.93 | 80.53 | 4.63 | 73 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS JNS L1 (track 1): laser gives 0.58 m above the track bed (≈0.40 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Laser-traced roof (61 m², top 10.9 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (61 m², top 10.9 m above the platform, 11.6 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 26 files found (11 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-08-06: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_N5424G3), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned N5424G3 2024-08-06 (20240203_Swissphoto_Joensuu_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2024-08-06; 110,304 points in the box, 0.56 per m²; classes {'1': 1, '2': 82860, '3': 285, '4': 2218, '5': 24940}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=29.772261,62.597348,29.782488,62.603368, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
