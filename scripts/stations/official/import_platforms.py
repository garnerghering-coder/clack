"""Official platform facts for a station map, from the national registers: a sidecar the drafter reads before the
hand edits (scripts/stations/<id>.official.json). Nothing here is walked or guessed; every fact names its source.

What it writes, per station:
- `platform_edges`: which side of each platform each track runs along, from the register's per-track lines (Trafikverket
  BanInfo, CC0; Digitraffic/Väylä infra-api platforms, CC BY 4.0; Bane NOR's track table placed on OSM rails; Banedanmark
  Sporforløb, CC BY 4.0), as kept in the station's research pack (data/stations/research/<pack>/*_platform_*.geojson).
  A line serves a platform when at least 30 m of it runs within 7 m of the outline (the rule of
  station3d/platform_refs.py). Each side is a `near` point and the stretch of the line beside the platform, in the
  drafter's frame, so the drafter can name an OSM side or draw the side from the register when OSM has no rails there.
  Finland's `platform_side` (Väylä WFS) is not needed: the infra-api lines are one per track, so the geometry says
  which side.
- `extra_platforms` (Denmark): Banedanmark's platform outlines (FOR_PERRONER_OD, read from its ArcGIS service) that no
  OSM platform covers and that a register track runs along: København H's platforms OSM lacks. Banedanmark gave the
  owner permission to use them (2026-11-08).
- `sectors` (Norway): Entur's stop place register (NSR, NLOD) boarding positions, the lettered sectors, per quay (the
  quay's public code is its track), and `accessibility`: each quay's step-free and lift-free flags.

Usage: python3 scripts/stations/official/import_platforms.py <station id> [--no-fetch]
  --no-fetch  uses only what is cached under data/cache/stations/official/ (no Banedanmark or Entur request).
Requests: at most one to Banedanmark and one to Entur per station, cached; the client name says what it is.
"""
import json
import math
import os
import re
import subprocess
import sys
import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.join(ROOT, "scripts/stations"))
from draft_from_osm import dist_to_poly, open_db, simplify, polylen  # noqa: E402

RESEARCH = os.path.join(ROOT, "data/stations/research")
CACHE = os.path.join(ROOT, "data/cache/stations/official")
NEAR_M, ALONG_M = 7, 30
UA = "clack-station-maps (open data import; one request per station)"
REGISTERS = {
    "trafikverket": "Trafikverket BanInfo (CC0)",
    "vayla": "Digitraffic infra-api platforms (Väylävirasto, CC BY 4.0)",
    "banenor": "Bane NOR's track table, placed on OSM rails",
    "banedanmark": "Banedanmark Open Data Sporforløb (CC BY 4.0)",
}


