# Tampere (`fi:TPE`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **96.14** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **95.37** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 87.25 – 100.55 (median 95.44) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 96.14.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_M4212G1, scanned 2023-06-08. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| TPE L1 | 1 | korkea (0.55) | 500.0 | – | None | 95.14 | 95.87 | 0.73 | 0.56 |  |
| TPE L2 | 2 | korkea (0.55) | 500.0 | – | None | 95.16 | 96.01 | 0.85 | 0.68 |  |
| TPE L3 | 3 | korkea (0.55) | 500.0 | – | None | 95.38 | 96.14 | 0.76 | 0.59 |  |
| TPE L4 | 4 | korkea (0.55) | 500.0 | – | None | 95.37 | 96.27 | 0.90 | 0.72 |  |
| TPE L5 | 5 | korkea (0.55) | 500.0 | – | None | 95.42 | 96.29 | 0.87 | 0.70 |  |

## Structures

`tampere_structures_heights.geojson`, 45 features: 32 building, 7 canopy_osm, 3 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w89322118 | apartments | 112.72 | 115.74 | 89.65 | 16.58 | 5 |
| building | w123677255 | P-Asema (parking) | – | – | 89.87 | – | 3 |
| building | w128036311 | Tampereen rautatieasema (station building) | – | – | 91.54 | – | 2 |
| building | w128036316 | commercial | – | – | 91.71 | – | 0 |
| building | w128132500 | retail | – | – | 89.97 | – | 2 |
| building | w264963250 | building | – | – | 95.96 | – | 0 |
| building | w359881021 | commercial | – | – | 91.73 | – | 0 |
| building | w407503927 | Scandic Tampere Station (hotel) | – | – | 93.82 | – | 4 |
| building | w719386123 | building | – | – | 95.94 | – | 0 |
| building | w719386124 | building | – | – | 96.16 | – | 0 |
| canopy_osm | w719386125 | roof | 99.96 | 100.01 | 95.12 | 3.82 | 6 |
| bridge | w1304545431 | bridge | – | – | 90.53 | – | 0 |
| building | w1389611556 | construction | – | – | 95.31 | – | 4 |
| building | w1424026791 | building | – | – | 95.69 | – | 0 |
| building | w1424026793 | Entinen hissi (elevator) | – | – | 96.24 | – | 0 |
| canopy_osm | w1424026794 | roof | 100.00 | 100.08 | 95.11 | 3.86 | 7 |
| building | w1424026795 | building | – | – | 96.22 | – | 0 |
| building | w1424120771 | elevator | – | – | 95.63 | – | 0 |
| building | w1424120772 | elevator | – | – | 96.00 | – | 0 |
| building | w1424120773 | elevator | – | – | 96.23 | – | 0 |
| building | w1424120774 | Entinen hissi (elevator) | – | – | – | – | 0 |
| building | w1424120775 | Entinen hissi (elevator) | – | – | 95.87 | – | 0 |
| building | w1424120776 | elevator | – | – | 89.93 | – | 0 |
| building | w1424120778 | elevator | – | – | 96.15 | – | 0 |
| building | w1424120780 | elevator | – | – | 96.10 | – | 0 |
| building | w1424120783 | building | – | – | 92.19 | – | 0 |
| building | w1424120784 | building | – | – | 91.95 | – | 1 |
| building | w1424120785 | building | – | – | 91.97 | – | 1 |
| building | w1424120786 | building | – | – | 91.67 | – | 0 |
| building | w1424287118 | building | – | – | 91.54 | – | 0 |
| building | w1424496071 | building | – | – | 95.99 | – | 0 |
| canopy_osm | w1424496072 | roof | – | – | 96.09 | – | 0 |
| building | w1424496073 | building | – | – | 96.19 | – | 0 |
| canopy_osm | w1424496074 | roof | – | – | 96.15 | – | 1 |
| building | w1448499485 | construction | – | – | 95.39 | – | 0 |
| building | w1448499486 | construction | – | – | 95.36 | – | 1 |
| building | w1448500461 | building | – | – | 89.93 | – | 4 |
| canopy_osm | w1536302175 | roof | 99.41 | 99.45 | 95.21 | 3.27 | 12 |
| canopy_osm | w1536302176 | roof | – | – | 95.15 | – | 3 |
| canopy_osm | w1536302179 | roof | – | – | 95.58 | – | 2 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 100.61 | 100.75 | 95.31 | 4.47 | 114 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 100.66 | 100.79 | 95.33 | 4.52 | 201 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 100.72 | 100.83 | 95.41 | 4.58 | 173 |
| train_in_scan | (laser) | train standing during the scan (51.6 m × 3.2 m) | 99.93 | – | – | 4.53 | 94 |
| train_in_scan | (laser) | train standing during the scan (19.4 m × 3.1 m) | 98.69 | – | – | 3.32 | 32 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS TPE L2 (track 2): laser gives 0.85 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS TPE L4 (track 4): laser gives 0.90 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS TPE L5 (track 5): laser gives 0.87 m above the track bed (≈0.70 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1304545431 (cycleway, primary).
- Laser-traced roof (184 m², top 4.5 m above the platform, 5.2 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (353 m², top 4.5 m above the platform, 5.3 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (342 m², top 4.6 m above the platform, 5.3 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (30 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-06-08: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_M4212G1), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned M4212G1 2023-06-08 (20230107_Leica_Tampere_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2023-06-08; 112,355 points in the box, 0.55 per m²; classes {'1': 991, '2': 73664, '3': 269, '4': 2490, '5': 34941}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=23.770334,61.494558,23.777231,61.502705, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
