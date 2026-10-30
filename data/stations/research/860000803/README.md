# Køge (`860000803`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the brief STATION_3D_RESEARCH_BRIEF_DK_FI.md (Denmark).
Heights are metres in DVR90; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 701324–701637, N 6150042–6150698
(313 × 656 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `koge_structures_heights.geojson` (31 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6150_701) |
| `koge_ground_1m.tif` (241 kB) | Ground, 1 m, float32, EPSG:25832, DVR90, gridded here from the laser's ground points (class 2), median per 1 m cell; no-data where there is no ground point | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6150_701) |
| `koge_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `koge_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `koge_laser_station_2025.laz` (23.0 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (5280 points) | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6150_701) |
| `koge_platform_banedanmark.geojson` | Bilag 3.6 platforms (perron, track, length, height in cm) on Banedanmark track centrelines, with the laser levels | Bilag 3.6: facts from Banedanmark's network statement; geometry Banedanmark Open Data, CC BY 4.0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Banedanmark |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor's permission for OSM.

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 2.29 m over 1570 m², 2.30 m over 1722 m², 2.31 m over 1908 m², 2.32 m over 1933 m², 2.33 m over 2051 m², 2.34 m over 2217 m², 2.35 m over 2062 m², 2.36 m over 1982 m², 2.37 m over 1927 m², 2.38 m over 1935 m², 2.39 m over 2021 m², 2.40 m over 2004 m², 2.41 m over 1993 m², 2.42 m over 1894 m², 2.43 m over 1960 m², 2.44 m over 1918 m², 2.45 m over 1749 m², 2.46 m over 1778 m², 2.47 m over 1790 m², 2.48 m over 1752 m², 2.49 m over 1773 m², 2.50 m over 1763 m², 2.51 m over 1515 m², 2.61 m over 1542 m², 2.62 m over 1552 m²
