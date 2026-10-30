"""Put the research's amenities that the map doesn't have yet into a station's edits (`pois`, docs/STATION_3D_RESEARCH.md).

The research (`station_facts.json`) found amenities on the station owner's page, plans and OSM. Those it matched to the
map's own (`app_poi`) already carry their hours (facts_to_edits.py); this adds the rest (owner, 2026-10-30):
- with a position (an OSM node: exact; the representative point of an OSM building: `approximate`), at that point;
- described only ("in the station building", "by entrance A"): at the named entrance, or at the station building's
  middle when the description puts it in the building or hall; `approximate`, with the description as `where`;
- too vague to place (no building or entrance named), not a place the app shows (parking, Wi-Fi, the hall itself), or
  already on the map under the same name: left in the research files.
Hours go in only when read on a dated source and parseable later (check_hours.ts runs on `pois` too).

Usage: python3 scripts/stations/station3d/research_pois.py 740000140
"""
import hashlib
import json
import math
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
TAG = "research pass 2026-10-30"

CATEGORY = {
    "toilets": "toilet", "toilet": "toilet",
    "cafe": "cafe", "bakery": "cafe", "confectionery": "cafe", "coffee": "cafe",
    "restaurant": "restaurant", "fast_food": "restaurant", "pub": "restaurant", "bar": "restaurant", "ice_cream": "restaurant", "food_court": "restaurant",
    "kiosk": "kiosk", "convenience": "kiosk", "newsagent": "kiosk",
    "ticket_office": "ticket", "shop=ticket": "ticket", "ticket_machine": "ticket", "ticket": "ticket",
    "luggage_locker": "locker", "lockers": "locker", "left_luggage": "locker", "locker": "locker",
    "waiting_room": "waiting", "lounge": "waiting",
    "atm": "atm", "bureau_de_change": "atm", "bank": "atm",
    "pharmacy": "pharmacy", "chemist": "pharmacy",
    "taxi": "taxi", "bus_stop": "bus", "bus_station": "bus",
    "lost_property": "info", "information": "info",
    "clothes": "shop", "hairdresser": "shop", "books": "shop", "supermarket": "shop", "shop": "shop", "electronics": "shop",
    "car_rental": "shop", "florist": "shop", "gift": "shop", "optician": "shop", "shoes": "shop", "cosmetics": "shop", "jewelry": "shop",
}
IN_BUILDING = re.compile(r"\b(station building|stationshus|stationsbyggnad|station hall|main hall|in the hall|vänthall|waiting room|centralhall|resecentrum|travel cent(re|er)|in the station)\b", re.I)


def norm(s):
    return re.sub(r"[^a-z0-9åäöæøé]", "", (s or "").lower())


