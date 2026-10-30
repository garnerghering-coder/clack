# Hämeenlinna (`fi:HL`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **84.40** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **83.62** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 79.08 – 103.13 (median 83.93) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 84.40.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_M4131C2, scanned 2023-06-09. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| HL L1 | 1 | korkea (0.55) | 257.0 | – | None | 83.62 | 84.37 | 0.75 | 0.57 |  |
| HL L2 | 2 | korkea (0.55) | 444.0 | – | None | 83.58 | 84.44 | 0.86 | 0.68 |  |
| HL L3 | 3 | korkea (0.55) | 449.0 | – | None | 83.62 | 84.40 | 0.78 | 0.61 |  |

## Structures

`hameenlinna_structures_heights.geojson`, 14 features: 5 building, 6 canopy_osm, 1 canopy_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w100952803 | building | – | – | 83.41 | – | 0 |
| building | w139083640 | industrial | 88.24 | 88.87 | 83.46 | 3.84 | 7 |
| building | w439781957 | building | – | – | 83.58 | – | 0 |
| building | w439781958 | Hämeenlinnan rautatieasema (station building) | – | – | 83.41 | – | 0 |
| canopy_osm | w527219814 | building | 87.52 | 87.65 | 82.80 | 3.12 | 7 |
| canopy_osm | w534256214 | roof | – | – | 84.51 | – | 0 |
| canopy_osm | w534256215 | roof | – | – | 84.40 | – | 1 |
| canopy_osm | w534256216 | roof | 88.22 | 88.47 | 84.48 | 3.82 | 9 |
| building | w534256217 | transportation | – | – | 84.46 | – | 0 |
| canopy_osm | w628981871 | roof | 88.38 | 90.97 | 83.63 | 3.98 | 55 |
| bridge | w786496613 | Viipurintien ylikulkusilta (bridge) | – | – | 83.07 | – | 2 |
| canopy_osm | w885656325 | building | – | – | 82.47 | – | 0 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 88.72 | 89.18 | 83.63 | 4.32 | 71 |
| train_in_scan | (laser) | train standing during the scan (29.0 m × 2.9 m) | 87.32 | – | – | 3.70 | 46 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS HL L2 (track 2): laser gives 0.86 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w786496613 Viipurintien ylikulkusilta (cycleway, footway, primary).
- Laser-traced roof (113 m², top 4.3 m above the platform, 5.1 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 11 files found (4 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-06-09: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_M4131C2), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned M4131C2 2023-06-09 (20230207_Swissphoto_Riihimaki_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2023-06-09; 180,879 points in the box, 0.62 per m²; classes {'1': 126, '2': 100488, '3': 681, '4': 7309, '5': 72275}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=24.473624,60.998785,24.485608,61.005185, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
