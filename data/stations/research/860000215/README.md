# Esbjerg (`860000215`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the brief STATION_3D_RESEARCH_BRIEF_DK_FI.md (Denmark).
Heights are metres in DVR90; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 465641–466056, N 6146845–6147539
(415 × 694 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `esbjerg_structures_heights.geojson` (20 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6146_465, PUNKTSKY_1km_6146_466, PUNKTSKY_1km_6147_465, PUNKTSKY_1km_6147_466) |
| `esbjerg_ground_1m.tif` (389 kB) | Ground, 1 m, float32, EPSG:25832, DVR90, gridded here from the laser's ground points (class 2), median per 1 m cell; no-data where there is no ground point | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6146_465, PUNKTSKY_1km_6146_466, PUNKTSKY_1km_6147_465, PUNKTSKY_1km_6147_466) |
| `esbjerg_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `esbjerg_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `esbjerg_laser_station_2025.laz` (35.6 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (8906 points) | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6146_465, PUNKTSKY_1km_6146_466, PUNKTSKY_1km_6147_465, PUNKTSKY_1km_6147_466) |
| `esbjerg_platform_banedanmark.geojson` | Bilag 3.6 platforms (perron, track, length, height in cm) on Banedanmark track centrelines, with the laser levels | Bilag 3.6: facts from Banedanmark's network statement; geometry Banedanmark Open Data, CC BY 4.0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Banedanmark |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor's permission for OSM.

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 12.29 m over 1775 m², 12.30 m over 2310 m², 12.31 m over 2460 m², 12.32 m over 2489 m², 12.33 m over 2248 m², 12.34 m over 1619 m²
- - Bilag 3.6 gives 26 cm for perron 1 track 0 and perron 2; the laser gives about 0.4–0.6 m above rail. Raised after the 2023 table, or a mismatch: see REVIEW_platform_heights_DK.md.
