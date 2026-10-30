# Uppsala C (`740000005`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 648052–648690, N 6638175–6638794
(638 × 619 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `uppsala_c_structures_heights.geojson` (117 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `uppsala_c_ground_1m.tif` (1.4 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 663_64 (2023-04-26)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `uppsala_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `uppsala_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `uppsala_c_laser_station_2021.laz` (5.9 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (1835 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `uppsala_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Seven platform objects (tracks 1–8). Six have laser levels; the spread (7.24–7.83 m) follows the track bed, which rises by ~1 m from the west tracks to tracks 3–4. Three disagree with the register by more than 0.1 m and are flagged: tracks 2a/2b (≈0.82 above rail vs mellan 0.58), 7a/7b (≈0.71 vs 0.58) and 3 (≈0.52 vs hög 0.73). Track 4's platform (BIS 2051) has no laser level.
- The two "ej norm" platforms on tracks z9/z10 (Lennakatten's narrow-gauge line, km 114) are outside this pass.
- One laser-traced roof over a track (3.9 m above the bed) may be a train: check before use.
