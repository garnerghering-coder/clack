# Nässjö C (`740000140`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **294.52** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **293.63** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 290.16 – 301.69 (median 293.83) | terrain model 638_48 (2023-10-31), 639_48 (2023-10-31) |

Every height in the structures file becomes metres above the platform by subtracting 294.52.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 22c001, scanned 2022-03-20. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 235 | 8s | hög (0.73) | 478.0 | 5.0 | Tak | 293.60 | 294.55 | 0.95 | 0.77 |  |
| 258 | 2s | hög (0.73) | 499.0 | 5.0 | Tak | 293.65 | 294.57 | 0.92 | 0.74 |  |
| 259 | 10n,10s | hög (0.73) | 310.0 | 5.0 | Tak | 293.58 | 294.50 | 0.92 | 0.75 |  |
| 257 | 1n | mellan (0.58) | 125.0 | 5.0 | Tak | 294.05 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1547 | 1s | mellan (0.58) | 148.0 | – | Tak | 293.63 | 294.26 | 0.63 | 0.45 |  |

## Structures

`nassjo_c_structures_heights.geojson`, 13 features: 4 building, 3 canopy_laser, 6 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w138143727 | building | – | – | 293.63 | – | 0 |
| building | w180051276 | building | 300.82 | 301.12 | 293.99 | 6.30 | 42 |
| building | w180051280 | building | 300.33 | 300.88 | 296.44 | 5.81 | 11 |
| building | w185046408 | Nässjö resecentrum (station building) | 301.18 | 307.61 | 294.05 | 6.66 | 2520 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 299.02 | 299.33 | 293.99 | 4.50 | 75 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 299.23 | 299.62 | 293.57 | 4.71 | 1347 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 299.51 | 299.72 | 294.50 | 4.99 | 114 |
| train_in_scan | (laser) | train standing during the scan (97.4 m × 3.4 m) | 297.41 | – | – | 3.80 | 505 |
| train_in_scan | (laser) | train standing during the scan (60.7 m × 3.1 m) | 297.59 | – | – | 3.99 | 282 |
| train_in_scan | (laser) | train standing during the scan (88.7 m × 3.1 m) | 297.60 | – | – | 3.94 | 234 |
| train_in_scan | (laser) | train standing during the scan (54.7 m × 3.0 m) | 297.65 | – | – | 3.58 | 246 |
| train_in_scan | (laser) | train standing during the scan (47.9 m × 3.0 m) | 297.46 | – | – | 3.48 | 254 |
| train_in_scan | (laser) | train standing during the scan (77.9 m × 3.3 m) | 297.59 | – | – | 3.48 | 415 |

## Trains in the scan

6 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 1547 (track 1s): laser gives 0.63 m above the track bed (≈0.45 m above rail after −0.15…0.2 m), register class mellan = 0.58 m. Not decided; add to REVIEW.md.
- w185046408 Nässjö resecentrum (station building): p95 307.6 m is 6.4 m above the median 301.2 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 77 files found (44 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2022-03-20: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y22c001-63875_4800_25.copc.laz, y22c001-63900_4800_25.copc.laz
  (scan 2022-03-20, nominal 1.3 points/m², flight height 3200 m; 527,319 points in the box,
  1.61 per m²; classes {'1': 180613, '2': 330557, '7': 276, '9': 14786, '17': 1087}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 638_48 (2023-10-31), 639_48 (2023-10-31), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=14.687483,57.648071,14.700976,57.655709, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
