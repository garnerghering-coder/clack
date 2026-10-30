"""Draft a station map (data/stations/<id>.json, format in packages/shared/src/station.ts) from OpenStreetMap.

ADDITIONS_01 C1. Reads the Geofabrik extract offline (pyosmium; Overpass isn't needed), keeps the levels you name,
turns footways, steps, escalators and lifts into a walking graph, attaches platforms and amenities, and then applies
the hand edits in scripts/stations/<id>.edits.json (extra connections OSM is missing, level names, dropped
objects; "entrances": entrances OSM lacks, as a point and level; "default_level": the OSM level untagged platforms, paths and buildings belong to, "0" unless the
country numbers the ground floor "1" as Norway does). Re-running the script keeps those edits, so the map can be refreshed from newer OSM data.

Usage: python3 scripts/stations/draft_from_osm.py 740000001 [--pbf data/cache/osm/sweden-latest.osm.pbf]
The OSM part of the output is ODbL (© OpenStreetMap contributors); see the Sources page.
A one-off data tool, like scripts/phase0/*.py; the app itself is TypeScript. (pip install osmium)
"""
import argparse
import urllib.parse
import datetime
import json
import math
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict

ROOT = os.environ.get("CLACK_ROOT") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WALK_SPEED = 1.3  # m/s, normal pace, no luggage
STAIRS_SPEED = 0.55  # m/s along the stair's footprint
ESCALATOR_SPEED = 0.75  # standing plus a few steps
STAIRS_MIN_SECONDS = 18  # one flight, ~5 m up or down
ESCALATOR_MIN_SECONDS = 20
LIFT_SECONDS = 45  # wait and ride, one level change
LIFT_PER_EXTRA_LEVEL = 8
PLATFORM_CROSS_SECONDS = 8  # from one side of an island platform to the other

WALK_HIGHWAYS = {"footway", "corridor", "pedestrian", "steps", "elevator", "path", "living_street"}


def parse_levels(v):
    """'-1;0' -> ['-1', '0']; ranges like '0-5' are not walking levels and return None."""
    if v is None:
        return None
    parts = [p.strip() for p in v.split(";") if p.strip()]
    if any(re.fullmatch(r"-?\d+(\.\d+)?", p) is None for p in parts):
        return None
    return parts


OSM_KEYS = ["railway", "public_transport", "highway", "indoor", "amenity", "shop", "building", "entrance", "level", "conveying", "tourism", "vending", "room", "office", "healthcare", "wheelchair", "ref", "name", "step_count", "incline", "layer", "tunnel", "bridge", "covered", "location", "ele", "height", "min_height", "building:levels", "handrail", "escalator", "lit"]


