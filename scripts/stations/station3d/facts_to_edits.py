"""Write the matched facts of a station's research (`station_facts.json`) into its edits file (playbook Part 2).

- `poi_hours`: opening hours for the amenities the research matched to the map's own (`app_poi`), when it read them
  from a dated source (the station owner's page): they replace OSM's hours, with the date checked.
- Level names: a level the map still calls "Level N" takes the name the research found for the same OSM level, without
  the research's own remarks in brackets ("(no signposted name found)"). Names a person wrote are left alone.

Hours that the app's parser can't read are dropped afterwards (scripts/stations/station3d/check_hours.ts).
Unmatched amenities, entrances and connections stay research notes: they come as descriptions, not positions.
Usage: python3 scripts/stations/station3d/facts_to_edits.py 740000170
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


def clean_name(n):
    n = re.sub(r"\s*\((?:[^()]*\b(?:signpost|not found|OSM|name not|no level)[^()]*)\)", "", n, flags=re.I).strip()
    return n


def main():
    sid = sys.argv[1]
    # --pack <folder> when the research folder isn't named by the app's id (Norway); files use "_" for ":".
    pack = sys.argv[sys.argv.index("--pack") + 1] if "--pack" in sys.argv else sid.replace(":", "_")
    safe = sid.replace(":", "_")
    facts = json.load(open(os.path.join(ROOT, f"data/stations/research/{pack}/station_facts.json")))
    m = json.load(open(os.path.join(ROOT, f"data/stations/{safe}.json")))
    epath = os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")
    e = json.load(open(epath))
    ids = {p["id"] for p in m["pois"]}
    hours = {}
    for a in facts.get("amenities", []):
        pid, oh = a.get("app_poi"), a.get("opening_hours")
        if pid in ids and oh and a.get("hours_checked") and a.get("_source") and "website" in (a.get("hours_source") or ""):
            hours[pid] = {"opening_hours": oh, "checked": a["hours_checked"], "_source": f"{a['_source']} (read {a['hours_checked']}; {a.get('hours_source')})"}
    e["poi_hours"] = hours
    renamed = []
    by_level = {str(l.get("osm_level")): l for l in facts.get("levels") or [] if l.get("osm_level") is not None and l.get("name")}
    for l in e.get("levels", []):
        if re.fullmatch(r"Level -?\d+", l.get("name", "")) and str(l.get("osm")) in by_level:
            f = by_level[str(l["osm"])]
            name = clean_name(f["name"])
            if name:
                l["name"] = name
                l["name_source"] = f.get("_source")
                renamed.append(f"{l['osm']}: {name}")
    json.dump(e, open(epath, "w"), ensure_ascii=False, indent=2)
    open(epath, "a").write("\n")
    print(f"{sid} {m['name']}: hours for {len(hours)} of {len(m['pois'])} amenities; levels named: {renamed or 'none'}")


if __name__ == "__main__":
    main()
