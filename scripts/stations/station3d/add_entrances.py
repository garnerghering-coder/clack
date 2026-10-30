"""Add the entrances the research located (`station_facts.json` entries with a `position`) to a station's edits.

Each becomes an edits `entrances` item at that point (the map's local metres, the drafter's frame) on the street level,
so the drafter turns the nearest walkway point into the entrance (owner, 2026-10-30: researched entrances first, at the
nearest walkway point, each sourced). Entries without a position are left to the research notes.
Usage: python3 scripts/stations/station3d/add_entrances.py 740000077
"""
import json
import math
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def main():
    sid = sys.argv[1]
    facts = json.load(open(os.path.join(ROOT, f"data/stations/research/{sid}/station_facts.json")))
    epath = os.path.join(ROOT, f"scripts/stations/{sid}.edits.json")
    e = json.load(open(epath))
    if "origin" in e:
        lat0, lon0 = e["origin"]["lat"], e["origin"]["lon"]
    else:
        db = sqlite3.connect(f"file:{os.path.join(ROOT, 'data/app.db')}?mode=ro", uri=True)
        lat0, lon0 = db.execute("select lat, lon from stations where id=?", (sid,)).fetchone()
    k = math.cos(math.radians(lat0)) * 111320
    level = e.get("default_level", "0")
    kept = [x for x in e.get("entrances", []) if "station_facts.json" not in x.get("_source", "")]
    added = []
    for en in facts.get("entrances", []):
        pos = en.get("position")
        if not isinstance(pos, dict) or pos.get("lat") is None:
            continue
        x, y = round((pos["lon"] - lon0) * k, 1), round(-(pos["lat"] - lat0) * 111320, 1)
        name = en.get("name") if en.get("name") not in (None, "None") else (f"Entrance ({en['street']})" if en.get("street") not in (None, "None") else "Entrance")
        src = f"{en.get('_source') or 'research'}; position {pos.get('how', '')} (data/stations/research/{sid}/station_facts.json)".strip()
        added.append({"at": [x, y], "level": level, "name": name, "_source": src})
    e["entrances"] = kept + added
    json.dump(e, open(epath, "w"), ensure_ascii=False, indent=2)
    open(epath, "a").write("\n")
    print(f"{sid}: {len(added)} entrances from the research")


if __name__ == "__main__":
    main()