OVERPASS_ENDPOINTS = ["https://overpass-api.de/api/interpreter", "https://lz4.overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]


def load_osm_overpass(lat0, lon0, radius, cache, endpoints=OVERPASS_ENDPOINTS):
    """The same extract as load_osm, but from the Overpass API for the station's box: no PBF download needed
    (the four countries' PBFs are 3.8 GB). Everything tagged with one of OSM_KEYS inside the box, with the nodes
    of every such way, plus multipolygon relations' outer rings. Cached like the PBF extract. One request per
    station, well within Overpass's fair-use limits; the result is ODbL like the PBF."""
    if os.path.exists(cache):
        return json.load(open(cache))
    dlat = radius / 111320
    dlon = radius / (111320 * math.cos(math.radians(lat0)))
    bb = (lat0 - dlat, lat0 + dlat, lon0 - dlon, lon0 + dlon)
    inside = lambda la, lo: bb[0] <= la <= bb[1] and bb[2] <= lo <= bb[3]
    keys = "|".join(OSM_KEYS)
    q = (
        f"[out:json][timeout:120][bbox:{bb[0]},{bb[2]},{bb[1]},{bb[3]}];"
        f'(node[~"^({keys})$"~"."];way[~"^({keys})$"~"."];relation["type"="multipolygon"][~"^({keys})$"~"."];);'
        "out body;>;out skel qt;"
    )
    # curl, not urllib: the Python that ships with Xcode can't complete the TLS handshake with overpass-api.de.
    import subprocess

    raw, errors = None, []
    for endpoint in endpoints:
        r = subprocess.run(["curl", "-sS", "--fail", "--max-time", "200", "-A", "clack-station-drafter (OpenStreetMap ODbL; one request per station)", "--data-urlencode", "data=" + q, endpoint], capture_output=True, text=True)
        if r.returncode == 0:
            try:
                raw = json.loads(r.stdout)
                break
            except ValueError:
                errors.append(f"{endpoint}: not JSON")
        else:
            errors.append(f"{endpoint}: {r.stderr.strip()}")
    if raw is None:
        raise SystemExit("Overpass failed: " + "; ".join(errors))
    coords, nodes, ways, rels = {}, {}, {}, {}
    for el in raw["elements"]:
        if el["type"] == "node":
            coords[el["id"]] = (el["lat"], el["lon"])
            if el.get("tags") and inside(el["lat"], el["lon"]):
                nodes[el["id"]] = dict(t=el["tags"], lat=el["lat"], lon=el["lon"])
    for el in raw["elements"]:
        if el["type"] == "way":
            pts = [(ref, *coords[ref]) for ref in el["nodes"] if ref in coords]
            if el.get("tags") and any(inside(la, lo) for _, la, lo in pts):
                ways[el["id"]] = dict(t=el["tags"], nd=pts)
            elif pts:
                ways.setdefault(f"_m{el['id']}", dict(nd=pts))
    out = dict(retrieved=datetime.date.today().isoformat(), source="overpass", nodes={str(k): v for k, v in nodes.items() if isinstance(k, int)}, ways={str(k): v for k, v in ways.items() if isinstance(k, int)})
    member_pts = {int(k[2:]) if isinstance(k, str) else k: v["nd"] for k, v in ways.items()}
    for el in raw["elements"]:
        if el["type"] == "relation" and el.get("tags", {}).get("type") == "multipolygon":
            refs = [m["ref"] for m in el["members"] if m["type"] == "way" and m.get("role", "") in ("outer", "")]
            rels[el["id"]] = dict(t=el["tags"], members=[member_pts.get(ref) for ref in refs])
    add_relation_rings(out, rels, inside)
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    json.dump(out, open(cache, "w"))
    return out


def load_osm(pbf, lat0, lon0, radius, cache):
    if os.path.exists(cache):
        return json.load(open(cache))
    if not os.path.exists(pbf):
        return load_osm_overpass(lat0, lon0, radius, cache)
    import osmium

    dlat = radius / 111320
    dlon = radius / (111320 * math.cos(math.radians(lat0)))
    bb = (lat0 - dlat, lat0 + dlat, lon0 - dlon, lon0 + dlon)
    inside = lambda la, lo: bb[0] <= la <= bb[1] and bb[2] <= lo <= bb[3]

    class H(osmium.SimpleHandler):
        def __init__(s):
            super().__init__()
            s.nodes, s.ways, s.rels = {}, {}, {}

        def node(s, n):
            if n.tags and n.location.valid() and inside(n.location.lat, n.location.lon):
                s.nodes[n.id] = dict(t=dict(n.tags), lat=n.location.lat, lon=n.location.lon)

        def way(s, w):
            pts, hit = [], False
            for nd in w.nodes:
                try:
                    la, lo = nd.location.lat, nd.location.lon
                except osmium.InvalidLocationError:
                    continue
                pts.append((nd.ref, la, lo))
                hit = hit or inside(la, lo)
            if hit:
                s.ways[w.id] = dict(t=dict(w.tags), nd=pts)

    keys = OSM_KEYS
    h = H()
    h.apply_file(pbf, locations=True, filters=[osmium.filter.KeyFilter(*keys)])
    out = dict(retrieved=datetime.date.fromtimestamp(os.path.getmtime(pbf)).isoformat(), nodes={str(k): v for k, v in h.nodes.items()}, ways={str(k): v for k, v in h.ways.items()})

    # Multipolygon relations (Gävle C maps its platforms and station house this way): their outer rings, kept apart
    # in "relation_ways" and read only by stations whose edits ask for "multipolygons".
    class Rels(osmium.SimpleHandler):
        def __init__(s):
            super().__init__()
            s.rels = {}

        def relation(s, r):
            if r.tags.get("type") == "multipolygon":
                s.rels[r.id] = dict(t=dict(r.tags), m=[m.ref for m in r.members if m.type == "w" and m.role in ("outer", "")])

    rh = Rels()
    rh.apply_file(pbf, filters=[osmium.filter.KeyFilter(*keys)])
    want = {ref for v in rh.rels.values() for ref in v["m"]}

    class Members(osmium.SimpleHandler):
        def __init__(s):
            super().__init__()
            s.ways = {}

        def way(s, w):
            if w.id in want:
                pts = []
                for nd in w.nodes:
                    try:
                        pts.append((nd.ref, nd.location.lat, nd.location.lon))
                    except osmium.InvalidLocationError:
                        pass
                s.ways[w.id] = pts

    mh = Members()
    mh.apply_file(pbf, locations=True)
    add_relation_rings(out, {rid: dict(t=v["t"], members=[mh.ways.get(ref) for ref in v["m"]]) for rid, v in rh.rels.items()}, inside)
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    json.dump(out, open(cache, "w"))
    return out


def add_relation_rings(out, rels, inside):
    """Join each multipolygon's outer member ways into closed rings, kept in out["relation_ways"] as "r<id>[_<k>]"."""
    for rid, v in rels.items():
        parts = [list(p) for p in v["members"] if p and len(p) >= 2]
        if not any(inside(q[1], q[2]) for p in parts for q in p):
            continue
        rings = []
        while parts:
            ring = parts.pop(0)
            grown = True
            while ring[0][0] != ring[-1][0] and grown:
                grown = False
                for i, p in enumerate(parts):
                    if p[0][0] == ring[-1][0]:
                        ring += p[1:]
                    elif p[-1][0] == ring[-1][0]:
                        ring += p[::-1][1:]
                    elif p[-1][0] == ring[0][0]:
                        ring = p[:-1] + ring
                    elif p[0][0] == ring[0][0]:
                        ring = p[::-1][:-1] + ring
                    else:
                        continue
                    parts.pop(i)
                    grown = True
                    break
            if ring[0][0] == ring[-1][0] and len(ring) >= 4:
                rings.append(ring)
        for k, ring in enumerate(rings):
            out.setdefault("relation_ways", {})[f"r{rid}" + (f"_{k}" if len(rings) > 1 else "")] = dict(t=v["t"], nd=ring)


def category(t):
    a, shop = t.get("amenity"), t.get("shop")
    if a == "toilets":
        return "toilet"
    if a == "cafe" or shop in ("bakery", "pastry", "coffee", "tea"):
        return "cafe"
    if a in ("restaurant", "fast_food", "food_court", "bar", "pub", "ice_cream"):
        return "restaurant"
    if shop in ("kiosk", "convenience", "newsagent"):
        return "kiosk"
    if a == "pharmacy" or t.get("healthcare") == "pharmacy" or shop == "chemist":
        return "pharmacy"
    if a in ("atm", "bank", "bureau_de_change"):
        return "atm"
    if (a == "vending_machine" and "ticket" in t.get("vending", "")) or shop == "ticket" or a == "ticket_office" or t.get("office") == "ticket":
        return "ticket"
    if a in ("luggage_locker", "locker", "left_luggage"):
        return "locker"
    if a == "waiting_room" or t.get("room") == "waiting":
        return "waiting"
    if t.get("tourism") == "information" and t.get("information") in (None, "office"):
        return "info"
    if a == "taxi":
        return "taxi"
    if shop and shop not in ("vacant", "no"):
        return "shop"
    return None


# A more specific icon than the category, from OSM tags and well-known chains (generic pictograms, never logos).
BRAND_ICONS = {
    "mcdonald": "burger", "burger king": "burger", "max": "burger", "sibylla": "burger", "subway": "sandwich",
    "espresso house": "coffee", "starbucks": "coffee", "wayne": "coffee", "joe & the juice": "juice", "pressbyrån": "kiosk",
    "7-eleven": "convenience", "coop": "supermarket", "ica": "supermarket", "pizza hut": "pizza", "o'learys": "bar",
}
CUISINE_ICONS = {"burger": "burger", "pizza": "pizza", "sushi": "sushi", "japanese": "sushi", "asian": "noodles", "thai": "noodles", "chinese": "noodles",
                 "vietnamese": "noodles", "noodle": "noodles", "ramen": "noodles", "sandwich": "sandwich", "kebab": "kebab", "chicken": "chicken",
                 "coffee_shop": "coffee", "ice_cream": "ice_cream", "juice": "juice", "bagel": "sandwich", "salad": "salad", "donut": "donut"}
SHOP_ICONS = {"bakery": "bakery", "pastry": "bakery", "confectionery": "candy", "chocolate": "candy", "convenience": "convenience", "kiosk": "kiosk",
              "newsagent": "kiosk", "supermarket": "supermarket", "books": "books", "clothes": "clothes", "shoes": "shoes", "fashion_accessories": "clothes",
              "cosmetics": "cosmetics", "perfumery": "cosmetics", "beauty": "cosmetics", "chemist": "pharmacy", "florist": "flowers", "electronics": "electronics",
              "mobile_phone": "electronics", "computer": "electronics", "jewelry": "jewelry", "watches": "jewelry", "gift": "gift", "variety_store": "gift",
              "hairdresser": "hairdresser", "optician": "optician", "tobacco": "kiosk", "tea": "coffee", "coffee": "coffee", "alcohol": "bar", "wine": "bar",
              "travel_agency": "info", "bag": "clothes", "toys": "gift", "interior_decoration": "gift", "stationery": "books"}


def poi_icon(t):
    name = (t.get("brand") or t.get("name") or "").lower()
    for brand, icon in BRAND_ICONS.items():
        if name.startswith(brand):
            return icon
    for c in (t.get("cuisine") or "").split(";"):
        if c.strip() in CUISINE_ICONS:
            return CUISINE_ICONS[c.strip()]
    if t.get("shop") in SHOP_ICONS:
        return SHOP_ICONS[t["shop"]]
    a = t.get("amenity")
    return {"cafe": "coffee", "bar": "bar", "pub": "bar", "ice_cream": "ice_cream", "fast_food": "fast_food"}.get(a)


def pip(pt, poly):
    x, y = pt
    ins = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[i - 1]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            ins = not ins
    return ins


def dist_to_poly(pt, poly):
    if pip(pt, poly):
        return 0.0
    best = float("inf")
    for i in range(len(poly)):
        ax, ay = poly[i - 1]
        bx, by = poly[i]
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        t = 0 if L == 0 else max(0, min(1, ((pt[0] - ax) * dx + (pt[1] - ay) * dy) / L))
        best = min(best, math.hypot(pt[0] - ax - t * dx, pt[1] - ay - t * dy))
    return best


def simplify(pts, tol=0.4):
    """Douglas–Peucker; a closed ring is split at its farthest point first."""
    if len(pts) < 3:
        return pts
    if len(pts) > 3 and pts[0] == pts[-1]:
        far = max(range(len(pts)), key=lambda i: math.hypot(pts[i][0] - pts[0][0], pts[i][1] - pts[0][1]))
        return simplify(pts[: far + 1], tol)[:-1] + simplify(pts[far:], tol)
    ax, ay = pts[0]
    bx, by = pts[-1]
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy) or 1e-9
    i, dmax = 0, -1
    for k in range(1, len(pts) - 1):
        d = abs(dy * (pts[k][0] - ax) - dx * (pts[k][1] - ay)) / L
        if d > dmax:
            i, dmax = k, d
    if dmax <= tol:
        return [pts[0], pts[-1]]
    return simplify(pts[: i + 1], tol)[:-1] + simplify(pts[i:], tol)


