# Kouvola (`fi:KV`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **72.36** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **71.52** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 60.70 – 79.31 (median 71.56) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 72.36.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_L4443D2, scanned 2025-08-02. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| KV L1 | 1 | korkea (0.55) | 350.0 | – | None | 71.51 | 72.19 | 0.68 | 0.51 |  |
| KV L3 | 3 | korkea (0.55) | 430.0 | – | None | 71.52 | 72.36 | 0.84 | 0.67 |  |
| KV L4 | 4 | korkea (0.55) | 430.0 | – | None | 71.55 | 72.35 | 0.80 | 0.63 |  |
| KV L6 | 6 | korkea (0.55) | 480.0 | – | None | 71.50 | 72.36 | 0.86 | 0.68 |  |
| KV L7 | 7 | korkea (0.55) | 480.0 | – | None | 71.52 | 72.37 | 0.85 | 0.68 |  |
| KV L9 | 9 | korkea (0.55) | 230.0 | – | None | 71.55 | 72.37 | 0.82 | 0.65 |  |
| KV L10 | 10 | korkea (0.55) | 230.0 | – | None | 71.56 | 72.37 | 0.81 | 0.64 |  |

## Structures

`kouvola_structures_heights.geojson`, 37 features: 5 building, 19 canopy_osm, 13 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| canopy_osm | w31793542 | roof | – | – | 72.97 | – | 0 |
| canopy_osm | w32469956 | roof | – | – | 74.50 | – | 4 |
| canopy_osm | w32469958 | roof | – | – | 74.71 | – | 0 |
| building | w42198846 | Kouvolan matkakeskus (station building) | – | – | 71.44 | – | 1 |
| canopy_osm | w135756548 | roof | – | – | 75.12 | – | 3 |
| canopy_osm | w150348628 | roof | 76.60 | 76.70 | 71.49 | 4.24 | 5 |
| canopy_osm | w150348690 | roof | – | – | 71.45 | – | 3 |
| canopy_osm | w150348714 | roof | – | – | 71.95 | – | 2 |
| canopy_osm | w193325177 | shelter | – | – | 72.21 | – | 1 |
| building | w402757120 | building | – | – | 72.35 | – | 0 |
| building | w402757122 | building | – | – | 72.33 | – | 0 |
| canopy_osm | w402757163 | shelter | – | – | 72.08 | – | 0 |
| canopy_osm | w402757165 | shelter | – | – | 72.33 | – | 0 |
| canopy_osm | w402757168 | shelter | – | – | 72.35 | – | 2 |
| canopy_osm | w402757171 | shelter | – | – | 72.35 | – | 0 |
| canopy_osm | w402757174 | shelter | – | – | 72.37 | – | 0 |
| canopy_osm | w402757177 | shelter | – | – | 72.34 | – | 0 |
| canopy_osm | w402757181 | shelter | – | – | 72.35 | – | 0 |
| canopy_osm | w402757184 | shelter | – | – | 72.07 | – | 0 |
| building | w406450872 | building | – | – | 71.62 | – | 0 |
| building | w406450873 | building | – | – | 71.85 | – | 0 |
| canopy_osm | w1206247067 | roof | – | – | 72.09 | – | 3 |
| canopy_osm | w1328839326 | roof | – | – | 74.64 | – | 0 |
| canopy_osm | w1328839327 | roof | – | – | 74.63 | – | 0 |
| train_in_scan | (laser) | train standing during the scan (55.4 m × 2.9 m) | 75.10 | – | – | 3.58 | 87 |
| train_in_scan | (laser) | train standing during the scan (89.6 m × 2.9 m) | 75.07 | – | – | 3.57 | 136 |
| train_in_scan | (laser) | train standing during the scan (15.7 m × 2.7 m) | 75.07 | – | – | 3.55 | 30 |
| train_in_scan | (laser) | train standing during the scan (36.6 m × 2.3 m) | 75.53 | – | – | 4.02 | 58 |
| train_in_scan | (laser) | train standing during the scan (73.3 m × 2.9 m) | 75.52 | – | – | 4.00 | 131 |
| train_in_scan | (laser) | train standing during the scan (17.1 m × 2.7 m) | 74.96 | – | – | 3.44 | 30 |
| train_in_scan | (laser) | train standing during the scan (17.1 m × 2.9 m) | 74.94 | – | – | 3.42 | 31 |
| train_in_scan | (laser) | train standing during the scan (35.9 m × 2.8 m) | 75.09 | – | – | 3.57 | 62 |
| train_in_scan | (laser) | train standing during the scan (157.8 m × 2.9 m) | 75.48 | – | – | 3.96 | 259 |
| train_in_scan | (laser) | train standing during the scan (18.3 m × 2.6 m) | 75.39 | – | – | 3.88 | 28 |
| train_in_scan | (laser) | train standing during the scan (157.9 m × 2.8 m) | 75.52 | – | – | 4.00 | 262 |
| train_in_scan | (laser) | train standing during the scan (38.1 m × 2.7 m) | 75.19 | – | – | 3.68 | 62 |
| train_in_scan | (laser) | train standing during the scan (16.8 m × 2.5 m) | 75.00 | – | – | 3.59 | 29 |

## Trains in the scan

13 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS KV L6 (track 6): laser gives 0.86 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.
- Platform BIS KV L7 (track 7): laser gives 0.85 m above the track bed (≈0.68 m above rail after −0.15…0.2 m), register class korkea = 0.55 m. Not decided; add to REVIEW.md.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 50 files found (26 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2025-08-02: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_L4443D2), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned L4443D2 2025-08-02 (20250001_MML_Kouvola_kesa_LAATUPOIKKEAMIA). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2025-08-02; 124,903 points in the box, 0.57 per m²; classes {'1': 100, '2': 89594, '3': 329, '4': 2959, '5': 31921}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=26.695845,60.863511,26.711180,60.867656, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
