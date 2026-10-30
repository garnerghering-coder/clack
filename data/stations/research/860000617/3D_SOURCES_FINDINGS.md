# Roskilde (`860000617`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **44.81** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **44.02** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 35.96 – 52.07 (median 43.97) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 44.81.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6169_694, PUNKTSKY_1km_6170_694, scanned 2024-04-27. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 322.0 | 5.5 | None | 44.01 | 44.78 | 0.77 | 0.60 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 339.0 | 8.4 | None | 44.00 | 44.81 | 0.81 | 0.64 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 339.0 | 8.4 | None | 44.02 | 44.81 | 0.79 | 0.61 |  |
| perron 3 / track 4 | 4 | 55 (0.55) | 367.0 | 7.8 | None | 44.04 | 44.83 | 0.79 | 0.61 |  |
| perron 3 / track 5 | 5 | 55 (0.55) | 367.0 | 7.8 | None | 44.02 | 44.82 | 0.80 | 0.62 |  |
| perron 4 / track 6 | 6 | 55 (0.55) | 322.0 | 7.9 | None | 44.02 | 44.79 | 0.77 | 0.59 |  |
| perron 4 / track 7 | 7 | 55 (0.55) | 322.0 | 7.8 | None | 43.95 | 44.78 | 0.83 | 0.65 |  |

## Structures

`roskilde_structures_heights.geojson`, 20 features: 7 building, 6 canopy_osm, 5 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w331283205 | building | 48.77 | 49.84 | 43.99 | 3.96 | 216 |
| building | w331283206 | building | 50.54 | 54.56 | 42.12 | 5.73 | 105 |
| building | w331283207 | building | 49.64 | 52.03 | 43.67 | 4.83 | 777 |
| canopy_osm | w331283208 | roof | 48.77 | 49.29 | 43.97 | 3.96 | 293 |
| canopy_osm | w331283213 | roof | 47.91 | 48.01 | 43.73 | 3.10 | 196 |
| canopy_osm | w331284123 | roof | 48.48 | 49.08 | 41.90 | 3.66 | 52 |
| canopy_osm | w396597908 | roof | 49.05 | 49.39 | 44.05 | 4.24 | 49 |
| building | w397668034 | station building | 50.52 | 60.22 | 43.86 | 5.71 | 309 |
| building | w397795651 | building | 49.17 | 56.05 | 43.93 | 4.36 | 93 |
| building | w397827704 | building | – | – | 43.46 | – | 0 |
| building | w1164409900 | building | 47.81 | 47.88 | 44.75 | 3.00 | 111 |
| canopy_osm | w1442886797 | building | 46.37 | 46.47 | 43.85 | 1.56 | 31 |
| canopy_osm | w1443067560 | building | 46.50 | 46.61 | 43.95 | 1.69 | 35 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 49.12 | 49.59 | 43.98 | 4.31 | 7526 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 48.71 | 48.76 | 43.93 | 3.90 | 1598 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 48.74 | 48.78 | 43.99 | 3.93 | 1098 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 48.76 | 48.83 | 44.00 | 3.95 | 940 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 48.42 | 48.51 | 44.00 | 3.61 | 924 |
| train_in_scan | (laser) | train standing during the scan (17.4 m × 2.4 m) | 47.87 | – | – | 3.78 | 545 |
| train_in_scan | (laser) | train standing during the scan (76.4 m × 2.7 m) | 47.95 | – | – | 3.94 | 2415 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w331283206 building: p95 54.6 m is 4.0 m above the median 50.5 m (a taller neighbour or a mast inside the outline?).
- w397668034 station building: p95 60.2 m is 9.7 m above the median 50.5 m (a taller neighbour or a mast inside the outline?).
- w397795651 building: p95 56.1 m is 6.9 m above the median 49.2 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (188 m², top 3.6 m above the platform, 4.4 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (80 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-04-27: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6169_694, PUNKTSKY_1km_6170_694). https://dataforsyningen.dk/data/3931 (scan 2024-04-27; 4,567,819 points in the box, 15.6 per m²; classes {'2': 2178662, '3': 176397, '4': 153733, '5': 965220, '6': 977469, '7': 93176, '14': 14158, '17': 95, '18': 8909}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.08026,55.63491,12.0952,55.64221, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
