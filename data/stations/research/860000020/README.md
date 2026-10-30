# Aalborg (`860000020`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the brief STATION_3D_RESEARCH_BRIEF_DK_FI.md (Denmark).
Heights are metres in DVR90; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 555441–555823, N 6322199–6322788
(382 × 589 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `aalborg_structures_heights.geojson` (60 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6322_555) |
| `aalborg_ground_1m.tif` (269 kB) | Ground, 1 m, float32, EPSG:25832, DVR90, gridded here from the laser's ground points (class 2), median per 1 m cell; no-data where there is no ground point | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6322_555) |
| `aalborg_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `aalborg_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `aalborg_laser_station_2022.laz` (40.4 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (17871 points) | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6322_555) |
| `aalborg_platform_banedanmark.geojson` | Bilag 3.6 platforms (perron, track, length, height in cm) on Banedanmark track centrelines, with the laser levels | Bilag 3.6: facts from Banedanmark's network statement; geometry Banedanmark Open Data, CC BY 4.0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Banedanmark |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor's permission for OSM.

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 4.00 m over 1534 m², 4.01 m over 1674 m², 4.02 m over 1924 m², 4.03 m over 2235 m², 4.04 m over 2502 m², 4.05 m over 2563 m², 4.06 m over 2546 m², 4.07 m over 2590 m², 4.08 m over 2594 m², 4.09 m over 2755 m², 4.10 m over 2676 m², 4.11 m over 2558 m², 4.12 m over 2386 m², 4.13 m over 2300 m², 4.14 m over 2255 m², 4.15 m over 2104 m², 4.16 m over 1936 m², 4.17 m over 1867 m², 4.18 m over 1690 m², 4.19 m over 1591 m², 4.20 m over 1575 m²
