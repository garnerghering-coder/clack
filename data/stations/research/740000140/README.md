# Nässjö C (`740000140`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 481479–482023, N 6389695–6390298
(544 × 603 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `nassjo_c_structures_heights.geojson` (55 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `nassjo_c_ground_1m.tif` (695 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 638_48 (2023-10-31), 639_48 (2023-10-31)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `nassjo_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `nassjo_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `nassjo_c_laser_station_2022.laz` (4.4 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (1936 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `nassjo_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- 130560 m² of the box hold exactly 0.00 in the terrain model (no data at a tile edge); left as no-data
- 88862 m² of terrain-model no-data filled from the laser ground points (class 2, median per 1 m cell); 41698 m² still have no ground value
- terrain model is exactly flat over large areas (a water surface, not ground): 290.23 m over 17791 m²
- Five platform objects (tracks 1–10). The three hög platforms (BIS 235, 258, 259) measure ≈0.74–0.77 m above rail (hög 0.73); track 1s's mellan platform (BIS 1547) ≈0.45 (flagged, 0.13 low). Track 1n's short platform (BIS 257) has no laser level.
- The terrain model has no data over 13 ha of the box (exactly 0.00 at a tile edge, 639_48/638_48); most of it was filled from the laser's ground points, 4 ha stay empty. Ground there in the GeoTIFF is laser-derived, as its tags say.
- The flat 290.23 m is a water surface in the terrain model (a lake), not ground.
