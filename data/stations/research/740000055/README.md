# Södertälje Syd (`740000055`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 651021–651684, N 6560998–6561462
(663 × 464 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `sodertalje_syd_structures_heights.geojson` (25 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `sodertalje_syd_ground_1m.tif` (1.0 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 656_65 (2022-11-04)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `sodertalje_syd_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `sodertalje_syd_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `sodertalje_syd_laser_station_2020.laz` (5.0 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (440 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `sodertalje_syd_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 0.14 m over 14932 m²
- **Two stations on two levels.** Södertälje syd **övre** (tracks 5–8, BIS 820/821, mellan) sits on the bridge over the Igelsta valley: the laser classes it as bridge (17), and the pack reads its track bed (≈40.1 m) and platforms (≈41.2 m) from those points. Södertälje syd **undre** (tracks 3–4, BIS 1331/1332, hög) is at ground level (bed ≈15.4 m, platforms ≈16.6–16.7 m).
- The single "station level" in the files (28.95 m) is the median of both and **should not be used**: use ≈41.2 m for övre and ≈16.6 m for undre.
- All four platforms measure 0.9–1.1 m above rail, far above their classes (mellan 0.58, hög 0.73). On the bridge the class-17 points beside the track include parapets and roofs, so the övre values are rough; the undre values (243 and 107 points) are also high. Flagged, not decided.
- The flat 0.14 m is Lake Mälaren / Södertälje canal water.
