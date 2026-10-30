# Hässleholm C (`740000006`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 422970–423400, N 6223957–6224693
(430 × 736 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `hassleholm_structures_heights.geojson` (37 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `hassleholm_ground_1m.tif` (1.0 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 622_42 (2025-09-20)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `hassleholm_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `hassleholm_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `hassleholm_laser_station_2025.laz` (4.4 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (1815 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `hassleholm_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Hässleholm C was being rebuilt: the southern platform objects (BIS 2538–2543, 2041; BanInfo records valid from 2026-05…09) show no raised ground at all in the February 2025 scan, so they were not built yet or under construction; they have no laser level. The measured platforms (tracks 1b and 15) give the station level.
- OSM has no roof outlines at the platforms; the two roofs over the platforms are traced from the laser.
- Six trains stood in the scan (`train_in_scan`).
- BanInfo was being re-issued during the day (2026-10-28…30 records): some objects changed track link and side between queries; the platform side was taken from the raised ground beside the line, BanInfo's SIDE only as a tie-break.
