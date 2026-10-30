# Örebro S (`740000361`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **–** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **28.38** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 24.64 – 34.00 (median 28.33) | terrain model 657_51 (2024-10-02), 656_51 (2024-10-02) |

Every height in the structures file becomes metres above the platform by subtracting –.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 23c023, scanned 2023-07-11. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 2618 | 30 | mellan (0.58) | 240.0 | 5.0 | Skydd | 28.38 | – | – | – | no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points) |
| 1219 | 1 | låg (0.35) | 188.0 | – | Saknas | 28.35 | 29.03 | 0.68 | 0.50 | not in Bilaga 2A (report 2026-02-04) and the BanInfo record is from 2026-01-27: probably built or rebuilt after the scan, so the laser value is not this platform; left out of the station level |

## Structures

`orebro_s_structures_heights.geojson`, 2 features: 2 building.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w92083242 | station building | 34.49 | 35.87 | 28.48 | – | 794 |
| building | w92083245 | building | 34.76 | 36.33 | 28.28 | – | 1422 |

## Trains in the scan

0 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Platform BIS 1219 (track 1): register låg, laser 0.68 m above the bed; record valid from 2026-01-27, not in Bilaga 2A; the scan is from 2023-07-11: probably built after the scan.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 59 files found (13 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-07-11: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y23c023-65675_5100_25.copc.laz, y23c023-65700_5100_25.copc.laz
  (scan 2023-07-11, nominal 1.1 points/m², flight height 3200 m; 484,681 points in the box,
  2.8 per m²; classes {'1': 229779, '2': 253110, '7': 241, '9': 187, '17': 1333, '18': 31}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 657_51 (2024-10-02), 656_51 (2024-10-02), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=15.196084,59.266066,15.206920,59.272400, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
