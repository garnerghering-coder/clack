# Slagelse (`860000605`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **34.53** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **33.79** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 27.60 – 37.87 (median 33.62) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 34.53.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6142_648, scanned 2024-03-30. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 268.0 | 7.4 | None | 33.50 | 34.27 | 0.77 | 0.60 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 357.0 | 8.5 | None | 33.88 | 34.55 | 0.67 | 0.50 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 357.0 | 8.6 | None | 33.83 | 34.55 | 0.72 | 0.55 |  |
| perron 3 / track 4 | 4 | 55 (0.55) | 160.0 | 7.4 | None | 33.79 | 34.53 | 0.74 | 0.57 |  |
| perron 3 / track 5 | 5 | 55 (0.55) | 160.0 | 7.4 | None | 33.78 | 34.53 | 0.75 | 0.57 |  |

## Structures

`slagelse_structures_heights.geojson`, 21 features: 6 building, 1 footbridge, 11 canopy_osm, 2 hall_roof_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w290146554 | Slagelse Station (station building) | 40.07 | 45.96 | 33.70 | 5.54 | 1911 |
| canopy_osm | w290146558 | roof | 37.74 | 38.76 | 32.88 | 3.21 | 544 |
| canopy_osm | w290146559 | roof | 37.69 | 38.62 | 32.89 | 3.16 | 539 |
| canopy_osm | w290146560 | roof | 37.97 | 40.02 | 33.13 | 3.44 | 480 |
| canopy_osm | w290146561 | roof | 37.99 | 39.59 | 33.13 | 3.46 | 560 |
| building | w290146562 | retail | 39.67 | 43.25 | 33.04 | 5.14 | 1838 |
| canopy_osm | w290146563 | roof | 38.33 | 38.61 | 33.45 | 3.80 | 309 |
| canopy_osm | w290146564 | roof | 38.35 | 38.56 | 33.44 | 3.82 | 385 |
| building | w560394230 | Posthuset (building) | 38.76 | 41.78 | 33.76 | 4.23 | 1927 |
| building | w560394253 | SDU Slagelse (university) | 40.10 | 45.23 | 31.56 | 5.57 | 2653 |
| canopy_osm | w625086240 | roof | 39.27 | 39.84 | 32.93 | 4.74 | 179 |
| building | w962214809 | school | 47.71 | 51.79 | 31.75 | 13.18 | 492 |
| canopy_osm | w1125506818 | roof | 39.30 | 39.37 | 33.88 | 4.77 | 452 |
| canopy_osm | w1125506819 | roof | 39.29 | 39.36 | 33.86 | 4.76 | 366 |
| canopy_osm | w1125506820 | roof | 39.29 | 39.35 | 33.80 | 4.76 | 380 |
| building | w1156885774 | service | 38.54 | 38.58 | 34.56 | 4.01 | 23 |
| footbridge | w1238405938 | bridge | 41.84 | 42.75 | 33.42 | 7.31 | 618 |
| canopy_osm | w1444656722 | building | – | – | – | – | 0 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 41.96 | 42.37 | 33.48 | 7.43 | 666 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 42.10 | 42.39 | 33.50 | 7.57 | 260 |
| train_in_scan | (laser) | train standing during the scan (38.8 m × 2.6 m) | 37.83 | – | – | 4.00 | 1107 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w290146554 Slagelse Station (station building): p95 46.0 m is 5.9 m above the median 40.1 m (a taller neighbour or a mast inside the outline?).
- w560394253 SDU Slagelse (university): p95 45.2 m is 5.1 m above the median 40.1 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (120 m², top 7.4 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (120 m², top 7.4 m above the platform, 8.2 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (42 m², top 7.6 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (42 m², top 7.6 m above the platform, 8.3 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 60 files found (53 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-03-30: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6142_648). https://dataforsyningen.dk/data/3931 (scan 2024-03-30; 2,664,053 points in the box, 15.08 per m²; classes {'2': 1475094, '3': 128962, '4': 77977, '5': 309316, '6': 599185, '7': 59933, '14': 3819, '17': 4339, '18': 5428}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=11.33999,55.40469,11.35557,55.41024, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
