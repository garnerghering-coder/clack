# Hallsberg (`740000077`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 505858–506444, N 6547292–6547640
(586 × 348 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `hallsberg_structures_heights.geojson` (27 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `hallsberg_ground_1m.tif` (640 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 654_50 (2024-05-14)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `hallsberg_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `hallsberg_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `hallsberg_laser_station_2023.laz` (2.6 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (1558 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `hallsberg_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Two long platforms. The island platform at track 5a (BIS 1386, 593 m) measures ≈0.68 m above rail (mellan 0.58, within tolerance) and gives the station level.
- For the other platform (BIS 1400, Bilaga row 281, tracks 1/151–152/2, 523 m) BanInfo returned only a 1 m fragment of its track line, so it has no laser level; re-query BanInfo for its full geometry.
- OSM has no roof outlines at the platforms and none were traced from the laser; five trains stood in the scan.
