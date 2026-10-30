# Pasila (`fi:PSL`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **24.33** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **23.63** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 9.56 – 35.88 (median 23.37) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 24.33.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_hel2021_676496a, clack_fi_hel2021_676496b, scanned 2021. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| PSL L1 | 1 | korkea (0.55) | 332.0 | – | None | 23.63 | 24.33 | 0.70 | 0.52 |  |
| PSL L2 | 2 | korkea (0.55) | 321.0 | – | None | 23.59 | 24.33 | 0.74 | 0.57 |  |
| PSL L3 | 3 | korkea (0.55) | 418.0 | – | None | 23.71 | 24.43 | 0.72 | 0.54 |  |
| PSL L4 | 4 | korkea (0.55) | 418.0 | – | None | 23.69 | 24.41 | 0.72 | 0.54 |  |
| PSL L5 | 5 | korkea (0.55) | 433.0 | – | None | 23.73 | 24.77 | 1.04 | 0.87 |  |
| PSL L6 | 6 | korkea (0.55) | 447.0 | – | None | 23.88 | 24.78 | 0.90 | 0.73 |  |
| PSL L7 | 7 | korkea (0.55) | 320.0 | – | None | 23.56 | 24.23 | 0.67 | 0.49 |  |
| PSL L8 | 8 | korkea (0.55) | 322.0 | – | None | 23.59 | 24.32 | 0.73 | 0.55 |  |
| PSL L9 | 9 | korkea (0.55) | 321.0 | – | None | 23.63 | 24.31 | 0.69 | 0.51 |  |
| PSL L10 | 10 | matala (0.27) | 320.0 | – | None | 23.62 | 24.37 | 0.75 | 0.57 |  |
| PSL L11 | 11 | korkea (0.55) | 250.0 | – | None | 23.52 | 24.31 | 0.79 | 0.61 |  |

## Structures

