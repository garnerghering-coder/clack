# Vaasa (`fi:VS`): 3D sources and findings

Pass of 2026-10-30. Recipe: `STATION_3D_RESEARCH.md`. Every value below is measured (laser, terrain model) or recorded (Väylävirasto (Finnish Transport Infrastructure Agency));
nothing is estimated. Where a source gives nothing, the cell says –.

## Key levels (for the app)

| | m N2000 | How |
|---|---|---|
| **Platform surface** (reference level 0) | **4.99** | median of the per-platform laser medians below (ground-class points 2.0 m to 2.0 m + width beside the track line, on the raised side) |
| **Track bed** | **4.29** | median of ground-class points within 0.8 m of the track lines (ballast/sleepers, not rail head) |
| Ground in the box | 3.57 – 13.31 (median 7.35) | ground grid from the laser class 2 (see the GeoTIFF tags) |

Every height in the structures file becomes metres above the platform by subtracting 4.99.

## Platforms (Väylävirasto (Finnish Transport Infrastructure Agency) register vs laser)

Register: Digitraffic infra-api `laiturit` (read 2026-10-30, CC BY 4.0): platform number (`kaupallinenNumero`), height class `korkea`/`matala`, length; no width or roof. Class heights: korkea 0.55 m, matala 0.265 m above rail (Väylävirasto Network Statement 2021 appendix 3B via Wikipedia "Platform height", read 2026-10-30). Laser: clack_fi_mml05_P3411E4, scanned 2021-06-07. "Above rail" = surface − bed − 0.175 m
(the playbook's 0.15–0.2 m from ballast to rail head): a cross-check, not a measurement of the platform edge.

| Platform | Track | Class (m) | Length | Width | Roof | Track bed | Platform surface | Surface − bed | ≈ above rail | Note |
|---|---|---|---|---|---|---|---|---|---|---|
| VS L1 | 1 | korkea (0.55) | 258.0 | – | None | 4.29 | 4.99 | 0.70 | 0.53 |  |

## Structures

`vaasa_structures_heights.geojson`, 10 features: 5 building, 2 canopy_osm, 1 canopy_laser, 1 train_in_scan.
Selection: OSM buildings, roofs (`building=roof`), canopies, shelters and bridges that touch the platforms (Digitraffic track line
buffered by platform width + 12 m) or are tagged as the station; plus roofs traced from the laser over the platforms outside
those outlines; plus trains. Roof = median of non-ground (classes 1,3,4,5) laser points > 2 m above the terrain model inside the outline.
Ground = terrain model on a 0.3–1.5 m ring outside the outline. Airborne laser sees tops only: undersides, decks and floors are unknown.

| Kind | OSM | Name | Top median | Top p95 (p90 traced) | Ground min | Top above platform (trains: above bed) | Points |
|---|---|---|---|---|---|---|---|
| building | w24559319 | Vaasan Matkakeskus - Rautatieasema (station building) | – | – | 4.00 | – | 2 |
| building | w25613454 | building | 7.39 | 10.18 | 4.46 | 2.40 | 8 |
| canopy_osm | w40271506 | roof | 8.53 | 10.54 | 4.64 | 3.54 | 72 |
| building | w41679917 | Vaasan Matkakeskus - Matkahuolto (transportation) | – | – | 4.56 | – | 1 |
| building | w321416648 | building | – | – | 4.74 | – | 0 |
| building | w321416649 | building | – | – | 4.64 | – | 1 |
| canopy_osm | w557114260 | roof | – | – | – | – | 0 |
| bridge | w655237791 | bridge | 11.74 | 14.21 | 3.98 | 6.75 | 17 |
| canopy_laser | (laser) | roof over the platforms (traced from the laser) | 9.60 | 9.66 | 4.18 | 4.61 | 179 |
| train_in_scan | (laser) | train standing during the scan (15.1 m × 2.8 m) | 8.06 | – | – | 3.77 | 28 |

## Trains in the scan

1 found (`train_in_scan`; their points are class 64 in the LAZ): non-ground (classes 1,3,4,5) points 2.6–5.0 m above the terrain model
within 2.2 m of a track centreline (OSM `railway=rail`), along one track, centred on it (median offset ≤ 1.0 m), ≥ 15 m long,
3.0–4.8 m above the track bed. A canopy over a track at that height would also pass: the flags list anything doubtful.

## Flags (not decided)

- OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): w655237791 (cycleway, footway, primary).
- Laser-traced roof (278 m², top 4.6 m above the platform, 5.3 m above the track bed) lies partly over a track: a bridge, gantry or roof over the track; check in a cross-section.

## Not obtained

- Undersides of roofs and canopies, footbridge decks, floors inside buildings: airborne laser sees tops only.
- Mapillary: not searched in this pass. Commons: 23 files found (5 station-related by title/description), listed
  in `photos.json`; labels in this pass come from OSM tags and the laser, the photos were not each viewed.
- Laser scan date 2021-06-07: anything built since is missing from the laser (compare the Digitraffic valid-from dates).

## Sources

- Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_P3411E4), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned P3411E4 2021-06-07 (20210108_Swissphoto_Vaasa_kesa). https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p (scan 2021-06-07; 93,817 points in the box, 0.6 per m²; classes {'1': 15, '2': 58195, '3': 184, '4': 3138, '5': 32285}).
- Ground grid: made here from the same laser (class 2), see `README.md`.
- Digitraffic infra-api (Väylävirasto / Fintraffic) `https://rata.digitraffic.fi/infra-api/latest/laiturit.json` and `rautatieliikennepaikat.json`, read 2026-10-30, CC BY 4.0.
- OpenStreetMap (https://api.openstreetmap.org/api/0.6/map?bbox=21.618540,63.094625,21.628376,63.099774, 2026-10-30), © OpenStreetMap contributors, ODbL.
- Wikimedia Commons API (geosearch 400 m + name search), licences per file in `photos.json`.
