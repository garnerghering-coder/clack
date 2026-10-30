# Roskilde (`860000617`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the brief STATION_3D_RESEARCH_BRIEF_DK_FI.md (Denmark).
Heights are metres in DVR90; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 694049–694637, N 6169930–6170428
(588 × 498 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `roskilde_structures_heights.geojson` (66 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6169_694, PUNKTSKY_1km_6170_694) |
| `roskilde_ground_1m.tif` (353 kB) | Ground, 1 m, float32, EPSG:25832, DVR90, gridded here from the laser's ground points (class 2), median per 1 m cell; no-data where there is no ground point | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6169_694, PUNKTSKY_1km_6170_694) |
| `roskilde_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `roskilde_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `roskilde_laser_station_2024.laz` (35.1 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (2960 points) | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6169_694, PUNKTSKY_1km_6170_694) |
| `roskilde_platform_banedanmark.geojson` | Bilag 3.6 platforms (perron, track, length, height in cm) on Banedanmark track centrelines, with the laser levels | Bilag 3.6: facts from Banedanmark's network statement; geometry Banedanmark Open Data, CC BY 4.0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Banedanmark |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor's permission for OSM.

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 43.94 m over 1508 m², 43.95 m over 1536 m², 43.96 m over 1601 m², 43.97 m over 1590 m², 43.98 m over 1710 m², 43.99 m over 1910 m², 44.00 m over 2048 m², 44.01 m over 2275 m², 44.02 m over 2587 m², 44.03 m over 2441 m², 44.04 m over 2425 m², 44.05 m over 2321 m², 44.06 m over 2194 m², 44.07 m over 2069 m², 44.08 m over 1934 m², 44.09 m over 1917 m², 44.10 m over 1965 m², 44.11 m over 2039 m², 44.12 m over 2123 m², 44.13 m over 1882 m², 44.14 m over 1654 m², 44.15 m over 1525 m²
