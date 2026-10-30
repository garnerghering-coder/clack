# Køge Nord (`860000797`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **7.69** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **6.95** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.85 – 15.44 (median 6.87) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 7.69.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6154_700, PUNKTSKY_1km_6155_700, scanned 2025-03-19. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 3 / track 3 | 3 | 55 (0.55) | 400.0 | 14.0 | None | 6.96 | 7.69 | 0.73 | 0.56 |  |
| perron 3 / track 4 | 4 | 55 (0.55) | 400.0 | 14.0 | None | 6.95 | 7.69 | 0.74 | 0.57 |  |
| perron 4 / track 6 | 6 | 55 (0.55) | 400.0 | 12.6 | None | 6.95 | 7.70 | 0.75 | 0.57 |  |
| perron 4 / track 7 | 7 | 55 (0.55) | 400.0 | 12.6 | None | 6.96 | 7.70 | 0.74 | 0.57 |  |
| perron 1 / track 1 | 1 | 92 (0.92) | 180.0 | 12.9 | None | 4.24 | 5.48 | 1.24 | 1.07 |  |
| perron 2 / track 2 | 2 | 92 (0.92) | 180.0 | 9.5 | None | 4.30 | 5.49 | 1.19 | 1.02 |  |

## Structures

`koge_nord_structures_heights.geojson`, 4 features: 2 footbridge, 2 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| footbridge | w542437234 | bridge | 15.92 | 17.06 | 2.30 | 8.23 | 94 |
| footbridge | w762353310 | bridge | 17.58 | 19.25 | 4.27 | 9.89 | 1034 |
| canopy_osm | w1163116041 | building | 10.16 | 10.18 | 7.63 | 2.47 | 81 |
| canopy_osm | w1163116042 | building | 10.14 | 10.17 | 7.60 | 2.45 | 47 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS perron 1 / track 1 (track 1): laser gives 1.24 m above the track bed (≈1.07 m above rail after −0.15…0.2 m), register class 92 = 0.92 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 2.22 m across the station (5.48–7.70 m); the station reference above is their median — check which level the app should use.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 6 files found (6 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-19: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6154_700, PUNKTSKY_1km_6155_700). https://dataforsyningen.dk/data/3931 (scan 2025-03-19; 3,283,518 points in the box, 10.68 per m²; classes {'2': 2496819, '3': 60723, '4': 91425, '5': 483339, '6': 117760, '7': 25980, '14': 1115, '17': 1719, '18': 4638}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.16716,55.4956,12.1802,55.50419, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
