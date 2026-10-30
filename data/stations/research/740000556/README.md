# Arlanda C (`740000556`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 664898–665228, N 6615396–6616409
(330 × 1013 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `arlanda_c_structures_heights.geojson` (62 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `arlanda_c_ground_1m.tif` (1.0 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 661_66 (2023-05-16)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `arlanda_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `arlanda_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `arlanda_c_laser_station_2021.laz` (4.5 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (0 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `arlanda_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- **Arlanda C is underground** (rock tunnel under the terminals): the airborne laser cannot see its platforms or track bed. The "track bed" values in the platform table are the ground surface above the tunnel and the platform surface is not measured; there is no station reference level from the laser. BanInfo gives the three platforms as `hög` (0.73 m) only, with no length, width or roof; Arlandabanan is not in Bilaga 2A.
- The structures are the terminal buildings, roofs and bus-stop shelters above the station (OSM outlines with laser roof tops), not the station's platform roofs.
- BanInfo's track numbers for these objects changed during the day (BanInfo records were being re-issued on 2026-10-28…30); trust the platform objects (BIS 2305–2307), not the track numbers.
