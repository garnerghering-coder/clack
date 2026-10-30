# Norrköping C (`740000007`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **3.24** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **2.58** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 0.67 – 13.20 (median 2.79) | terrain model 649_56 (2022-10-17) |

Every height in the structures file becomes metres above the platform by subtracting 3.24.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20c012, scanned 2020-02-03. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1849 | ? | låg (0.35) | 300.0 | 6.0 | Tak | 2.54 | 3.27 | 0.73 | 0.55 |  |
| 1841 | 2b | låg (0.35) | 195.0 | 6.0 | Skydd | 2.22 | 2.88 | 0.66 | 0.48 |  |
| 1850 | ? | mellan (0.58) | 176.0 | 6.0 | Tak | 2.62 | 3.33 | 0.71 | 0.53 |  |
| 1843 | 2a | låg (0.35) | 140.0 | 6.0 | Saknas | 2.40 | 3.18 | 0.78 | 0.61 |  |
| 1230 | 1 | mellan (0.58) | 345.0 | – | Tak | 2.78 | 3.53 | 0.75 | 0.57 |  |
| 1846 | 2a | låg (0.35) | 90.0 | – | Saknas | 2.64 | 3.20 | 0.56 | 0.39 |  |

## Structures

`norrkoping_c_structures_heights.geojson`, 29 features: 13 building, 3 canopy_osm, 1 canopy_laser, 12 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w88701127 | Resecentrum Norrköping (transportation) | 6.47 | 7.14 | 2.60 | 3.23 | 612 |
| building | w102030313 | Norrköpings centralstation (station building) | 10.82 | 13.22 | 2.22 | 7.58 | 1692 |
| canopy_osm | w244139352 | roof | 6.81 | 7.14 | 2.30 | 3.57 | 1504 |
| canopy_osm | w244139353 | roof | 7.75 | 8.00 | 2.49 | 4.51 | 420 |
| canopy_osm | w244139355 | roof | 7.81 | 8.18 | 2.27 | 4.57 | 503 |
| building | w285587669 | building | 11.52 | 12.37 | 2.22 | 8.28 | 142 |
| building | w285587674 | building | 6.52 | 8.89 | 2.26 | 3.28 | 37 |
| building | w285587679 | building | 11.60 | 12.43 | 2.24 | 8.36 | 185 |
| building | w285587681 | building | 9.70 | 10.29 | 2.38 | 6.46 | 16 |
| building | w285587683 | building | 7.10 | 7.57 | 2.22 | 3.86 | 191 |
| building | w285587686 | building | 10.19 | 12.08 | 2.37 | 6.95 | 525 |
| building | w285587688 | building | 9.64 | 9.98 | 2.23 | 6.40 | 46 |
| building | w285587691 | building | 11.80 | 12.48 | 2.23 | 8.56 | 27 |
| building | w285587694 | building | 12.01 | 13.48 | 2.23 | 8.77 | 46 |
| building | w285587697 | building | 7.45 | 9.74 | 2.25 | 4.21 | 129 |
| building | w285587700 | building | 12.55 | 14.03 | 2.22 | 9.31 | 328 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 7.12 | 7.22 | 2.30 | 3.88 | 146 |
| train_in_scan | (laser) | train standing during the scan (31.4 m × 2.4 m) | 7.87 | – | – | 3.64 | 73 |
| train_in_scan | (laser) | train standing during the scan (16.5 m × 2.5 m) | 6.13 | – | – | 3.68 | 67 |
| train_in_scan | (laser) | train standing during the scan (71.2 m × 3.0 m) | 6.26 | – | – | 3.65 | 432 |
| train_in_scan | (laser) | train standing during the scan (70.7 m × 3.1 m) | 6.07 | – | – | 3.68 | 434 |
| train_in_scan | (laser) | train standing during the scan (71.0 m × 3.0 m) | 5.88 | – | – | 3.67 | 546 |
| train_in_scan | (laser) | train standing during the scan (17.7 m × 0.9 m) | 6.62 | – | – | 4.16 | 31 |
| train_in_scan | (laser) | train standing during the scan (16.2 m × 1.5 m) | 7.71 | – | – | 3.68 | 31 |
| train_in_scan | (laser) | train standing during the scan (167.9 m × 2.5 m) | 6.16 | – | – | 3.63 | 815 |
| train_in_scan | (laser) | train standing during the scan (18.7 m × 2.2 m) | 7.90 | – | – | 3.93 | 75 |
| train_in_scan | (laser) | train standing during the scan (51.1 m × 3.3 m) | 6.26 | – | – | 3.61 | 350 |
| train_in_scan | (laser) | train standing during the scan (27.2 m × 2.3 m) | 7.89 | – | – | 3.66 | 120 |
| train_in_scan | (laser) | train standing during the scan (18.0 m × 0.9 m) | 6.77 | – | – | 4.21 | 28 |

## Trains in the scan

12 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 1849 (track None): laser gives 0.73 m above the track bed (≈0.55 m above rail after −0.15…0.2 m), register class låg = 0.35 m. Not decided; add to REVIEW.md.
- Platform BIS 1841 (track 2b): laser gives 0.66 m above the track bed (≈0.48 m above rail after −0.15…0.2 m), register class låg = 0.35 m. Not decided; add to REVIEW.md.
- Platform BIS 1843 (track 2a): laser gives 0.78 m above the track bed (≈0.61 m above rail after −0.15…0.2 m), register class låg = 0.35 m. Not decided; add to REVIEW.md.
- Platform surfaces differ by 0.65 m across the station (2.88–3.53 m); the station reference above is their median — check which level the app should use.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 115 files found (56 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-02-03: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20c012-64950_5675_25.copc.laz
  (scan 2020-02-03, nominal 1.2 points/m², flight height 3000 m; 680,234 points in the box,
  2.35 per m²; classes {'1': 216581, '2': 462247, '7': 72, '17': 1334}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 649_56 (2022-10-17), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=16.172840,58.593763,16.190702,58.599213, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
