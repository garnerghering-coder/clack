# CPH Airport (`860000858`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **–** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **–** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -6.14 – 17.99 (median 3.44) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting –.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6170_729, PUNKTSKY_1km_6170_730, PUNKTSKY_1km_6171_729, PUNKTSKY_1km_6171_730, scanned 2025-03-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 1 / track 1 | 1 | 55 (0.55) | 322.0 | 4.3 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |
| perron 2 / track 2 | 2 | 55 (0.55) | 322.0 | 4.4 | None | – | – | – | – | underground platform: the airborne laser sees the surface above it, not the platform or the track bed |

## Structures

`cph_airport_structures_heights.geojson`, 22 features: 5 building, 1 footbridge, 14 canopy_osm.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w25604962 | P4 (parking) | 14.70 | 17.30 | 3.17 | – | 1590 |
| building | w28134507 | P7 (building) | 10.63 | 11.00 | 2.64 | – | 3978 |
| building | w148886117 | station building | – | – | 1.44 | – | 0 |
| canopy_osm | w1017579598 | roof | 10.04 | 10.20 | 4.49 | – | 226 |
| footbridge | w1051058815 | bridge | 7.96 | 9.13 | 2.05 | – | 89 |
| bridge | w1051058820 | bridge | 7.69 | 8.62 | 1.44 | – | 5 |
| bridge | w1051058821 | bridge | 7.66 | 12.80 | -2.70 | – | 94 |
| building | w1051058822 | building | 19.78 | 23.47 | 3.18 | – | 1533 |
| canopy_osm | w1080247627 | roof | 9.86 | 9.93 | 3.53 | – | 152 |
| canopy_osm | w1165610087 | building | 5.92 | 6.00 | 3.43 | – | 100 |
| canopy_osm | w1165610088 | building | 5.92 | 5.99 | 3.46 | – | 68 |
| canopy_osm | w1165610102 | roof | 7.26 | 7.35 | 3.79 | – | 118 |
| canopy_osm | w1165610103 | roof | 7.27 | 7.38 | 3.78 | – | 103 |
| canopy_osm | w1165610104 | roof | 7.29 | 7.38 | 3.78 | – | 358 |
| canopy_osm | w1165610105 | roof | 9.03 | 10.82 | 3.58 | – | 2000 |
| canopy_osm | w1165610106 | roof | 9.99 | 10.71 | 3.70 | – | 1394 |
| canopy_osm | w1165610107 | roof | 9.17 | 10.84 | 3.62 | – | 2610 |
| canopy_osm | w1165610108 | roof | 9.10 | 10.82 | 3.57 | – | 5967 |
| canopy_osm | w1165610109 | roof | 9.91 | 10.68 | 3.64 | – | 4109 |
| canopy_osm | w1165610110 | roof | 9.23 | 10.83 | 3.65 | – | 4258 |
| canopy_osm | w1479402771 | building | 5.73 | 5.78 | 3.29 | – | 58 |
| building | r21036258 | Terminal 3 Københavns Lufthavn (building) | 12.42 | 22.73 | 2.62 | – | 4941 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- New platforms at tracks 11/12 opened 27 April 2026 (Sund & Bælt, Transportministeriet; per the facts pass): not in Bilag 3.6 (table dated 1 August 2023), so not in this register
- w1051058822 building: p95 23.5 m is 3.7 m above the median 19.8 m (a taller neighbour or a mast inside the outline?).
- r21036258 Terminal 3 Københavns Lufthavn (building): p95 22.7 m is 10.3 m above the median 12.4 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w1051058820 (no mapped ways); w1051058821 (no mapped ways).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-10: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6170_729, PUNKTSKY_1km_6170_730, PUNKTSKY_1km_6171_729, PUNKTSKY_1km_6171_730). https://dataforsyningen.dk/data/3931 (scan 2025-03-10; 2,424,477 points in the box, 16.31 per m²; classes {'2': 1046107, '3': 113461, '4': 42998, '5': 202440, '6': 930284, '7': 76114, '14': 1040, '17': 3577, '18': 8456}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.64232,55.62699,12.65644,55.63222, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
