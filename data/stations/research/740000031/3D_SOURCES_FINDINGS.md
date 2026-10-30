# Flemingsberg (`740000031`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **34.40** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **33.65** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 28.79 – 69.18 (median 36.79) | terrain model 656_66 (2022-10-10) |

Every height in the structures file becomes metres above the platform by subtracting 34.40.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20c029, scanned 2020-03-31. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1011 | 3 | mellan (0.58) | 510.0 | 13.0 | Tak | – | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1278 | 7 | mellan (0.58) | 395.0 | 14.0 | Tak | 33.52 | 34.23 | 0.71 | 0.54 |  |
| 1277 | 5 | hög (0.73) | 221.0 | 14.0 | Skydd | 33.77 | 34.57 | 0.80 | 0.62 |  |

## Structures

`flemingsberg_structures_heights.geojson`, 8 features: 5 building, 2 canopy_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w102577789 | Flemingsberg (station building) | 48.30 | 52.19 | 32.42 | 13.90 | 3785 |
| building | w331828079 | service | 37.30 | 37.40 | 33.43 | 2.90 | 152 |
| building | w923519265 | building | 45.07 | 45.28 | 34.10 | 10.67 | 23 |
| building | w923519268 | building | 43.93 | 46.09 | 33.35 | 9.53 | 396 |
| building | w923519276 | building | 43.36 | 45.31 | 33.35 | 8.96 | 61 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 38.91 | 39.17 | 31.39 | 4.51 | 3243 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 39.20 | 39.41 | 33.50 | 4.80 | 2120 |
| train_in_scan | (laser) | train standing during the scan (204.1 m × 3.1 m) | 37.41 | – | – | 3.49 | 1063 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w102577789 Flemingsberg (station building): p95 52.2 m is 3.9 m above the median 48.3 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 113 files found (55 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-03-31: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20c029-65675_6675_25.copc.laz
  (scan 2020-03-31, nominal 1.2 points/m², flight height 3000 m; 498,586 points in the box,
  1.74 per m²; classes {'1': 137107, '2': 349316, '7': 366, '9': 430, '17': 11274, '18': 93}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 656_66 (2022-10-10), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://overpass-api.de/api/interpreter, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
