"""Re-reads the opening hours of every station map's places from OpenStreetMap (weekly, .github/workflows/hours.yml).

For each map in data/stations, one Overpass request asks for the current `opening_hours` of the places whose hours
came from OSM (hours_source "osm", or none yet), by their OSM ids; requests are 10 s apart. A changed value is written
into the map with its source; the map's `hours_checked` becomes today. Hours a person checked (hours_source "website" or
"manual", with their `hours_verified` date) are left alone: they are re-checked by hand from the station owner's page.
The drafter keeps hours re-read here over its older OSM extract (draft_from_osm.py, "hours_checked").
Afterwards run `npm run stations:validate -- --coverage` (the workflow does) so the coverage follows.

Usage: python3 scripts/stations/hours_recheck.py [station ids...] [--dry]
"""
import datetime
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENDPOINTS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]
UA = "clack-hours-recheck (OpenStreetMap ODbL; one request per station, weekly)"
PAUSE_S = 10


def overpass(query):
    for url in ENDPOINTS:
        r = subprocess.run(["curl", "-sS", "--fail", "--max-time", "120", "-A", UA, "--data-urlencode", "data=" + query, url], capture_output=True, text=True)
        if r.returncode == 0:
            try:
                return json.loads(r.stdout)
            except ValueError:
                pass
    return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry" in sys.argv
    sdir = os.path.join(ROOT, "data/stations")
    files = sorted(f for f in os.listdir(sdir) if f.endswith(".json") and (not args or f[:-5] in {a.replace(":", "_") for a in args}))
    today = datetime.date.today().isoformat()
    changed_total = 0
    for i, f in enumerate(files):
        path = os.path.join(sdir, f)
        m = json.load(open(path))
        ids = {}
        for p in m["pois"]:
            if p.get("hours_source") not in (None, "osm"):
                continue
            hit = re.match(r"osm:(node|way)/(\d+)", p.get("_source") or "")
            if hit:
                ids[(hit.group(1), hit.group(2))] = p
        if not ids:
            continue
        if i:
            time.sleep(PAUSE_S)
        nodes = ",".join(k[1] for k in ids if k[0] == "node")
        ways = ",".join(k[1] for k in ids if k[0] == "way")
        q = "[out:json][timeout:60];(" + (f"node(id:{nodes});" if nodes else "") + (f"way(id:{ways});" if ways else "") + ");out tags;"
        data = overpass(q)
        if data is None:
            print(f"{m['name']}: Overpass did not answer; left as it was")
            continue
        now = {(e["type"], str(e["id"])): (e.get("tags") or {}).get("opening_hours") for e in data.get("elements", [])}
        changed = 0
        for key, p in ids.items():
            if key not in now:
                continue  # gone from OSM: the next redraft drops it; the hours are not guessed meanwhile
            new = now[key]
            if new != p.get("opening_hours"):
                p["opening_hours"] = new
                p["hours_source"] = "osm" if new else None
                changed += 1
        m["hours_checked"] = today
        changed_total += changed
        print(f"{m['name']}: {len(ids)} places re-read, {changed} hours changed")
        if not dry:
            json.dump(m, open(path, "w"), ensure_ascii=False, separators=(",", ":"))
    print(f"{changed_total} hours changed")


if __name__ == "__main__":
    main()
