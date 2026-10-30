# Helsinki (`fi:HKI`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **4.09** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **3.23** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | -4.97 – 9.95 (median 3.31) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 4.09.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_hel2021_673496c, clack_fi_hel2021_673496d, scanned 2021. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| HKI L1 | 1 | korkea (0.55) | 278.0 | – | None | 3.27 | 4.10 | 0.83 | 0.65 |  |
| HKI L2 | 2 | korkea (0.55) | 290.0 | – | None | 3.28 | 4.10 | 0.82 | 0.65 |  |
| HKI L3 | 3 | korkea (0.55) | 288.0 | – | None | 3.26 | 4.09 | 0.83 | 0.66 |  |
| HKI L4 | 4 | korkea (0.55) | 423.0 | – | None | 3.27 | 4.08 | 0.81 | 0.64 |  |
| HKI L6 | 6 | korkea (0.55) | 416.0 | – | None | 3.22 | 4.12 | 0.90 | 0.72 |  |
| HKI L7 | 7 | korkea (0.55) | 438.0 | – | None | 3.26 | 4.09 | 0.83 | 0.66 |  |
| HKI L8 | 8 | korkea (0.55) | 444.0 | – | None | 3.22 | 4.10 | 0.88 | 0.70 |  |
| HKI L11 | 11 | korkea (0.55) | 363.0 | – | None | 3.23 | 4.09 | 0.86 | 0.68 |  |
| HKI L12 | 12 | korkea (0.55) | 275.0 | – | None | 3.22 | 4.09 | 0.87 | 0.70 |  |
| HKI L13 | 13 | korkea (0.55) | 236.0 | – | None | 3.22 | 4.06 | 0.84 | 0.67 |  |
| HKI L14 | 14 | korkea (0.55) | 246.0 | – | None | 3.22 | 4.06 | 0.85 | 0.67 |  |
| HKI L15 | 15 | korkea (0.55) | 246.0 | – | None | 3.23 | 4.04 | 0.82 | 0.64 |  |
| HKI L16 | 16 | korkea (0.55) | 246.0 | – | None | 3.21 | 4.04 | 0.84 | 0.66 |  |
| HKI L17 | 17 | korkea (0.55) | 246.0 | – | None | 3.21 | 4.10 | 0.89 | 0.72 |  |
| HKI L18 | 18 | korkea (0.55) | 246.0 | – | None | 3.14 | 4.10 | 0.96 | 0.78 |  |
| HKI L19 | 19 | korkea (0.55) | 246.0 | – | None | 3.21 | 4.06 | 0.85 | 0.68 |  |
| HKI L5 | 5 | korkea (0.55) | 392.0 | – | None | 3.25 | 4.11 | 0.87 | 0.69 |  |
| HKI L9 | 9 | korkea (0.55) | 407.0 | – | None | 3.26 | 4.06 | 0.80 | 0.63 |  |
| HKI L10 | 10 | korkea (0.55) | 377.0 | – | None | 3.24 | 4.06 | 0.82 | 0.64 |  |

## Structures

