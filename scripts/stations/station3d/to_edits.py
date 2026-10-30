"""Write a station's 3D research pack into its edits file (docs/STATION_3D_RESEARCH.md, Part 2; playbook step 10).

Reads data/stations/research/<id>/ (the pack: `_report.json`, `<slug>_structures_heights.geojson`, the ground GeoTIFF)
and data/stations/research/trafikverket_platforms_SE.csv, and sets in scripts/stations/<id>.edits.json:

- `platform_heights`: per platform of the current map, the register's class height for its track. Where several
  register rows list the track (a short low end, two platforms either side), the longest row is used and the others
  are named in the source. "ej norm" rows have no height and are skipped.
- `structures_file` + `structures`: OSM buildings (top and lowest ground), OSM and laser-traced canopies (top; drawn as
  roofs), footbridges (from the minimum clear height over electrified track, 5.9 m above the rail, TRVR Bro 11, to the
  measured roof), road bridges the same way. Left out, for a look first: `hall_roof_laser` (maybe a building) and the
  trains in the scan. `--surface` for a station whose platforms are in a tunnel: buildings, roofs and ground from the
  street level, no platform heights.
- `terrain`: the ground grid, heights above the station's platform surface.
- `sources` and `changelog` entries for the pass (replaced, not duplicated, on a re-run).

Then run the drafter and the validator. Usage: python3 scripts/stations/station3d/to_edits.py 740000170 | NSR:StopPlace:288 --pack NO-NTH [--surface]
"""
import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LM = "Laserdata Nedladdning, skog, © Lantmäteriet, bearbetad, CC BY 4.0"
# Per country: the platform register (file in data/stations/research/, how it's cited, its licence and link).
COUNTRY = {
    "SE": ("trafikverket_platforms_SE.csv", "Trafikverket register (CC0)", "trafikverket", "CC0", "http://geo-baninfo.trafikverket.se/mapservice/wms.axd/BanInfo_1_5"),
    "FI": ("vayla_platforms_FI.csv", "Digitraffic infra-api platforms (Fintraffic/Väylävirasto, CC BY 4.0)", "digitraffic", "CC BY 4.0", "https://rata.digitraffic.fi/infra-api/"),
    "NO": ("banenor_platforms_NO.csv", "Bane NOR's station page, track table (facts)", "banenor", None, "https://www.banenor.no/"),
    "DK": ("banedanmark_platforms_DK.csv", "Banedanmark Netredegørelse 2027, Bilag 3.6 (facts)", "banedanmark", None, "https://www.bane.dk/"),
}
# The laser credit, from the pack's README (each pack says which open laser it used).
LASERS = [
    ("Helsingin laserkeilausaineisto", "helsinki", "Helsingin laserkeilausaineisto 2021, © Helsingin kaupunki, CC BY 4.0", "https://hri.fi/"),
    ("Laserkeilausaineisto 0,5 p", "nls", "Laserkeilausaineisto 0,5 p, © Maanmittauslaitos, CC BY 4.0", "https://www.maanmittauslaitos.fi/"),
    ("Høydedata", "kartverket", "Høydedata, © Kartverket, CC BY 4.0", "https://hoydedata.no/"),
    ("Danmarks Højdemodel", "sdfi", "Danmarks Højdemodel, © Klimadatastyrelsen, CC BY 4.0", "https://dataforsyningen.dk/"),
]


def country_of(pack):
    return "FI" if pack.startswith("fi_") else "NO" if pack.startswith("NO-") else "DK" if pack.startswith(("860", "gtfs")) else "SE"


def laser_credit(rdir):
    text = open(os.path.join(ROOT, rdir, "README.md")).read() if os.path.exists(os.path.join(ROOT, rdir, "README.md")) else ""
    for key, kind, credit, url in LASERS:
        if key in text:
            return kind, credit, url
    return "lantmateriet", LM, "https://www.lantmateriet.se/sv/geodata/vara-produkter/produktlista/laserdata-nedladdning-skog/"
TAG = "3D research pass"
MIN_CLEAR_ABOVE_RAIL = 5.9


def track_numbers(tracks):
    out = set()
    for t in tracks.split(","):
        m = re.match(r"^\s*(\d+)[a-z]?\s*$", t.strip().lower())
        if m:
            out.add(m.group(1))
    return out


