# Hyllie (`740001586`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 372113–372652, N 6159069–6159528
(539 × 459 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `hyllie_structures_heights.geojson` (19 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `hyllie_ground_1m.tif` (807 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 615_37 (2025-09-18)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `hyllie_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `hyllie_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `hyllie_laser_station_2025.laz` (2.9 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (340 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `hyllie_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Hyllie's two island-platform faces (tracks 71–74) lie in a cutting about 7 m below the surrounding ground; the laser reaches them through the open sides and gives both platforms a level (≈0.51–0.57 m above rail, mellan). Ground-class points ~7 m above the bed over parts of the tracks are the street-level decks over the cutting.
- BanInfo's track-75 platform (BIS 2597, 0.9 km south-west) lies outside the station box and is not in this pack.
- No Jernhusen page (Hyllie is not a Jernhusen station); facts come from OSM and the laser only.
