# København H (`860000626`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Banedanmark);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m DVR90 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **1.33** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **0.39** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -0.70 – 10.91 (median 3.13) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 1.33.

## Platforms (Banedanmark register vs laser)

Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length. Laser: DHM punktsky PUNKTSKY_1km_6174_724, PUNKTSKY_1km_6175_724, scanned 2025-03-10. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Perron / track | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| perron 3 / track 5 | 5 | 55 (0.55) | 310.0 | 8.1 | None | 0.42 | 1.17 | 0.75 | 0.57 |  |
| perron 3 / track 6 | 6 | 55 (0.55) | 310.0 | 8.3 | None | 0.42 | 1.17 | 0.75 | 0.57 |  |
| perron 4 / track 7 | 7 | 72 (0.72) | 347.0 | 7.7 | None | 0.48 | 1.39 | 0.91 | 0.74 |  |
| perron 4 / track 8 | 8 | 72 (0.72) | 347.0 | 7.9 | None | 0.40 | 1.38 | 0.98 | 0.81 |  |
| perron 1 / track 1 | 1 | 72 (0.72) | 311.0 | 7.2 | None | 0.42 | 1.37 | 0.95 | 0.78 |  |
| perron 1 / track 2 | 2 | 72 (0.72) | 311.0 | 7.3 | None | 0.40 | 1.37 | 0.97 | 0.80 |  |
| perron 2 / track 3 | 3 | 55 (0.55) | 273.0 | 7.5 | None | 0.39 | 1.14 | 0.75 | 0.58 |  |
| perron 2 / track 4 | 4 | 55 (0.55) | 273.0 | 7.6 | None | 0.39 | 1.14 | 0.75 | 0.58 |  |
| perron 7 / track 26 | 26 | 55 (0.55) | 178.0 | 249.6 | None | 0.33 | 1.32 | 0.99 | 0.81 |  |
| perron 5 / track 9 | 9 | 92 (0.92) | 201.0 | 8.4 | None | 0.17 | 1.33 | 1.16 | 0.99 |  |
| perron 5 / track 10 | 10 | 92 (0.92) | 201.0 | 8.6 | None | 0.16 | 1.33 | 1.17 | 1.00 |  |
| perron 6 / track 11 | 11 | 92 (0.92) | 201.0 | 6.7 | None | 0.21 | 1.33 | 1.12 | 0.95 |  |
| perron 6 / track 12 | 12 | 92 (0.92) | 201.0 | 6.8 | None | 0.18 | 1.33 | 1.15 | 0.98 |  |

## Structures

