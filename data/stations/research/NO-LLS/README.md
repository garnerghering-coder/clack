# Lillestrøm (`NO-LLS`): measured 3D data

Research pack made 2026-10-30 following `STATION_3D_RESEARCH.md` (playbook, Part 1 steps 3–9) and the Sweden brief, applied to Norway (sources swapped for the Norwegian equivalents).
Heights are metres in NN2000; coordinates WGS84 in the GeoJSON files and ETRS89 / UTM 32N (EPSG:25832) in the rasters and the LAZ.
Station box (ETRS89 / UTM 32N): E 613802–614590, N 6647435–6648494
(788 × 1059 m: the hoydedata.no export rectangle (platforms plus a margin)).

| File | What it is | Licence |
|---|---|---|
| `3D_SOURCES_FINDINGS.md` | Values, flags and sources | — |
| `lillestrom_structures_heights.geojson` (53 kB) | Outlines with measured roof heights: OSM buildings, roofs and bridges at the platforms, roofs traced from the laser, trains standing in the scan | outlines from OSM: ODbL; heights: Høydedata, project "Romerike 2013" (id 121, FKB-Laser 2.0, nominal 2 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `lillestrom_ground_1m.tif` (789 kB) | Ground, 1 m, float32, EPSG:25832, NN2000, gridded here from the laser's ground points (class 2), median per 1 m cell; cells with no ground point (under buildings, trains, roofs) are no-data | Høydedata, project "Romerike 2013" (id 121, FKB-Laser 2.0, nominal 2 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `lillestrom_ground_1m_heightmap.png` + `.json` | The same ground as a 16-bit PNG; the JSON says how to turn values into metres | as above |
| `lillestrom_ground_1m_preview.png` | 8-bit grey preview, for looking at only (dark = low) | as above |
| `lillestrom_laser_station_2013.laz` (14.7 MB) | Laser points clipped to the station box, original classes, **trains as class 64** (3514 points) | Høydedata, project "Romerike 2013" (id 121, FKB-Laser 2.0, nominal 2 points/m², supplier Terratec AS), © Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box |
| `lillestrom_platform_banenor.geojson` | Bane NOR Sportabell platforms (track, length, height in mm, width, type) placed on the OSM track centreline, with the laser levels | facts from Bane NOR's station page (not open: facts only); line geometry © OpenStreetMap contributors, ODbL; NSR quays © Entur, NLOD |
| `photos.json` | Wikimedia Commons files near the station, with author, licence and link | each file's own licence (listed) |
| `station_facts.json` | Part 2 of the brief: levels, platform sides, ways between levels, entrances, amenities (every shop, café, restaurant and kiosk) with opening hours and a `position` (lon/lat, OSM level, inside the station building or not) for the 2D map, plans, open points; every entry has its `_source`. Shops with several same-name places in OSM have `position_candidates` instead; shops not in OSM have `position: null` | facts from the owner's pages and plans (not open: facts only), OSM (ODbL), laser + Bane NOR |
| `_report.json` | Machine-readable summary of this pass | — |

The laser data is © Kartverket, CC BY 4.0: do not upload values derived from it to OpenStreetMap without Kartverket's permission for OSM.

## Unusual at this station

- track 20: 72 m, 350 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 20: 107 m, 350 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 20: 107 m, 350 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 22: 107 m, 350 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 22: 107 m, 350 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 24: 95 m, 350 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 24: 107 m, 350 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- track 25: 80 m, 600 mm, "Island platform. Stabling." (not a passenger platform: left out of the register lines)
- terrain model is exactly flat over large areas (a water surface, not ground): 106.23 m over 1527 m², 106.24 m over 1531 m², 106.25 m over 1608 m², 106.26 m over 1548 m², 106.27 m over 1579 m², 106.28 m over 1530 m², 106.29 m over 1563 m², 106.31 m over 1516 m², 106.32 m over 1588 m², 106.33 m over 1670 m², 106.34 m over 1824 m², 106.35 m over 1743 m², 106.36 m over 1759 m², 106.37 m over 1807 m², 106.38 m over 1773 m², 106.39 m over 1955 m², 106.40 m over 1883 m², 106.41 m over 1934 m², 106.42 m over 1847 m², 106.43 m over 1989 m², 106.44 m over 1958 m², 106.45 m over 1884 m², 106.46 m over 1854 m², 106.47 m over 1831 m², 106.48 m over 1965 m², 106.49 m over 1995 m², 106.50 m over 1907 m², 106.51 m over 1940 m², 106.52 m over 1951 m², 106.53 m over 1939 m², 106.54 m over 1918 m², 106.55 m over 1947 m², 106.56 m over 1926 m², 106.57 m over 1963 m², 106.58 m over 1973 m², 106.59 m over 1859 m², 106.60 m over 1936 m², 106.61 m over 1790 m², 106.62 m over 1908 m², 106.63 m over 1844 m², 106.64 m over 1911 m², 106.65 m over 1810 m², 106.66 m over 1712 m², 106.67 m over 1683 m², 106.68 m over 1643 m², 106.69 m over 1603 m², 106.70 m over 1618 m², 106.71 m over 1609 m², 106.72 m over 1611 m², 106.73 m over 1622 m², 106.74 m over 1667 m², 106.75 m over 1688 m², 106.76 m over 1708 m², 106.77 m over 1725 m², 106.78 m over 1714 m², 106.79 m over 1659 m², 106.80 m over 1719 m², 106.81 m over 1750 m², 106.82 m over 1609 m², 106.83 m over 1668 m², 106.84 m over 1688 m², 106.85 m over 1725 m², 106.86 m over 1811 m², 106.87 m over 1848 m², 106.88 m over 1693 m², 106.89 m over 1761 m², 106.90 m over 1699 m², 106.91 m over 1701 m², 106.92 m over 1737 m², 106.93 m over 1700 m², 106.94 m over 1756 m², 106.95 m over 1682 m², 106.96 m over 1758 m², 106.97 m over 1763 m², 106.98 m over 1704 m², 106.99 m over 1689 m², 107.00 m over 1697 m², 107.01 m over 1686 m², 107.02 m over 1551 m², 107.03 m over 1621 m², 107.05 m over 1542 m²
- Lillestrøm's island platforms 3/4 and 6/7 are under long canopies: no flat platform surface in the airborne laser (Romerike 2013, 2 points/m²). The 2013 classification leaves platform decks in class 1; levels for platforms 1/2 and 8/9 come from a flat class-1 band.
