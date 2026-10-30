# Herning (`860000275`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **52.33** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **51.52** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 48.31 – 58.10 (median 51.56) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 52.33.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6220_498, PUNKTSKY_1km_6220_499, scanned 2025-03-06. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 268.0 | 6.5 | None | 51.52 | 52.33 | 0.81 | 0.63 |  |
| perron 1 / track 2 | 2 | 55 (0.55) | 277.0 | 6.5 | None | 51.45 | 52.33 | 0.88 | 0.70 |  |
| perron 1 / track 43a | 43a | 55 (0.55) | 132.0 | 19.7 | None | 51.39 | 51.86 | 0.47 | 0.29 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 280.0 | 11.4 | None | 51.52 | 52.36 | 0.84 | 0.66 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 270.0 | 11.4 | None | 51.54 | 52.35 | 0.81 | 0.64 |  |

## Structures

`herning_structures_heights.geojson`, 17 features: 7 building, 5 canopy_osm, 1 canopy_laser, 4 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w122292140 | station building | 64.01 | 70.46 | 50.95 | 11.68 | 723 |
| canopy_osm | w141500147 | roof | 55.28 | 55.35 | 52.32 | 2.95 | 3641 |
| building | w141500148 | transportation | 61.62 | 61.77 | 53.87 | 9.29 | 269 |
| building | w141500150 | bridge | 57.59 | 65.29 | 51.60 | 5.26 | 113 |
| canopy_osm | w141500152 | roof | 58.67 | 60.40 | 53.60 | 6.34 | 14 |
| building | w141500155 | bridge | 60.66 | 61.31 | 48.64 | 8.33 | 294 |
| canopy_osm | w141500157 | roof | 55.28 | 55.35 | 52.32 | 2.95 | 3275 |
| building | w141500158 | station building | 56.96 | 62.20 | 51.61 | 4.63 | 788 |
| building | w141501367 | bridge | 57.61 | 60.83 | 51.64 | 5.28 | 85 |
| canopy_osm | w450856195 | roof | 59.11 | 61.33 | 54.31 | 6.78 | 102 |
| building | w939278135 | station building | 61.62 | 61.70 | 53.89 | 9.29 | 9 |
| canopy_osm | w939278136 | roof | 61.52 | 61.60 | 53.78 | 9.19 | 13 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 55.50 | 55.80 | 51.64 | 3.17 | 262 |
| train_in_scan | (laser) | train standing during the scan (39.1 m × 2.8 m) | 55.25 | – | – | 3.77 | 1276 |
| train_in_scan | (laser) | train standing during the scan (29.4 m × 2.8 m) | 55.47 | – | – | 3.81 | 881 |
| train_in_scan | (laser) | train standing during the scan (123.2 m × 2.8 m) | 54.94 | – | – | 3.74 | 5837 |
| train_in_scan | (laser) | train standing during the scan (38.8 m × 2.8 m) | 55.62 | – | – | 3.81 | 1162 |

## Trains in the scan

4 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 1 track 1: the outline FOR_PERRONER_OD Hr 171 runs 416 m along the track, Bilag says 268 m; line drawn to the outline
- Perron 1 track 2: the outline FOR_PERRONER_OD Hr 171 runs 416 m along the track, Bilag says 277 m; line drawn to the outline
- Platform BIS perron 1 / track 2 (track 2): laser gives 0.88 m above the track bed (≈0.70 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS perron 1 / track 43a (track 43a): laser gives 0.47 m above the track bed (≈0.29 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- w122292140 station building: p95 70.5 m is 6.4 m above the median 64.0 m (a taller neighbour or a mast inside the outline?).
- w141500158 station building: p95 62.2 m is 5.2 m above the median 57.0 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (44 m², top 3.2 m above the platform, 4.0 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (98 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-06: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6220_498, PUNKTSKY_1km_6220_499). https://dataforsyningen.dk/data/3931 (scan 2025-03-06; 3,024,954 points in the box, 12.96 per m²; classes {'2': 1545009, '3': 82135, '4': 85937, '5': 773899, '6': 489420, '7': 39261, '14': 298, '17': 3153, '18': 5842}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=8.97304,56.12927,8.98921,56.13533, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