def main():
    sid = sys.argv[1]
    # --pack <folder>: the research folder when it isn't named by the app's id (Norway: NO-OSL_S for 760000100).
    pack = sys.argv[sys.argv.index("--pack") + 1] if "--pack" in sys.argv else sid.replace(":", "_")
    safe = sid.replace(":", "_")
    # --surface: the platforms are in a tunnel the laser can't see (Varberg C, Triangeln): heights are measured from the
    # street (the ground's median in the box), and the platforms get no height, so nothing raises them at the surface.
    surface = "--surface" in sys.argv[2:]
    rdir = f"data/stations/research/{pack}"
    cc = country_of(pack)
    reg_file, reg_name, reg_type, reg_licence, reg_url = COUNTRY[cc]
    laser_type, LM, laser_url = laser_credit(rdir)
    report = json.load(open(os.path.join(ROOT, rdir, "_report.json")))
    slug = report["slug"]
    level = report["ground"].get("median_m") if surface else report.get("platform_surface_m")
    if level is None:
        raise SystemExit(f"{sid}: the pack has no platform surface level (underground?): run with --surface for the buildings and ground only")
    scan = report["laser"].get("scan_date", "?")
    m = json.load(open(os.path.join(ROOT, f"data/stations/{safe}.json")))
    epath = os.path.join(ROOT, f"scripts/stations/{safe}.edits.json")
    e = json.load(open(epath))
    pack_id = report.get("clack_id") or sid
    rows = [r for r in csv.DictReader(open(os.path.join(ROOT, "data/stations/research", reg_file))) if r["clack_id"] in (sid, pack_id, pack)]

    # Platform heights.
    heights, notes = {}, []
    for p in ([] if surface else m["platforms"]):
        # The map's tracks as numbers: "2a" → 2, "spår 1" → 1, "2 & 3" → 2 and 3.
        want = {n for t in p["tracks"] for n in re.findall(r"\d+", t)}
        # Where the register numbers the tracks differently (Hyllie: signposted 1–4 = Trafikverket 71–74), the edits say.
        alias = e.get("register_tracks", {})
        if any(t in alias for t in want):
            want = {r for t in want for r in alias.get(t, [t])}
        cands = [r for r in rows if r["height_m"] and track_numbers(r["tracks"]) & want]
        if not cands:
            notes.append(f"platform {p['ref']}: no register row with a height")
            continue
        best = max(cands, key=lambda r: float(r["length_m"] or 0))
        others = [r for r in cands if r is not best and r["height_m"] != best["height_m"]]
        src = (f"{reg_name}, {best['source_row']}: tracks {best['tracks']}, class {best['height_class']} = "
               f"{best['height_m']} m above rail, {best['length_m'] or '?'} m long; a recorded design class, not a survey")
        if others:
            src += "; other rows for this track: " + "; ".join(f"{r['tracks']} {r['height_class']} {r['height_m']} m ({r['length_m'] or '?'} m, {r['source_row'].split(';')[0]})" for r in others)
            notes.append(f"platform {p['ref']}: several register rows ({best['height_m']} m used, the longest)")
        heights[p["ref"]] = {"height_m": float(best["height_m"]), "_source": src}

    # Structures.
    # Bridge decks the laser saw (class 17, the research's footbridge_decks.json): metres above the platform surface.
    dpath = os.path.join(ROOT, rdir, "footbridge_decks.json")
    decks = {b["osm_id"]: b["deck_above_platform_m"] for b in (json.load(open(dpath))["bridges"] if os.path.exists(dpath) else []) if b.get("deck_above_platform_m") is not None}
    gpath = f"{rdir}/{slug}_structures_heights.geojson"
    feats = json.load(open(os.path.join(ROOT, gpath)))["features"]
    rail_below = (sorted(h["height_m"] for h in heights.values())[len(heights) // 2] if heights else 0.55)
    structures, skipped = [], []
    for i, f in enumerate(feats):
        pr = f["properties"]
        kind, top, base = pr.get("kind"), pr.get("top_above_platform_m"), pr.get("base_above_platform_m")
        if surface or top is None:
            # From the absolute (RH 2000) values against this pass's reference level.
            rt = pr.get("roof_top_median_m") if pr.get("roof_top_median_m") is not None else pr.get("top_median_m")
            top = round(rt - level, 2) if rt is not None else None
            base = round(pr["ground_min_m"] - level, 2) if pr.get("ground_min_m") is not None else None
        if top is None:
            continue
        ref = pr.get("osm_id") or f"#{i}"
        name = pr.get("name") or kind
        ref_name = "the street (the ground's median; the platforms are in a tunnel)" if surface else "the platform surface"
        src = f"{pr.get('source', '')}; from {gpath} (metres above {ref_name}, {level} m RH 2000, laser {scan})"
        if kind == "building":
            structures.append({"from": ref, "kind": "building", "name": name, "top_m": round(top, 2), "base_m": round(base if base is not None else 0, 2), "_source": src})
        elif kind in ("canopy_osm", "canopy_laser"):
            st = {"from": ref, "kind": "roof", "name": name, "top_m": round(top, 2), "_source": src + "; underside not measured"}
            if kind == "canopy_laser":
                st["simplify_m"] = 2.0
            structures.append(st)
        elif kind in ("footbridge", "bridge"):
            # Road bridges too (owner, 2026-10-30); one whose deck is below the minimum clearance is the railway
            # passing over a road, and stays out.
            under = round(MIN_CLEAR_ABOVE_RAIL - rail_below, 2)
            deck = decks.get(pr.get("osm_id"))
            if deck is not None:
                # The deck is measured: it is the bridge's top (the road or walking surface); below the clearance it
                # is the railway passing over a road, and stays out.
                if deck <= under:
                    skipped.append(f"{name}: deck {deck} m is under the clearance (the railway passes over it)")
                    continue
                structures.append({"from": ref, "kind": "bridge", "name": name, "top_m": round(deck, 2), "base_m": under,
                                   "_source": src + f"; top = the deck the laser saw (class 17, footbridge_decks.json), {deck} m above the platform; underside drawn at the minimum clear height over an electrified railway, {MIN_CLEAR_ABOVE_RAIL} m above the rail (TRVR Bro 11): a lower bound"})
                continue
            if top - under < 1.0:
                skipped.append(f"{name}: roof {top} m is not above the minimum clearance")
                continue
            structures.append({"from": ref, "kind": "bridge", "name": name, "top_m": round(top, 2), "base_m": under,
                               "_source": src + f"; underside drawn at the minimum clear height over an electrified railway, {MIN_CLEAR_ABOVE_RAIL} m above the rail (TRVR Bro 11, Trafikverket publ. 2011:086): a lower bound, not measured"})
        elif kind != "train_in_scan":
            skipped.append(f"{name} ({kind}): left out until checked")

    e["platform_heights"] = heights
    e["structures_file"] = gpath
    e["structures"] = structures
    # The ground grid's projection (the pack's heightmap JSON says: SWEREF 99 TM, TM35FIN, GK25, UTM 32N).
    hm = os.path.join(ROOT, rdir, f"{slug}_ground_1m_heightmap.json")
    crs_text = json.load(open(hm)).get("crs", "EPSG:3006") if os.path.exists(hm) else "EPSG:3006"
    crs = int(re.search(r"EPSG:(\d+)", crs_text).group(1)) if re.search(r"EPSG:(\d+)", crs_text) else 3006
    datum = {"SE": "RH 2000", "FI": "N2000", "NO": "NN2000", "DK": "DVR90"}[cc]
    e["terrain"] = {"geotiff": f"{rdir}/{slug}_ground_1m.tif", "crs": crs, "reference_m": level, "step_m": 5,
                    "_source": f"ground from the laser's ground points, 1 m ({rdir}/{slug}_ground_1m.tif), sampled every 5 m; {LM}. Heights above {'the street' if surface else 'the platform surface'} ({level} m {datum}, laser {scan})"}
    e["sources"] = [s for s in e.get("sources", []) if TAG not in (s.get("note") or "")] + [
        {"type": laser_type, "license": "CC BY 4.0", "retrieved": "2026-10-30", "url": laser_url,
         "note": f"{LM}: building and roof heights and the ground ({TAG}; pack in {rdir})."},
        {"type": reg_type, **({"license": reg_licence} if reg_licence else {}), "retrieved": "2026-10-30", "url": reg_url,
         "note": f"{reg_name}: platform heights ({TAG}; data/stations/research/{reg_file})."},
    ]
    e["changelog"] = [c for c in e.get("changelog", []) if TAG not in c.get("what", "")] + [
        {"date": "2026-10-30", "who": "the owner's assistant", "what": f"Platform heights from {reg_name}; {len(structures)} buildings, roofs and footbridges with laser heights; the ground as a 5 m grid ({TAG}, {rdir})."}]
    json.dump(e, open(epath, "w"), ensure_ascii=False, indent=2)
    open(epath, "a").write("\n")
    print(f"{sid} {m['name']}: {len(heights)}/{len(m['platforms'])} platform heights, {len(structures)} structures, level {level} m")
    for n in notes + skipped:
        print("  -", n)


if __name__ == "__main__":
    main()
