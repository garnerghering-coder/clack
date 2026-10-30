"""Number the OSM rail platforms that carry no `ref`, from Trafikverket's track lines (docs/STATION_3D_RESEARCH.md).

A `railway=platform` way in the station's OSM cache serves a track when the track's BanInfo line (the pack's
`<slug>_platform_trafikverket.geojson`) runs alongside it: at least 30 m of the line within 7 m of the platform's
outline. The platform's number is its tracks, "2" or "2–3" (lowest first). Written as the edits' `platform_refs`
(way id → number), each with the BanInfo objects as its source; ways already numbered in the edits are left alone.
BanInfo's track numbers were being re-issued on 2026-10-28…30 (the handoff): the source says so.

Usage: python3 scripts/stations/station3d/platform_refs.py 740000060 [--dry]
"""
import csv
import json
import math
import re
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def main():
    sid = sys.argv[1]
    dry = "--dry" in sys.argv
    # --override: also renumber platforms OSM numbers with something else than their track (Tampere: 0807–0810).
    override = "--override" in sys.argv
    pack = sys.argv[sys.argv.index("--pack") + 1] if "--pack" in sys.argv else sid.replace(":", "_")
    safe = sid.replace(":", "_")
    rdir = os.path.join(ROOT, f"data/stations/research/{pack}")
    slug = json.load(open(os.path.join(rdir, "_report.json")))["slug"]
    # The register's platform lines: Trafikverket, Digitraffic (vayla) or Bane NOR, whichever the pack has.
    lfile = next(f for f in (f"{slug}_platform_trafikverket.geojson", f"{slug}_platform_vayla.geojson", f"{slug}_platform_banenor.geojson", f"{slug}_platform_banedanmark.geojson") if os.path.exists(os.path.join(rdir, f)))
    register_name = {"trafikverket": "Trafikverket BanInfo (CC0)", "vayla": "Digitraffic infra-api platforms (CC BY 4.0)", "banenor": "Bane NOR's track table", "banedanmark": "Banedanmark Open Data (CC BY 4.0)"}[lfile.rsplit("_", 1)[1].split(".")[0]]
    lines = json.load(open(os.path.join(rdir, lfile)))["features"]
    osm = json.load(open(os.path.join(ROOT, f"data/cache/stations/{safe}-osm.json")))
    ways = {**osm["ways"], **osm.get("relation_ways", {})}
    lat0 = sum(c[1] for f in lines for c in f["geometry"]["coordinates"]) / sum(len(f["geometry"]["coordinates"]) for f in lines)
    kx, ky = 111320 * math.cos(math.radians(lat0)), 110574
    xy = lambda lat, lon: (lon * kx, lat * ky)

    def seg_dist(p, a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dy * dy
        t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)) if l2 else 0
        return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dy * t)

    def dist(p, poly):
        return min(seg_dist(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))

    # Which side of each track its platform lies on: the laser's compass side (station_facts.json), else BanInfo's SIDE
    # (1 = left of the line's direction, 2 = right).
    facts = json.load(open(os.path.join(rdir, "station_facts.json")))
    compass = {"north": (0, 1), "south": (0, -1), "east": (1, 0), "west": (-1, 0)}
    sides = {}
    for ps in facts.get("platform_sides", []):
        v = [0.0, 0.0]
        for part in (ps.get("side") or "").split("-"):
            c = compass.get(part.strip())
            if c:
                v[0] += c[0]
                v[1] += c[1]
        if v != [0.0, 0.0]:
            sides[str(ps.get("platform_bis"))] = v
    track_lines = []
    for f in lines:
        t = (f["properties"].get("track") or "").strip()
        if not t or "/" in t or not t[0].isdigit():
            continue
        pts = [xy(la, lo) for lo, la in f["geometry"]["coordinates"]]
        bis = str(f["properties"].get("bis_object"))
        side = sides.get(bis)
        if side is None and f["properties"].get("side") in ("1", "2") and len(pts) >= 2:
            dx, dy = pts[-1][0] - pts[0][0], pts[-1][1] - pts[0][1]
            side = (-dy, dx) if f["properties"]["side"] == "1" else (dy, -dx)
        track_lines.append((t, bis, pts, side))

    csv_file = {"trafikverket": "trafikverket_platforms_SE.csv", "vayla": "vayla_platforms_FI.csv", "banenor": "banenor_platforms_NO.csv", "banedanmark": "banedanmark_platforms_DK.csv"}[lfile.rsplit("_", 1)[1].split(".")[0]]
    pack_id = json.load(open(os.path.join(rdir, "_report.json"))).get("clack_id") or sid
    register = [r for r in csv.DictReader(open(os.path.join(ROOT, "data/stations/research", csv_file))) if r["clack_id"] in (sid, pack_id, pack)]
    epath = os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")
    e = json.load(open(epath))
    refs = e.get("platform_refs", {})
    src = e.setdefault("platform_refs_source", {})
    out = []
    for wid, w in ways.items():
        t = w["t"]
        if t.get("railway") != "platform" or (t.get("ref") and not override) or (str(wid) in refs and not override):
            continue
        poly = [xy(p[1], p[2]) for p in w["nd"]]
        if len(poly) < 3:
            continue
        served = {}
        cx, cy = sum(q[0] for q in poly) / len(poly), sum(q[1] for q in poly) / len(poly)
        for track, bis, pts, side in track_lines:
            # The platform must lie on the side of the track its platform is on.
            if side is not None:
                near_pt = min(pts, key=lambda q: math.hypot(q[0] - cx, q[1] - cy))
                if (cx - near_pt[0]) * side[0] + (cy - near_pt[1]) * side[1] <= 0:
                    continue
            # Sample the line every 2 m and count the metres within 7 m of the outline.
            near = 0.0
            for a, b in zip(pts, pts[1:]):
                n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) // 2))
                for k in range(n):
                    q = (a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n)
                    if dist(q, poly) <= 7:
                        near += math.hypot(b[0] - a[0], b[1] - a[1]) / n
            if near >= 30:
                base = "".join(ch for ch in track if ch.isdigit())
                served.setdefault(base, set()).add(str(bis))
        if not served:
            continue
        # The register lists every track a platform object serves (BanInfo draws one line per object): use its rows.
        bis_all = {b for v in served.values() for b in v}
        for r in register:
            if r["bis_object"] in bis_all:
                for n in re.findall(r"\d+", r["tracks"]):
                    served.setdefault(n, set()).add(r["bis_object"])
        tracks = sorted(served, key=int)
        nums = [int(t) for t in tracks]
        ref = tracks[0] if len(tracks) == 1 else (f"{tracks[0]}–{tracks[-1]}" if nums == list(range(nums[0], nums[-1] + 1)) else ", ".join(tracks))
        refs[str(wid)] = ref
        src[str(wid)] = (f"{register_name} platform objects {', '.join(sorted(bis_all))} run alongside osm:way/{wid}; tracks {', '.join(tracks)} from the register ({csv_file}) "
                         f"run alongside osm:way/{wid}, read 2026-10-30 (data/stations/research/{sid}); BanInfo's track numbers were being re-issued then: check on site")
        out.append(f"way {wid} → {ref}")
    if not dry:
        e["platform_refs"] = refs
        json.dump(e, open(epath, "w"), ensure_ascii=False, indent=2)
        open(epath, "a").write("\n")
    print(f"{sid}: {len(out)} platforms numbered: {', '.join(out) or 'none'}")


if __name__ == "__main__":
    main()
