# Jönköping C (740000090): 3D research data

What the 3D research pass of 2026-10-29/30 found and built, kept here so the values in
`scripts/stations/740000090.edits.json` can be traced and re-derived. The method is `docs/STATION_3D_RESEARCH.md`; the
findings, with every source, are `3D_SOURCES_FINDINGS.md`.

| File | What | Licence |
|---|---|---|
| `jonkoping_c_laser_station_2022.laz` | Laser points clipped to the station (116,646, scanned 2022-03-19/20), original classes, the two parked trains as class 64 | Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0 (Lantmäteriet's GDPR terms apply) |
| `jonkoping_c_ground_1m.tif`, `_heightmap.json` | Ground, 1 m GeoTIFF, EPSG:3006 / RH 2000, from the laser's ground and water points | as above |
| `jonkoping_c_ground_1m_preview.png` | The same as 8-bit grey for viewing (`scripts/stations/terrain_preview.py`); not data | as above |
| `jonkoping_c_structures_heights.geojson` | Outlines (OSM) and traced roofs (laser) with roof heights, and the two trains in the scan | CC BY 4.0 (Lantmäteriet) + ODbL (OSM) |
| `jonkoping_c_platform_trafikverket.geojson` | Trafikverket's platform record (BIS object 1705) as track lines | CC0 (Trafikverket BanInfo) |
| `jonkoping_c_station.json` | Every value with its source, in the research pass's own layout | as above |
| `jonkoping_c_model.glb` | The research pass's block model, for review only (the app builds its own from the station map). Its footbridge underside, 97.2 m, is an assumption | as above |
| `photos.json` | 18 Wikimedia Commons photos with author, licence and link (the files themselves are not kept) | per photo |

Heights in the research files are metres in RH 2000. The station map uses metres above the platform surface,
91.67 m RH 2000 (laser): see the edits file.
