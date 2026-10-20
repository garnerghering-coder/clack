# OSM rail graph

`rail-graph.json.gz` is the rail network Clack routes legs on and draws as the "Rail network" map layer.

- **Source:** OpenStreetMap extracts for Sweden, Denmark and Norway (`download.openstreetmap.fr`, 2026-10-19).
  Kept: `railway=rail|light_rail|narrow_gauge`, with service track flagged.
- **License:** © OpenStreetMap contributors, available under the
  [Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/1-0/). This file is a derived
  database and is shared under the same license. The app shows "© OpenStreetMap contributors" on every map.
- **Format:** junction nodes and edges with encoded-polyline geometry (simplified to 2 m). See
  `scripts/osm/build-rail-graph.mjs`.

## Refreshing it

Rail lines change rarely, so this is a manual step (a few times a year at most):

1. Download the three `.osm.pbf` extracts into `data/cache/osm/`
   (`https://download.openstreetmap.fr/extracts/europe/{sweden,denmark,norway}-latest.osm.pbf`, ~3 GB).
2. `pip install osmium`, then
   `python3 scripts/phase0/osm_rail_extract.py data/cache/osm/sweden-latest.osm.pbf data/cache/osm/denmark-latest.osm.pbf data/cache/osm/norway-latest.osm.pbf` (~15 min).
3. `node --max-old-space-size=8000 scripts/osm/build-rail-graph.mjs` (~10 s), then commit the new file.

Cached routes live in the `track_segments` table; delete its rows after a refresh to re-route.