def polylen(pts):
    return sum(math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]) for i in range(1, len(pts)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("station_id")
    ap.add_argument("--pbf", default=os.path.join(ROOT, "data/cache/osm/sweden-latest.osm.pbf"))
    args = ap.parse_args()
    sid = args.station_id
    # Finnish ids carry a colon ("fi:HKI"); files are named with an underscore (fi_HKI.edits.json, fi_HKI.json).
    safe = sid.replace(":", "_")
    edits = json.load(open(os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")))
    db = sqlite3.connect(f"file:{os.path.join(ROOT, 'data/app.db')}?mode=ro", uri=True)
    name, lat0, lon0 = db.execute("select name, lat, lon from stations where id=?", (sid,)).fetchone()
    if "origin" in edits:
        lat0, lon0 = edits["origin"]["lat"], edits["origin"]["lon"]
    K = math.cos(math.radians(lat0)) * 111320
    xy = lambda la, lo: (round((lo - lon0) * K, 2), round(-(la - lat0) * 111320, 2))
    osm = load_osm(args.pbf, lat0, lon0, edits.get("radius", 400), os.path.join(ROOT, f"data/cache/stations/{safe}-osm.json"))
    nodes, ways = osm["nodes"], osm["ways"]
    if edits.get("multipolygons"):
        # Platforms and station houses OSM maps as multipolygon relations: their outer rings, as ways "r<id>".
        ways = {**ways, **osm.get("relation_ways", {})}
    keep_levels = {str(l["osm"]) for l in edits["levels"]}
    level_id = {str(l["osm"]): l["id"] for l in edits["levels"]}
    limit = edits.get("radius", 400)
    near = lambda p: math.hypot(*p) <= limit
    log = []

    def coords(w):
        return [xy(p[1], p[2]) for p in w["nd"]]

    def platform_levels(t, wid=None):
        """A platform's level tag; or, with "layer_as_level" in the edits, its layer (Malmö C's underground platforms
        carry layer=-2 and no level); otherwise ground level."""
        lv = parse_levels(t.get("level")) or parse_levels(edits.get("platform_levels", {}).get(wid))
        if lv is None and edits.get("layer_as_level"):
            lv = parse_levels(t.get("layer"))
        return lv or [edits.get("default_level", "0")]

    # ---- Station buildings: shapes, and the area where untagged in-station paths count as ground level ----
    station_polys = []
    shapes = []
    indoor_shapes = []
    for wid, w in ways.items():
        t = w["t"]
        if w["nd"][0][0] != w["nd"][-1][0]:
            continue
        p = coords(w)
        if not any(near(q) for q in p):
            continue
        if t.get("building") in ("train_station", "transportation") or t.get("railway") == "station" or (t.get("public_transport") == "station" and t.get("train") != "no"):
            station_polys.append(p)
            b = dict(level=edits.get("building_level", level_id[edits.get("default_level", "0")]), kind="building", points=simplify(p, 0.8), _source=f"osm:way/{wid}")
            h = re.match(r"^\s*(\d+(?:\.\d+)?)\s*(m)?\s*$", t.get("height") or "")
            if h:
                b["height_m"] = float(h.group(1))
            shapes.append(b)
        lv = parse_levels(t.get("level"))
        if t.get("indoor") in ("room", "area", "corridor") and lv and lv[0] in keep_levels:
            kind = "shop" if (t.get("shop") or t.get("amenity") in ("cafe", "restaurant", "fast_food")) else ("hall" if t.get("indoor") == "area" else "room")
            s = dict(level=level_id[lv[0]], kind=kind, points=simplify(p, 0.5), _source=f"osm:way/{wid}")
            if t.get("name"):
                s["name"] = t["name"]
            indoor_shapes.append(s)
    in_station = lambda p: any(pip(p, poly) for poly in station_polys)
    # Indoor rooms only inside the station: the radius also sweeps in neighbours (Hötorgshallen's stalls, 600 m from
    # Stockholm C), which aren't part of it.
    centre_of = lambda pts: (sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts))
    shapes += [s for s in indoor_shapes if in_station(centre_of(s["points"]))]

    # ---- Platforms (one per track side; OSM maps island platforms as two halves with local_ref) ----
    platforms = []
    drop = set(edits.get("drop_platforms", []))
    for wid, w in ways.items():
        t = w["t"]
        if not (t.get("railway") == "platform" or (t.get("public_transport") == "platform" and t.get("train") == "yes")):
            continue
        lv = platform_levels(t, wid)
        if lv[0] not in keep_levels or t.get("subway") == "yes":
            continue
        # A platform OSM left without a number: named by way id in the edits ("platform_refs": {"123": "2"}).
        ref = edits.get("platform_refs", {}).get(wid) or t.get("local_ref") or t.get("ref")
        if not ref or ref in drop or wid in edits.get("drop_platform_ways", []):
            continue
        p = coords(w)
        if not any(near(q) for q in p):
            continue
        if w["nd"][0][0] != w["nd"][-1][0]:
            # A platform drawn as a line: give it a 4 m wide outline.
            left, right = [], []
            for i, (x, y) in enumerate(p):
                a = p[max(0, i - 1)]
                b = p[min(len(p) - 1, i + 1)]
                dx, dy = b[0] - a[0], b[1] - a[1]
                L = math.hypot(dx, dy) or 1
                nx, ny = -dy / L * 2, dx / L * 2
                left.append((x + nx, y + ny))
                right.append((x - nx, y - ny))
            p = left + right[::-1] + [left[0]]
        # Tracks without their sector letter ("2a" → "2"): the app and the validator match tracks that way; the
        # platform's ref keeps the letter, and so does an edge's track from the rail's own number.
        tracks = list(dict.fromkeys(re.sub(r"[a-z]+$", "", x.strip().lower()) for x in re.split(r"[;,]", ref) if x.strip()))
        platforms.append(dict(ref=ref.replace(";", "–"), tracks=tracks, level=level_id[lv[0]], poly=p, wid=wid))
    # Merge pieces with the same ref.
    by_ref = defaultdict(list)
    for p in platforms:
        by_ref[p["ref"]].append(p)

    # ---- Tracks between the platforms: rail segments near a platform (drawn; and, with a track number, the rails a
    # train stands at). Above-ground rails go on level 0; rails in a tunnel or a negative layer are kept for the
    # platform edges (Malmö C's underground platforms) but drawn only when "layer_as_level" maps their layer. ----
    plat_polys = [p["poly"] for p in platforms]
    rails = []  # (wid, pts, track ref or None, underground)
    for wid, w in ways.items():
        t = w["t"]
        if t.get("railway") != "rail":
            continue
        pts = coords(w)
        if not any(dist_to_poly(q, pp) <= 12 for q in pts for pp in plat_polys):
            continue
        track_ref = (t.get("railway:track_ref") or t.get("ref") or "").strip().lower() or None
        underground = bool(t.get("tunnel")) or (t.get("layer") or "0").startswith("-")
        rails.append((wid, pts, track_ref, underground))
        lv = None
        if underground:
            lv = parse_levels(t.get("level")) or (parse_levels(t.get("layer")) if edits.get("layer_as_level") else None)
            if not lv or lv[0] not in keep_levels:
                continue
        run = []
        for q in pts + [None]:
            close = q is not None and any(dist_to_poly(q, pp) <= 12 for pp in plat_polys)
            if close:
                run.append(q)
            elif run:
                if len(run) >= 2:
                    shape = dict(level=level_id[lv[0]] if lv else level_id[edits.get("default_level", "0")], kind="track", points=simplify(run, 0.6), _source=f"osm:way/{wid}")
                    if track_ref:
                        shape["ref"] = track_ref
                    shapes.append(shape)
                run = []

    def dist_to_line(q, pts):
        """Distance from q to an open polyline, and how far along it the nearest point is."""
        best, at, run = float("inf"), 0.0, 0.0
        for i in range(1, len(pts)):
            ax, ay = pts[i - 1]
            bx, by = pts[i]
            dx, dy = bx - ax, by - ay
            L2 = dx * dx + dy * dy
            tt = 0 if L2 == 0 else max(0, min(1, ((q[0] - ax) * dx + (q[1] - ay) * dy) / L2))
            d = math.hypot(ax + tt * dx - q[0], ay + tt * dy - q[1])
            if d < best:
                best, at = d, run + tt * math.sqrt(L2)
            run += math.sqrt(L2)
        return best, at

    def platform_edges(ref, pieces):
        """The platform's sides along the rails (schema 2): the outline vertices within 6 m of each rail way nearby,
        in order along the rail. The track comes from the rail's own number when OSM has one and the platform serves
        it, else from the platform when it has one track; otherwise it is left unknown for the review queue (or set
        in the edits: "platform_edges": {"<ref>": [{"track": "7", "near": [x, y], "_source": "plan:…"}]})."""
        out = []
        tracks = sorted({t for p in pieces for t in p["tracks"]})
        verts = [q for p in pieces for q in p["poly"]]
        for wid, pts, track_ref, _ in rails:
            close = []
            for q in verts:
                d, at = dist_to_line(q, pts)
                if d <= 6:
                    close.append((at, q))
            if len(close) < 2:
                continue
            close.sort()
            line = simplify([q for _, q in close], 0.5)
            if polylen(line) < 15:
                continue
            e = dict(points=[[round(x, 1), round(y, 1)] for x, y in line], _source=f"osm:way/{','.join(str(p['wid']) for p in pieces)} along rail osm:way/{wid}")
            if track_ref and track_ref in tracks:
                e["track"] = track_ref
            elif len(tracks) == 1:
                e["track"] = tracks[0]
                e["note"] = "the platform's only track"
            else:
                e["track"] = None
                e["note"] = "island platform: which side is which track is not in OSM" + (f" (rail says {track_ref})" if track_ref else "")
            out.append(e)
        for o in edits.get("platform_edges", {}).get(ref, []):
            if not out:
                break
            x, y = o["near"]
            best = min(out, key=lambda e: min(math.hypot(px - x, py - y) for px, py in e["points"]))
            best["track"] = o["track"].lower()
            best["_source"] += f"; track from {o['_source']}"
            best.pop("note", None)
        # One edge per track: the longest.
        by_track = {}
        for e in out:
            k = e["track"] or f"?{len(by_track)}"
            if k not in by_track or polylen(e["points"]) > polylen(by_track[k]["points"]):
                by_track[k] = e
        return list(by_track.values())

    # ---- Walking graph from OSM ways ----
    g_nodes = {}  # vid -> dict(x, y, levels Counter, osm tags)
    g_edges = []  # (a, b, kind, pts)

    def vid(nid, level):
        return f"{nid}@{level}"

    node_level_votes = defaultdict(Counter)
    vertical = []
    untagged_vertical = []
    for wid, w in ways.items():
        t = w["t"]
        hw = t.get("highway")
        walky = hw in WALK_HIGHWAYS or t.get("indoor") == "corridor" or t.get("conveying")
        # With "walk_cycleways" in the edits: shared foot and cycle paths (Katrineholm's Lövatunneln is a cycleway with
        # foot=designated) are walking routes too.
        walky = walky or (edits.get("walk_cycleways") and hw == "cycleway" and t.get("foot") in ("yes", "designated", "permissive"))
        if not walky or t.get("access") in ("private", "no") or wid in edits.get("drop_ways", []):
            continue
        pts = coords(w)
        if not any(near(q) for q in pts):
            continue
        lv = parse_levels(t.get("level"))
        if lv is None and t.get("level") is None and edits.get("paths_by_layer") and (t.get("tunnel") or t.get("bridge") or t.get("covered")) and t.get("layer"):
            # Untagged tunnels and footbridges (most small stations): their layer is the level.
            lv = parse_levels(t.get("layer"))
            if lv and lv[0] not in keep_levels:
                lv = None
        vertical_way = hw in ("steps", "elevator") or bool(t.get("conveying"))
        if lv is None and vertical_way and t.get("level") is None:
            # Stairs without a level: worked out below from what their ends touch.
            untagged_vertical.append(dict(ids=[p[0] for p in w["nd"]], pts=pts, kind="lift" if hw == "elevator" else ("escalator" if t.get("conveying") else "stairs"), incline=t.get("incline"), step_count=t.get("step_count"), way=wid, conveying=t.get("conveying")))
            continue
        if lv is None:
            # Untagged paths count inside the station building (as ground level), and with "path_radius" in the edits
            # also near the platforms (stations whose platforms are reached from the street, not a hall).
            mid = pts[len(pts) // 2]
            near_platform = edits.get("path_radius") and any(dist_to_poly(q, pp) <= edits["path_radius"] for q in (pts[0], mid, pts[-1]) for pp in plat_polys)
            if t.get("level") is not None or not (in_station(mid) or near_platform):
                continue
            lv = [edits.get("default_level", "0")]
        if not set(lv) <= keep_levels:
            continue
        if len(lv) == 1 and hw not in ("steps", "elevator") and not t.get("conveying"):
            for (nid, _, _) in w["nd"]:
                node_level_votes[nid][lv[0]] += 1
            g_edges.append(dict(ids=[p[0] for p in w["nd"]], pts=pts, kind="walk", levels=lv, way=wid))
        else:
            kind = "lift" if hw == "elevator" else ("escalator" if t.get("conveying") else "stairs")
            vertical.append(dict(ids=[p[0] for p in w["nd"]], pts=pts, kind=kind, levels=lv, incline=t.get("incline"), way=wid, conveying=t.get("conveying")))

    # Platform outlines: a stair that shares a node with one starts or ends on that platform's level.
    platform_node_level = {}
    for wid, w in ways.items():
        t = w["t"]
        if t.get("railway") == "platform" or (t.get("public_transport") == "platform" and t.get("train") == "yes"):
            lv = platform_levels(t, wid)
            if lv[0] in keep_levels and t.get("subway") != "yes":
                for p in w["nd"]:
                    platform_node_level[p[0]] = lv[0]
    order = {str(l["osm"]): l["order"] for l in edits["levels"]}
    by_order = sorted(order, key=lambda k: order[k])

    def step_level(lv, d):
        i = by_order.index(lv) + d
        return by_order[i] if 0 <= i < len(by_order) else None

    for e in untagged_vertical:
        first, last = e["ids"][0], e["ids"][-1]
        known = lambda nid: platform_node_level.get(nid) or (node_level_votes[nid].most_common(1)[0][0] if node_level_votes.get(nid) else None)
        la, lb = known(first), known(last)
        up = e["incline"] in ("up", "yes") or (e["incline"] or "").startswith(("+",))
        down = e["incline"] == "down" or (e["incline"] or "").startswith("-")
        # A few steps at a door (step_count <= 6, or under 2.5 m drawn) aren't a change of floor: keep them on the
        # level of the end that is known.
        sc = e.get("step_count")
        if e["kind"] == "stairs" and bool(la) != bool(lb) and ((sc or "").isdigit() and int(sc) <= 6 or polylen(e["pts"]) < 2.5):
            L = la or lb
            vertical.append(dict(ids=e["ids"], pts=e["pts"], kind="stairs", levels=[L], ends=(L, L), short=True, way=e["way"]))
            continue
        if la and not lb and (up or down):
            lb = step_level(la, 1 if up else -1)
        elif lb and not la and (up or down):
            la = step_level(lb, -1 if up else 1)
        if not la or not lb or la == lb:
            continue
        vertical.append(dict(ids=e["ids"], pts=e["pts"], kind=e["kind"], levels=sorted([la, lb], key=lambda k: order[k]), ends=(la, lb), way=e["way"], conveying=e.get("conveying"), incline=e.get("incline")))

    def level_of(nid, default):
        c = node_level_votes.get(nid)
        return c.most_common(1)[0][0] if c else default

    V = {}

    def vertex(nid, level, x, y):
        level = level_id[level]
        k = vid(nid, level)
        if k not in V:
            V[k] = dict(id=k, x=x, y=y, level=level, osm=nid, src=f"osm:node/{nid}")
        return k

    E = []
    for e in g_edges:
        L = e["levels"][0]
        for i in range(1, len(e["ids"])):
            a = vertex(e["ids"][i - 1], L, *e["pts"][i - 1])
            b = vertex(e["ids"][i], L, *e["pts"][i])
            E.append(dict(a=a, b=b, kind="walk", pts=[e["pts"][i - 1], e["pts"][i]], src=f"osm:way/{e['way']}"))

    def escalator_direction(e):
        """Which way an escalator runs, from the way's conveying= and incline= tags; None when OSM doesn't say."""
        c, inc = e.get("conveying"), e.get("incline")
        if c == "reversible":
            return "both"
        if c in ("forward", "backward", "yes") and inc in ("up", "down"):
            up = (inc == "up") == (c != "backward")
            return "up" if up else "down"
        return None

    for e in vertical:
        lo, hi = e["levels"][0], e["levels"][-1]
        # Which end is which level: ask the ways that meet each end; otherwise guess from the order given.
        la = level_of(e["ids"][0], None) if "ends" not in e else e["ends"][0]
        lb = level_of(e["ids"][-1], None) if "ends" not in e else e["ends"][1]
        if la is None and lb is None:
            la, lb = lo, hi
        elif la is None:
            la = lo if lb != lo else hi
        elif lb is None:
            lb = hi if la != hi else lo
        if e["kind"] == "lift" and len(e["ids"]) <= 2 and la == lb:
            la, lb = lo, hi
        a = vertex(e["ids"][0], la, *e["pts"][0])
        b = vertex(e["ids"][-1], lb, *e["pts"][-1])
        E.append(dict(a=a, b=b, kind=e["kind"], pts=e["pts"], levels=e["levels"], short=e.get("short"), src=f"osm:way/{e['way']}", direction=escalator_direction(e) if e["kind"] == "escalator" else None))
    # Lift nodes (a single node tagged highway=elevator with level "-1;0"): one vertex per level, joined by lift edges.
    for nid, n in nodes.items():
        t = n["t"]
        if t.get("highway") != "elevator":
            continue
        lv = parse_levels(t.get("level"))
        here = [k for k in V if V[k]["osm"] == int(nid)]
        if not lv and edits.get("paths_by_layer") and len({V[k]["level"] for k in here}) >= 2:
            # A lift without a level tag that joins paths on different levels: it serves those levels.
            lv = sorted({next(o for o, i in level_id.items() if i == V[k]["level"]) for k in here})
        if not lv or not set(lv) <= keep_levels:
            continue
        if len(here) < 2:
            continue
        for i in range(len(here)):
            for j in range(i + 1, len(here)):
                E.append(dict(a=here[i], b=here[j], kind="lift", pts=[(V[here[i]]["x"], V[here[i]]["y"]), (V[here[j]]["x"], V[here[j]]["y"])], levels=lv, src=f"osm:node/{nid}"))

    # ---- Snap loose ends: OSM often draws stairs and lifts a few metres short of the path or platform they serve,
    # and some lifts are a single node on no way at all. ----
    SNAP = 12

    def piece_at(x, y, level, tol=2.0):
        for ref, pieces in by_ref.items():
            if pieces[0]["level"] == level and any(dist_to_poly((x, y), p["poly"]) <= tol for p in pieces):
                return ref
        return None

    degree = Counter()
    for e in E:
        degree[e["a"]] += 1
        degree[e["b"]] += 1
    snaps = []  # (vertex, x, y, level, kind)
    for e in [e for e in E if e["kind"] != "walk"]:
        for end in (e["a"], e["b"]):
            if degree[end] == 1:
                snaps.append(end)
    # Dead-end footways that stop just short of a platform.
    for k, v in list(V.items()):
        if degree[k] == 1 and k not in snaps and piece_at(v["x"], v["y"], v["level"], tol=4.0):
            snaps.append(k)
    for nid, n in nodes.items():
        t = n["t"]
        if t.get("highway") != "elevator" or any(v["osm"] == int(nid) for v in V.values()):
            continue
        lv = parse_levels(t.get("level"))
        if not lv or len(lv) < 2 or not set(lv) <= keep_levels:
            continue
        x, y = xy(n["lat"], n["lon"])
        if not near((x, y)):
            continue
        ends = [vertex(int(nid), L, x, y) for L in lv]
        for i in range(len(ends) - 1):
            E.append(dict(a=ends[i], b=ends[i + 1], kind="lift", pts=[(x, y), (x, y)], levels=lv, src=f"osm:node/{nid}"))
        snaps.extend(ends)
    pending_platform_links = []
    for k in snaps:
        v = V[k]
        ref = piece_at(v["x"], v["y"], v["level"], tol=4.0)
        if ref:
            pending_platform_links.append((k, ref))
            continue
        best, bd = None, SNAP
        for k2, v2 in V.items():
            if k2 == k or v2["level"] != v["level"] or v2.get("type") == "platform":
                continue
            d = math.hypot(v2["x"] - v["x"], v2["y"] - v["y"])
            if d < bd and not any((e["a"] == k and e["b"] == k2) or (e["b"] == k and e["a"] == k2) for e in E if e["kind"] != "walk"):
                best, bd = k2, d
        if best:
            E.append(dict(a=k, b=best, kind="walk", pts=[(v["x"], v["y"]), (V[best]["x"], V[best]["y"])], src=f"derived:gap of {bd:.0f} m closed between {v['src']} and {V[best]['src']}"))

    # ---- Platforms in the graph: a node in the middle of each, joined to the paths that touch it ----
    out_platforms, extra_nodes = [], []
    for ref, pieces in sorted(by_ref.items(), key=lambda kv: (len(kv[0]), kv[0])):
        pid = "p" + re.sub(r"[^0-9a-z]+", "_", ref.lower())
        allpts = [q for p in pieces for q in p["poly"]]
        # Middle of the platform: the point of the outline nearest the centroid, nudged inside.
        cx = sum(q[0] for q in allpts) / len(allpts)
        cy = sum(q[1] for q in allpts) / len(allpts)
        level = pieces[0]["level"]
        node_id = f"{pid}_mid"
        piece_src = ",".join(f"osm:way/{p['wid']}" for p in pieces)
        V[node_id] = dict(id=node_id, x=round(cx, 2), y=round(cy, 2), level=level, osm=None, type="platform", platform=pid, src=f"derived:middle of {piece_src}")
        access = [k for k, v in V.items() if v["level"] == level and v.get("type") != "platform" and any(dist_to_poly((v["x"], v["y"]), p["poly"]) <= 1.5 for p in pieces)]
        access += [k for k, r in pending_platform_links if r == ref and k not in access]
        for k in access:
            V[k]["type"] = V[k].get("type") or "platform_access"
            V[k]["platform"] = pid
            E.append(dict(a=node_id, b=k, kind="walk", pts=[(cx, cy), (V[k]["x"], V[k]["y"])], src=f"derived:along the platform ({piece_src})"))
        out_platforms.append(dict(id=pid, ref=ref, tracks=sorted({t for p in pieces for t in p["tracks"]}), level=level, geometry=[simplify(p["poly"], 0.5) for p in pieces], node=node_id, edges=platform_edges(ref, pieces), _source=piece_src))
    # Two halves of an island platform: a short walk across.
    for i, a in enumerate(out_platforms):
        for b in out_platforms[i + 1 :]:
            if a["level"] != b["level"]:
                continue
            close = min(dist_to_poly(q, pb) for pa in a["geometry"] for q in pa for pb in b["geometry"])
            if close <= 1.5:
                # At least the walk between the two platform nodes: halves of different lengths (a short bay beside a
                # long platform) can have their middles 100 m or more apart.
                na, nb = V[a["node"]], V[b["node"]]
                d = math.hypot(na["x"] - nb["x"], na["y"] - nb["y"])
                E.append(dict(a=a["node"], b=b["node"], kind="walk", pts=None, seconds=max(PLATFORM_CROSS_SECONDS, round(d / WALK_SPEED)), meters=max(6, round(d, 1)), island=True, src=f"derived:island platform halves {a['_source']} and {b['_source']}"))

    # ---- Entrances ----
    for nid, n in nodes.items():
        t = n["t"]
        if nid in edits.get("drop_entrances", []):
            continue
        if t.get("railway") == "train_station_entrance" or t.get("entrance") in ("main", "yes", "entrance"):
            for k, v in V.items():
                if v["osm"] == int(nid):
                    v["type"] = "entrance"
                    if t.get("name"):
                        v["name"] = t["name"]

    # ---- Hand edits: extra connections, nearest vertex on a level ----
    def nearest(x, y, level, exclude=()):
        best, bd = None, float("inf")
        for k, v in V.items():
            if v["level"] != level or k in exclude:
                continue
            d = math.hypot(v["x"] - x, v["y"] - y)
            if d < bd:
                best, bd = k, d
        return best, bd

    def closest_on(poly, x, y):
        best, bd = None, float("inf")
        for i in range(len(poly)):
            ax, ay = poly[i - 1]
            bx, by = poly[i]
            dx, dy = bx - ax, by - ay
            L = dx * dx + dy * dy
            t = 0 if L == 0 else max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / L))
            q = (ax + t * dx, ay + t * dy)
            d = math.hypot(q[0] - x, q[1] - y)
            if d < bd:
                best, bd = q, d
        return best

    def endpoint(spec, i):
        """A node id, {"at": [x, y], "level": osm level} (nearest vertex), or {"platform": ref, "near": [x, y]}
        (a new access point on that platform's edge, walked to from the platform's middle)."""
        if isinstance(spec, str):
            return spec
        if "platform" in spec:
            pieces = by_ref[spec["platform"]]
            x, y = spec["near"]
            q = min((closest_on(p["poly"], x, y) for p in pieces), key=lambda q: math.hypot(q[0] - x, q[1] - y))
            pid = "p" + re.sub(r"[^0-9a-z]+", "_", spec["platform"].lower())
            k = f"manual{i}@{pieces[0]['level']}"
            V[k] = dict(id=k, x=round(q[0], 2), y=round(q[1], 2), level=pieces[0]["level"], osm=None, type="platform_access", platform=pid, src="manual:edits connections")
            mid = V[f"{pid}_mid"]
            E.append(dict(a=f"{pid}_mid", b=k, kind="walk", pts=[(mid["x"], mid["y"]), q], src="derived:along the platform to a hand-placed access point"))
            return k
        return nearest(*spec["at"], level_id[str(spec["level"])])[0]

    for i, c in enumerate(edits.get("connections", [])):
        a, b = endpoint(c["from"], f"{i}a"), endpoint(c["to"], f"{i}b")
        E.append(dict(a=a, b=b, kind=c.get("kind", "walk"), pts=None, seconds=c.get("seconds"), manual=True, note=c.get("note"), meters=c.get("meters"), src=c.get("_source") or f"manual:scripts/stations/{safe}.edits.json connections[{i}]" + (f" ({c['note']})" if c.get("note") else "")))

    # Entrances OSM doesn't tag (edits "entrances": [{"at": [x, y], "level": osm level, "name": …, "_source": …}]):
    # the nearest vertex on that level becomes an entrance.
    for spec in edits.get("entrances", []):
        k, d = nearest(*spec["at"], level_id[str(spec["level"])])
        if k is None:
            continue
        V[k]["type"] = "entrance"
        if spec.get("name"):
            V[k]["name"] = spec["name"]
        V[k]["src"] = spec.get("_source") or V[k].get("src")

    # ---- Keep the part of the graph the platforms are on ----
    adj = defaultdict(set)
    for e in E:
        adj[e["a"]].add(e["b"])
        adj[e["b"]].add(e["a"])
    # No tagged entrance (OSM often has none at mid-size stations): the walking network's loose ends away from the
    # platforms are where its footways leave the station area for the street, so they stand in as exits. That is read
    # off the geometry, not guessed: the source names the way and says what the point is.
    if not any(v.get("type") == "entrance" for v in V.values()):
        ends = 0
        for k, v in V.items():
            if v.get("type") in ("platform", "platform_access", "entrance") or len(adj[k]) != 1:
                continue
            if all(dist_to_poly((v["x"], v["y"]), pl["poly"]) >= 25 for pl in platforms):
                v["type"] = "entrance"
                v["src"] = (v.get("src") or "osm") + " (footway end: the path leaves the station area here; no entrance tagged in OSM)"
                ends += 1
        if ends:
            print(f"  ! no tagged entrance in OSM: {ends} footway end(s) away from the platforms stand in as exits")
    comp, seen = {}, set()
    for p in out_platforms:
        stack = [p["node"]]
        while stack:
            n = stack.pop()
            if n in seen:
                continue
            seen.add(n)
            comp[n] = p["node"]
            stack.extend(adj[n])
    if os.environ.get("STATION_DEBUG"):
        json.dump(dict(V=V, E=[dict(a=e["a"], b=e["b"], kind=e["kind"], pts=e["pts"]) for e in E], comp=comp, platforms=out_platforms, shapes=shapes), open(os.environ["STATION_DEBUG"], "w"))
    if not out_platforms:
        sys.exit(f"{name}: no numbered platforms in OSM; name them in the edits file's platform_refs (way id -> number)")
    main_start = max(out_platforms, key=lambda p: sum(1 for k in comp if comp[k] == comp.get(p["node"])))["node"]
    main = {k for k, c in comp.items() if c == comp[main_start]}
    for p in out_platforms:
        if p["node"] not in main:
            log.append(f"platform {p['ref']}: not connected to the main walking graph")

    # ---- Collapse plain pass-through vertices into edge geometry ----
    keep_types = {"platform", "platform_access", "entrance"}
    # Distinct neighbours, not edges: the same way drawn twice mustn't make a junction look like a pass-through point
    # (which lost real paths, differently from run to run).
    nbrs = defaultdict(set)
    for e in E:
        if e["a"] in main and e["b"] in main and e["a"] != e["b"]:
            nbrs[e["a"]].add(e["b"])
            nbrs[e["b"]].add(e["a"])
    deg = Counter({k: len(v) for k, v in nbrs.items()})
    special = {e["a"] for e in E if e["kind"] != "walk"} | {e["b"] for e in E if e["kind"] != "walk"}
    # A hand connection's ends stay nodes: joined to a dead end, the end has two neighbours and was folded into a
    # pass-through point, which dropped the connection.
    special |= {e["a"] for e in E if e.get("manual")} | {e["b"] for e in E if e.get("manual")}
    is_key = lambda k: deg[k] != 2 or V[k].get("type") in keep_types or k in special
    inc = defaultdict(list)
    for i, e in enumerate(E):
        if e["a"] in main and e["b"] in main:
            inc[e["a"]].append(i)
            inc[e["b"]].append(i)
    used, final_edges = set(), []

    def edge_pts(e, start):
        pts = e["pts"] or [(V[e["a"]]["x"], V[e["a"]]["y"]), (V[e["b"]]["x"], V[e["b"]]["y"])]
        return list(pts) if start == e["a"] else list(pts)[::-1]

    # Sorted, so the same OSM data always gives the same map.
    for k in sorted(k for k in main if is_key(k)):
        for ei in inc[k]:
            if ei in used:
                continue
            e = E[ei]
            if e["kind"] != "walk" or e.get("manual") or e.get("island"):
                used.add(ei)
                final_edges.append(e)
                continue
            # Walk along a chain of plain vertices.
            used.add(ei)
            pts = edge_pts(e, k)
            srcs = [e.get("src")]
            cur = e["b"] if e["a"] == k else e["a"]
            while not is_key(cur):
                nxt = [j for j in inc[cur] if j not in used and (E[j]["b"] if E[j]["a"] == cur else E[j]["a"]) != cur]
                if not nxt:
                    break
                used.add(nxt[0])
                f = E[nxt[0]]
                pts += edge_pts(f, cur)[1:]
                srcs.append(f.get("src"))
                cur = f["b"] if f["a"] == cur else f["a"]
            final_edges.append(dict(a=k, b=cur, kind="walk", pts=pts, src=",".join(sorted({x for x in srcs if x}))))

    # ---- Ids, seconds, output ----
    names = {}
    out_nodes = []
    for k in sorted(main, key=lambda k: (V[k]["level"], V[k].get("type") != "platform", k)):
        if not is_key(k):
            continue
        v = V[k]
        nid = v["id"] if v.get("type") == "platform" else f"n{len(out_nodes) + 1}"
        names[k] = nid
        node = dict(id=nid, type=v.get("type") or "junction", level=v["level"], x=round(v["x"], 1), y=round(v["y"], 1), _source=v.get("src") or "osm:node/?")
        if v.get("platform"):
            node["platform"] = v["platform"]
        if v.get("name"):
            node["name"] = v["name"]
        out_nodes.append(node)
    vertical_types = {"stairs": "stairs", "escalator": "escalator", "lift": "lift"}
    out_edges, seen_pairs = [], {}
    for e in final_edges:
        if e["a"] not in names or e["b"] not in names or e["a"] == e["b"]:
            continue
        pts = e["pts"] or [(V[e["a"]]["x"], V[e["a"]]["y"]), (V[e["b"]]["x"], V[e["b"]]["y"])]
        meters = e["meters"] if e.get("meters") is not None else polylen(pts)
        kind = e["kind"]
        if e.get("seconds"):
            secs = e["seconds"]
        elif kind == "walk":
            secs = meters / WALK_SPEED
        elif kind == "stairs" and e.get("short"):
            secs = meters / STAIRS_SPEED + 3  # a few steps at a door
        elif kind == "stairs":
            # A flight between two floors takes at least ~18 s, however short its drawn footprint.
            secs = max(meters / STAIRS_SPEED + 3, STAIRS_MIN_SECONDS)
        elif kind == "escalator":
            secs = max(meters / ESCALATOR_SPEED + 3, ESCALATOR_MIN_SECONDS)
        else:
            lv = e.get("levels") or []
            secs = LIFT_SECONDS + max(0, len(lv) - 2) * LIFT_PER_EXTRA_LEVEL
        key = (min(names[e["a"]], names[e["b"]]), max(names[e["a"]], names[e["b"]]), kind)
        # Two paths between the same two points (parallel corridors): keep the shorter.
        if key in seen_pairs and seen_pairs[key]["meters"] <= round(meters, 1):
            continue
        if key in seen_pairs:
            out_edges.remove(seen_pairs[key])
        edge = dict(**{"from": names[e["a"]], "to": names[e["b"]]}, seconds=max(1, round(secs)), step_free=kind in ("walk", "lift"), kind=kind, meters=round(meters, 1))
        g = simplify([(round(x, 1), round(y, 1)) for x, y in pts], 0.4)
        if len(g) > 2:
            edge["geometry"] = [list(p) for p in g]
        edge["source"] = "manual" if e.get("manual") else "osm"
        edge["_source"] = e.get("src") or ("manual:edits connections" if e.get("manual") else "osm:way/?")
        if e.get("direction"):
            edge["direction"] = e["direction"]
        out_edges.append(edge)
        seen_pairs[key] = edge
    # Mark the vertical ends.
    by_name = {n["id"]: n for n in out_nodes}
    for e in out_edges:
        if e["kind"] != "walk":
            for end in (e["from"], e["to"]):
                if by_name[end]["type"] == "junction":
                    by_name[end]["type"] = e["kind"]

    # ---- POIs ----
    pois = []
    drop_pois = set(edits.get("drop_pois", []))
    for src_id, obj in list(nodes.items()) + [(k, w) for k, w in ways.items() if w["nd"][0][0] == w["nd"][-1][0]]:
        t = obj["t"]
        cat = category(t)
        if not cat or not t.get("name") and cat not in ("toilet", "atm", "ticket", "locker", "info", "waiting"):
            continue
        outline = None
        if "lat" in obj:
            p = xy(obj["lat"], obj["lon"])
        else:
            cs = coords(obj)
            p = (sum(q[0] for q in cs) / len(cs), sum(q[1] for q in cs) / len(cs))
            # A shop mapped as its room: keep the room's outline, so the map can draw the shop's real shape.
            outline = [list(q) for q in simplify(cs, 0.4)]
        lv = parse_levels(t.get("level"))
        if lv is None:
            if not in_station(p):
                continue
            lv = [edits.get("default_level", "0")]
        if lv[0] not in keep_levels or not in_station(p):
            continue
        level = level_id[lv[0]]
        attach, d = nearest(p[0], p[1], level)
        if attach not in names:
            # Nearest vertex that survived simplification on this level.
            cands = [(math.hypot(n["x"] - p[0], n["y"] - p[1]), n["id"]) for n in out_nodes if n["level"] == level]
            if not cands:
                continue
            d, nid = min(cands)
        else:
            nid = names[attach]
        if d > 60:
            continue
        pid = f"osm{src_id}"
        if pid in drop_pois:
            continue
        fee = t.get("fee")
        icon = poi_icon(t)
        poi = dict(id=pid, category=cat, name=t.get("name") or "", level=level, x=round(p[0], 1), y=round(p[1], 1), node=nid, **({"icon": icon} if icon else {}),
                   opening_hours=t.get("opening_hours"), hours_source="osm" if t.get("opening_hours") else None, hours_verified=None, _source=f"osm:{'node' if 'lat' in obj else 'way'}/{src_id}")
        if fee in ("no",):
            poi["fee"] = "free"
        elif fee:
            m = re.search(r"(\d+)\s*(kr|SEK)", t.get("charge", "") or "")
            poi["fee"] = dict(amount=int(m.group(1)), currency="SEK") if m else None
        if outline and len(outline) >= 4:
            poi["outline"] = outline
        pois.append(poi)
    # A place mapped as a point inside a room (or a kiosk's own small building) takes that room's outline, when it's
    # the only place in there: a shared room's outline would claim the whole room for one of them.
    units = []
    for wid, w in ways.items():
        t = w["t"]
        if w["nd"][0][0] != w["nd"][-1][0] or not (t.get("indoor") in ("room", "area") or t.get("building") in ("kiosk", "retail", "yes")):
            continue
        if t.get("building") in ("train_station", "transportation") or t.get("railway") == "station" or t.get("public_transport"):
            continue
        cs = coords(w)
        a = abs(sum(cs[i - 1][0] * cs[i][1] - cs[i][0] * cs[i - 1][1] for i in range(len(cs)))) / 2
        if not 4 <= a <= (600 if t.get("indoor") else 150):
            continue
        lv = parse_levels(t.get("level"))
        if lv is None and t.get("indoor"):
            lv = [edits.get("default_level", "0")]
        units.append(dict(pts=cs, area=a, levels={level_id[x] for x in (lv or [edits.get("default_level", "0")]) if x in level_id}))
    for u in sorted(units, key=lambda u: u["area"]):
        inside = [q for q in pois if q["level"] in u["levels"] and pip((q["x"], q["y"]), u["pts"])]
        ring = [list(q) for q in simplify(u["pts"], 0.4)]
        if len(inside) == 1 and not inside[0].get("outline") and len(ring) >= 4:
            inside[0]["outline"] = ring
    # Hand-drawn outlines for places OSM maps only as points (a source's plan the owner cleared, or a survey).
    for o in edits.get("outlines", []):
        for q in pois:
            if q["id"] == o["poi"]:
                q["outline"] = o["points"]
    for p in edits.get("pois", []):
        p = dict(p)
        p["level"] = level_id[str(p["level"])]
        p.setdefault("_source", f"manual:scripts/stations/{safe}.edits.json pois (see the sources list)")
        # "attach": [x, y] joins the place to the walking graph there instead of at its pin (a shop inside a building
        # with no mapped paths, whose nearest node would otherwise be across a track).
        ax, ay = p.pop("attach", None) or (p["x"], p["y"])
        p["node"] = names.get(nearest(ax, ay, p["level"])[0]) or min(((math.hypot(n["x"] - ax, n["y"] - ay), n["id"]) for n in out_nodes if n["level"] == p["level"]))[1]
        pois = [q for q in pois if q["id"] != p["id"]] + [p]

    def level_out(l):
        o = dict(id=l["id"], name=l["name"], order=l["order"], _source=l.get("_source") or f"osm:level={l['osm']}")
        if "height_m" in l:
            o["height_m"] = l["height_m"]
            o["_source"] = l.get("height_source") or o["_source"]
        return o

    out = dict(
        schema=2,
        station_id=sid,
        name=name,
        updated=datetime.date.today().isoformat(),
        quality=edits.get("quality", "osm_draft"),
        sources=[dict(type="osm", license="ODbL", retrieved=osm["retrieved"], url="https://www.openstreetmap.org/copyright", note="via the Overpass API" if osm.get("source") == "overpass" else "from the Geofabrik/openstreetmap.fr extract")] + edits.get("sources", []),
        changelog=edits.get("changelog", []),
        coord_system="local_m",
        origin=dict(lat=lat0, lon=lon0),
        view=dict(rotation=edits.get("rotation", 0)),
        levels=[level_out(l) for l in edits["levels"]],
        shapes=[s for s in shapes if len(s["points"]) >= (2 if s["kind"] == "track" else 3)],
        platforms=[p for p in out_platforms if p["node"] in names],
        nodes=out_nodes,
        edges=out_edges,
        pois=sorted(pois, key=lambda p: (p["category"], p["name"])),
    )
    apply_structures(out["shapes"], edits, xy, level_id[edits.get("default_level", "0")])
    for s in out["shapes"]:
        s["points"] = [[round(x, 1), round(y, 1)] for x, y in s["points"]]
    for p in out["platforms"]:
        p["geometry"] = [[[round(x, 1), round(y, 1)] for x, y in g] for g in p["geometry"]]
        # Sectors ("2a", "2b") along one platform, from a line file (Trafikverket's BanInfo track lines): extra edges
        # with the sector's track, so a train announced at "2a" stands in that part (docs/STATION_3D_RESEARCH.md).
        for sec in edits.get("sector_edges", {}).get(p["ref"], []):
            feats = json.load(open(os.path.join(ROOT, sec["file"])))["features"]
            f = next((f for f in feats if f["properties"].get("track") == sec["feature_track"]), None)
            if f is None:
                raise SystemExit(f"sector_edges {p['ref']}: no track {sec['feature_track']} in {sec['file']}")
            pts = [[round(x, 1), round(y, 1)] for x, y in (xy(la, lo) for lo, la in f["geometry"]["coordinates"])]
            p.setdefault("edges", []).append(dict(track=sec["track"].lower(), points=pts, _source=sec["_source"], note="the sector's track line, not the platform edge itself"))
        if "height_m" in edits.get("platform_heights", {}).get(p["ref"], {}):
            p["height_m"] = edits["platform_heights"][p["ref"]]["height_m"]
            p["_source"] += f"; height from {edits['platform_heights'][p['ref']]['_source']}"
    if "terrain" in edits:
        out["terrain"] = terrain_grid(edits["terrain"], lat0, lon0, K, out)
    path = os.path.join(ROOT, f"data/stations/{safe}.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(out, open(path, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"{name}: {len(out['platforms'])} platforms, {len(out_nodes)} nodes, {len(out_edges)} edges, {len(pois)} amenities, {os.path.getsize(path) // 1024} KB")
    for line in log:
        print("  !", line)


def apply_structures(shapes, edits, xy, ground_level):
    """`structures` in the edits: buildings and roofs with measured heights (docs/STATION_3D_RESEARCH.md). Each names
    a feature of `structures_file` (a GeoJSON of outlines, e.g. the laser research's) by its OSM id ("w81576737",
    "r13095414") or, for an outline traced from the laser alone, its `kind` ("hall_roof_laser"); the heights are given
    in the edits, in metres above the platform surface (`top_m`, and `base_m` for the lowest ground at the outline).
    A structure whose OSM way the draft already drew as a building replaces that shape."""
    if not edits.get("structures"):
        return
    features = json.load(open(os.path.join(ROOT, edits["structures_file"])))["features"]
    for i, st in enumerate(edits["structures"]):
        f = next((f for f in features if f["properties"].get("osm_id") == st["from"] or (f["properties"].get("osm_id") is None and f["properties"].get("kind") == st["from"])), None)
        if f is None:
            raise SystemExit(f"structures[{i}]: no feature {st['from']} in {edits['structures_file']}")
        ring = f["geometry"]["coordinates"][0]
        # Outlines traced from 1 m laser cells come out stair-stepped: `simplify_m` smooths them (2 m keeps the shape).
        pts = simplify([xy(la, lo) for lo, la in ring], st.get("simplify_m", 0.5))
        osm = None
        if st["from"][:1] in ("w", "r") and st["from"][1:].isdigit():
            osm = f"osm:{'way' if st['from'][0] == 'w' else 'relation'}/{st['from'][1:]}"
        shape = dict(level=st.get("level", ground_level), kind=st["kind"], points=pts, _source=st["_source"])
        if st.get("name"):
            shape["name"] = st["name"]
        for k in ("top_m", "base_m"):
            if k in st:
                shape[k] = st[k]
        at = next((j for j, s in enumerate(shapes) if osm and s.get("_source") == osm), None)
        if at is None:
            shapes.append(shape)
        else:
            shapes[at] = shape


def sweref99tm(lat, lon):
    """WGS84 → SWEREF 99 TM (EPSG:3006), Lantmäteriet's Gauss–Krüger formulas."""
    a, f, lon0, k0, fe = 6378137.0, 1 / 298.257222101, 15.0, 0.9996, 500000.0
    e2, n = f * (2 - f), f / (2 - f)
    ah = a / (1 + n) * (1 + n * n / 4 + n ** 4 / 64)
    A, B = e2, (5 * e2 * e2 - e2 ** 3) / 6
    C, D = (104 * e2 ** 3 - 45 * e2 ** 4) / 120, 1237 * e2 ** 4 / 1260
    b = [n / 2 - 2 * n * n / 3 + 5 * n ** 3 / 16 + 41 * n ** 4 / 180, 13 * n * n / 48 - 3 * n ** 3 / 5 + 557 * n ** 4 / 1440,
         61 * n ** 3 / 240 - 103 * n ** 4 / 140, 49561 * n ** 4 / 161280]
    ph, dl = math.radians(lat), math.radians(lon - lon0)
    s = math.sin(ph)
    ps = ph - s * math.cos(ph) * (A + B * s * s + C * s ** 4 + D * s ** 6)
    xi, eta = math.atan(math.tan(ps) / math.cos(dl)), math.atanh(math.cos(ps) * math.sin(dl))
    N = k0 * ah * (xi + sum(b[i] * math.sin(2 * (i + 1) * xi) * math.cosh(2 * (i + 1) * eta) for i in range(4)))
    E = k0 * ah * (eta + sum(b[i] * math.cos(2 * (i + 1) * xi) * math.sinh(2 * (i + 1) * eta) for i in range(4))) + fe
    return E, N


def terrain_grid(spec, lat0, lon0, K, out):
    """`terrain` in the edits: the ground under the station as a coarse grid in the map's frame, heights in metres
    above the platform surface (`reference_m`, RH 2000), sampled bilinearly from a 1 m ground GeoTIFF in SWEREF 99 TM
    every `step_m` metres over the extent of the map's shapes and platforms. Cells off the GeoTIFF are null."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from terrain_preview import read_tiff
    w, h, grid, tags = read_tiff(os.path.join(ROOT, spec["geotiff"]), with_tags=True)
    sx, sy = tags[33550][0], tags[33550][1]
    tie = tags[33922]
    e0, n0 = tie[3] - tie[0] * sx, tie[4] + tie[1] * sy
    step = spec.get("step_m", 5)
    pts = [q for s in out["shapes"] for q in s["points"]] + [q for p in out["platforms"] for g in p["geometry"] for q in g]
    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
    pad = spec.get("pad_m", 20)
    x0, y0 = math.floor((min(xs) - pad) / step) * step, math.floor((min(ys) - pad) / step) * step
    cols, rows = int((max(xs) + pad - x0) // step) + 1, int((max(ys) + pad - y0) // step) + 1

    def sample(E, N):
        c, r = (E - e0) / sx - 0.5, (n0 - N) / sy - 0.5
        c0, r0 = math.floor(c), math.floor(r)
        if c0 < 0 or r0 < 0 or c0 + 1 >= w or r0 + 1 >= h:
            return None
        fc, fr = c - c0, r - r0
        v = [grid[r0][c0], grid[r0][c0 + 1], grid[r0 + 1][c0], grid[r0 + 1][c0 + 1]]
        if any(math.isnan(q) for q in v):
            return None
        return v[0] * (1 - fc) * (1 - fr) + v[1] * fc * (1 - fr) + v[2] * (1 - fc) * fr + v[3] * fc * fr

    heights = []
    for j in range(rows):
        row = []
        for i in range(cols):
            x, y = x0 + i * step, y0 + j * step
            # The map's frame back to WGS84 (the inverse of `xy` in main), then to SWEREF 99 TM.
            z = sample(*sweref99tm(lat0 - y / 111320, lon0 + x / K))
            row.append(None if z is None else round(z - spec["reference_m"], 2))
        heights.append(row)
    return dict(x0=x0, y0=y0, step=step, cols=cols, rows=rows, heights=heights, _source=spec["_source"])


if __name__ == "__main__":
    main()
