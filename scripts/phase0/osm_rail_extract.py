"""Q6 (part 2): extract the OSM rail network for routing.

Keeps railway=rail|light_rail|narrow_gauge ways. Service track (service=yard|siding|spur|crossover)
is kept but flagged so the router can penalise it: dropping it disconnects lines inside stations
(Phase 0 found Borlänge–Falun and Hallsberg–Kumla unroutable without it).
Writes data/cache/osm/rail.json: {"nodes": {id: [lat, lon]}, "ways": [[way_id, kind, usage, service, [node ids]]]}

Usage: python3 scripts/phase0/osm_rail_extract.py [--out rail.json] <country.osm.pbf>...
Several extracts (e.g. Sweden + Denmark + Norway + Finland) are merged; OSM ids are global, so ways on a
border that appear in two files are simply de-duplicated. --out sets the output path (default: rail.json next
to the first extract); use it to extract one country on its own, e.g. Finland, which scripts/osm/build-rail-graph.mjs
then adds to the committed graph (--base) without re-extracting the others.
(pyosmium: pip install osmium). A one-off data tool; the app itself is TypeScript.
"""
import json
import sys
import osmium

KEEP = {"rail", "light_rail", "narrow_gauge"}


class Rail(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.ways = {}
        self.need = set()

    def way(self, w):
        t = w.tags
        if t.get("railway") not in KEEP:
            return
        ids = [n.ref for n in w.nodes]
        self.ways[w.id] = [w.id, t.get("railway"), t.get("usage", ""), t.get("service", ""), ids]
        self.need.update(ids)


class Nodes(osmium.SimpleHandler):
    def __init__(self, need):
        super().__init__()
        self.need = need
        self.nodes = {}

    def node(self, n):
        if n.id in self.need:
            self.nodes[n.id] = [round(n.location.lat, 6), round(n.location.lon, 6)]


args = sys.argv[1:]
out = None
if args and args[0] == "--out":
    out, args = args[1], args[2:]
pbfs = args
r = Rail()
for pbf in pbfs:
    r.apply_file(pbf)
    print(f"{pbf}: rail ways so far {len(r.ways)}")
n = Nodes(r.need)
for pbf in pbfs:
    n.apply_file(pbf)
print(f"rail ways {len(r.ways)}, nodes needed {len(r.need)}, found {len(n.nodes)}")
out = out or pbfs[0].rsplit("/", 1)[0] + "/rail.json"
with open(out, "w") as f:
    json.dump({"nodes": n.nodes, "ways": list(r.ways.values())}, f)
print(f"wrote {out}")
