# OSM rail graph

`rail-graph.json.gz` is the rail network Clack routes legs on and draws as the "Rail network" map layer.

- **Source:** OpenStreetMap extracts for Sweden, Denmark and Norway (`download.openstreetmap.fr`, 2026-10-19) and
  Finland (Geofabrik, `https://download.geofabrik.de/europe/finland-latest.osm.pbf`, OSM data timestamp
  2026-10-23). Kept, the same for all four countries: `railway=rail|light_rail|narrow_gauge`, with service track
  flagged and industrial/military/tourism usage hidden from the map layer. Lines tagged `railway=tram|subway` are
  not kept. Note that in Finland the Helsinki metro (including the western extension to Espoo) and the Tampere tram
  are tagged `railway=light_rail` in OSM; they are NOT in the graph (owner, 2026-10-24: no light rail in Finland). `build-rail-graph.mjs` skips light_rail ways east of 20.5°E; the committed graph had the same edges removed. Light rail in Sweden, Norway and Denmark is kept (kind 1).
- **License:** © OpenStreetMap contributors, available under the
  [Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/1-0/). This file is a derived
  database and is shared under the same license. The app shows "© OpenStreetMap contributors" on every map.
- **Format:** junction nodes and edges with encoded-polyline geometry (simplified to 2 m). See
  `scripts/osm/build-rail-graph.mjs`.
- **Finland and the border:** Finland was extracted on its own and appended to the existing graph (`--base`); the
  Sweden/Denmark/Norway edges are unchanged. The Swedish extract already held the Finnish track at Tornio, so the two
  networks join on a shared junction at 65.829926, 24.164376 and a Tornio–Haparanda leg routes on track.

## Refreshing it

Rail lines change rarely, so this is a manual step (a few times a year at most):

1. Download the `.osm.pbf` extracts into `data/cache/osm/` (git-ignored)
   (`https://download.openstreetmap.fr/extracts/europe/{sweden,denmark,norway}-latest.osm.pbf`, ~3 GB, and
   `https://download.geofabrik.de/europe/finland-latest.osm.pbf`, ~0.8 GB).
2. `pip install osmium`, then extract all four at once:
   `python3 scripts/phase0/osm_rail_extract.py data/cache/osm/{sweden,denmark,norway,finland}-latest.osm.pbf` (~20 min).
3. `node --max-old-space-size=8000 scripts/osm/build-rail-graph.mjs` (~10 s), then commit the new file.

To add or refresh one country without redoing the rest (how Finland was added, ~4 min extract):
`python3 scripts/phase0/osm_rail_extract.py --out data/cache/osm/rail-finland.json data/cache/osm/finland-latest.osm.pbf`,
then `node scripts/osm/build-rail-graph.mjs --base data/osm/rail-graph.json.gz data/cache/osm/rail-finland.json`
(copy the old graph elsewhere first if you want to compare). Run it only once per extract: a second run on the
already-merged file would append the same edges again.

Cached routes live in the `track_segments` table; delete its rows after a refresh to re-route.
