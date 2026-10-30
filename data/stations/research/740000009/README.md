# Linköping C (`740000009`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 536224–536730, N 6475067–6475575
(506 × 508 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `linkoping_c_structures_heights.geojson` (39 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `linkoping_c_ground_1m.tif` (790 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 647_53 (2023-04-28)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `linkoping_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `linkoping_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `linkoping_c_laser_station_2021.laz` (7.1 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (1385 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `linkoping_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 36.63 m over 1645 m²
- Three platforms (tracks 1–5), all with laser levels: ≈0.57–0.64 m above rail against mellan 0.58. Dense scan (3.4 points/m² in the box).
- One laser-traced roof (315 m², 4.6 m above the track bed) lies partly over a track: possibly a double-deck train; check in a cross-section before using it.
- A small flat patch at 36.63 m in the terrain model is water (1645 m²).
