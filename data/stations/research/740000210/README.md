# Gävle C (`740000210`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 617306–617818, N 6728193–6728889
(512 × 696 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `gavle_c_structures_heights.geojson` (87 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `gavle_c_ground_1m.tif` (1.2 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 672_61 (2023-05-07)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `gavle_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `gavle_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `gavle_c_laser_station_2021.laz` (4.5 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (347 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `gavle_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + BanInfo |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- Five platform objects (tracks 1s–5). The platform levels spread over 0.5 m (5.38–5.89): track 5's short platform (BIS 1585) sits lowest, track 3's (BIS 1978) highest.
- Track 3 (BIS 1978, mellan) measures ≈0.75 m above rail, 0.17 m over the class; the låg platform BIS 1800 (Bilaga row 263, tracks 1s/1n/5, 123 m) measures ≈0.50 m, between låg and mellan. Both flagged.
- BanInfo gave no track number for BIS 1800 (its track link had no Sparnummer hit).
- OSM maps many shelters and roofs at the platforms (50 `canopy_osm`); the bridges Islandsbron and Murénbron are road/cycle bridges (kind `bridge`).