`kobenhavn_h_structures_heights.geojson`, 112 features: 96 building, 6 canopy_osm, 4 canopy_laser, 1 hall_roof_laser, 4 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Banedanmark track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w25616602 | Tivolis Koncertsal (building) | 12.24 | 15.37 | -0.45 | 10.91 | 7578 |
| building | w25678722 | station building | 9.57 | 12.60 | 0.12 | 8.24 | 5452 |
| building | w26659863 | DGI Byen (sports_centre) | 10.20 | 17.59 | 2.16 | 8.87 | 29541 |
| building | w71407970 | office | 15.35 | 23.12 | 3.14 | 14.02 | 2570 |
| building | w71407972 | building | 22.79 | 23.82 | 2.88 | 21.46 | 457 |
| building | w71407973 | Tietgensgade transformerstation (industrial) | 12.57 | 17.48 | 4.48 | 11.24 | 1384 |
| building | w71407974 | government | 13.79 | 17.41 | 4.37 | 12.46 | 375 |
| building | w89694228 | Den flyvende Kuffert (building) | 7.93 | 12.23 | 2.09 | 6.60 | 1605 |
| building | w89694238 | building | 8.74 | 16.39 | 3.33 | 7.41 | 4427 |
| building | w91260821 | Københavns Hovedbanegård (station building) | 14.71 | 23.39 | 0.07 | 13.38 | 5777 |
| building | w91275428 | station building | 13.20 | 13.83 | 1.07 | 11.87 | 72 |
| building | w100293735 | building | 14.18 | 20.90 | 1.69 | 12.85 | 3277 |
| building | w100293746 | apartments | 14.46 | 21.31 | 1.60 | 13.13 | 5454 |
| building | w115857527 | building | 7.06 | 8.82 | 2.64 | 5.73 | 1342 |
| building | w115857578 | retail | 6.85 | 8.16 | 2.57 | 5.52 | 733 |
| building | w115858115 | apartments | 16.84 | 22.22 | 2.30 | 15.51 | 643 |
| building | w115858116 | apartments | 16.76 | 22.50 | 2.78 | 15.43 | 1083 |
| building | w115858117 | apartments | 16.56 | 23.56 | 2.27 | 15.23 | 632 |
| building | w115858118 | apartments | 17.82 | 21.57 | 3.03 | 16.49 | 338 |
| building | w115858119 | university | 12.16 | 20.65 | 1.74 | 10.83 | 6925 |
| building | w115858120 | apartments | 14.08 | 21.40 | 2.45 | 12.75 | 7218 |
| building | w115858121 | apartments | 13.02 | 18.03 | 1.43 | 11.69 | 1914 |
| building | w115858122 | apartments | 18.35 | 23.55 | 3.01 | 17.02 | 462 |
| building | w115858123 | apartments | 15.53 | 21.19 | 2.56 | 14.20 | 1296 |
| building | w115858124 | apartments | 15.69 | 22.36 | 2.93 | 14.36 | 947 |
| building | w115858125 | apartments | 17.75 | 21.78 | 3.11 | 16.42 | 1162 |
| building | w115858126 | apartments | 15.92 | 22.24 | 1.71 | 14.59 | 858 |
| building | w115858127 | apartments | 14.81 | 21.43 | 1.42 | 13.48 | 3638 |
| building | w115858128 | apartments | 13.26 | 20.26 | 0.98 | 11.93 | 2203 |
| building | w115858156 | apartments | 15.73 | 21.42 | 2.92 | 14.40 | 1537 |
| building | w115858157 | apartments | 15.72 | 22.20 | 1.57 | 14.39 | 3545 |
| building | w115858158 | apartments | 17.80 | 23.57 | 1.39 | 16.47 | 1259 |
| building | w115859478 | university | 6.24 | 9.31 | 2.46 | 4.91 | 608 |
| building | w128033567 | building | 13.56 | 19.20 | 2.59 | 12.23 | 2654 |
| building | w132682512 | building | 10.08 | 13.79 | 3.14 | 8.75 | 2155 |
| building | w132682515 | office | 10.18 | 15.85 | 0.12 | 8.85 | 2004 |
| building | w205605176 | building | 10.22 | 10.29 | 2.10 | 8.89 | 24 |
| building | w205605180 | building | 9.76 | 17.44 | 2.41 | 8.43 | 5057 |
| building | w314828169 | building | 6.63 | 7.42 | 3.08 | 5.30 | 144 |
| building | w314828171 | building | 7.55 | 10.81 | 3.24 | 6.22 | 1074 |
| building | w314828173 | building | 6.05 | 6.65 | 3.53 | 4.72 | 296 |
| bridge | w413851030 | Tietgensbro (bridge) | 7.18 | 13.13 | 0.16 | 5.85 | 11186 |
| building | w554997660 | building | 8.39 | 15.50 | – | 7.06 | 1911 |
| building | w652975859 | service | 7.88 | 7.94 | 0.93 | 6.55 | 243 |
| building | w652975861 | service | 3.59 | 3.64 | 1.07 | 2.26 | 352 |
| building | w652975862 | service | 5.69 | 5.76 | 0.83 | 4.36 | 225 |
| building | w652975863 | service | 5.57 | 5.69 | 0.27 | 4.24 | 226 |
| building | w652975865 | service | 3.60 | 3.64 | 1.06 | 2.27 | 238 |
| building | w652975868 | service | 7.21 | 7.89 | 0.32 | 5.88 | 379 |
| building | w652975870 | service | 7.67 | 7.98 | 0.97 | 6.33 | 348 |
| building | w652975871 | service | – | – | 0.84 | – | 0 |
| building | w652975874 | service | 3.67 | 3.72 | 0.60 | 2.34 | 213 |
| building | w652975875 | building | 7.30 | 7.81 | 0.40 | 5.97 | 252 |
| building | w652975876 | 3064 (service) | 4.04 | 4.48 | 1.04 | 2.71 | 183 |
| building | w652976342 | building | 7.60 | 16.73 | 3.02 | 6.27 | 91 |
| building | w652976351 | shed | 5.64 | 6.24 | 2.96 | 4.31 | 61 |
| building | w653186018 | building | 6.37 | 6.65 | 3.37 | 5.04 | 214 |
| building | w653186026 | building | 8.23 | 9.96 | 3.45 | 6.90 | 330 |
| building | w653186035 | Tik Tak (building) | 8.01 | 12.76 | 2.92 | 6.68 | 3047 |
| building | w653186039 | building | 9.52 | 12.04 | 3.71 | 8.19 | 184 |
| canopy_osm | w653186048 | roof | 11.46 | 17.28 | 6.58 | 10.13 | 57 |
| building | w653186050 | building | 12.28 | 17.91 | 2.46 | 10.95 | 1495 |
| building | w653216228 | building | 6.82 | 6.86 | 4.46 | 5.49 | 30 |
| canopy_osm | w653247246 | roof | 6.29 | 18.17 | 2.76 | 4.96 | 1161 |
| canopy_osm | w653247268 | roof | 5.28 | 7.56 | 2.52 | 3.95 | 34 |
| canopy_osm | w679148877 | building | 9.31 | 9.43 | 6.00 | 7.98 | 741 |
| building | w1013387413 | building | 17.95 | 26.44 | 6.04 | 16.62 | 300 |
| building | w1013387417 | building | – | – | – | – | 0 |
| building | w1013387418 | building | – | – | – | – | 0 |
| building | w1013387419 | building | – | – | – | – | 0 |
| building | w1013387429 | building | 14.48 | 23.39 | 2.17 | 13.15 | 7106 |
| building | w1013387430 | building | – | – | – | – | 0 |
| building | w1013387431 | building | – | – | – | – | 0 |
| building | w1013387432 | building | – | – | – | – | 0 |
| building | w1013387433 | building | 12.69 | 24.27 | 0.91 | 11.36 | 11 |
| building | w1013387434 | building | 10.62 | 16.58 | 3.75 | 9.29 | 3081 |
| building | w1013387435 | building | – | – | – | – | 0 |
| building | w1013387436 | building | – | – | – | – | 0 |
| building | w1013387437 | building | – | – | -0.52 | – | 2 |
| building | w1013387438 | building | – | – | – | – | 0 |
| building | w1013387439 | building | 14.10 | 23.32 | 4.59 | 12.77 | 3577 |
| building | w1013387440 | building | 15.80 | 24.08 | 5.46 | 14.47 | 2459 |
| building | w1017475760 | Danske Bank (office) | 21.37 | 42.24 | 3.23 | 20.04 | 6353 |
| building | w1046559581 | De fire tårne bliver ca. 59.000 m2, fordelt på ca. 33.000 m2 til lejligheder,  hotellejligheder og erhverv samt ca. 26.000 m2 til parkering, teknik og depot. I tårnene bliver der bygget 162 lejligheder og 236 hotellejligheder. (building) | 26.98 | 66.15 | 8.04 | 25.65 | 13956 |
| building | w1046562415 | De fire tårne bliver ca. 59.000 m2, fordelt på ca. 33.000 m2 til lejligheder,  hotellejligheder og erhverv samt ca. 26.000 m2 til parkering, teknik og depot. I tårnene bliver der bygget 162 lejligheder og 236 hotellejligheder. (building) | 74.13 | 114.77 | 7.49 | 72.80 | 17828 |
| building | w1046744401 | The Stamp (office) | 46.05 | 47.89 | 1.80 | 44.72 | 9974 |
| building | w1084266890 | station building | 4.37 | 5.01 | 0.19 | 3.04 | 614 |
| building | w1087551733 | building | 6.52 | 15.94 | 2.29 | 5.19 | 316 |
| building | w1103097512 | Locke Aparthotel (hotel) | 51.35 | 92.56 | 8.02 | 50.02 | 18091 |
| building | w1186079812 | building | 13.41 | 16.20 | 2.64 | 12.08 | 199 |
| building | w1186079813 | retail | 11.64 | 11.76 | 5.27 | 10.31 | 306 |
| building | w1186079814 | retail | 10.66 | 14.85 | 3.28 | 9.33 | 4288 |
| building | w1293517617 | building | 20.90 | 26.12 | 7.22 | 19.57 | 292 |
| building | w1294739600 | building | 5.76 | 6.09 | 3.04 | 4.43 | 25 |
| canopy_osm | w1319644669 | building | 7.13 | 7.20 | 4.44 | 5.80 | 73 |
| building | w1516535905 | Radiobilerne (building) | 9.23 | 12.45 | 3.44 | 7.90 | 778 |
| building | w1516936503 | Galejen (building) | 8.52 | 18.68 | 3.26 | 7.19 | 2332 |
| canopy_osm | w1517166922 | roof | 10.31 | 11.23 | 5.57 | 8.98 | 117 |
| building | w1525679798 | Stairway to parking basement (utility) | 8.57 | 12.87 | 4.54 | 7.24 | 203 |
| building | w1529485764 | building | – | – | – | – | 0 |
| building | r1433982 | apartments | 15.07 | 22.17 | 1.50 | 13.74 | 8569 |
| building | r1627113 | apartments | 15.14 | 23.10 | 3.29 | 13.81 | 10647 |
| building | r7926899 | Centralpostbygningen (commercial) | 12.68 | 23.07 | 2.21 | 11.35 | 18136 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 5.58 | 6.56 | 3.36 | 4.25 | 1964 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 4.98 | 6.05 | 3.44 | 3.65 | 227 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 4.09 | 4.40 | 2.89 | 2.76 | 301 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 4.21 | 4.45 | 2.81 | 2.88 | 270 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 8.45 | 9.13 | 8.38 | 7.12 | 144 |
| train_in_scan | (laser) | train standing during the scan (76.2 m × 2.7 m) | 4.46 | – | – | 3.89 | 3172 |
| train_in_scan | (laser) | train standing during the scan (17.6 m × 2.8 m) | 4.59 | – | – | 3.98 | 329 |
| train_in_scan | (laser) | train standing during the scan (27.1 m × 1.7 m) | 4.44 | – | – | 3.87 | 403 |
| train_in_scan | (laser) | train standing during the scan (23.9 m × 2.3 m) | 4.30 | – | – | 3.74 | 480 |

