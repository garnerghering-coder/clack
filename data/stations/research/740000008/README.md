# Skövde C (`740000008`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 432703–433116, N 6472376–6472974
(413 × 598 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `skovde_c_structures_heights.geojson` (73 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `skovde_c_ground_1m.tif` (747 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 647_43 (2024-04-05)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `skovde_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `skovde_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `skovde_c_laser_station_2022.laz` (3.7 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (582 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `skovde_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Two platforms. Track 1's side platform (BIS 392) measures ≈0.55 m above rail (mellan). The island platform BIS 391 (Bilaga row 780: tracks 2/3a/3b/151–152; BanInfo references it to track 151–152) measures ≈0.76 m from only 350 laser points: flagged, check before trusting.
- OSM has three bridge outlines at the platforms (one with a path and a road, two with no mapped ways): kind `bridge`.