def fetch_json(url, cache, headers=()):
    if os.path.exists(cache):
        return json.load(open(cache))
    if "--no-fetch" in sys.argv:
        return None
    cmd = ["curl", "-sS", "--fail", "--max-time", "60", "-A", UA]
    for h in headers:
        cmd += ["-H", h]
    r = subprocess.run(cmd + [url], capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ! {url}: {r.stderr.strip()[:120]}")
        return None
    data = json.loads(r.stdout)
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    json.dump(data, open(cache, "w"))
    return data


def pack_dir(safe):
    """The research pack for the station: the one its edits name, else the one named like it."""
    edits = open(os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")).read()
    for d in re.findall(r"research/([\w-]+)", edits) + [safe]:
        if os.path.isdir(os.path.join(RESEARCH, d)) and os.path.exists(os.path.join(RESEARCH, d, "_report.json")):
            return d
    return None


def frame(sid, edits):
    """The drafter's frame: the edits' origin, else the station's position; x east, y south, metres."""
    if "origin" in edits:
        lat0, lon0 = edits["origin"]["lat"], edits["origin"]["lon"]
    else:
        lat0, lon0 = open_db().execute("select lat, lon from stations where id=?", (sid,)).fetchone()
    K = math.cos(math.radians(lat0)) * 111320
    return lat0, lon0, K, (lambda la, lo: (round((lo - lon0) * K, 2), round(-(la - lat0) * 111320, 2)))


def metres_near(pts, poly):
    """How much of a polyline runs within NEAR_M of an outline, and that stretch's points (sampled every 2 m)."""
    near, run = 0.0, []
    for a, b in zip(pts, pts[1:]):
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(seg // 2))
        for k in range(n):
            q = (a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
            if dist_to_poly(q, poly) <= NEAR_M:
                near += seg / n
                run.append(q)
    return near, run


def osm_platforms(safe, edits, xy):
    osm = json.load(open(os.path.join(ROOT, f"data/cache/stations/{safe}-osm.json")))
    ways = {**osm["ways"], **osm.get("relation_ways", {})}
    out = []
    for wid, w in ways.items():
        t = w["t"]
        if t.get("railway") != "platform" and not (t.get("public_transport") == "platform" and t.get("train") == "yes"):
            continue
        if w["nd"][0][0] != w["nd"][-1][0] or len(w["nd"]) < 4:
            continue
        ref = edits.get("platform_refs", {}).get(wid) or t.get("local_ref") or t.get("ref")
        out.append(dict(wid=wid, ref=(ref or "").replace(";", "–"), poly=[xy(p[1], p[2]) for p in w["nd"]]))
    return out


def register_lines(pack, xy):
    files = [f for f in os.listdir(os.path.join(RESEARCH, pack)) if re.search(r"_platform_(trafikverket|vayla|banenor|banedanmark)\.geojson$", f)]
    if not files:
        return None, []
    kind = files[0].rsplit("_", 1)[1].split(".")[0]
    lines = []
    for f in json.load(open(os.path.join(RESEARCH, pack, files[0])))["features"]:
        p = f["properties"]
        for t in re.split(r"[,;]", str(p.get("track") or "")):
            t = t.strip().lower()
            # Tracks are numbers (with a sector letter at most): Stockholm C's "E6n" is a shunting track, not one a train
            # is boarded at.
            if re.fullmatch(r"\d+[a-z]?", t):
                lines.append(dict(track=t, pts=[xy(la, lo) for lo, la in f["geometry"]["coordinates"]], obj=str(p.get("bis_object")), oid=p.get("reflink_oid")))
    return kind, lines


def sides(platforms, lines, kind, pack):
    """For every platform with a number: the register tracks along it, a side each."""
    out = {}
    for pl in platforms:
        if not pl["ref"]:
            continue
        base = {re.sub(r"[a-z]+$", "", x.strip().lower()) for x in re.split(r"[–,;-]", pl["ref"]) if x.strip()}
        for ln in lines:
            if re.sub(r"[a-z]+$", "", ln["track"]) not in base:
                continue
            near, run = metres_near(ln["pts"], pl["poly"])
            if near < ALONG_M:
                continue
            mid = run[len(run) // 2]
            entry = dict(track=ln["track"], near=[round(mid[0], 1), round(mid[1], 1)], points=[[round(x, 1), round(y, 1)] for x, y in simplify(run, 0.5)],
                         _source=f"{REGISTERS[kind]} object {ln['obj']} (track {ln['track']}), {round(near)} m along the platform; data/stations/research/{pack}")
            have = out.setdefault(pl["ref"], [])
            # One side per track: the longest stretch.
            same = next((e for e in have if e["track"] == entry["track"]), None)
            if same is None:
                have.append(entry)
            elif polylen(entry["points"]) > polylen(same["points"]):
                have[have.index(same)] = entry
    return out


def dk_extra(sid, safe, edits, xy, lat0, lon0, K, platforms, lines, pack):
    """Banedanmark platform outlines no OSM platform covers, numbered by the register tracks along them."""
    r = edits.get("radius", 400)
    dlat, dlon = r / 111320, r / K
    url = ("https://services1.arcgis.com/QcgJt0vVxSaqMKl7/arcgis/rest/services/FOR_PERRONER_OD/FeatureServer/0/query?where=1%3D1"
           f"&geometry={lon0 - dlon},{lat0 - dlat},{lon0 + dlon},{lat0 + dlat}&geometryType=esriGeometryEnvelope&inSR=4326"
           "&spatialRel=esriSpatialRelIntersects&outFields=OBJECTID,BGV_NR,KOMMENTAR&outSR=4326&f=geojson")
    data = fetch_json(url, os.path.join(CACHE, f"{safe}-banedanmark-perroner.json"))
    if not data:
        return []
    served = {re.sub(r"[a-z]+$", "", x.strip().lower()) for p in platforms for x in re.split(r"[–,;-]", p["ref"]) if x.strip()}
    out = []
    for f in data.get("features", []):
        g = f.get("geometry") or {}
        rings = g.get("coordinates", [])
        if g.get("type") == "MultiPolygon":
            rings = [p[0] for p in rings]
        elif g.get("type") == "Polygon":
            rings = rings[:1]
        else:
            continue
        for ring in rings:
            poly = [xy(la, lo) for lo, la in ring]
            cx, cy = sum(q[0] for q in poly) / len(poly), sum(q[1] for q in poly) / len(poly)
            # Covered by OSM already: OSM's outline holds this one's middle, or lies within 2 m of it.
            if any(dist_to_poly((cx, cy), p["poly"]) <= 2 or pip_any((cx, cy), p["poly"]) for p in platforms):
                continue
            tracks = sorted({ln["track"] for ln in lines if metres_near(ln["pts"], poly)[0] >= ALONG_M}, key=lambda t: (int(re.sub(r"\D", "", t) or 0), t))
            # Only tracks no OSM platform serves: the two outlines of one platform are often a few metres apart.
            tracks = [t for t in tracks if re.sub(r"[a-z]+$", "", t) not in served]
            if not tracks:
                continue
            nums = [re.sub(r"[a-z]+$", "", t) for t in tracks]
            ref = nums[0] if len(set(nums)) == 1 else f"{nums[0]}–{nums[-1]}"
            p = f["properties"]
            out.append(dict(ref=ref, tracks=sorted(set(nums), key=int), points=[[round(x, 1), round(y, 1)] for x, y in simplify(poly, 0.5)],
                            _source=f"banedanmark:FOR_PERRONER_OD {p.get('BGV_NR') or p.get('OBJECTID')} (Banedanmark Open Data, used with Banedanmark's permission given to the owner 2026-11-08); tracks from {REGISTERS['banedanmark']} along it"))
    return out


def pip_any(pt, poly):
    from draft_from_osm import pip
    return pip(pt, poly)


def nsr(sid, safe, xy, platforms):
    """Entur's boarding positions (sectors) and accessibility per quay, for the station's NSR stop place."""
    no = json.load(open(os.path.join(RESEARCH, "_sources/NO/no_stations.json")))
    edits_text = open(os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")).read()
    m = re.search(r"research/NO-([A-ZÆØÅ_]+)", edits_text)
    code = m.group(1) if m else None
    entry = no.get(code) if code else None
    place = None
    if entry and entry.get("quays"):
        place = entry["quays"][0]["stopPlace"]["id"]
    elif sid.startswith("NSR:StopPlace:"):
        place = sid
    if not place:
        return {}, {}, None
    data = fetch_json(f"https://api.entur.io/stop-places/v1/read/stop-places/{place}", os.path.join(CACHE, f"{place.replace(':', '_')}.json"), headers=["ET-Client-Name: clack-station-maps"])
    if not data:
        return {}, {}, place
    sectors, access = {}, {}
    for q in (data.get("quays") or {}).get("quayRefOrQuay", []):
        track = str(q.get("publicCode") or "").strip().lower()
        if not track:
            continue
        lim = ((q.get("accessibilityAssessment") or {}).get("limitations") or {}).get("accessibilityLimitation") or {}
        if lim:
            access[track] = dict(step_free=lim.get("stepFreeAccess"), lift_free=lim.get("liftFreeAccess"), escalator_free=lim.get("escalatorFreeAccess"), wheelchair=lim.get("wheelchairAccess"),
                                 _source=f"entur:nsr {q.get('id')} (Entur stop place register, NLOD)")
        for bp in (q.get("boardingPositions") or {}).get("boardingPositionRefOrBoardingPosition", []):
            loc = ((bp.get("centroid") or {}).get("location")) or {}
            if not bp.get("publicCode") or "latitude" not in loc:
                continue
            x, y = xy(loc["latitude"], loc["longitude"])
            sectors.setdefault(track, []).append(dict(ref=bp["publicCode"], track=track, point=[round(x, 1), round(y, 1)], _source=f"entur:nsr {bp.get('id')} on {q.get('id')} (Entur stop place register, NLOD)"))
    return sectors, access, place


def main():
    sid = sys.argv[1]
    safe = sid.replace(":", "_")
    edits = json.load(open(os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")))
    lat0, lon0, K, xy = frame(sid, edits)
    pack = pack_dir(safe)
    platforms = osm_platforms(safe, edits, xy) if os.path.exists(os.path.join(ROOT, f"data/cache/stations/{safe}-osm.json")) else []
    kind, lines = register_lines(pack, xy) if pack else (None, [])
    out = dict(_comment="Written by scripts/stations/official/import_platforms.py; the drafter reads it before the hand edits, which win.",
               station_id=sid, retrieved=datetime.date.today().isoformat(), pack=pack, sources=[])
    if kind:
        out["sources"].append(dict(type={"trafikverket": "trafikverket", "vayla": "digitraffic", "banenor": "banenor", "banedanmark": "banedanmark"}[kind],
                                   license={"trafikverket": "CC0", "vayla": "CC BY 4.0", "banenor": None, "banedanmark": "CC BY 4.0"}[kind], note=REGISTERS[kind]))
        extra = dk_extra(sid, safe, edits, xy, lat0, lon0, K, platforms, lines, pack) if kind == "banedanmark" else []
        if extra:
            out["extra_platforms"] = extra
            out["sources"].append(dict(type="banedanmark", license="permission given to the owner, 2026-11-08", note="Banedanmark Open Data FOR_PERRONER_OD platform outlines", url="https://services1.arcgis.com/QcgJt0vVxSaqMKl7/arcgis/rest/services/FOR_PERRONER_OD/FeatureServer"))
        everything = platforms + [dict(wid=None, ref=e["ref"], poly=e["points"]) for e in extra]
        out["platform_edges"] = sides(everything, lines, kind, pack)
    if sid.startswith("76") or sid.startswith("NSR:"):
        sectors, access, place = nsr(sid, safe, xy, platforms)
        if sectors:
            out["sectors"] = sectors
        if access:
            out["accessibility"] = access
        if place:
            out["nsr_stop_place"] = place
            out["sources"].append(dict(type="entur", license="NLOD", note=f"Entur stop place register (NSR) {place}", url=f"https://api.entur.io/stop-places/v1/read/stop-places/{place}"))
    path = os.path.join(ROOT, f"scripts/stations/{safe}.official.json")
    json.dump(out, open(path, "w"), ensure_ascii=False, indent=1)
    open(path, "a").write("\n")
    n_sides = sum(len(v) for v in out.get("platform_edges", {}).values())
    print(f"{sid}: pack {pack or '–'}, {len(platforms)} OSM platforms, {len(lines)} register lines → {n_sides} sides on {len(out.get('platform_edges', {}))} platforms"
          + (f", {len(out['extra_platforms'])} platforms from Banedanmark" if out.get("extra_platforms") else "")
          + (f", sectors on tracks {', '.join(sorted(out['sectors']))}" if out.get("sectors") else ""))


if __name__ == "__main__":
    main()