## Trains in the scan

4 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Perron 7 track 26: the outline FOR_PERRONER_OD Kh 395 runs 5 m along the track, Bilag says 178 m; line drawn to the outline
- Platform BIS perron 7 / track 26 (track 26): laser gives 0.99 m above the track bed (≈0.81 m above rail after −0.15…0.2 m), register class 55 = 0.55 m. Not decided; add to REVIEW.md.
- w25616602 Tivolis Koncertsal (building): p95 15.4 m is 3.1 m above the median 12.2 m (a taller neighbour or a mast inside the outline?).
- w25678722 station building: p95 12.6 m is 3.0 m above the median 9.6 m (a taller neighbour or a mast inside the outline?).
- w26659863 DGI Byen (sports_centre): p95 17.6 m is 7.4 m above the median 10.2 m (a taller neighbour or a mast inside the outline?).
- w71407970 office: p95 23.1 m is 7.8 m above the median 15.3 m (a taller neighbour or a mast inside the outline?).
- w71407973 Tietgensgade transformerstation (industrial): p95 17.5 m is 4.9 m above the median 12.6 m (a taller neighbour or a mast inside the outline?).
- w71407974 government: p95 17.4 m is 3.6 m above the median 13.8 m (a taller neighbour or a mast inside the outline?).
- w89694228 Den flyvende Kuffert (building): p95 12.2 m is 4.3 m above the median 7.9 m (a taller neighbour or a mast inside the outline?).
- w89694238 building: p95 16.4 m is 7.6 m above the median 8.7 m (a taller neighbour or a mast inside the outline?).
- w91260821 Københavns Hovedbanegård (station building): p95 23.4 m is 8.7 m above the median 14.7 m (a taller neighbour or a mast inside the outline?).
- w100293735 building: p95 20.9 m is 6.7 m above the median 14.2 m (a taller neighbour or a mast inside the outline?).
- w100293746 apartments: p95 21.3 m is 6.9 m above the median 14.5 m (a taller neighbour or a mast inside the outline?).
- w115858115 apartments: p95 22.2 m is 5.4 m above the median 16.8 m (a taller neighbour or a mast inside the outline?).
- w115858116 apartments: p95 22.5 m is 5.7 m above the median 16.8 m (a taller neighbour or a mast inside the outline?).
- w115858117 apartments: p95 23.6 m is 7.0 m above the median 16.6 m (a taller neighbour or a mast inside the outline?).
- w115858118 apartments: p95 21.6 m is 3.8 m above the median 17.8 m (a taller neighbour or a mast inside the outline?).
- w115858119 university: p95 20.7 m is 8.5 m above the median 12.2 m (a taller neighbour or a mast inside the outline?).
- w115858120 apartments: p95 21.4 m is 7.3 m above the median 14.1 m (a taller neighbour or a mast inside the outline?).
- w115858121 apartments: p95 18.0 m is 5.0 m above the median 13.0 m (a taller neighbour or a mast inside the outline?).
- w115858122 apartments: p95 23.5 m is 5.2 m above the median 18.4 m (a taller neighbour or a mast inside the outline?).
- w115858123 apartments: p95 21.2 m is 5.7 m above the median 15.5 m (a taller neighbour or a mast inside the outline?).
- w115858124 apartments: p95 22.4 m is 6.7 m above the median 15.7 m (a taller neighbour or a mast inside the outline?).
- w115858125 apartments: p95 21.8 m is 4.0 m above the median 17.8 m (a taller neighbour or a mast inside the outline?).
- w115858126 apartments: p95 22.2 m is 6.3 m above the median 15.9 m (a taller neighbour or a mast inside the outline?).
- w115858127 apartments: p95 21.4 m is 6.6 m above the median 14.8 m (a taller neighbour or a mast inside the outline?).
- w115858128 apartments: p95 20.3 m is 7.0 m above the median 13.3 m (a taller neighbour or a mast inside the outline?).
- w115858156 apartments: p95 21.4 m is 5.7 m above the median 15.7 m (a taller neighbour or a mast inside the outline?).
- w115858157 apartments: p95 22.2 m is 6.5 m above the median 15.7 m (a taller neighbour or a mast inside the outline?).
- w115858158 apartments: p95 23.6 m is 5.8 m above the median 17.8 m (a taller neighbour or a mast inside the outline?).
- w115859478 university: p95 9.3 m is 3.1 m above the median 6.2 m (a taller neighbour or a mast inside the outline?).
- w128033567 building: p95 19.2 m is 5.6 m above the median 13.6 m (a taller neighbour or a mast inside the outline?).
- w132682512 building: p95 13.8 m is 3.7 m above the median 10.1 m (a taller neighbour or a mast inside the outline?).
- w132682515 office: p95 15.8 m is 5.7 m above the median 10.2 m (a taller neighbour or a mast inside the outline?).
- w205605180 building: p95 17.4 m is 7.7 m above the median 9.8 m (a taller neighbour or a mast inside the outline?).
- w314828171 building: p95 10.8 m is 3.3 m above the median 7.5 m (a taller neighbour or a mast inside the outline?).
- w554997660 building: p95 15.5 m is 7.1 m above the median 8.4 m (a taller neighbour or a mast inside the outline?).
- w652976342 building: p95 16.7 m is 9.1 m above the median 7.6 m (a taller neighbour or a mast inside the outline?).
- w653186035 Tik Tak (building): p95 12.8 m is 4.8 m above the median 8.0 m (a taller neighbour or a mast inside the outline?).
- w653186048 roof: p95 17.3 m is 5.8 m above the median 11.5 m (a taller neighbour or a mast inside the outline?).
- w653186050 building: p95 17.9 m is 5.6 m above the median 12.3 m (a taller neighbour or a mast inside the outline?).
- w653247246 roof: p95 18.2 m is 11.9 m above the median 6.3 m (a taller neighbour or a mast inside the outline?).
- w1013387413 building: p95 26.4 m is 8.5 m above the median 18.0 m (a taller neighbour or a mast inside the outline?).
- w1013387429 building: p95 23.4 m is 8.9 m above the median 14.5 m (a taller neighbour or a mast inside the outline?).
- w1013387433 building: p95 24.3 m is 11.6 m above the median 12.7 m (a taller neighbour or a mast inside the outline?).
- w1013387434 building: p95 16.6 m is 6.0 m above the median 10.6 m (a taller neighbour or a mast inside the outline?).
- w1013387439 building: p95 23.3 m is 9.2 m above the median 14.1 m (a taller neighbour or a mast inside the outline?).
- w1013387440 building: p95 24.1 m is 8.3 m above the median 15.8 m (a taller neighbour or a mast inside the outline?).
- w1017475760 Danske Bank (office): p95 42.2 m is 20.9 m above the median 21.4 m (a taller neighbour or a mast inside the outline?).
- w1046559581 De fire tårne bliver ca. 59.000 m2, fordelt på ca. 33.000 m2 til lejligheder,  hotellejligheder og erhverv samt ca. 26.000 m2 til parkering, teknik og depot. I tårnene bliver der bygget 162 lejligheder og 236 hotellejligheder. (building): p95 66.2 m is 39.2 m above the median 27.0 m (a taller neighbour or a mast inside the outline?).
- w1046562415 De fire tårne bliver ca. 59.000 m2, fordelt på ca. 33.000 m2 til lejligheder,  hotellejligheder og erhverv samt ca. 26.000 m2 til parkering, teknik og depot. I tårnene bliver der bygget 162 lejligheder og 236 hotellejligheder. (building): p95 114.8 m is 40.6 m above the median 74.1 m (a taller neighbour or a mast inside the outline?).
- w1103097512 Locke Aparthotel (hotel): p95 92.6 m is 41.2 m above the median 51.4 m (a taller neighbour or a mast inside the outline?).
- w1186079814 retail: p95 14.8 m is 4.2 m above the median 10.7 m (a taller neighbour or a mast inside the outline?).
- w1293517617 building: p95 26.1 m is 5.2 m above the median 20.9 m (a taller neighbour or a mast inside the outline?).
- w1516535905 Radiobilerne (building): p95 12.5 m is 3.2 m above the median 9.2 m (a taller neighbour or a mast inside the outline?).
- w1516936503 Galejen (building): p95 18.7 m is 10.2 m above the median 8.5 m (a taller neighbour or a mast inside the outline?).
- w1525679798 Stairway to parking basement (utility): p95 12.9 m is 4.3 m above the median 8.6 m (a taller neighbour or a mast inside the outline?).
- r1433982 apartments: p95 22.2 m is 7.1 m above the median 15.1 m (a taller neighbour or a mast inside the outline?).
- r1627113 apartments: p95 23.1 m is 8.0 m above the median 15.1 m (a taller neighbour or a mast inside the outline?).
- r7926899 Centralpostbygningen (commercial): p95 23.1 m is 10.4 m above the median 12.7 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w413851030 Tietgensbro (tertiary).
- Laser-traced roof (114 m², top 7.1 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 0 files found (0 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-03-10: anything built since is missing from the laser (compare the Banedanmark valid-from dates).

## Sources

- Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6174_724, PUNKTSKY_1km_6175_724). https://dataforsyningen.dk/data/3931 (scan 2025-03-10; 7,563,812 points in the box, 30.2 per m²; classes {'2': 2535689, '3': 537808, '4': 133052, '5': 1126938, '6': 2948648, '7': 174121, '14': 9161, '17': 84514, '18': 13881}).
- Ground grid: made here from the same laser (class 2).
- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.55966,55.66658,12.57194,55.67568, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
