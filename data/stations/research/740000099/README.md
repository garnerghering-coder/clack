# Västerås C (`740000099`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 587273–587908, N 6608406–6608984
(635 × 578 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `vasteras_c_structures_heights.geojson` (22 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `vasteras_c_ground_1m.tif` (1.2 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 660_58 (2023-04-07)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `vasteras_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `vasteras_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `vasteras_c_laser_station_2021.laz` (6.4 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (703 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `vasteras_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 0.76 m over 2555 m², 0.81 m over 24678 m²
- Three hög platforms (tracks 1–5). Track 5's (BIS 1311) measures ≈0.64 m above rail and track 1b's (BIS 1306) ≈0.51 (flagged against hög 0.73); track 2's (BIS 1309) has no laser level. Jernhusen lists a "Gångbron" (footbridge) with its own opening hours.
- A small high roof over a track (53 m², 10.4 m above the bed) is probably the footbridge; it is a laser trace (`hall_roof_laser`) and needs a look before use.
- The flat 0.76/0.81 m patches are water (Mälaren / Svartån).
