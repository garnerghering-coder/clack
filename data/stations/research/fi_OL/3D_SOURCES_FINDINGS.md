# Oulu (`fi:OL`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **12.65** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **12.11** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 3.56 – 18.22 (median 11.82) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 12.65.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_R4414A2, scanned 2023-06-14. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| OL L1 | 1 | korkea (0.55) | 368.0 | – | None | 12.10 | 12.83 | 0.73 | 0.56 |  |
| OL L2 | 2 | matala (0.27) | 412.0 | – | None | 12.11 | 12.65 | 0.54 | 0.37 |  |
| OL L3 | 3 | matala (0.27) | 494.0 | – | None | 12.15 | 12.65 | 0.50 | 0.33 |  |

## Structures

`oulu_structures_heights.geojson`, 26 features: 18 building, 5 canopy_osm, 2 canopy_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w38295259 | Oulun rautatieasema (station building) | – | – | 12.68 | – | 0 |
| building | w45418237 | Taito (building) | – | – | 11.60 | – | 2 |
| building | w87499625 | Oulun linja-autoasema (building) | – | – | 11.92 | – | 2 |
| building | w87687268 | canopy | – | – | 12.50 | – | 2 |
| canopy_osm | w135976271 | roof | – | – | 9.24 | – | 1 |
| canopy_osm | w427854919 | roof | – | – | 9.28 | – | 0 |
| canopy_osm | w814111629 | roof | – | – | 11.87 | – | 3 |
| building | w831245387 | apartments | – | – | 12.51 | – | 1 |
| building | w831245389 | building | – | – | 12.10 | – | 0 |
| building | w831245390 | building | – | – | 12.06 | – | 0 |
| building | w844277144 | building | – | – | 12.15 | – | 0 |
| building | w877996837 | Scandic Oulu Station (hotel) | – | – | 10.88 | – | 0 |
| building | w878645018 | apartments | – | – | 8.93 | – | 1 |
| building | w878645019 | apartments | – | – | 8.53 | – | 1 |
| canopy_osm | w898545089 | roof | – | – | 11.94 | – | 1 |
| canopy_osm | w1343382901 | roof | – | – | 12.21 | – | 0 |
| building | w1343382907 | building | – | – | 11.95 | – | 0 |
| building | w1343382908 | building | – | – | 12.08 | – | 1 |
| building | w1343382909 | building | – | – | 12.32 | – | 0 |
| building | w1460220552 | apartments | 19.62 | 47.61 | 11.27 | 6.97 | 21 |
| building | w1490205622 | apartments | – | – | 10.50 | – | 2 |
| building | w1490205623 | apartments | – | – | 12.08 | – | 1 |
| building | w1490205624 | apartments | – | – | 12.06 | – | 0 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 16.20 | 16.26 | 12.08 | 3.54 | 28 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 17.44 | 17.52 | 12.02 | 4.79 | 378 |
| train_in_scan | (laser) | train standing during the scan (25.4 m × 2.8 m) | 15.33 | – | – | 3.17 | 47 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- Laser-traced roof (40 m², top 3.5 m above the platform, 4.1 m above the track bed) lies partly over a track: it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.
- Laser-traced roof (620 m², top 4.8 m above the platform, 5.3 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 100 files found (50 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2023-06-14: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_R4414A2), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned R4414A2 2023-06-14 (20230206_Swissphoto_Oulu_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2023-06-14; 191,783 points in the box, 0.57 per m²; classes {'1': 487, '2': 117656, '3': 461, '4': 6117, '5': 67062}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=25.476132,65.006385,25.489219,65.013818, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