`pasila_structures_heights.geojson`, 50 features: 31 building, 10 canopy_osm, 4 hall_roof_laser.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w9647598 | building | 57.84 | 58.05 | 25.82 | 33.51 | 1082 |
| canopy_osm | w31713670 | roof | 50.88 | 50.91 | 17.43 | 26.55 | 585 |
| bridge | w155457229 | Pasilansilta (bridge) | 29.69 | 38.93 | 14.52 | 5.36 | 8462 |
| bridge | w574637018 | bridge | 23.65 | 25.55 | 17.20 | -0.68 | 518 |
| building | w621975025 | Tripla Workery West (commercial) | 79.50 | 93.32 | 15.28 | 55.17 | 11996 |
| building | w621975602 | Pasilan rautatieasema (station building) | 55.94 | 80.24 | 22.68 | 31.61 | 17136 |
| building | w621975603 | building | 69.26 | 80.39 | 22.68 | 44.93 | 3523 |
| building | w621975604 | building | 69.35 | 80.35 | 23.27 | 45.02 | 9849 |
| building | w721657452 | service | 27.00 | 27.06 | 24.42 | 2.67 | 66 |
| building | w1024911731 | building | 31.45 | 44.57 | 15.18 | 7.12 | 257 |
| building | w1025824935 | building | 48.55 | 56.20 | 23.21 | 24.22 | 3788 |
| bridge | w1118864385 | bridge | 25.30 | 25.40 | 15.45 | 0.97 | 645 |
| building | w1134455891 | building | 29.16 | 78.27 | 22.85 | 4.83 | 189 |
| building | w1134546152 | 3-4 (transportation) | 28.39 | 30.09 | 23.98 | 4.06 | 437 |
| building | w1134546153 | 5-6 (transportation) | 28.34 | 30.04 | 23.39 | 4.01 | 513 |
| building | w1134546154 | 7-8 (transportation) | 28.35 | 30.25 | 23.27 | 4.02 | 438 |
| building | w1134546155 | 9-10 (transportation) | 28.45 | 31.02 | 23.57 | 4.12 | 234 |
| building | w1134546156 | 11 (transportation) | 28.52 | 30.78 | 23.16 | 4.19 | 248 |
| building | w1134723992 | retail | 31.53 | 80.20 | 15.22 | 7.20 | 8535 |
| building | w1134729404 | building | 57.96 | 93.32 | 15.18 | 33.63 | 20020 |
| building | w1196125831 | building | – | – | – | – | 0 |
| building | w1196125832 | building | – | – | – | – | 0 |
| building | w1245442056 | 1-2 (transportation) | 76.99 | 80.25 | 24.03 | 52.66 | 300 |
| canopy_osm | w1284814285 | roof | 24.95 | 24.99 | 22.17 | 0.62 | 275 |
| canopy_osm | w1284814286 | roof | 27.15 | 27.19 | 24.39 | 2.82 | 343 |
| canopy_osm | w1284814287 | roof | 28.69 | 28.73 | 26.17 | 4.36 | 374 |
| building | w1307088408 | apartments | 19.02 | 21.35 | 16.55 | -5.31 | 781 |
| building | w1307088410 | apartments | – | – | 17.47 | – | 0 |
| building | w1355619972 | commercial | 53.41 | 57.76 | 30.12 | 29.09 | 2124 |
| building | w1355619982 | building | 53.41 | 57.76 | 30.12 | 29.09 | 2124 |
| building | w1362426141 | Pasilan virastokeskus (office) | 57.70 | 58.05 | 25.82 | 33.37 | 1411 |
| bridge | w1384641422 | bridge | 25.17 | 26.28 | 17.22 | 0.84 | 722 |
| bridge | w1384641423 | bridge | 26.28 | 30.11 | 17.24 | 1.95 | 115 |
| canopy_osm | w1447697492 | canopy | – | – | – | – | 0 |
| canopy_osm | w1447697493 | canopy | – | – | – | – | 0 |
| canopy_osm | w1447697494 | canopy | – | – | – | – | 0 |
| canopy_osm | w1447697495 | canopy | – | – | – | – | 0 |
| building | w1557701180 | building | 21.33 | 21.37 | 17.38 | -3.00 | 131 |
| building | w1557701186 | building | 19.58 | 20.62 | 16.95 | -4.75 | 30 |
| building | w1557701191 | building | – | – | 17.39 | – | 0 |
| canopy_osm | r13706934 | roof | 38.93 | 38.95 | 31.51 | 14.60 | 567 |
| canopy_osm | r13756565 | roof | 37.83 | 37.86 | 31.44 | 13.50 | 5162 |
| building | r15350849 | Pasilan asemahalli (building) | 51.12 | 80.20 | 22.85 | 26.79 | 828 |
| building | r16121663 | Kulttuuriaukio (building) | 93.15 | 93.46 | 32.32 | 68.82 | 366 |
| building | r19097175 | Mall of Tripla (retail) | 56.24 | 93.16 | 14.56 | 31.91 | 84384 |
| building | r21358353 | building | 35.42 | 35.54 | 23.95 | 11.09 | 641 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.48 | 32.72 | 21.00 | 8.15 | 4823 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.03 | 35.18 | 31.17 | 7.70 | 4620 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.11 | 33.51 | 31.89 | 7.78 | 1730 |
| hall_roof_laser | (laser) | roof over the platforms (traced from the laser) | 32.49 | 32.93 | 31.90 | 8.16 | 1856 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS PSL L5 (track 5): laser gives 1.04 m above the track bed (≈0.87 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS PSL L6 (track 6): laser gives 0.90 m above the track bed (≈0.73 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS PSL L10 (track 10): laser gives 0.75 m above the track bed (≈0.57 m above rail after −0.15…0.2 m), register class matala = 0.265 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 0.55 m across the station (24.23–24.78 m); the station reference above is their median — check which level the app should use.
- w621975602 Pasilan rautatieasema (station building): p95 80.2 m is 24.3 m above the median 55.9 m (a taller neighbour or a mast inside the outline?).
- w621975603 building: p95 80.4 m is 11.1 m above the median 69.3 m (a taller neighbour or a mast inside the outline?).
- w621975604 building: p95 80.4 m is 11.0 m above the median 69.4 m (a taller neighbour or a mast inside the outline?).
- w1024911731 building: p95 44.6 m is 13.1 m above the median 31.4 m (a taller neighbour or a mast inside the outline?).
- w1025824935 building: p95 56.2 m is 7.7 m above the median 48.5 m (a taller neighbour or a mast inside the outline?).
- w1134455891 building: p95 78.3 m is 49.1 m above the median 29.2 m (a taller neighbour or a mast inside the outline?).
- w1134723992 retail: p95 80.2 m is 48.7 m above the median 31.5 m (a taller neighbour or a mast inside the outline?).
- w1245442056 1-2 (transportation): p95 80.2 m is 3.3 m above the median 77.0 m (a taller neighbour or a mast inside the outline?).
- r15350849 Pasilan asemahalli (building): p95 80.2 m is 29.1 m above the median 51.1 m (a taller neighbour or a mast inside the outline?).
- r19097175 Mall of Tripla (retail): p95 93.2 m is 36.9 m above the median 56.2 m (a taller neighbour or a mast inside the outline?).
- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w155457229 Pasilansilta (cycleway, footway, service, tertiary); w574637018 (construction, cycleway, primary); w1118864385 (no mapped ways); w1384641422 (no mapped ways); w1384641423 (no mapped ways).
- Laser-traced roof (414 m², top 8.2 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (640 m², top 7.7 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (640 m², top 7.7 m above the platform, 8.4 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (255 m², top 7.8 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (255 m², top 7.8 m above the platform, 8.5 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.
- Laser-traced roof (200 m², top 8.2 m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.
- Laser-traced roof (200 m², top 8.2 m above the platform, 8.9 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (33 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Helsingin laserkeilausaineisto 2021 (kaikki pisteet, 0.5 km tiles clack_fi_hel2021_676496a, clack_fi_hel2021_676496b), City of Helsinki, Kaupunkimittauspalvelut, CC BY 4.0. https://hri.fi/data/en/dataset/helsingin-laserkeilausaineistot (scan 2021; 12,024,426 points in the box, 59.93 per m²; classes {'1': 1393, '2': 5735730, '3': 973645, '4': 336423, '5': 1226820, '6': 2839803, '8': 113636, '17': 796976}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=24.928407,60.196246,24.937263,60.203597, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
