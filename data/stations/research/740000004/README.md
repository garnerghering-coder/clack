# Alvesta (`740000004`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 472735–473168, N 6305767–6306383
(433 × 616 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `alvesta_structures_heights.geojson` (45 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `alvesta_ground_1m.tif` (592 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 630_47 (2024-03-08)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `alvesta_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `alvesta_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `alvesta_laser_station_2026.laz` (5.6 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (2736 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `alvesta_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 142.26 m over 66156 m²
- Newest scan of the batch (2026-03-08, 1.8 points/m² nominal, 2.5/m² in the box). Six trains stood in the scan, including two long ones (150 and 230 m, likely freight) — all `train_in_scan`, points class 64.
- Platform BIS 703 (track 4b, mellan, 610 m, Tak) has no laser level: its surface is under the canopy or not found beside the line.
- Platform BIS 700 (tracks 1a/1b, låg, not open to passengers per Bilaga 2A) measures ~0.46 m above rail: between låg and mellan, within the cross-check's tolerance.
- The flat 142.26 m in the terrain model is the lake Salen, not ground.
