# Kuopio (`fi:KUO`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief, applied to Finland (sources swapped for the Finnish equivalents).
Heights are metres in N2000; coordinates WGS84 in the GeoJSON files and ETRS-TM35FIN (EPSG:3067) in the rasters and the LAZ.
Station box (ETRS-TM35FIN): E 534312–534862, N 6974207–6974457
(550 × 250 m: the platforms' extent plus a margin).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `kuopio_structures_heights.geojson` (23 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_P5114D3), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned P5114D3 2021-07-05 (20210102_Swissphoto_Kuopio_kesa) |
| `kuopio_ground_1m.tif` (145 kB) | Ground, 1 m, float32, EPSG:3067, N2000, gridded here from the laser's ground points (class 2), median per 1 m cell; cells with no ground point (under buildings, trains, roofs) are no-data | Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_P5114D3), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned P5114D3 2021-07-05 (20210102_Swissphoto_Kuopio_kesa) |
| `kuopio_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `kuopio_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `kuopio_laser_station_2021.laz` (570 kB) | Laser points clipped to the station box, original classes, **trains as class 64** (0 points) | Laserkeilausaineisto 0,5 p, newest per sheet (clack_fi_mml05_P5114D3), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0; scanned P5114D3 2021-07-05 (20210102_Swissphoto_Kuopio_kesa) |
| `kuopio_platform_vayla.geojson` | Digitraffic infra-api platform objects (laiturit) as track-centre lines, with platform number, height class, length and the laser levels | Väylävirasto / Fintraffic (Digitraffic), CC BY 4.0 |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Digitraffic |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor's permission for OSM.
