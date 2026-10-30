# Linköping C (`740000009`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Trafikverket);
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m RH 2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **41.62** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on BanInfo's side) |
| **Track bed** | **40.80** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 36.58 – 47.42 (median 40.99) | terrain model 647_53 (2023-04-28) |

Every height in the structures file becomes metres above the platform by subtracting 41.62.

## Platforms (Trafikverket register vs laser)

Register: BanInfo `Plattform` objects (CC0), class heights from JNB 2027 Bilaga 2A tab "2.) Förklaringar"; the batch file
`trafikverket_platforms_SE.csv` has the Bilaga 2A rows. Laser: 21c011, scanned 2021-03-26. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| BIS | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| 1205 | 2 | mellan (0.58) | 376.0 | 10.0 | Skydd | 40.80 | 41.62 | 0.82 | 0.64 |  |
| 1204 | 1 | mellan (0.58) | 371.0 | – | Skydd | 40.76 | 41.50 | 0.74 | 0.57 |  |
| 1594 | 4 | mellan (0.58) | 152.0 | – | Skydd | 40.85 | 41.65 | 0.80 | 0.62 |  |

## Structures

`linkoping_c_structures_heights.geojson`, 14 features: 4 building, 1 footbridge, 4 canopy_osm, 3 canopy_laser, 2 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (BanInfo track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of unclassified laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w39983371 | Linköpings centralstation (station building) | 45.66 | 52.44 | 37.36 | 4.04 | 3947 |
| building | w39983372 | Östgötatrafikens kundcenter (transportation) | 45.76 | 46.83 | 37.26 | 4.14 | 1721 |
| building | w156024124 | Bussgods (transportation) | 48.46 | 50.83 | 41.29 | 6.84 | 369 |
| building | w203690334 | office | 63.97 | 66.96 | 45.31 | 22.35 | 1678 |
| canopy_osm | w291677725 | roof | 45.89 | 46.10 | 36.84 | 4.27 | 1004 |
| canopy_osm | w291677726 | roof | 45.82 | 46.07 | 36.93 | 4.20 | 2132 |
| canopy_osm | w291677727 | roof | 45.80 | 46.04 | 36.92 | 4.18 | 3200 |
| footbridge | w450434287 | Gumpekullabron (bridge) | 49.09 | 55.86 | 36.63 | 7.47 | 38 |
| canopy_osm | w975271977 | roof | 47.80 | 48.04 | 42.35 | 6.18 | 1079 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 45.88 | 46.09 | 37.59 | 4.26 | 568 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 45.43 | 46.18 | 36.92 | 3.81 | 421 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 45.18 | 45.36 | 38.45 | 3.56 | 653 |
| train_in_scan | (laser) | train standing during the scan (70.8 m × 3.1 m) | 44.76 | – | – | 3.84 | 1209 |
| train_in_scan | (laser) | train standing during the scan (34.1 m × 2.8 m) | 44.70 | – | – | 3.83 | 176 |

## Trains in the scan

2 found (`train_in_scan`; their points are class 64 in the LAZ): unclassified points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- w39983371 Linköpings centralstation (station building): p95 52.4 m is 6.8 m above the median 45.7 m (a taller neighbour or a mast inside the outline?).
- w450434287 Gumpekullabron (bridge): p95 55.9 m is 6.8 m above the median 49.1 m (a taller neighbour or a mast inside the outline?).
- Laser-traced roof (315 m², top 3.8 m above the platform, 4.6 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 97 files found (62 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-03-26: anything built since is missing from the laser (compare the BanInfo valid-from dates).

## Sources

- Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0. Lantmäteriet STAC `https://api.lantmateriet.se/stac-hojd/v1`, collection `dsm-skoglig-copc`, tiles y21c011-64750_5350_25.copc.laz
  (scan 2021-03-26, nominal 1.2 points/m², flight height 3000 m; 864,949 points in the box,
  3.36 per m²; classes {'1': 356235, '2': 476107, '7': 449, '9': 21495, '17': 10663}). Terms: CC BY 4.0 + GDPR terms since 1 June 2026.
- Lantmäteriet Markhöjdmodell Nedladdning, collection `dtm-cog`, tiles 647_53 (2023-04-28), read as a 1 m window. CC BY 4.0.
- Trafikverket BanInfo WMS `https://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5`, layers `Plattform` and `Sparnummer`
  (GetFeatureInfo 2026-10-30), CC0. Trafikverket JNB 2027 Bilaga 2A (`bil_2_a_jnb_2027_moteslangder_och_plattformar_260924.xlsx`), CC0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=15.617945,58.413713,15.630841,58.420537, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
