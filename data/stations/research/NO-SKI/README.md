# Ski (`NO-SKI`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief, applied to Norway (sources swapped for the Norwegian equivalents).
Heights are metres in NN2000; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 602746–603542, N 6620912–6622070
(796 × 1158 m: the hoydedata.no export rectangle (platforms plus a margin)).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `ski_structures_heights.geojson` (65 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Høydedata, project "Follo 2014" (id 119, FKB-Laser 2.0, nominal 5 points/m², supplier Blom Geomatics), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `ski_ground_1m.tif` (1.4 MB) | Ground, 1 m, float32, EPSG:25832, NN2000, gridded here from the laser's ground points (class 2), median per 1 m cell; cells with no ground point (under buildings, trains, roofs) are no-data | Høydedata, project "Follo 2014" (id 119, FKB-Laser 2.0, nominal 5 points/m², supplier Blom Geomatics), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `ski_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `ski_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `ski_laser_station_2014.laz` (60.1 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (2864 points) | Høydedata, project "Follo 2014" (id 119, FKB-Laser 2.0, nominal 5 points/m², supplier Blom Geomatics), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `ski_platform_banenor.geojson` | Bane NOR Sportabell platforms (track, length, height in mm, width, type) placed on the OSM track centreline, with the laser levels | facts from Bane NOR's station page (not open: facts only); line geometry © OpenStreetMap contributors, ODbL; NSR quays © Entur, NLOD |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Bane NOR |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is © Kartverket, CC BY 4.0: do not upload values derived from it to OpenStreetMap without Kartverket's permission for OSM.

## Unusual at this station

- track 12: 237 m, 340/100 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 13: 238 m, 340/100 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- Bane NOR's English station page (https://www.banenor.no/en/traffic-and-travel/railway-stations/-s-/ski/) and Norwegian page (https://www.banenor.no/reise-og-trafikk/stasjoner/-s-/ski/) give different track tables; the English one is used (it matches Entur's quays and the Bane NOR circulars)
- The laser (Follo 2014, last flight 2014-12-08) predates the Follobanen rebuild of Ski station (new tracks 4–6 in use from 6 Aug 2022, S-sirkulære 124-2022; the station reopened in its current form in 2022). Platform levels measured here are of the old layout: the low values (track 2 island 0.26 m above the bed) are not today's 760 mm platforms. Use Bane NOR's track table for heights until a newer open scan exists. Bane NOR's Norwegian track table is out of date; the English one (current) was used.
