# Kil (`740000206`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 404376–405021, N 6597321–6597633
(645 × 312 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `kil_structures_heights.geojson` (62 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `kil_ground_1m.tif` (577 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 659_40 (2022-08-02)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `kil_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `kil_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `kil_laser_station_2019.laz` (4.6 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (7047 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `kil_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Junction station with a yard: 11 trains stood in the scan (October 2019), all `train_in_scan` (class 64 in the LAZ). The station needed four laser tiles (it sits on a tile corner); the bundle was split into files to move it.
- Track 2's platform (BIS 454, mellan) measures ≈0.53 m above rail; the low platforms by tracks 6–7 and 1 (BIS 457, 455) ≈0.32–0.34 (låg 0.35). Track 4–5's platform (BIS 456) has no laser level.
