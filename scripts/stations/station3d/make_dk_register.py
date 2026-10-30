"""Danish platform register for the 27 stations: Bilag 3.6 rows placed on Banedanmark's open track and platform data.

python3 make_dk_register.py <out dir>
  writes <out>/banedanmark_platforms_DK.csv (columns of trafikverket_platforms_SE.csv) and
         <out>/dk_register/<safe id>.json (the per-station platform list in the shape station_pack.py takes as meta['baninfo'])

Inputs (sources/DK, read 2026-10-30):
  clack_dk_bilag_3_6_NS2027.pdf            Banedanmark Netredegørelse 2027, Bilag 3.6 "Perronlængder og -højder"
                                           (table dated 1 August 2023): TIB, station, perron no., track no., length m, height cm
  clack_dk_banedanmark_opendata.json        Banedanmark Open Data (CC BY 4.0): Sporforløb (track centrelines with SPORNUMMER),
                                           FOR_PERRONER_OD (platform outlines), Befæstede arealer (Perron/Trappe/Tunnel… surfaces)
How a Bilag row is placed:
  - track line: Sporforløb features with SPORNUMMER = the Bilag track number (or 'N.hsp', the line's main track N, where the
    station has no own track numbers, e.g. Nørreport), within 700 m of the station point, merged;
  - extent: the Banedanmark platform outline (FOR_PERRONER_OD, else Befæstede 'Perron') beside that track (≤ 6 m) projected
    onto it; width = outline area / that length. Without an outline: Bilag length centred on the track point nearest the
    station point, flagged.
Nothing is estimated beyond that; every placement says how in `x_geometry`.
"""
import json, sys, os, re, csv, subprocess
from shapely.geometry import shape, Point, LineString
from shapely.ops import unary_union, linemerge, substring, transform
from pyproj import Transformer

OUT = sys.argv[1] if len(sys.argv) > 1 else 'data/stations/research'
SRC = os.environ.get('DK_SOURCES', 'data/stations/research/_sources/DK')
ST = json.load(open(os.environ.get('DK_STATIONS', 'data/stations/research/_sources/DK/dk_stations.json')))
os.makedirs(f'{OUT}/dk_register', exist_ok=True)
fw = Transformer.from_crs(4326, 25832, always_xy=True).transform
bw = Transformer.from_crs(25832, 4326, always_xy=True).transform
P = lambda g: transform(fw, g)

# ---- Bilag 3.6
txt = subprocess.run(['pdftotext', '-layout', f'{SRC}/clack_dk_bilag_3_6_NS2027.pdf', '-'], capture_output=True, text=True).stdout
ROWS = []
for ln in txt.splitlines():
    m = re.match(r'^\s*(\d+)\s+(.+?)\s{2,}(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s*$', ln)
    if m:
        ROWS.append(dict(tib=m[1], station=m[2].strip(), perron=m[3], spor=m[4], length_m=int(m[5]), height_cm=int(m[6])))
BILAG = 'Banedanmark Netredegørelse 2027, Bilag 3.6 "Perronlængder og -højder" (table dated 1 August 2023), read 2026-10-30'

# ---- open data
B = json.load(open(f'{SRC}/clack_dk_banedanmark_opendata.json'))
READ = B['_meta']['read'][:10]
SP = [(P(shape(f['geometry'])), f['properties']) for f in B['Sporforloeb_OD']['features'] if f['geometry']]
FP = [(P(shape(f['geometry'])), f['properties'], 'FOR_PERRONER_OD') for f in B['FOR_PERRONER_OD']['features'] if f['geometry']]
BF = [(P(shape(f['geometry'])), f['properties'], 'Befaestede_arealer') for f in B['Befaestede_perron_etc']['features']
      if f['geometry'] and f['properties'].get('befaestet_formaal') == 'Perron']

EXTRA_FLAGS = {'860000858': ['New platforms at tracks 11/12 opened 27 April 2026 (Sund & Bælt, Transportministeriet; per the facts pass): not in Bilag 3.6 (table dated 1 August 2023), so not in this register'],
               '860000683': ['Station rebuilt Feb 2026–Sep 2027 (new footbridge opened 12 Oct 2026, Banedanmark): platform outlines may change'],
               '860000646': ['Underground (Boulevardbanen tunnel): the outlines and track lines are Banedanmark\'s; the laser will not see these platforms']}
