# Skanderborg (`860000061`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **48.83** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **47.93** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 24.17 – 69.55 (median 47.91) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 48.83.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6211_557, scanned 2025-03-22. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 220.0 | 4.3 | None | 47.92 | 48.76 | 0.84 | 0.66 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 266.0 | 8.3 | None | 48.00 | 48.84 | 0.84 | 0.67 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 266.0 | 8.4 | None | 47.93 | 48.83 | 0.90 | 0.72 |  |

## Structures

`skanderborg_structures_heights.geojson`, 10 features: 5 building, 3 canopy_osm, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w49511360 | station building | – | – | – | – | 0 |
| building | w49512202 | Museum Skanderborg (building) | 54.05 | 54.25 | 47.73 | 5.22 | 842 |
| canopy_osm | w433455940 | roof | 51.49 | 52.02 | 48.29 | 2.66 | 1637 |
| building | w433455941 | station building | 51.24 | 51.30 | 48.24 | 2.41 | 72 |
| canopy_osm | w433500353 | roof | 46.75 | 46.83 | 43.00 | -2.08 | 42 |
| building | w433516648 | station building | 51.53 | 51.72 | 48.23 | 2.70 | 40 |
| building | w648695442 | building | 47.48 | 48.00 | 44.55 | -1.35 | 75 |
| canopy_osm | r6439812 | roof | 51.19 | 52.23 | 47.85 | 2.36 | 987 |
| train_in_scan | (laser) | train standing during the scan (41.2 m × 2.6 m) | 50.84 | – | – | 3.91 | 728 |
| train_in_scan | (laser) | train standing during the scan (109.1 m × 2.7 m) | 51.42 | – | – | 3.90 | 1914 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 1 track 1: the outline FOR_PERRONER_OD Sd 171 runs 320 m along the track, Bilag says 220 m; line drawn to the outline
- Perron 2 track 2: the outline FOR_PERRONER_OD Sd 172 runs 365 m along the track, Bilag says 266 m; line drawn to the outline
- Perron 2 track 3: the outline FOR_PERRONER_OD Sd 172 runs 361 m along the track, Bilag says 266 m; line drawn to the outline
- Platform BIS perron 2 / track 3 (track 3): laser gives 0.90 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-22: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6211_557). https://dataforsyningen.dk/data/3931 (scan 2025-03-22; 5,323,008 points in the box, 23.71 per m²; classes {'2': 2415565, '3': 264581, '4': 203007, '5': 1881359, '6': 476235, '7': 69659, '14': 487, '17': 3916, '18': 8199}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=9.91871,56.04079,9.93331,56.0471, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
