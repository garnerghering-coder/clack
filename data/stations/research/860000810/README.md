# Næstved (`860000810`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the brief STATION_3D_RESEARCH_BRIEF_DK_FI.md (Denmark).
Heights are metres in DVR90; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 675699–676187, N 6123803–6124412
(488 × 609 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `naestved_structures_heights.geojson` (85 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6123_675, PUNKTSKY_1km_6123_676, PUNKTSKY_1km_6124_675, PUNKTSKY_1km_6124_676) |
| `naestved_ground_1m.tif` (447 kB) | Ground, 1 m, float32, EPSG:25832, DVR90, gridded here from the laser's ground points (class 2), median per 1 m cell; no-data where there is no ground point | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6123_675, PUNKTSKY_1km_6123_676, PUNKTSKY_1km_6124_675, PUNKTSKY_1km_6124_676) |
| `naestved_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `naestved_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `naestved_laser_station_2024.laz` (43.0 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (28804 points) | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6123_675, PUNKTSKY_1km_6123_676, PUNKTSKY_1km_6124_675, PUNKTSKY_1km_6124_676) |
| `naestved_platform_banedanmark.geojson` | Bilag 3.6 platforms (perron, track, length, height in cm) on Banedanmark track centrelines, with the laser levels | Bilag 3.6: facts from Banedanmark's network statement; geometry Banedanmark Open Data, CC BY 4.0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Banedanmark |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor's permission for OSM.

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 13.59 m over 1558 m², 13.60 m over 1882 m², 13.61 m over 2070 m², 13.62 m over 2069 m², 13.63 m over 2128 m², 13.64 m over 2107 m², 13.65 m over 2002 m², 13.66 m over 1954 m², 13.67 m over 1963 m², 13.68 m over 1945 m², 13.69 m over 1928 m², 13.70 m over 1928 m², 13.71 m over 2016 m², 13.72 m over 2060 m², 13.73 m over 2287 m², 13.74 m over 2087 m², 13.75 m over 2123 m², 13.76 m over 2073 m², 13.77 m over 2054 m², 13.78 m over 1820 m², 13.79 m over 1700 m², 13.80 m over 1666 m², 13.81 m over 1544 m²