cols = ['clack_id', 'station_name', 'bandel', 'tracks', 'bis_object', 'height_class', 'height_m', 'length_m', 'width_m', 'roof',
        'valid_from', 'source_row', 'remark']
csvrows = []
summary = {}
for s in ST:
    c = Point(fw(s['lon'], s['lat']))
    rows = [r for r in ROWS if r['station'] == s['bilag_name']]
    near_sp = [(g, pr) for g, pr in SP if g.distance(c) < 700]
    abbr = sorted({pr['STRKAFS_FORKORTELSE'] for g, pr in near_sp if pr.get('SPORNUMMER') and re.fullmatch(r'\d+', pr['SPORNUMMER'])})
    outl = [(g, pr, src) for g, pr, src in FP + BF if g.distance(c) < 800]
    plat, trk, flags = [], [], []
    by_perron = {}
    for r in rows:
        by_perron.setdefault((r['tib'], r['perron']), []).append(r)
    used_outline = {}
    for (tib, perron), rr in by_perron.items():
        # 1) the track line of each Bilag row
        lines = {}
        for r in rr:
            own = {pr['STRKAFS_FORKORTELSE'] for g, pr in near_sp if g.distance(c) < 250 and re.fullmatch(r'\d+[a-z]?', pr.get('SPORNUMMER') or '')}
            cand = [g for g, pr in near_sp if pr.get('SPORNUMMER') == r['spor'] and pr.get('STRKAFS_FORKORTELSE') in own]
            how_track = f"Sporforløb SPORNUMMER {r['spor']} (station {'/'.join(sorted(own))})"
            if not cand:
                cand = [g for g, pr in near_sp if pr.get('SPORNUMMER') == f"{r['spor']}.hsp"]
                how_track = f"Sporforløb SPORNUMMER {r['spor']}.hsp (line main track; the station has no own track {r['spor']})"
            if not cand:
                flags.append(f"Bilag row TIB {tib} perron {perron} track {r['spor']}: no Banedanmark track {r['spor']} within 700 m; not placed")
                csvrows.append(dict(clack_id=s['clack_id'], station_name=s['name'], bandel=tib, tracks=r['spor'], bis_object=f'perron {perron}',
                                    height_class=f"{r['height_cm']} cm", height_m=r['height_cm'] / 100, length_m=r['length_m'], width_m='', roof='',
                                    valid_from='', source_row=f"{BILAG}; TIB {tib}", remark='not placed: no matching track line'))
                continue
            u = unary_union(cand)
            mg = linemerge(u) if u.geom_type == 'MultiLineString' else u
            lines[r['spor']] = (list(mg.geoms) if mg.geom_type == 'MultiLineString' else [mg], how_track, r)
        if not lines:
            continue
        # 2) one platform outline for the whole perron: the one beside every track of the perron (an island has two), nearest
        def pick(pool):
            best = None
            for g, pr, src in pool:
                ds = []
                for comps, _, _ in lines.values():
                    ds.append(min(L.distance(g) for L in comps))
                if max(ds) < 6:
                    sc = (sum(ds), g.distance(c))
                    if best is None or sc < best[0]:
                        best = (sc, g, pr, src)
            return best
        best = pick([o for o in outl if o[2] == 'FOR_PERRONER_OD']) or pick([o for o in outl if o[2] != 'FOR_PERRONER_OD'])
        if best:
            oname = f"{best[3]} " + str(best[2].get('BGV_NR') or best[2].get('objectid'))
            if oname in used_outline:
                flags.append(f"Perron {perron} (TIB {tib}) and perron {used_outline[oname]} were matched to the same outline {oname}: track numbers repeat between lines here; check which outline is which")
            used_outline[oname] = f"{perron} (TIB {tib})"
        for spor, (comps, how_track, r) in lines.items():
            if best:
                g = best[1]
                L = min(comps, key=lambda q: q.distance(g))
                pts_ = list(g.exterior.coords) if g.geom_type == 'Polygon' else [p for gg in g.geoms for p in gg.exterior.coords]
                proj = [L.project(Point(xy)) for xy in pts_]
                s0, s1 = min(proj), max(proj)
                width = round(g.area / max(s1 - s0, 1), 1)
                how = f"track: {how_track}; extent: Banedanmark platform outline {oname} beside the track ({s1 - s0:.0f} m along it; Bilag {r['length_m']} m)"
                if abs((s1 - s0) - r['length_m']) > 0.3 * r['length_m']:
                    flags.append(f"Perron {perron} track {spor}: the outline {oname} runs {s1 - s0:.0f} m along the track, Bilag says {r['length_m']} m; line drawn to the outline")
                width_note = 'outline area / length along the track (an island outline gives the full island width)'
            else:
                L = min(comps, key=lambda q: q.distance(c))
                sc = L.project(c)
                s0, s1 = max(sc - r['length_m'] / 2, 0), min(sc + r['length_m'] / 2, L.length)
                width = None
                how = f"track: {how_track}; extent: no Banedanmark platform outline beside the track(s) of this perron: Bilag length centred on the track point nearest the station point"
                flags.append(f"Perron {perron} track {spor}: no Banedanmark platform outline beside the track; placed by length around the station point: ends uncertain")
                width_note = None
            seg = substring(L, s0, s1)
            pts = [bw(x, y) for x, y in seg.coords]
            oid = f"{s['safe']}-{tib}-{perron}-{spor}"
            plat.append({'BisObjektNr': f"perron {perron} / track {spor}", 'Points': ' '.join(f'{la:.7f} {lo:.7f}' for lo, la in pts),
                         'Höjd': str(r['height_cm']), 'Höjd_beskr': f"{r['height_cm']} cm above top of rail (Bilag 3.6)", 'Längd_m': r['length_m'],
                         'Bredd_m': width, 'Väderskydd': None, 'SIDE': None, 'VALID_FROM': None, 'REFLINK_OID': oid, 'MEASURE_FROM': 0, 'MEASURE_TO': 1e9,
                         'Kmtal': None, 'x_tib': tib, 'x_perron': perron, 'x_track': spor, 'x_perron_tracks': [x['spor'] for x in rr], 'x_geometry': how, 'x_width_note': width_note,
                         '_source': f"{BILAG}, TIB {tib}; geometry: Banedanmark Open Data (CC BY 4.0) read {READ}"})
            trk.append({'REFLINK_OID': oid, 'IndKod': spor, 'MEASURE_FROM': 0, 'MEASURE_TO': 1e9})
            csvrows.append(dict(clack_id=s['clack_id'], station_name=s['name'], bandel=tib, tracks=','.join(x['spor'] for x in rr), bis_object=f'perron {perron} / track {spor}',
                                height_class=f"{r['height_cm']} cm", height_m=r['height_cm'] / 100, length_m=r['length_m'], width_m=width or '', roof='',
                                valid_from='', source_row=f"{BILAG}; TIB {tib}", remark=how))
    flags += EXTRA_FLAGS.get(s['clack_id'], [])
    if not rows:
        flags.append(f"No Bilag 3.6 rows under the name '{s['bilag_name']}'")
    json.dump({'clack_id': s['clack_id'], 'name': s['name'], 'bilag_name': s['bilag_name'], 'station_abbr': abbr, 'plat': plat, 'trk': trk,
               'flags': flags, 'heights': {str(r['height_cm']): r['height_cm'] / 100 for r in rows}},
              open(f"{OUT}/dk_register/{s['safe']}.json", 'w'), ensure_ascii=False, indent=1)
    summary[s['name']] = (len(rows), len(plat), len(flags))
with open(f'{OUT}/banedanmark_platforms_DK.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, cols); w.writeheader(); w.writerows(csvrows)
for k, v in summary.items():
    print(f'{k:22s} bilag rows {v[0]:2d}  placed {v[1]:2d}  flags {v[2]}')
