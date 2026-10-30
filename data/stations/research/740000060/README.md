# Falköping C (`740000060`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 414581–415100, N 6448882–6449519
(519 × 637 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `falkoping_c_structures_heights.geojson` (50 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `falkoping_c_ground_1m.tif` (1.0 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 644_41 (2023-04-11)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `falkoping_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `falkoping_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `falkoping_c_laser_station_2022.laz` (9.1 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (947 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `falkoping_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Two long platforms (tracks 1–4) under OSM roofs, both measuring ≈0.67 m above rail against the register's mellan 0.58 m — just inside the 0.1 m tolerance after the 0.15–0.2 m ballast allowance, so not flagged, but both lean high. Scan density is good (3.1 points/m² in the box).
- The short platform on track 21 (BIS 1138, 40 m, no roof) has no laser level.
- Three trains stood in the scan (`train_in_scan`).