`helsinki_structures_heights.geojson`, 64 features: 39 building, 12 canopy_osm, 13 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5,6) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w28908668 | roof | 14.66 | 14.99 | 4.02 | 10.57 | 50 |
| canopy_osm | w28908670 | roof | 13.94 | 18.04 | 3.24 | 9.85 | 148234 |
| building | w29072452 | commercial | 28.83 | 35.16 | -3.20 | 24.74 | 5603 |
| canopy_osm | w29072646 | roof | 8.37 | 9.07 | 4.11 | 4.28 | 580 |
| canopy_osm | w30368518 | roof | 7.83 | 7.92 | 3.39 | 3.74 | 1574 |
| building | w89381373 | building | – | – | – | – | 0 |
| building | w89381377 | building | 26.06 | 26.45 | 4.00 | 21.97 | 356 |
| building | w89381379 | building | – | – | – | – | 0 |
| building | w89381381 | building | 21.18 | 26.19 | 3.27 | 17.09 | 1500 |
| building | w89381386 | building | – | – | – | – | 0 |
| building | w89381391 | building | – | – | 4.07 | – | 0 |
| building | w89381392 | building | – | – | 4.19 | – | 0 |
| building | w89381396 | building | – | – | 4.12 | – | 0 |
| building | w89384389 | building | 23.07 | 32.64 | 4.11 | 18.98 | 4807 |
| building | w122595198 | Helsingin päärautatieasema (station building) | 15.51 | 19.69 | 1.51 | 11.42 | 10795 |
| building | w122595207 | Suomen Kansallisteatteri (public) | 17.78 | 24.20 | 1.71 | 13.69 | 854 |
| building | w122595238 | Sokos (retail) | 23.07 | 32.64 | 4.11 | 18.98 | 4807 |
| building | w262601390 | KPMG (office) | 25.64 | 29.73 | 3.19 | 21.55 | 12895 |
| canopy_osm | w396370569 | roof | 25.54 | 25.67 | 4.24 | 21.45 | 3007 |
| canopy_osm | w396371418 | roof | 25.55 | 25.65 | 4.60 | 21.46 | 2275 |
| canopy_osm | w396371905 | roof | 25.61 | 25.69 | 4.92 | 21.52 | 1700 |
| building | w470004887 | transportation | 6.88 | 6.92 | 4.05 | 2.79 | 461 |
| building | w470004888 | transportation | 6.89 | 6.93 | 4.04 | 2.80 | 359 |
| building | w470004889 | transportation | 6.89 | 6.93 | 4.02 | 2.80 | 448 |
| canopy_osm | w470004898 | roof | 6.89 | 6.93 | 4.08 | 2.80 | 390 |
| building | w612014375 | building | 29.70 | 29.77 | 3.54 | 25.61 | 3323 |
| building | w644615094 | building | 7.00 | 7.06 | 2.13 | 2.91 | 480 |
| building | w655097862 | Entinen VR:n pääkonttori, nykyään hotelli (office) | 17.81 | 24.15 | 1.71 | 13.72 | 6878 |
| building | w1025787754 | building | 23.07 | 32.64 | 4.11 | 18.98 | 4807 |
| building | w1032889414 | service | 6.34 | 6.37 | 3.35 | 2.25 | 223 |
| canopy_osm | w1033871890 | roof | – | – | – | – | 0 |
| canopy_osm | w1049219122 | roof | – | – | – | – | 0 |
| building | w1134655277 | UPM (office) | 25.65 | 25.68 | 2.15 | 21.56 | 2710 |
| building | w1176578924 | roof | – | – | 3.27 | – | 0 |
| building | w1176578925 | roof | – | – | -3.20 | – | 0 |
| building | w1176578926 | building | – | – | -3.20 | – | 0 |
| building | w1176578927 | building | – | – | – | – | 0 |
| building | w1176578928 | building | – | – | – | – | 0 |
| building | w1176578929 | building | – | – | 3.27 | – | 0 |
| building | w1176578942 | roof | – | – | – | – | 0 |
| building | w1176578943 | building | – | – | – | – | 0 |
| building | w1176578944 | building | – | – | 4.11 | – | 0 |
| building | w1176578945 | building | – | – | – | – | 0 |
| building | w1176578946 | building | – | – | – | – | 0 |
| building | w1176578948 | building | 26.19 | 26.20 | -3.07 | 22.10 | 33 |
| canopy_osm | w1280860265 | roof | 7.67 | 8.72 | 4.08 | 3.58 | 434 |
| canopy_osm | w1280860268 | roof | 7.71 | 8.49 | 4.29 | 3.62 | 520 |
| building | w1497383655 | building | 25.65 | 25.68 | 2.15 | 21.56 | 2346 |
| building | w1570456564 | transportation | – | – | -3.26 | – | 0 |
| building | r1319473 | building | – | – | 4.30 | – | 0 |
| building | r1319474 | building | 23.07 | 32.64 | 4.11 | 18.98 | 4807 |
| train_in_scan | (laser) | train standing during the scan (61.3 m × 2.7 m) | 7.48 | – | – | 4.21 | 2267 |
| train_in_scan | (laser) | train standing during the scan (59.7 m × 2.9 m) | 6.97 | – | – | 3.73 | 10639 |
| train_in_scan | (laser) | train standing during the scan (52.4 m × 2.8 m) | 7.75 | – | – | 4.50 | 8981 |
| train_in_scan | (laser) | train standing during the scan (106.0 m × 2.8 m) | 7.76 | – | – | 4.52 | 14341 |
| train_in_scan | (laser) | train standing during the scan (122.5 m × 2.9 m) | 6.99 | – | – | 3.75 | 17136 |
| train_in_scan | (laser) | train standing during the scan (44.3 m × 2.9 m) | 6.96 | – | – | 3.71 | 7824 |
| train_in_scan | (laser) | train standing during the scan (16.8 m × 2.9 m) | 7.27 | – | – | 4.00 | 2215 |
| train_in_scan | (laser) | train standing during the scan (148.5 m × 3.0 m) | 6.98 | – | – | 3.74 | 14389 |
| train_in_scan | (laser) | train standing during the scan (60.1 m × 2.9 m) | 6.99 | – | – | 3.75 | 7666 |
| train_in_scan | (laser) | train standing during the scan (73.1 m × 2.9 m) | 7.00 | – | – | 3.75 | 12303 |
| train_in_scan | (laser) | train standing during the scan (28.0 m × 2.9 m) | 7.09 | – | – | 3.80 | 3415 |
| train_in_scan | (laser) | train standing during the scan (24.7 m × 2.9 m) | 7.06 | – | – | 3.79 | 2958 |
| train_in_scan | (laser) | train standing during the scan (56.5 m × 2.9 m) | 6.94 | – | – | 3.71 | 8593 |

