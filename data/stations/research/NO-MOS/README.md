# Moss (`NO-MOS`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief, applied to Norway (sources swapped for the Norwegian equivalents).
Heights are metres in NN2000; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 593523–594509, N 6588773–6589849
(986 × 1076 m: the hoydedata.no export rectangle (platforms plus a margin)).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `moss_structures_heights.geojson` (31 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Høydedata, project "Moss Done FOU 2020" (id 4249, FKB-Laser 3.0, nominal 5 points/m², supplier Statens Kartverk), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `moss_ground_1m.tif` (1.3 MB) | Ground, 1 m, float32, EPSG:25832, NN2000, gridded here from the laser's ground points (class 2), median per 1 m cell; cells with no ground point (under buildings, trains, roofs) are no-data | Høydedata, project "Moss Done FOU 2020" (id 4249, FKB-Laser 3.0, nominal 5 points/m², supplier Statens Kartverk), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `moss_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `moss_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `moss_laser_station_2020.laz` (184.5 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (15450 points) | Høydedata, project "Moss Done FOU 2020" (id 4249, FKB-Laser 3.0, nominal 5 points/m², supplier Statens Kartverk), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `moss_platform_banenor.geojson` | Bane NOR Sportabell platforms (track, length, height in mm, width, type) placed on the OSM track centreline, with the laser levels | facts from Bane NOR's station page (not open: facts only); line geometry © OpenStreetMap contributors, ODbL; NSR quays © Entur, NLOD |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Bane NOR |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is © Kartverket, CC BY 4.0: do not upload values derived from it to OpenStreetMap without Kartverket's permission for OSM.

## Unusual at this station

- Laser: Moss Done FOU 2020, a drone research scan (Kartverket/Geovekstforum, ~150 points/m², classes 1, 2, 5, 6). The 942 MB export was thinned here to one sixth (random, seed 0; ~25 points/m², 18.7 M points) so the pack stays usable; the full export is in the owner's raw bundles (`raw_bundles/NO/punktsky/eksport_1797495_20261030.zip`). Moss station is on a temporary layout while the new station is built (Bane NOR, Jan 2026: no opening date): levels here are of the 2020 layout.
