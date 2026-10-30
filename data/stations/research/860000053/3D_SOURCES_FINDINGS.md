# Aarhus H (`860000053`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **7.13** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **6.29** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 5.50 – 18.36 (median 11.68) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 7.13.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6223_574, PUNKTSKY_1km_6223_575, scanned 2025-03-23. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 2 | 2 | 50 (0.50) | 257.0 | 8.4 | None | 6.18 | 7.13 | 0.95 | 0.78 |  |
| perron 1 / track 3 | 3 | 55 (0.55) | 257.0 | 8.4 | None | 6.24 | 7.13 | 0.89 | 0.71 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 260.0 | 6.4 | None | 6.30 | 7.13 | 0.83 | 0.66 |  |
| perron 2 / track 5 | 5 | 55 (0.55) | 260.0 | 6.4 | None | 6.35 | 7.14 | 0.79 | 0.61 |  |
| perron 3 / track 6 | 6 | 50 (0.50) | 260.0 | 7.6 | None | 6.29 | 7.16 | 0.87 | 0.70 |  |
| perron 3 / track 7 | 7 | 50 (0.50) | 260.0 | 7.5 | None | 6.53 | 7.19 | 0.66 | 0.49 |  |

## Structures

`aarhus_h_structures_heights.geojson`, 37 features: 23 building, 1 footbridge, 11 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w147077550 | commercial | 27.06 | 30.86 | 6.25 | 19.93 | 32 |
| building | w231434889 | building | – | – | – | – | 0 |
| building | w231434891 | building | 42.75 | 42.86 | 6.12 | 35.62 | 129 |
| building | w231434903 | Bruuns Galleri (retail) | 21.34 | 42.83 | 5.98 | 14.21 | 3032 |
| building | w231436752 | station building | 17.81 | 30.85 | 5.98 | 10.68 | 349 |
| canopy_osm | w231436753 | roof | – | – | 6.48 | – | 0 |
| footbridge | w231436755 | building | 23.02 | 42.92 | 5.98 | 15.89 | 29 |
| building | w231436756 | retail | – | – | – | – | 0 |
| building | w231436757 | station building | 15.64 | 17.46 | 6.01 | 8.51 | 33 |
| building | w231436758 | station building | – | – | 6.07 | – | 0 |
| canopy_osm | w231436759 | roof | – | – | – | – | 0 |
| building | w231436760 | building | 30.86 | 30.91 | 6.25 | 23.73 | 9 |
| building | w514519653 | building | 9.88 | 9.95 | 6.99 | 2.75 | 83 |
| building | w515037674 | station building | – | – | – | – | 0 |
| building | w515037733 | building | 9.28 | 9.39 | 6.06 | 2.15 | 133 |
| building | w515037737 | station building | 19.24 | 26.61 | 6.23 | 12.11 | 45 |
| bridge | w515368259 | bridge | 14.43 | 26.92 | 6.02 | 7.30 | 516 |
| bridge | w977481194 | Frederiksbroen (bridge) | 17.36 | 17.86 | 6.57 | 10.23 | 62 |
| canopy_osm | w1149384805 | roof | 9.53 | 9.63 | 6.33 | 2.40 | 102 |
| canopy_osm | w1149384806 | roof | 9.53 | 9.62 | 6.40 | 2.40 | 112 |
| building | w1149450179 | building | – | – | – | – | 0 |
| canopy_osm | w1171449826 | building | 9.70 | 9.72 | 7.08 | 2.57 | 33 |
| canopy_osm | w1171449827 | building | 9.59 | 9.66 | 6.97 | 2.46 | 69 |
| canopy_osm | w1171449828 | building | 9.74 | 9.78 | 7.08 | 2.61 | 63 |
| building | w1223425950 | station building | – | – | – | – | 0 |
| canopy_osm | w1223727477 | roof | – | – | – | – | 0 |
| canopy_osm | w1223727478 | roof | – | – | – | – | 0 |
| canopy_osm | w1223727479 | roof | – | – | – | – | 0 |
| canopy_osm | w1223827963 | roof | – | – | 11.49 | – | 0 |
| building | w1223832610 | building | – | – | – | – | 0 |
| building | w1223832611 | building | – | – | – | – | 0 |
| building | w1223832612 | building | – | – | – | – | 0 |
| building | w1223832613 | building | – | – | – | – | 0 |
| building | w1223832614 | building | – | – | – | – | 0 |
| building | w1223832615 | building | – | – | – | – | 0 |
| building | w1223832616 | building | – | – | – | – | 0 |
| building | w1223832617 | building | – | – | – | – | 0 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS perron 1 / track 2 (track 2): laser gives 0.95 m above the track bed (≈0.78 m above rail after −0.15…0.2 m), register class 50 = 0.5 m. Not decided; add to REVIEW.md.
- Platform BIS perron 1 / track 3 (track 3): laser gives 0.89 m above the track bed (≈0.71 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 3 / track 6 (track 6): laser gives 0.87 m above the track bed (≈0.70 m above rail after −0.15…0.2 m), register class 50 = 0.5 m. Not decided; add to REVIEW.md.
- w231434903 Bruuns Galleri (retail): p95 42.8 m is 21.5 m above the median 21.3 m (a taller neighbour or a mast inside the outline?).
- w231436752 station building: p95 30.9 m is 13.0 m above the median 17.8 m (a taller neighbour or a mast inside the outline?).
- w231436755 building: p95 42.9 m is 19.9 m above the median 23.0 m (a taller neighbour or a mast inside the outline?).
- w515037737 station building: p95 26.6 m is 7.4 m above the median 19.2 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w515368259 (footway, tertiary); w977481194 Frederiksbroen (tertiary).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (30 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-23: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6223_574, PUNKTSKY_1km_6223_575). https://dataforsyningen.dk/data/3931 (scan 2025-03-23; 2,144,190 points in the box, 10.59 per m²; classes {'2': 800480, '3': 42663, '4': 48062, '5': 418089, '6': 758014, '7': 49195, '14': 619, '17': 13616, '18': 13452}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.19588,56.14665,10.21004,56.15273, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
