# Flemingsberg (`740000031`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 667984–668488, N 6567899–6568469
(504 × 570 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `flemingsberg_structures_heights.geojson` (47 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `flemingsberg_ground_1m.tif` (962 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 656_66 (2022-10-10)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `flemingsberg_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `flemingsberg_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `flemingsberg_laser_station_2020.laz` (4.3 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (1063 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `flemingsberg_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Commuter and long-distance platforms (tracks 2b–7). The track-3 platform (BIS 1011, 510 m) lies under the station building that spans the tracks, so the laser has neither its surface nor its bed.
- The hög platform on tracks 4–5 (BIS 1277) measures ≈0.62 m above rail against 0.73 m: 0.11 m low, at the edge of the tolerance.
- OSM has no roof outlines at the platforms; the roofs over them are traced from the laser.
