# Seinäjoki (`fi:SK`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **45.14** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **44.53** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 40.99 – 50.15 (median 44.60) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 45.14.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_P3334A4, scanned 2025-06-13. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| SK L1 | 1 | korkea (0.55) | 451.0 | – | None | 44.56 | 45.22 | 0.66 | 0.48 |  |
| SK L2 | 2 | matala (0.27) | 448.0 | – | None | 44.55 | 45.25 | 0.70 | 0.52 |  |
| SK L3 | 3 | matala (0.27) | 459.0 | – | None | 44.50 | 45.06 | 0.56 | 0.39 |  |
| SK L4 | 4 | matala (0.27) | 396.0 | – | None | 44.52 | 45.02 | 0.50 | 0.33 |  |

## Structures

`seinajoki_structures_heights.geojson`, 33 features: 6 building, 1 footbridge, 23 canopy_osm, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w27744921 | station building | 52.27 | 56.33 | 43.78 | 7.12 | 14 |
| canopy_osm | w151098137 | roof | – | – | 44.93 | – | 2 |
| building | w151098138 | service | – | – | 44.95 | – | 0 |
| building | w151098180 | building | – | – | 45.07 | – | 0 |
| canopy_osm | w604670956 | roof | – | – | 43.42 | – | 0 |
| canopy_osm | w751304345 | canopy | 49.86 | 49.92 | 44.59 | 4.72 | 7 |
| canopy_osm | w751304346 | canopy | 49.84 | 49.94 | 44.99 | 4.70 | 14 |
| building | w751304347 | building | – | – | 43.00 | – | 4 |
| canopy_osm | w751304348 | roof | – | – | 44.95 | – | 0 |
| canopy_osm | w835453209 | Toripaviljonki (roof) | – | – | 44.69 | – | 0 |
| canopy_osm | w837853691 | building | – | – | 43.16 | – | 1 |
| canopy_osm | w837853692 | building | – | – | 43.05 | – | 1 |
| canopy_osm | w837853693 | building | – | – | 43.03 | – | 4 |
| canopy_osm | w837853694 | building | – | – | 43.19 | – | 0 |
| canopy_osm | w837853695 | building | – | – | 43.04 | – | 1 |
| canopy_osm | w837853698 | building | – | – | 43.05 | – | 2 |
| canopy_osm | w837853700 | building | – | – | 43.20 | – | 0 |
| canopy_osm | w837853703 | building | – | – | 43.71 | – | 1 |
| canopy_osm | w837853711 | building | – | – | 44.12 | – | 1 |
| canopy_osm | w837853712 | building | – | – | 44.20 | – | 0 |
| canopy_osm | w837853717 | building | – | – | 44.23 | – | 0 |
| canopy_osm | w837853723 | building | – | – | 42.94 | – | 1 |
| canopy_osm | w837857314 | building | – | – | 43.80 | – | 0 |
| canopy_osm | w837857315 | building | – | – | 43.84 | – | 0 |
| canopy_osm | w838208630 | building | – | – | 43.43 | – | 1 |
| building | w1308029818 | Seinäjoen Asematalo (station building) | – | – | 45.10 | – | 0 |
| building | w1320722832 | P-Asema (building) | – | – | 44.90 | – | 0 |
| footbridge | w1409483521 | bridge | – | – | 41.69 | – | 0 |
| canopy_osm | w1419159649 | roof | – | – | 45.13 | – | 1 |
| bridge | w1431145276 | bridge | – | – | 44.74 | – | 0 |
| canopy_osm | r19440141 | roof | – | – | 44.93 | – | 0 |
| train_in_scan | (laser) | train standing during the scan (22.9 m × 2.7 m) | 48.36 | – | – | 3.81 | 37 |
| train_in_scan | (laser) | train standing during the scan (131.4 m × 2.9 m) | 48.36 | – | – | 3.82 | 211 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS SK L2 (track 2): laser gives 0.70 m above the track bed (≈0.52 m above rail after −0.15…0.2 m), register class matala = 0.265 m. Not decided; add to REVIEW.md.
- w27744921 station building: p95 56.3 m is 4.1 m above the median 52.3 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1431145276 (service).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 26 files found (3 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-06-13: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_P3334A4), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned P3334A4 2025-06-13 (20250105_Leica_Seinajoki_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2025-06-13; 182,403 points in the box, 0.54 per m²; classes {'1': 33, '2': 118080, '3': 481, '4': 6064, '5': 57745}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=22.837725,62.788636,22.850164,62.795844, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
