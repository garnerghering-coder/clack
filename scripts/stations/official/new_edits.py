"""The minimal edits file for a station that has none yet (scripts/stations/<id>.edits.json), so the batch can draft
it: the OpenStreetMap levels people walk on there (from one cached Overpass request), named "Level N" until a plan or
signage names them, and the default level (Norway numbers the ground floor 1). Exits 0 when it wrote a file after a
new Overpass request (the batch then pauses), 3 when the file or the cache was already there, 1 on failure.

Usage: python3 scripts/stations/official/new_edits.py <station id>
"""
import datetime
import json
import os
import sys
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
sys.path.insert(0, os.path.join(ROOT, "scripts/stations"))
from draft_from_osm import WALK_HIGHWAYS, load_osm_overpass, open_db, parse_levels  # noqa: E402

RADIUS = 400


def main():
    sid = sys.argv[1]
    safe = sid.replace(":", "_")
    path = os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")
    if os.path.exists(path):
        sys.exit(3)
    row = open_db().execute("select name, lat, lon, country from stations where id=?", (sid,)).fetchone()
    if not row:
        print(f"{sid}: not in data/app.db")
        sys.exit(1)
    name, lat, lon, country = row
    cache = os.path.join(ROOT, f"data/cache/stations/{safe}-osm.json")
    fetched = not os.path.exists(cache)
    try:
        osm = load_osm_overpass(lat, lon, RADIUS, cache)
    except SystemExit as e:
        print(f"{sid}: Overpass failed ({e})")
        sys.exit(1)
    default = "1" if country == "NO" else "0"
    votes = Counter()
    for w in osm["ways"].values():
        t = w["t"]
        if t.get("highway") in WALK_HIGHWAYS or t.get("railway") == "platform" or t.get("indoor") == "corridor":
            for lv in parse_levels(t.get("level")) or [default]:
                votes[lv] += 1
    # A level counts when a few walkable things are on it (a stray tag is not a floor).
    levels = sorted((lv for lv, n in votes.items() if n >= 3 or lv == default), key=float)
    if default not in levels:
        levels.append(default)
        levels.sort(key=float)
    edits = dict(
        _comment=f"Hand edits on top of the OpenStreetMap draft of {name} (scripts/stations/draft_from_osm.py), made by scripts/stations/official/new_edits.py on {datetime.date.today().isoformat()}. Levels are the OSM levels with paths or platforms on them; their names are placeholders until a plan or signage names them. Register facts are in {safe}.official.json.",
        radius=RADIUS, paths_by_layer=True, path_radius=30, default_level=default,
        levels=[dict(osm=lv, id=f"L{lv}", name=f"Level {lv}", order=int(float(lv)) - int(default)) for lv in levels],
        sources=[dict(name="OpenStreetMap contributors, via Overpass (ODbL)", read=osm.get("retrieved") or datetime.date.today().isoformat())],
        changelog=[dict(date=datetime.date.today().isoformat(), who="batch", what="First draft from OSM and the registers (scripts/stations/official/batch.sh).")],
    )
    json.dump(edits, open(path, "w"), ensure_ascii=False, indent=2)
    open(path, "a").write("\n")
    print(f"{sid} {name}: edits with levels {', '.join(levels)}")
    sys.exit(0 if fetched else 3)


if __name__ == "__main__":
    main()
