# Trollhättan (`740000191`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **44.60** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **43.80** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 38.23 – 47.48 (median 43.93) | terrain model 646_34 (2023-02-08) |

Every height in the structures file becomes metres above the platform by subtracting 44.60.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 20b016, scanned 2020-03-21. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1336 | 2 | hög (0.73) | 299.0 | – | Tak | 43.79 | 44.65 | 0.86 | 0.68 |  |
| 1333 | 1 | hög (0.73) | 299.0 | – | Skydd | 43.82 | 44.55 | 0.73 | 0.56 |  |

## Structures

`trollhattan_structures_heights.geojson`, 9 features: 3 building, 5 canopy_osm, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w76617203 | building | 49.85 | 50.03 | 43.79 | 5.25 | 415 |
| building | w88526977 | Trollhättan C (station building) | 51.03 | 54.22 | 43.86 | 6.43 | 704 |
| building | w310276083 | building | 48.90 | 53.11 | 43.97 | 4.30 | 167 |
| canopy_osm | w1201014738 | roof | 49.08 | 49.34 | 43.42 | 4.48 | 850 |
| canopy_osm | w1256391261 | building | 46.64 | 46.70 | 44.00 | 2.04 | 7 |
| canopy_osm | w1263691796 | building | 46.67 | 46.75 | 44.30 | 2.07 | 10 |
| canopy_osm | w1263691797 | building | 46.53 | 46.59 | 44.08 | 1.93 | 9 |
| canopy_osm | w1263691798 | building | 46.58 | 46.64 | 44.15 | 1.98 | 8 |
| train_in_scan | (laser) | train standing during the scan (55.7 m × 3.6 m) | 47.87 | – | – | 4.10 | 147 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 1333 (track 1): laser gives 0.73 m above the track bed (≈0.56 m above rail after −0.15…0.2 m), register class hög = 0.73 m. Not decided; add to REVIEW.md.
- w88526977 Trollhättan C (station building): p95 54.2 m is 3.2 m above the median 51.0 m (a taller neighbour or a mast inside the outline?).

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 59 files found (40 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2020-03-21: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y20b016-64625_3400_25.copc.laz
  (scan 2020-03-21, nominal 1.2 points/m², flight height 3200 m; 367,561 points in the box,
  1.79 per m²; classes {'1': 142896, '2': 223688, '17': 972, '18': 5}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 646_34 (2023-02-08), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=12.293314,58.284150,12.305115,58.290586, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
