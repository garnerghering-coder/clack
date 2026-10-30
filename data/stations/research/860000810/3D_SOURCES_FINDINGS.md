# Næstved (`860000810`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **14.38** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **13.60** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 9.99 – 40.80 (median 13.93) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 14.38.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6123_675, PUNKTSKY_1km_6123_676, PUNKTSKY_1km_6124_675, PUNKTSKY_1km_6124_676, scanned 2024-03-29. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 72 (0.72) | 286.0 | 5.4 | None | 13.58 | 14.39 | 0.81 | 0.64 |  |
| perron 2 / track 2 | 2 | 55 (0.55) | 400.0 | 6.8 | None | 13.61 | 14.36 | 0.75 | 0.57 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 400.0 | 6.8 | None | 13.60 | 14.37 | 0.77 | 0.60 |  |
| perron 3 / track 4 | 4 | 55 (0.55) | 400.0 | 7.4 | None | 13.62 | 14.38 | 0.76 | 0.58 |  |
| perron 3 / track 5 | 5 | 55 (0.55) | 400.0 | 7.3 | None | 13.60 | 14.38 | 0.78 | 0.61 |  |

## Structures

`naestved_structures_heights.geojson`, 38 features: 19 building, 2 footbridge, 6 canopy_osm, 2 canopy_laser, 1 hall_roof_laser, 8 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w115776625 | station building | 21.54 | 24.36 | 12.26 | 7.16 | 1367 |
| building | w115776679 | building | 17.45 | 19.59 | 11.94 | 3.07 | 275 |
| building | w115776683 | building | 26.87 | 27.22 | 13.90 | 12.49 | 24 |
| building | w115776738 | building | 19.45 | 21.40 | 13.71 | 5.07 | 616 |
| building | w115776743 | building | 18.03 | 18.10 | 13.56 | 3.65 | 195 |
| canopy_osm | w115776772 | roof | 18.06 | 18.17 | 13.56 | 3.68 | 91 |
| building | w609181738 | building | 16.01 | 16.06 | 13.70 | 1.63 | 224 |
| building | w609181924 | building | 16.01 | 16.05 | 13.71 | 1.63 | 279 |
| building | w609183947 | building | 16.02 | 16.06 | 13.71 | 1.64 | 251 |
| building | w609183957 | building | – | – | 13.84 | – | 0 |
| building | w609184328 | building | 16.02 | 16.05 | 13.70 | 1.64 | 228 |
| building | w609185774 | building | 16.02 | 16.06 | 13.70 | 1.64 | 275 |
| building | w609185800 | building | 16.24 | 16.27 | 13.85 | 1.86 | 108 |
| building | w609188897 | building | 16.01 | 16.03 | 13.71 | 1.63 | 137 |
| building | w609189534 | building | 16.01 | 16.05 | 13.70 | 1.63 | 173 |
| building | w609189983 | building | 16.29 | 16.42 | 13.90 | 1.91 | 26 |
| building | w609190760 | building | 16.23 | 16.26 | 13.89 | 1.85 | 84 |
| building | w609192049 | building | 16.79 | 18.10 | 13.94 | 2.41 | 80 |
| building | w609192532 | building | 16.02 | 16.05 | 13.70 | 1.64 | 260 |
| footbridge | w641161976 | bridge | 21.52 | 22.55 | 13.44 | 7.13 | 1532 |
| canopy_osm | w1164158599 | building | 16.92 | 16.96 | 14.40 | 2.54 | 74 |
| canopy_osm | w1164158600 | building | 16.69 | 16.76 | 14.31 | 2.31 | 30 |
| canopy_osm | w1164158602 | building | 16.73 | 16.74 | 14.35 | 2.35 | 18 |
| canopy_osm | w1164158603 | building | 16.71 | 16.78 | 14.30 | 2.33 | 18 |
| building | w1164158604 | building | 17.19 | 18.37 | 13.87 | 2.81 | 1305 |
| canopy_osm | w1164158629 | building | 16.89 | 16.91 | 14.33 | 2.51 | 74 |
| footbridge | w1377451327 | bridge | 19.01 | 21.07 | 13.93 | 4.63 | 1903 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 21.13 | 21.50 | 13.56 | 6.75 | 2271 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 18.06 | 20.35 | 13.56 | 3.68 | 2666 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 18.01 | 18.11 | 13.56 | 3.63 | 669 |
| train_in_scan | (laser) | train standing during the scan (64.2 m × 2.8 m) | 18.06 | – | – | 4.42 | 3723 |
| train_in_scan | (laser) | train standing during the scan (125.3 m × 2.9 m) | 18.01 | – | – | 4.24 | 7710 |
| train_in_scan | (laser) | train standing during the scan (27.8 m × 2.9 m) | 18.05 | – | – | 4.35 | 1800 |
| train_in_scan | (laser) | train standing during the scan (90.7 m × 2.9 m) | 17.84 | – | – | 4.25 | 5173 |
| train_in_scan | (laser) | train standing during the scan (117.0 m × 2.8 m) | 17.42 | – | – | 3.84 | 3290 |
| train_in_scan | (laser) | train standing during the scan (31.4 m × 2.5 m) | 18.24 | – | – | 4.49 | 894 |
| train_in_scan | (laser) | train standing during the scan (113.1 m × 2.7 m) | 18.08 | – | – | 4.35 | 3221 |
| train_in_scan | (laser) | train standing during the scan (72.4 m × 3.6 m) | 17.92 | – | – | 4.27 | 2993 |

## Trains in the scan

8 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Laser-traced roof (219 m², top 6.7 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (219 m², top 6.7 m above the platform, 7.5 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 98 files found (43 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2024-03-29: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6123_675, PUNKTSKY_1km_6123_676, PUNKTSKY_1km_6124_675, PUNKTSKY_1km_6124_676). https://dataforsyningen.dk/data/3931 (scan 2024-03-29; 5,599,845 points in the box, 18.84 per m²; classes {'2': 2789534, '3': 383641, '4': 207878, '5': 1281013, '6': 794540, '7': 88436, '14': 14899, '17': 31600, '18': 8304}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=11.76051,55.22768,11.77331,55.23637, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
