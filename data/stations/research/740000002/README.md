# Göteborg C (`740000002`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 319398–320227, N 6400204–6400734
(829 × 530 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `goteborg_c_structures_heights.geojson` (180 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `goteborg_c_ground_1m.tif` (1.1 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 640_32 (2023-02-10), 640_31 (2023-02-09)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `goteborg_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `goteborg_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `goteborg_c_laser_station_2020.laz` (5.3 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (6497 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `goteborg_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 0.00 m over 120310 m²
- Terminus with 15 BanInfo platform objects. 17 trains were standing at the platforms during the scan (2020-03-21, a Saturday); all are `train_in_scan`, their points class 64.
- Tracks 22 and 23 (BIS 2622/2623, mellan, 14.2 m wide) are new BanInfo objects valid from 2026-10-29 and not in Bilaga 2A; the 2020 laser predates them, so their laser values are of whatever stood there before and are left out of the station level.
- The terrain model is exactly 0.00 m over ~12 ha in the box: the water of Stora Hamnkanalen / Göta älv, not ground.
- Most platforms are under the OSM `building=roof` canopies (w1096834912–w1096834918): their surfaces are measured only where the roof leaves gaps.
- One laser-traced roof (480 m², 4.4 m above the track bed) lies partly over a track: may be a double-deck train rather than a canopy; check in a cross-section.
