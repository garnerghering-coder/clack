# Stockholm C (`740000001`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief.
Heights are metres in RH 2000; coordinates WGS84 in the GeoJSON files and SWEREF 99 TM (EPSG:3006) in the rasters and the LAZ.
Station box (SWEREF 99 TM): E 673333–674155, N 6580520–6581451
(822 × 931 m: the platforms' extent plus 120 m).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `stockholm_c_structures_heights.geojson` (86 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `stockholm_c_ground_1m.tif` (2.5 MB) | Ground, 1 m, float32, EPSG:3006, RH 2000 (Lantmäteriet terrain model 658_67 (2023-04-27)) | Markhöjdmodell Nedladdning, © Lantmäteriet, CC BY 4.0 |
| `stockholm_c_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `stockholm_c_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `stockholm_c_laser_station_2021.laz` (13.1 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (360 points) | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 |
| `stockholm_c_platform_trafikverket.geojson` | BanInfo platform objects as track lines, with track numbers, register values and the laser levels | Trafikverket, CC0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `_report.json` | Machine-readable summary of this pass | — |

Never upload the Lantmäteriet-derived values to OpenStreetMap (no OSMF waiver).

## Unusual at this station

- terrain model is exactly flat over large areas (a water surface, not ground): 0.89 m over 69471 m²
- Main-line platforms (tracks 1–19) plus the E6/E7 and C2–C4 platforms Bilaga 2A files under Stockholms central, 0.3–1 km north-west; Stockholm City (Citybanan, underground) is a separate station and was left out.
- Over parts of tracks 4–6 and 16–17 the laser's ground class lies ~7 m above the track bed: decks and viaducts over the tracks (Klarabergsviadukten, the station deck). Platforms there (BIS 726, 2510, 2511, 735, 736) have no laser level.
- Arlanda Express platform (tracks 1–2, BIS 1450, "ej norm", 1150 mm per Bilaga) has no laser level (covered).
- The short låg platforms on tracks 10 and 11 (BIS 2009/2010, 30 and 40 m) sit at the ends of hög platforms: the laser sees the hög surface beside them, hence the flag.
- The water of Klara sjö / Riddarfjärden is the flat 0.89 m in the terrain model.
