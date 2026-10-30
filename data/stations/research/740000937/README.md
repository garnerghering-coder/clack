# Burlöv (`740000937`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 378867–379355, N 6167490–6167976
(488 × 486 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `burlov_structures_heights.geojson` (11 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `burlov_ground_1m.tif` (800 kB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 616_37 (2025-09-28)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `burlov_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `burlov_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `burlov_laser_station_2025.laz` (7.3 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (0 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `burlov_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Densest scan in the batch (2025-03-07, 4.3 points/m² in the box). Two side platforms (tracks 61–64) under OSM roofs.
- Both platforms measure 0.59–0.63 m above the ballast, ≈0.41–0.45 m above rail after the playbook's 0.15–0.2 m: lower than the register's mellan 0.58 m by more than 0.1 m. With this density the value is well supported; worth a check against a photo or a site visit before trusting either.