## Trains in the scan

13 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5,6) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS HKI L6 (track 6): laser gives 0.90 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS HKI L8 (track 8): laser gives 0.88 m above the track bed (≈0.70 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS HKI L11 (track 11): laser gives 0.86 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS HKI L12 (track 12): laser gives 0.87 m above the track bed (≈0.70 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS HKI L17 (track 17): laser gives 0.89 m above the track bed (≈0.72 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS HKI L18 (track 18): laser gives 0.96 m above the track bed (≈0.78 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS HKI L19 (track 19): laser gives 0.85 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS HKI L5 (track 5): laser gives 0.87 m above the track bed (≈0.69 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- w28908670 roof: p95 18.0 m is 4.1 m above the median 13.9 m (a taller neighbour or a mast inside the outline?).
- w29072452 commercial: p95 35.2 m is 6.3 m above the median 28.8 m (a taller neighbour or a mast inside the outline?).
- w89381381 building: p95 26.2 m is 5.0 m above the median 21.2 m (a taller neighbour or a mast inside the outline?).
- w122595198 Helsingin päärautatieasema (station building): p95 19.7 m is 4.2 m above the median 15.5 m (a taller neighbour or a mast inside the outline?).
- w262601390 KPMG (office): p95 29.7 m is 4.1 m above the median 25.6 m (a taller neighbour or a mast inside the outline?).
- w655097862 Entinen VR:n pääkonttori, nykyään hotelli (office): p95 24.1 m is 6.3 m above the median 17.8 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (52 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Helsingin laserkeilausaineisto 2021 (kaikki pisteet, 0.5 km tiles clack_fi_hel2021_673496c, clack_fi_hel2021_673496d), City of Helsinki, Kaupunkimittauspalvelut, CC BY 4.0. https://hri.fi/data/en/dataset/helsingin-laserkeilausaineistot (scan 2021; 11,416,380 points in the box, 55.49 per m²; classes {'2': 6503347, '3': 822096, '4': 251338, '5': 1632795, '6': 2107267, '8': 99537}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=24.936483,60.169852,24.945178,60.177454, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
