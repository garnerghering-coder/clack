# Høje Taastrup (`gtfs:72888`): platform register and station facts (3D pending)

Pass of 2026-10-30 following `STATION_3D_RESEARCH_BRIEF_DK_FI.md`. **The 3D files are not here yet**: Danmarks Højdemodel's
point cloud needs a Dataforsyningen token (the owner's) or the 10 km block order; see `HANDOFF_STATION_3D.md`, Denmark.
`make_dk_bundle.py` + `station_pack.py` build the 3D pack from the 1 km tiles once they exist.

| File | What it is | Licence |
|---|---|---|
| `hoje_taastrup_platform_banedanmark.geojson` | One line per Bilag 3.6 row (perron, track, length, height in cm above rail) on Banedanmark's track centreline, cut to its platform outline; `geometry_how` says how each was placed; laser levels empty until the 3D pass | Bilag 3.6: Banedanmark's facts; geometry Banedanmark Open Data, CC BY 4.0 |
| `station_facts.json` | Part 2: levels, ways between levels, entrances, amenities (shops, cafés, kiosks…) with hours and positions, open points; each with `_source` | owner pages (facts only), OSM (ODbL) |

Register flags (not decided):
- none
