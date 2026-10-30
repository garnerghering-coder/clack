# Karlstad C (`740000070`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 414470–415025, N 6582945–6583221
(555 × 276 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `karlstad_c_structures_heights.geojson` (54 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `karlstad_c_ground_1m.tif` (457 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 658_41 (2023-01-22)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `karlstad_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `karlstad_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `karlstad_c_laser_station_2019.laz` (2.0 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (1644 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `karlstad_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Karlstad C was rebuilt after the scan (October 2019): the new island platform for tracks 3–4 (BIS 2615, 500 m) shows no raised ground in the laser, so it has no level; the station level comes from platform 1a (BIS 2608), which measures ≈0.72 m above rail (mellan 0.58: flagged).
- Two laser-traced roofs over the tracks sit 5.8–5.9 m above the bed (bridges/gantries or roofs, not trains); OSM has the Trädgårdslänken footbridge and new tunnels, all built after the scan.
