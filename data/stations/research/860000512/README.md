# Odense (`860000512`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the brief STATION_3D_RESEARCH_BRIEF_DK_FI.md (Denmark).
Heights are metres in DVR90; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 587316–587984, N 6140227–6140525
(668 × 298 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `odense_structures_heights.geojson` (71 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6140_587) |
| `odense_ground_1m.tif` (197 kB) | Ground, 1 m, float32, EPSG:25832, DVR90, gridded here from the laser's ground points (class 2), median per 1 m cell; no-data where there is no ground point | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6140_587) |
| `odense_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `odense_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `odense_laser_station_2025.laz` (29.5 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (43301 points) | Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles PUNKTSKY_1km_6140_587) |
| `odense_platform_banedanmark.geojson` | Bilag 3.6 platforms (perron, track, length, height in cm) on Banedanmark track centrelines, with the laser levels | Bilag 3.6: facts from Banedanmark's network statement; geometry Banedanmark Open Data, CC BY 4.0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Banedanmark |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor's permission for OSM.

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 13.83 m over 1567 m², 13.84 m over 1763 m², 13.85 m over 1949 m², 13.86 m over 2201 m², 13.87 m over 2202 m², 13.88 m over 2021 m², 13.89 m over 1871 m², 13.90 m over 1697 m², 13.91 m over 1558 m², 13.92 m over 1661 m², 13.93 m over 1710 m², 13.94 m over 1583 m², 14.08 m over 1765 m², 14.09 m over 1724 m², 14.10 m over 1730 m², 14.11 m over 1693 m², 14.12 m over 1579 m², 14.13 m over 1508 m², 14.18 m over 1562 m², 14.19 m over 1648 m²
