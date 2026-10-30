# Örebro S (`740000361`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 511297–511676, N 6569821–6570278
(379 × 457 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `orebro_s_structures_heights.geojson` (3 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `orebro_s_ground_1m.tif` (547 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 657_51 (2024-10-02), 656_51 (2024-10-02)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `orebro_s_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `orebro_s_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `orebro_s_laser_station_2023.laz` (4.3 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (0 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `orebro_s_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 26.45 m over 1580 m²
- **Örebro S was rebuilt after the laser scan (July 2023).** Trafikverket's Bilaga 2A tab 5 says the middle platform (tracks 2/30) was to be removed and a new 240 m mellan side platform built at track 30 (planned 2026-05-30); BanInfo has it (BIS 2618, valid from 2026-06-26). The 2023 laser shows no platform on that line, so the new platform has no level.
- BIS 1219 (track 1, låg, 188 m, BanInfo only) measures a raised surface ≈0.50 m above rail at 29.03 m: in 2023 that is most likely the old middle platform beside track 1, not the platform in BanInfo today. Left out of the station level, which therefore stays empty.
- The app withheld Örebro S because OSM joins no footway to the platforms; that may be because the platforms changed in 2026.
