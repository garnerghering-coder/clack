# Ørestad (`860000856`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **-2.23** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **-3.01** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -4.55 – 7.06 (median 0.99) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting -2.23.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6170_725, scanned 2025-03-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 322.0 | 7.4 | None | -3.05 | -2.16 | 0.89 | 0.72 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 322.0 | 7.1 | None | -2.97 | -2.29 | 0.68 | 0.51 |  |

## Structures

`orestad_structures_heights.geojson`, 22 features: 3 building, 3 footbridge, 8 canopy_osm, 2 canopy_laser, 1 hall_roof_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w48821420 | roof | 3.53 | 7.98 | 3.16 | 5.76 | 1158 |
| building | w417678706 | pumping_station | 3.91 | 4.01 | -0.25 | 6.14 | 43 |
| bridge | w423455253 | bridge | 5.08 | 7.43 | -4.04 | 7.31 | 1371 |
| building | w624098215 | building | – | – | – | – | 0 |
| building | w1050970810 | industrial | 0.67 | 0.81 | -2.19 | 2.90 | 41 |
| footbridge | w1050970811 | bridge | 4.74 | 5.90 | -3.95 | 6.97 | 706 |
| canopy_osm | w1165222447 | building | 0.03 | 0.08 | -2.50 | 2.26 | 17 |
| canopy_osm | w1165222448 | building | 0.01 | 0.07 | -2.51 | 2.24 | 33 |
| canopy_osm | w1165222449 | building | 0.15 | 0.20 | -2.36 | 2.38 | 14 |
| canopy_osm | w1165222450 | building | 0.17 | 0.21 | -2.33 | 2.40 | 20 |
| canopy_osm | w1165222451 | building | 0.30 | 0.37 | -2.20 | 2.53 | 27 |
| canopy_osm | w1165222452 | building | 0.14 | 0.21 | -2.33 | 2.37 | 6 |
| canopy_osm | w1165222453 | building | 0.12 | 0.18 | -2.27 | 2.35 | 52 |
| bridge | w1490476727 | bridge | – | – | -2.23 | – | 4 |
| bridge | w1490476730 | bridge | – | – | -2.36 | – | 0 |
| bridge | r20346573 | bridge | 4.88 | 5.97 | -3.03 | 7.11 | 1038 |
| footbridge | r20350078 | bridge | 8.00 | 8.23 | -3.07 | 10.23 | 43 |
| footbridge | r20350567 | bridge | 5.23 | 6.50 | -3.95 | 7.46 | 554 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 1.23 | 2.45 | -2.46 | 3.46 | 409 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 9.86 | 10.54 | -3.11 | 12.09 | 402 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 1.23 | 2.38 | -2.30 | 3.46 | 427 |
| train_in_scan | (laser) | train standing during the scan (189.9 m × 2.5 m) | 1.07 | – | – | 3.97 | 2542 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS perron 1 / track 1 (track 1): laser gives 0.89 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- w48821420 roof: p95 8.0 m is 4.5 m above the median 3.5 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w423455253 (motorway_link, tertiary); w1490476727 (no mapped ways); w1490476730 (no mapped ways); r20346573 (cycleway, footway, service, tertiary).
- Laser-traced roof (102 m², top 12.1 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (102 m², top 12.1 m above the platform, 12.9 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (28 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-10: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6170_725). https://dataforsyningen.dk/data/3931 (scan 2025-03-10; 1,409,149 points in the box, 9.89 per m²; classes {'2': 782107, '3': 41117, '4': 41726, '5': 206260, '6': 215863, '7': 29514, '14': 1090, '17': 86738, '18': 4734}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.5717,55.62577,12.58578,55.63117, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
