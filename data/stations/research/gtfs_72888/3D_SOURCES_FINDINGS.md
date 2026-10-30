# Høje Taastrup (`gtfs:72888`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **26.12** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **25.35** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 23.74 – 35.63 (median 30.04) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 26.12.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6171_705, PUNKTSKY_1km_6172_705, scanned 2024-04-28. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 339.0 | 11.6 | None | 25.41 | 26.10 | 0.69 | 0.52 |  |
| perron 1 / track 2 | 2 | 55 (0.55) | 339.0 | 11.6 | None | 25.42 | 26.11 | 0.69 | 0.51 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 339.0 | 12.0 | None | 25.39 | 26.12 | 0.73 | 0.56 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 339.0 | 12.0 | None | 25.31 | 26.12 | 0.81 | 0.63 |  |
| perron 3 / track 11 | 11 | 92 (0.92) | 223.0 | 11.3 | None | 25.26 | 26.40 | 1.14 | 0.97 |  |
| perron 3 / track 12 | 12 | 92 (0.92) | 223.0 | 11.3 | None | 25.29 | 26.40 | 1.11 | 0.94 |  |

## Structures

`hoje_taastrup_structures_heights.geojson`, 31 features: 4 building, 16 canopy_osm, 5 hall_roof_laser, 5 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w26176704 | retail | 39.27 | 44.14 | 26.17 | 13.15 | 13995 |
| bridge | w496715675 | bridge | 33.39 | 36.43 | 25.15 | 7.27 | 80 |
| canopy_osm | w846252137 | roof | 29.49 | 32.83 | 26.23 | 3.37 | 985 |
| canopy_osm | w846252138 | roof | 29.29 | 29.35 | 26.08 | 3.17 | 661 |
| canopy_osm | w846252139 | roof | 29.30 | 29.35 | 26.05 | 3.18 | 756 |
| canopy_osm | w846252140 | roof | 29.46 | 32.73 | 26.24 | 3.34 | 1062 |
| canopy_osm | w846252141 | roof | 29.54 | 35.86 | 26.25 | 3.42 | 738 |
| canopy_osm | w1123142805 | roof | 35.92 | 36.54 | 32.68 | 9.80 | 176 |
| canopy_osm | w1123142806 | roof | 30.99 | 31.53 | 28.57 | 4.87 | 118 |
| canopy_osm | w1123142807 | roof | 30.87 | 31.36 | 28.40 | 4.75 | 123 |
| canopy_osm | w1123142808 | roof | 31.39 | 35.32 | 28.12 | 5.27 | 174 |
| canopy_osm | w1123142809 | roof | 30.52 | 30.97 | 27.98 | 4.40 | 133 |
| canopy_osm | w1123142810 | roof | 30.98 | 35.52 | 28.40 | 4.86 | 194 |
| canopy_osm | w1123142811 | roof | 30.74 | 32.96 | 28.26 | 4.62 | 125 |
| canopy_osm | w1123142812 | roof | 31.04 | 31.74 | 28.57 | 4.92 | 176 |
| canopy_osm | w1123142813 | roof | 31.17 | 31.68 | 28.70 | 5.05 | 143 |
| canopy_osm | w1123142814 | roof | 37.14 | 37.20 | 32.62 | 11.02 | 657 |
| canopy_osm | w1123142815 | roof | 37.14 | 37.20 | 26.18 | 11.02 | 963 |
| building | w1524349680 | service | 29.69 | 29.72 | 26.44 | 3.57 | 29 |
| building | w1524349681 | service | 29.65 | 29.70 | 26.46 | 3.53 | 53 |
| building | w1524349682 | service | 29.62 | 29.68 | 26.43 | 3.50 | 27 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.67 | 34.04 | 32.59 | 6.55 | 89 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.67 | 33.41 | 24.97 | 6.55 | 2335 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.63 | 32.70 | 32.58 | 6.51 | 77 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.70 | 33.75 | 25.24 | 6.58 | 1034 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.63 | 32.66 | 32.59 | 6.51 | 53 |
| train_in_scan | (laser) | train standing during the scan (55.7 m × 2.5 m) | 29.07 | – | – | 3.96 | 1078 |
| train_in_scan | (laser) | train standing during the scan (20.8 m × 2.6 m) | 29.83 | – | – | 4.34 | 631 |
| train_in_scan | (laser) | train standing during the scan (43.6 m × 2.5 m) | 29.57 | – | – | 3.93 | 730 |
| train_in_scan | (laser) | train standing during the scan (21.9 m × 2.5 m) | 29.66 | – | – | 3.93 | 378 |
| train_in_scan | (laser) | train standing during the scan (39.7 m × 2.7 m) | 29.50 | – | – | 3.93 | 1587 |

## Trains in the scan

5 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w26176704 retail: p95 44.1 m is 4.9 m above the median 39.3 m (a taller neighbour or a mast inside the outline?).
- w846252137 roof: p95 32.8 m is 3.3 m above the median 29.5 m (a taller neighbour or a mast inside the outline?).
- w846252140 roof: p95 32.7 m is 3.3 m above the median 29.5 m (a taller neighbour or a mast inside the outline?).
- w846252141 roof: p95 35.9 m is 6.3 m above the median 29.5 m (a taller neighbour or a mast inside the outline?).
- w1123142808 roof: p95 35.3 m is 3.9 m above the median 31.4 m (a taller neighbour or a mast inside the outline?).
- w1123142810 roof: p95 35.5 m is 4.5 m above the median 31.0 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w496715675 (tertiary).
- Laser-traced roof (104 m², top 6.6 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (104 m², top 6.6 m above the platform, 7.3 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (228 m², top 6.6 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (228 m², top 6.6 m above the platform, 7.3 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (74 m², top 6.5 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (113 m², top 6.6 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (113 m², top 6.6 m above the platform, 7.4 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (87 m², top 6.5 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-04-28: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6171_705, PUNKTSKY_1km_6172_705). https://dataforsyningen.dk/data/3931 (scan 2024-04-28; 3,803,633 points in the box, 18.34 per m²; classes {'2': 1860884, '3': 156657, '4': 197757, '5': 773821, '6': 712920, '7': 70008, '14': 2754, '17': 23761, '18': 5071}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.26183,55.64578,12.2763,55.65163, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
