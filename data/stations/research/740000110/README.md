# Varberg C (`740000110`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 333290–333631, N 6333000–6333616
(341 × 616 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `varberg_c_structures_heights.geojson` (17 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `varberg_c_ground_1m.tif` (736 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 633_33 (2022-09-30)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `varberg_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `varberg_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `varberg_c_laser_station_2020.laz` (4.7 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (0 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `varberg_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- **Varberg's platforms are in the new railway tunnel** (Varbergstunneln), which opened after the laser scan (January 2020): along the BanInfo track lines (BIS 2610–2613, records valid 2025–2026) the laser shows only the flat ground of the old site, so the platforms and track bed have no laser level and the station has no reference level from this pass. The terrain model and the structures describe the surface as it was in 2020.
- Linda Hanssons Bro is mapped as a bridge with a service road (kind `bridge`).