def main():
    sid = sys.argv[1]
    facts = json.load(open(os.path.join(ROOT, f"data/stations/research/{sid}/station_facts.json")))
    m = json.load(open(os.path.join(ROOT, f"data/stations/{sid}.json")))
    epath = os.path.join(ROOT, f"scripts/stations/{sid}.edits.json")
    e = json.load(open(epath))
    if "origin" in e:
        lat0, lon0 = e["origin"]["lat"], e["origin"]["lon"]
    else:
        db = sqlite3.connect(f"file:{os.path.join(ROOT, 'data/app.db')}?mode=ro", uri=True)
        lat0, lon0 = db.execute("select lat, lon from stations where id=?", (sid,)).fetchone()
    k = math.cos(math.radians(lat0)) * 111320
    to_xy = lambda lat, lon: (round((lon - lon0) * k, 1), round(-(lat - lat0) * 111320, 1))
    # Only levels the map has walkways on (a place is joined to the nearest walkway point on its level).
    with_nodes = {n["level"] for n in m["nodes"]}
    keep_levels = {str(l["osm"]) for l in e["levels"] if l["id"] in with_nodes}
    ground = e.get("default_level", "0")

    # The map's own places, not the ones an earlier run of this script added (so a re-run gives the same result).
    own = [p for p in m["pois"] if TAG not in (p.get("_source") or "")]
    have = {(norm(p["name"]), p["category"]) for p in own} | {(norm(p["name"]), None) for p in own if p["name"]}
    # The station building: the largest building outline that isn't a neighbour, on the ground level.
    def area(pts):
        return abs(sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))) / 2
    station = [s for s in m["shapes"] if s["kind"] in ("building", "hall") and not (s.get("name") or "").startswith("Neighbour") and len(s["points"]) >= 3]
    hall = max(station, key=lambda s: area(s["points"]), default=None)
    hall_pt = (round(sum(p[0] for p in hall["points"]) / len(hall["points"]), 1), round(sum(p[1] for p in hall["points"]) / len(hall["points"]), 1)) if hall else None
    entrances = [(n.get("name") or "", n["x"], n["y"]) for n in m["nodes"] if n["type"] == "entrance" and n.get("name")]

    out, seen, skipped = [], set(), {"no category": 0, "already on the map": 0, "too vague": 0}
    for a in facts.get("amenities", []):
        if a.get("app_poi"):
            continue
        cat = CATEGORY.get((a.get("category") or "").lower())
        if not cat:
            skipped["no category"] += 1
            continue
        name = a.get("name") or ""
        key = (norm(name), cat)
        if key in have or (norm(name), None) in have or key in seen:
            skipped["already on the map"] += 1
            continue
        pos, where = a.get("position"), a.get("where")
        level = str(a.get("osm_level")) if str(a.get("osm_level")) in keep_levels else ground
        approximate, desc = False, None
        if isinstance(pos, dict) and pos.get("lat") is not None:
            x, y = to_xy(pos["lat"], pos["lon"])
            if str(pos.get("osm_level")) in keep_levels:
                level = str(pos["osm_level"])
            approximate = not str(pos.get("how", "")).startswith("OSM node")
            how = pos.get("how", "")
        else:
            w = str(where or "")
            hit = next(((n, ex, ey) for n, ex, ey in entrances if n and norm(n) and norm(n) in norm(w)), None)
            if hit:
                x, y, how = hit[1], hit[2], f"at the entrance '{hit[0]}' the description names"
            elif IN_BUILDING.search(w) and hall_pt:
                x, y, how = hall_pt[0], hall_pt[1], "at the middle of the station building the description names"
            else:
                skipped["too vague"] += 1
                continue
            # Shown on the place's card: the description without the research's working notes (brackets, "; …").
            approximate, desc = True, re.sub(r"\s*\([^)]*\)?", "", w).split(";")[0].strip(" ,.") or None
        seen.add(key)
        pid = "res" + hashlib.sha1(f"{sid}|{name}|{cat}".encode()).hexdigest()[:10]
        poi = {"id": pid, "category": cat, "name": name, "level": level, "x": x, "y": y, "fee": None,
               "opening_hours": None, "hours_source": None, "hours_verified": None,
               "_source": f"{a.get('_source') or 'research'}; placed {how} ({TAG}, data/stations/research/{sid}/station_facts.json)"}
        if a.get("opening_hours") and a.get("hours_checked") and a.get("_source"):
            poi.update(opening_hours=a["opening_hours"], hours_source="website" if "website" in str(a.get("hours_source")) else "manual", hours_verified=a["hours_checked"])
        if approximate:
            poi["approximate"] = True
            if desc:
                poi["where"] = desc
        out.append(poi)
    e["pois"] = [p for p in e.get("pois", []) if TAG not in p.get("_source", "")] + out
    json.dump(e, open(epath, "w"), ensure_ascii=False, indent=2)
    open(epath, "a").write("\n")
    print(f"{sid} {m['name']}: {len(out)} added ({sum(1 for p in out if p.get('approximate'))} approximate); left out: {skipped}")


if __name__ == "__main__":
    main()
