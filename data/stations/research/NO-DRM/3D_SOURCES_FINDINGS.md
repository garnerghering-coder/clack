# Drammen (`NO-DRM`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Bane NOR);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m NN2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **2.17** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **1.71** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -4.42 – 16.15 (median 2.01) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 2.17.

## Platforms (Bane NOR register vs laser)

Register: Bane NOR station page, track table (https://www.banenor.no/en/traffic-and-travel/railway-stations/-d-/drammen/, read 2026-10-30): per track the platform length, height (mm above top of rail), width and type; no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes. Laser: hoydedata.no project Drammen Eiker 2015, scanned 2015-07-07. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| track 1 | 1 | 760 (0.76) | 350.0 | 3.5 | None | 1.63 | 1.90 | 0.27 | 0.10 | platform surface from unclassified (class 1) laser points: this scan left the platform deck unclassified; flat band bed+0.2…+1.6 m |
| track 3 | 2,3 | 760 (0.76) | 350.0 | 3.5 | None | 2.06 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| track 4 | 4,5 | 760 (0.76) | 350.0 | 3.5 | None | 1.79 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| track 6 | 6 | 760 (0.76) | 350.0 | 3.5 | None | 1.61 | 2.43 | 0.82 | 0.65 |  |

## Structures

`drammen_structures_heights.geojson`, 38 features: 17 building, 10 canopy_osm, 3 canopy_laser, 4 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Bane NOR track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w111633153 | transportation | 7.53 | 7.60 | 2.48 | 5.36 | 167 |
| building | w134395837 | Drammen stasjon (station building) | 16.34 | 16.78 | 2.35 | 14.17 | 404 |
| building | w134395844 | Drammen stasjon (station building) | 7.22 | 10.49 | 2.23 | 5.05 | 204 |
| building | w134396697 | office | 14.18 | 20.69 | 2.36 | 12.01 | 255 |
| building | w134396699 | office | 20.78 | 21.02 | 2.20 | 18.61 | 219 |
| building | w134396701 | service | 8.17 | 8.60 | 2.32 | 6.00 | 250 |
| building | w139976887 | Drammen busstasjon (transportation) | 6.33 | 6.38 | 2.21 | 4.16 | 776 |
| building | w139979083 | Drammen brannstasjon (fire_station) | – | – | – | – | 0 |
| building | w152126642 | transportation | 11.49 | 12.30 | 2.46 | 9.32 | 352 |
| building | w152251029 | building | 20.60 | 23.51 | 2.29 | 18.43 | 215 |
| canopy_osm | w486952622 | roof | 7.59 | 7.65 | 2.81 | 5.42 | 103 |
| canopy_osm | w487054823 | roof | 13.20 | 13.32 | 7.65 | 11.03 | 245 |
| building | w490626523 | apartments | 18.47 | 23.48 | 2.29 | 16.30 | 348 |
| canopy_osm | w491749404 | shelter | 3.23 | 3.26 | 0.18 | 1.06 | 7 |
| canopy_osm | w491749406 | shelter | 3.22 | 3.29 | 0.17 | 1.05 | 5 |
| bridge | w594335608 | Bybrua (bridge) | 8.91 | 11.78 | 0.08 | 6.74 | 132 |
| bridge | w727089259 | bridge | – | – | 0.17 | – | 0 |
| bridge | w727089260 | bridge | – | – | 0.17 | – | 0 |
| bridge | w727089261 | Strømsøbrua (bridge) | – | – | – | – | 0 |
| canopy_osm | w751098853 | roof | – | – | – | – | 0 |
| canopy_osm | w930916193 | service | 9.87 | 12.23 | 2.57 | 7.70 | 138 |
| building | w980248930 | Quality Hotel River Station (hotel) | 9.50 | 10.32 | 1.80 | 7.33 | 57 |
| building | w991416887 | transportation | 6.27 | 6.36 | 3.12 | 4.10 | 158 |
| building | w991418896 | transportation | 7.97 | 8.13 | 2.11 | 5.80 | 660 |
| building | w991466242 | transportation | 9.32 | 9.73 | 3.12 | 7.15 | 58 |
| building | w991466420 | garage | 4.94 | 4.99 | 2.28 | 2.77 | 61 |
| building | w1116374192 | transportation | 8.38 | 8.63 | 3.10 | 6.21 | 282 |
| canopy_osm | w1535657340 | roof | 13.15 | 16.90 | 2.30 | 10.98 | 7 |
| canopy_osm | w1535657348 | roof | – | – | 1.29 | – | 0 |
| canopy_osm | w1535657349 | roof | 5.82 | 9.18 | 1.50 | 3.65 | 510 |
| canopy_osm | w1535657350 | roof | 6.88 | 9.66 | 1.55 | 4.71 | 227 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 5.87 | 7.67 | 1.61 | 3.70 | 794 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 5.78 | 6.22 | 1.46 | 3.61 | 2223 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 6.17 | 7.27 | 1.70 | 4.00 | 3313 |
| train_in_scan | (laser) | train standing during the scan (68.5 m × 1.2 m) | 6.62 | – | – | 4.04 | 464 |
| train_in_scan | (laser) | train standing during the scan (24.4 m × 1.8 m) | 6.22 | – | – | 3.99 | 268 |
| train_in_scan | (laser) | train standing during the scan (31.1 m × 2.1 m) | 6.27 | – | – | 4.10 | 306 |
| train_in_scan | (laser) | train standing during the scan (88.6 m × 3.3 m) | 6.26 | – | – | 4.47 | 1398 |

## Trains in the scan

4 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS track 1 (track 1): laser gives 0.27 m above the track bed (≈0.10 m above rail after −0.15…0.2 m), register class 760 = 0.76 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 0.53 m across the station (1.90–2.43 m); the station reference above is their median — check which level the app should use.
- w134395844 Drammen stasjon (station building): p95 10.5 m is 3.3 m above the median 7.2 m (a taller neighbour or a mast inside the outline?).
- w134396697 office: p95 20.7 m is 6.5 m above the median 14.2 m (a taller neighbour or a mast inside the outline?).
- w1535657340 roof: p95 16.9 m is 3.8 m above the median 13.2 m (a taller neighbour or a mast inside the outline?).
- w1535657349 roof: p95 9.2 m is 3.4 m above the median 5.8 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w594335608 Bybrua (footway, tertiary); w727089259 (no mapped ways); w727089260 (no mapped ways); w727089261 Strømsøbrua (footway, trunk).
- Laser-traced roof (241 m², top 3.7 m above the platform, 4.2 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.
- Laser-traced roof (498 m², top 3.6 m above the platform, 4.1 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.
- Laser-traced roof (731 m², top 4.0 m above the platform, 4.5 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (17 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2015-07-07: anything built since is missing from the laser (compare the Bane NOR valid-from dates).

## Sources

- Høydedata, project "Drammen Eiker 2015" (id 341, FKB-Laser 2.0, nominal 5 points/m², supplier Blom Geomatics), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box. https://hoydedata.no/LaserInnsyn2/ (scan 2015-07-07; 5,484,001 points in the box, 5.95 per m²; classes {'1': 2471828, '2': 2962433, '7': 7436, '10': 42304}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Bane NOR station page https://www.banenor.no/en/traffic-and-travel/railway-stations/-d-/drammen/ (track table, facts om stasjonen), read 2026-10-30: facts only.
- Entur National Stop Register quays via journey-planner v3 (NLOD), read 2026-10-30.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=10.196235,59.736104,10.214235,59.744104, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
