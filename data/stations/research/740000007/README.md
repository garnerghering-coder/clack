# Norrköping C (`740000007`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 568291–569080, N 6495544–6495911
(789 × 367 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `norrkoping_c_structures_heights.geojson` (58 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `norrkoping_c_ground_1m.tif` (1.0 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 649_56 (2022-10-17)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `norrkoping_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `norrkoping_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `norrkoping_c_laser_station_2020.laz` (5.7 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (3002 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `norrkoping_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Six platform objects (tracks 1–7). Track 1's platform (BIS 1230, mellan) measures ≈0.57 m above rail. The register's four `låg` (0.35 m) objects on tracks 2a/2b/6–7 measure ≈0.39–0.61 m: three of them disagree by more than 0.1 m and are flagged — the register may be out of date here (or the scan, February 2020, is).
- The track bed itself steps by ~0.5 m across the station (2.2–2.8 m), so the platform surfaces spread 2.88–3.53 m; the station level is their median.
- 12 trains stood in the scan (`train_in_scan`).
