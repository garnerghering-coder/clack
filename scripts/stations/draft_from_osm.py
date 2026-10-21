"""Draft a station map (data/stations/<id>.json, format in packages/shared/src/station.ts) from OpenStreetMap.

ADDITIONS_01 C1. Reads the Geofabrik extract offline (pyosmium; Overpass isn't needed), keeps the levels you name,
turns footways, steps, escalators and lifts into a walking graph, attaches platforms and amenities, and then applies
the hand edits in scripts/stations/<id>.edits.json (extra connections OSM is missing, level names, dropped
objects). Re-running the script keeps those edits, so the map can be refreshed from newer OSM data.

Usage: python3 scripts/stations/draft_from_osm.py 740000001 [--pbf data/cache/osm/sweden-latest.osm.pbf]
The OSM part of the output is ODbL (© OpenStreetMap contributors); see the Sources page.
A one-off data tool, like scripts/phase0/*.py; the app itself is TypeScript. (pip install osmium)
"""
import argparse
import datetime
import json
import math
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
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


def load_osm(pbf, lat0, lon0, radius, cache):
    if os.path.exists(cache):
        return json.load(open(cache))
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

    keys = ["railway", "public_transport", "highway", "indoor", "amenity", "shop", "building", "entrance", "level", "conveying", "tourism", "vending", "room", "office", "healthcare"]
    h = H()
    h.apply_file(pbf, locations=True, filters=[osmium.filter.KeyFilter(*keys)])
    out = dict(retrieved=datetime.date.fromtimestamp(os.path.getmtime(pbf)).isoformat(), nodes={str(k): v for k, v in h.nodes.items()}, ways={str(k): v for k, v in h.ways.items()})
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    json.dump(out, open(cache, "w"))
    return out


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
    edits = json.load(open(os.path.join(ROOT, f"scripts/stations/{sid}.edits.json")))
    db = sqlite3.connect(f"file:{os.path.join(ROOT, 'data/app.db')}?mode=ro", uri=True)
    name, lat0, lon0 = db.execute("select name, lat, lon from stations where id=?", (sid,)).fetchone()
    if "origin" in edits:
        lat0, lon0 = edits["origin"]["lat"], edits["origin"]["lon"]
    K = math.cos(math.radians(lat0)) * 111320
    xy = lambda la, lo: (round((lo - lon0) * K, 2), round(-(la - lat0) * 111320, 2))
    osm = load_osm(args.pbf, lat0, lon0, edits.get("radius", 400), os.path.join(ROOT, f"data/cache/stations/{sid}-osm.json"))
    nodes, ways = osm["nodes"], osm["ways"]
    keep_levels = {str(l["osm"]) for l in edits["levels"]}
    level_id = {str(l["osm"]): l["id"] for l in edits["levels"]}
    limit = edits.get("radius", 400)
    near = lambda p: math.hypot(*p) <= limit
    log = []

    def coords(w):
        return [xy(p[1], p[2]) for p in w["nd"]]

    # ---- Station buildings: shapes, and the area where untagged in-station paths count as ground level ----
    station_polys = []
    shapes = []
    for wid, w in ways.items():
        t = w["t"]
        if w["nd"][0][0] != w["nd"][-1][0]:
            continue
        p = coords(w)
        if not any(near(q) for q in p):
            continue
        if t.get("building") in ("train_station", "transportation") or t.get("railway") == "station" or (t.get("public_transport") == "station" and t.get("train") != "no"):
            station_polys.append(p)
            shapes.append(dict(level=edits.get("building_level", level_id["0"]), kind="building", points=simplify(p, 0.8)))
        lv = parse_levels(t.get("level"))
        if t.get("indoor") in ("room", "area", "corridor") and lv and lv[0] in keep_levels:
            kind = "shop" if (t.get("shop") or t.get("amenity") in ("cafe", "restaurant", "fast_food")) else ("hall" if t.get("indoor") == "area" else "room")
            s = dict(level=level_id[lv[0]], kind=kind, points=simplify(p, 0.5))
            if t.get("name"):
                s["name"] = t["name"]
            shapes.append(s)
    in_station = lambda p: any(pip(p, poly) for poly in station_polys)

    # ---- Platforms (one per track side; OSM maps island platforms as two halves with local_ref) ----
    platforms = []
    drop = set(edits.get("drop_platforms", []))
    for wid, w in ways.items():
        t = w["t"]
        if not (t.get("railway") == "platform" or (t.get("public_transport") == "platform" and t.get("train") == "yes")):
            continue
        lv = parse_levels(t.get("level")) or ["0"]
        if lv[0] not in keep_levels or t.get("subway") == "yes":
            continue
        ref = t.get("local_ref") or t.get("ref")
        if not ref or ref in drop:
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
        tracks = [x.strip().lower() for x in re.split(r"[;,]", ref) if x.strip()]
        platforms.append(dict(ref=ref.replace(";", "–"), tracks=tracks, level=level_id[lv[0]], poly=p))
    # Merge pieces with the same ref.
    by_ref = defaultdict(list)
    for p in platforms:
        by_ref[p["ref"]].append(p)

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
        if not walky or t.get("access") in ("private", "no"):
            continue
        pts = coords(w)
        if not any(near(q) for q in pts):
            continue
        lv = parse_levels(t.get("level"))
        vertical_way = hw in ("steps", "elevator") or bool(t.get("conveying"))
        if lv is None and vertical_way and t.get("level") is None:
            # Stairs without a level: worked out below from what their ends touch.
            untagged_vertical.append(dict(ids=[p[0] for p in w["nd"]], pts=pts, kind="lift" if hw == "elevator" else ("escalator" if t.get("conveying") else "stairs"), incline=t.get("incline")))
            continue
        if lv is None:
            # Untagged paths count only inside the station building (as ground level).
            if t.get("level") is not None or not in_station(pts[len(pts) // 2]):
                continue
            lv = ["0"]
        if not set(lv) <= keep_levels:
            continue
        if len(lv) == 1 and hw not in ("steps", "elevator") and not t.get("conveying"):
            for (nid, _, _) in w["nd"]:
                node_level_votes[nid][lv[0]] += 1
            g_edges.append(dict(ids=[p[0] for p in w["nd"]], pts=pts, kind="walk", levels=lv))
        else:
            kind = "lift" if hw == "elevator" else ("escalator" if t.get("conveying") else "stairs")
            vertical.append(dict(ids=[p[0] for p in w["nd"]], pts=pts, kind=kind, levels=lv, incline=t.get("incline")))

    # Platform outlines: a stair that shares a node with one starts or ends on that platform's level.
    platform_node_level = {}
    for wid, w in ways.items():
        t = w["t"]
        if t.get("railway") == "platform" or (t.get("public_transport") == "platform" and t.get("train") == "yes"):
            lv = parse_levels(t.get("level")) or ["0"]
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
        if la and not lb and (up or down):
            lb = step_level(la, 1 if up else -1)
        elif lb and not la and (up or down):
            la = step_level(lb, -1 if up else 1)
        if not la or not lb or la == lb:
            continue
        vertical.append(dict(ids=e["ids"], pts=e["pts"], kind=e["kind"], levels=sorted([la, lb], key=lambda k: order[k]), ends=(la, lb)))

    def level_of(nid, default):
        c = node_level_votes.get(nid)
        return c.most_common(1)[0][0] if c else default

    V = {}

    def vertex(nid, level, x, y):
        level = level_id[level]
        k = vid(nid, level)
        if k not in V:
            V[k] = dict(id=k, x=x, y=y, level=level, osm=nid)
        return k

    E = []
    for e in g_edges:
        L = e["levels"][0]
        for i in range(1, len(e["ids"])):
            a = vertex(e["ids"][i - 1], L, *e["pts"][i - 1])
            b = vertex(e["ids"][i], L, *e["pts"][i])
            E.append(dict(a=a, b=b, kind="walk", pts=[e["pts"][i - 1], e["pts"][i]]))
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
        E.append(dict(a=a, b=b, kind=e["kind"], pts=e["pts"], levels=e["levels"]))
    # Lift nodes (a single node tagged highway=elevator with level "-1;0"): one vertex per level, joined by lift edges.
    for nid, n in nodes.items():
        t = n["t"]
        if t.get("highway") != "elevator":
            continue
        lv = parse_levels(t.get("level"))
        if not lv or not set(lv) <= keep_levels:
            continue
        here = [k for k in V if V[k]["osm"] == int(nid)]
        if len(here) < 2:
            continue
        for i in range(len(here)):
            for j in range(i + 1, len(here)):
                E.append(dict(a=here[i], b=here[j], kind="lift", pts=[(V[here[i]]["x"], V[here[i]]["y"]), (V[here[j]]["x"], V[here[j]]["y"])], levels=lv))

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
            E.append(dict(a=ends[i], b=ends[i + 1], kind="lift", pts=[(x, y), (x, y)], levels=lv))
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
            E.append(dict(a=k, b=best, kind="walk", pts=[(v["x"], v["y"]), (V[best]["x"], V[best]["y"])]))

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
        V[node_id] = dict(id=node_id, x=round(cx, 2), y=round(cy, 2), level=level, osm=None, type="platform", platform=pid)
        access = [k for k, v in V.items() if v["level"] == level and v.get("type") != "platform" and any(dist_to_poly((v["x"], v["y"]), p["poly"]) <= 1.5 for p in pieces)]
        access += [k for k, r in pending_platform_links if r == ref and k not in access]
        for k in access:
            V[k]["type"] = V[k].get("type") or "platform_access"
            V[k]["platform"] = pid
            E.append(dict(a=node_id, b=k, kind="walk", pts=[(cx, cy), (V[k]["x"], V[k]["y"])]))
        out_platforms.append(dict(id=pid, ref=ref, tracks=sorted({t for p in pieces for t in p["tracks"]}), level=level, geometry=[simplify(p["poly"], 0.5) for p in pieces], node=node_id))
    # Two halves of an island platform: a short walk across.
    for i, a in enumerate(out_platforms):
        for b in out_platforms[i + 1 :]:
            if a["level"] != b["level"]:
                continue
            close = min(dist_to_poly(q, pb) for pa in a["geometry"] for q in pa for pb in b["geometry"])
            if close <= 1.5:
                E.append(dict(a=a["node"], b=b["node"], kind="walk", pts=None, seconds=PLATFORM_CROSS_SECONDS, meters=6, island=True))

    # ---- Entrances ----
    for nid, n in nodes.items():
        t = n["t"]
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
            V[k] = dict(id=k, x=round(q[0], 2), y=round(q[1], 2), level=pieces[0]["level"], osm=None, type="platform_access", platform=pid)
            mid = V[f"{pid}_mid"]
            E.append(dict(a=f"{pid}_mid", b=k, kind="walk", pts=[(mid["x"], mid["y"]), q]))
            return k
        return nearest(*spec["at"], level_id[str(spec["level"])])[0]

    for i, c in enumerate(edits.get("connections", [])):
        a, b = endpoint(c["from"], f"{i}a"), endpoint(c["to"], f"{i}b")
        E.append(dict(a=a, b=b, kind=c.get("kind", "walk"), pts=None, seconds=c.get("seconds"), manual=True, note=c.get("note"), meters=c.get("meters")))

    # ---- Keep the part of the graph the platforms are on ----
    adj = defaultdict(set)
    for e in E:
        adj[e["a"]].add(e["b"])
        adj[e["b"]].add(e["a"])
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
    main_start = max(out_platforms, key=lambda p: sum(1 for k in comp if comp[k] == comp.get(p["node"])))["node"]
    main = {k for k, c in comp.items() if c == comp[main_start]}
    for p in out_platforms:
        if p["node"] not in main:
            log.append(f"platform {p['ref']}: not connected to the main walking graph")

    # ---- Collapse plain pass-through vertices into edge geometry ----
    keep_types = {"platform", "platform_access", "entrance"}
    deg = Counter()
    for e in E:
        if e["a"] in main and e["b"] in main:
            deg[e["a"]] += 1
            deg[e["b"]] += 1
    special = {e["a"] for e in E if e["kind"] != "walk"} | {e["b"] for e in E if e["kind"] != "walk"}
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

    for k in [k for k in main if is_key(k)]:
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
            cur = e["b"] if e["a"] == k else e["a"]
            while not is_key(cur):
                nxt = [j for j in inc[cur] if j not in used]
                if not nxt:
                    break
                used.add(nxt[0])
                f = E[nxt[0]]
                pts += edge_pts(f, cur)[1:]
                cur = f["b"] if f["a"] == cur else f["a"]
            final_edges.append(dict(a=k, b=cur, kind="walk", pts=pts))

    # ---- Ids, seconds, output ----
    names = {}
    out_nodes = []
    for k in sorted(main, key=lambda k: (V[k]["level"], V[k].get("type") != "platform", k)):
        if not is_key(k):
            continue
        v = V[k]
        nid = v["id"] if v.get("type") == "platform" else f"n{len(out_nodes) + 1}"
        names[k] = nid
        node = dict(id=nid, type=v.get("type") or "junction", level=v["level"], x=round(v["x"], 1), y=round(v["y"], 1))
        if v.get("platform"):
            node["platform"] = v["platform"]
        if v.get("name"):
            node["name"] = v["name"]
        out_nodes.append(node)
    vertical_types = {"stairs": "stairs", "escalator": "escalator", "lift": "lift"}
    out_edges, seen_pairs = [], set()
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
        elif kind == "stairs":
            # A flight between two floors takes at least ~18 s, however short its drawn footprint.
            secs = max(meters / STAIRS_SPEED + 3, STAIRS_MIN_SECONDS)
        elif kind == "escalator":
            secs = max(meters / ESCALATOR_SPEED + 3, ESCALATOR_MIN_SECONDS)
        else:
            lv = e.get("levels") or []
            secs = LIFT_SECONDS + max(0, len(lv) - 2) * LIFT_PER_EXTRA_LEVEL
        key = (min(names[e["a"]], names[e["b"]]), max(names[e["a"]], names[e["b"]]), kind)
        if key in seen_pairs:
            continue
        seen_pairs.add(key)
        edge = dict(**{"from": names[e["a"]], "to": names[e["b"]]}, seconds=max(1, round(secs)), step_free=kind in ("walk", "lift"), kind=kind, meters=round(meters, 1))
        g = simplify([(round(x, 1), round(y, 1)) for x, y in pts], 0.4)
        if len(g) > 2:
            edge["geometry"] = [list(p) for p in g]
        edge["source"] = "manual" if e.get("manual") else "osm"
        out_edges.append(edge)
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
        if "lat" in obj:
            p = xy(obj["lat"], obj["lon"])
        else:
            cs = coords(obj)
            p = (sum(q[0] for q in cs) / len(cs), sum(q[1] for q in cs) / len(cs))
        lv = parse_levels(t.get("level"))
        if lv is None:
            if not in_station(p):
                continue
            lv = ["0"]
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
        poi = dict(id=pid, category=cat, name=t.get("name") or "", level=level, x=round(p[0], 1), y=round(p[1], 1), node=nid,
                   opening_hours=t.get("opening_hours"), hours_source="osm" if t.get("opening_hours") else None, hours_verified=None)
        if fee in ("no",):
            poi["fee"] = "free"
        elif fee:
            m = re.search(r"(\d+)\s*(kr|SEK)", t.get("charge", "") or "")
            poi["fee"] = dict(amount=int(m.group(1)), currency="SEK") if m else None
        pois.append(poi)
    for p in edits.get("pois", []):
        p = dict(p)
        p["level"] = level_id[str(p["level"])]
        p["node"] = names.get(nearest(p["x"], p["y"], p["level"])[0]) or min(((math.hypot(n["x"] - p["x"], n["y"] - p["y"]), n["id"]) for n in out_nodes if n["level"] == p["level"]))[1]
        pois = [q for q in pois if q["id"] != p["id"]] + [p]

    out = dict(
        station_id=sid,
        name=name,
        updated=datetime.date.today().isoformat(),
        quality=edits.get("quality", "osm_draft"),
        sources=[dict(type="osm", license="ODbL", retrieved=osm["retrieved"], url="https://www.openstreetmap.org/copyright")] + edits.get("sources", []),
        changelog=edits.get("changelog", []),
        coord_system="local_m",
        origin=dict(lat=lat0, lon=lon0),
        view=dict(rotation=edits.get("rotation", 0)),
        levels=[dict(id=l["id"], name=l["name"], order=l["order"]) for l in edits["levels"]],
        shapes=[s for s in shapes if len(s["points"]) >= 3],
        platforms=[p for p in out_platforms if p["node"] in names],
        nodes=out_nodes,
        edges=out_edges,
        pois=sorted(pois, key=lambda p: (p["category"], p["name"])),
    )
    for s in out["shapes"]:
        s["points"] = [[round(x, 1), round(y, 1)] for x, y in s["points"]]
    for p in out["platforms"]:
        p["geometry"] = [[[round(x, 1), round(y, 1)] for x, y in g] for g in p["geometry"]]
    path = os.path.join(ROOT, f"data/stations/{sid}.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(out, open(path, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"{name}: {len(out['platforms'])} platforms, {len(out_nodes)} nodes, {len(out_edges)} edges, {len(pois)} amenities, {os.path.getsize(path) // 1024} KB")
    for line in log:
        print("  !", line)


if __name__ == "__main__":
    main()
