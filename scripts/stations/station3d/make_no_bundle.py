"""Make a station bundle (the input of station_pack.py) for a Norwegian station.

python3 make_no_bundle.py <code e.g. OSL_S> <out bundle dir> <laz files...>

Inputs (read in the browser and saved as files, see HANDOFF):
  sources/NO/clack_no_banenor_stations.json  Bane NOR station pages: "Sportabell" (track table: track, platform length,
                                              height mm, width, comment "dekker spor X og Y") per station, Norwegian + English
  sources/NO/clack_no_osm_commons_nsr.json   OSM API 0.6 map call + Wikimedia Commons geosearch + Entur NSR quays
  sources/NO/clack_no_laser_projects.json    hoydedata.no project metadata (WFS Prosjektavgrensning)
  no_orders.json                              per station: the hoydedata.no project exported and the export polygon
Platform geometry: Bane NOR gives no coordinates, so each platform line is built here from open data, and says how:
  - the line is the OSM track centreline with railway:track_ref = the Bane NOR track number (OSM, ODbL);
  - its extent along the track is the OSM platform outline beside that track when there is one (projected onto the track);
    otherwise the Bane NOR platform length centred on the Entur NSR quay with that public code (the quay point is where the
    journey planner puts the platform, not a surveyed midpoint: flagged).
The terrain model is gridded here from the laser's own ground points (class 2), median per 1 m cell; cells without
ground points stay no-data (nothing is interpolated).
"""
import json, sys, os, re
import numpy as np, laspy
import xml.etree.ElementTree as ET
from pyproj import Transformer
from shapely.geometry import LineString, Point, Polygon, MultiLineString
from shapely.ops import linemerge, substring, unary_union

CODE, OUT = sys.argv[1], sys.argv[2]
LAZ = sys.argv[3:]
SRC = os.environ.get('NO_SOURCES', 'data/stations/research/_sources/NO')
ORD = json.load(open(os.environ.get('NO_ORDERS', 'data/stations/research/_sources/NO/no_orders.json')))[CODE]
EPSG = 25832
os.makedirs(OUT, exist_ok=True)
fw = Transformer.from_crs(4326, EPSG, always_xy=True).transform
bw = Transformer.from_crs(EPSG, 4326, always_xy=True).transform
E0, N0, E1, N1 = [int(v) for v in ORD['bbox32']]

# ---------------------------------------------------------------- laser: copy/clip and grid the ground
def grid_laser():
    global cls_all, tiles, dtm
    xs, ys, zs = [], [], []
    for f in LAZ:
        las = laspy.read(f)
        m = (las.x >= E0 - 5) & (las.x < E1 + 5) & (las.y >= N0 - 5) & (las.y < N1 + 5)
        if not m.any():
            continue
        tiles.append(os.path.basename(f))
        sub = laspy.LasData(las.header)
        sub.points = las.points[m]
        sub.write(f'{OUT}/{os.path.basename(f)}')
        for k, v in zip(*np.unique(np.asarray(las.classification[m]), return_counts=True)):
            cls_all[int(k)] = cls_all.get(int(k), 0) + int(v)
        g = m & (las.classification == 2)
        xs.append(np.asarray(las.x[g])); ys.append(np.asarray(las.y[g])); zs.append(np.asarray(las.z[g]))
    X, Y, Z = map(np.concatenate, (xs, ys, zs))
    W, H = E1 - E0, N1 - N0
    c = np.floor(X - E0).astype(int); r = np.floor(N1 - Y).astype(int)
    ok = (c >= 0) & (c < W) & (r >= 0) & (r < H)
    k = (r[ok] * W + c[ok]); z = Z[ok]
    o = np.lexsort((z, k)); k, z = k[o], z[o]
    uk, st, cnt = np.unique(k, return_index=True, return_counts=True)
    dtm = np.full(W * H, np.nan, 'float32'); dtm[uk] = z[st + cnt // 2]
    dtm.reshape(H, W).astype('<f4').tofile(f'{OUT}/dtm_window.f32')

tiles, cls_all = [], {}
dtm = np.array([np.nan])
if LAZ:
    grid_laser()


# ---------------------------------------------------------------- OSM, NSR, Commons
OC = json.load(open(f'{SRC}/clack_no_osm_commons_nsr.json'))
ST = OC[CODE]
json.dump(ST['osm'], open(f'{OUT}/osm.json', 'w'))
json.dump(ST['commons'], open(f'{OUT}/commons.json', 'w'))
root = ET.fromstring(ST['osm']['osm_api_xml'])
NODE = {n.get('id'): fw(float(n.get('lon')), float(n.get('lat'))) for n in root.iter('node')}
tg = lambda e: {t.get('k'): t.get('v') for t in e.findall('tag')}
rails, plats = {}, []
for w in root.iter('way'):
    t = tg(w)
    pts = [NODE[n.get('ref')] for n in w.findall('nd') if n.get('ref') in NODE]
    if len(pts) < 2:
        continue
    if t.get('railway') == 'rail' and t.get('railway:track_ref'):
        rails.setdefault(t['railway:track_ref'], []).append(LineString(pts))
    if (t.get('railway') == 'platform' or t.get('public_transport') == 'platform') and len(pts) >= 4 and pts[0] == pts[-1]:
        plats.append(('w' + w.get('id'), t, Polygon(pts)))
WAYPTS = {w.get('id'): [NODE[n.get('ref')] for n in w.findall('nd') if n.get('ref') in NODE] for w in root.iter('way')}
from shapely.ops import polygonize
for rel in root.iter('relation'):
    t = tg(rel)
    if t.get('type') == 'multipolygon' and (t.get('railway') == 'platform' or t.get('public_transport') == 'platform'):
        outers = [LineString(WAYPTS[m.get('ref')]) for m in rel.findall('member')
                  if m.get('type') == 'way' and m.get('role') in ('outer', '') and len(WAYPTS.get(m.get('ref')) or []) >= 2]
        polys = list(polygonize(unary_union(outers))) if outers else []
        if polys:
            plats.append(('r' + rel.get('id'), t, unary_union(polys)))
quays = [q for q in (ST['nsr'].get('quays') or next(iter(ST['nsr'].values()), {}).get('quays', []) if isinstance(ST['nsr'], dict) else [])]
if not quays:
    quays = json.load(open(os.environ.get('NO_STATIONS', 'data/stations/research/_sources/NO/no_stations.json')))[CODE]['quays']
centre = Point(fw(ST['lon'], ST['lat']))

# ---------------------------------------------------------------- Bane NOR track table
BN = json.load(open(f'{SRC}/clack_no_banenor_stations.json'))
bn = BN[CODE]
read = BN['_meta']['read'][:10]
NOTE_TAB = None
plat_rows = lambda t: [r for r in (t or [[]])[0][2:] if len(r) > 5 and r[5]]
if plat_rows(bn.get('tables')):
    tab, TAB_URL = bn['tables'][0], bn['url']      # the English page: same values as the Norwegian one except where it is newer (Ski)
    if [r[:8] for r in plat_rows(bn.get('tables'))] != [r[:8] for r in plat_rows(bn.get('tables_no'))] and plat_rows(bn.get('tables_no')):
        if any(r[5:8] != q[5:8] for r, q in zip(plat_rows(bn['tables']), plat_rows(bn['tables_no']))) or len(plat_rows(bn['tables'])) != len(plat_rows(bn['tables_no'])):
            NOTE_TAB = f"Bane NOR's English station page ({bn['url']}) and Norwegian page ({bn['url_no']}) give different track tables; the English one is used (it matches Entur's quays and the Bane NOR circulars)"
else:
    tab, TAB_URL = (bn.get('tables_no') or [[]])[0], bn['url_no']
num = lambda s: float(s.replace(',', '.')) if s and re.match(r'^[\d.,]+$', s) else None
digits = lambda s: re.sub(r'^[A-ZÆØÅa-zæøå]+', '', s or '')
plat, trk, flags, skipped = [], [], [], []
for row in tab[2:]:
    if len(row) < 9:
        continue
    nr, typ, tl, kl, fl, pl, ph, pb, note = row[:9]
    if not num(pl):
        continue
    if re.search(r'hensetting|serviceplattform|stabling|service platform', note or '', re.I):
        skipped.append(f'track {nr}: {pl} m, {ph} mm, "{note}" (not a passenger platform: left out of the register lines)')
        continue
    hs = [h for h in re.split(r'\s*/\s*', ph or '') if num(h)]
    m = re.search(r'dekker spor ([\w]+)(?: og (?:spor )?([\w]+))?', note or '', re.I) or re.search(r'between tracks ([\w]+)(?: and ([\w]+))?', note or '', re.I)
    covers = [x for x in (m.groups() if m else (nr,)) if x]
    lines = rails.get(nr) or rails.get(digits(nr))
    how = []
    if not lines:
        flags.append(f'Bane NOR platform at track {nr} ({pl} m, {ph} mm): no OSM track with railway:track_ref={nr} in the extract; not placed')
        continue
    u = unary_union(lines)
    mg = linemerge(u) if u.geom_type == 'MultiLineString' else u
    comps = list(mg.geoms) if mg.geom_type == 'MultiLineString' else [mg]
    qs = [q for q in quays if q.get('publicCode') in (nr, digits(nr))]
    qpts = [Point(fw(q['longitude'], q['latitude'])) for q in qs]
    ref_pt = min(qpts, key=lambda p: min(c_.distance(p) for c_ in comps)) if qpts else centre
    L = min(comps, key=lambda c_: c_.distance(ref_pt))
    if L.distance(ref_pt) > 60:
        flags.append(f'Bane NOR platform at track {nr}: the nearest OSM track {nr} is {L.distance(ref_pt):.0f} m from the NSR quay/station point; not placed')
        continue
    # OSM platform outline beside this track
    cand = []
    for oid, t, P in plats:
        refs = re.split(r'[;,/ ]+', t.get('ref') or t.get('railway:track_ref') or '')
        if P.distance(L) > 8:
            continue
        if refs != [''] and not (set(refs) & {nr, digits(nr)}):
            continue
        s = [L.project(Point(xy)) for xy in P.exterior.coords]
        if max(s) - min(s) < 20:
            continue
        cand.append((abs((max(s) - min(s)) - num(pl)), oid, min(s), max(s), t.get('ref')))
    if cand:
        cand.sort()
    if cand and not (0.5 <= (cand[0][3] - cand[0][2]) / num(pl) <= 2.0):
        flags.append(f'Platform at track {nr}: the nearest OSM platform outline ({cand[0][1]}) is {cand[0][3] - cand[0][2]:.0f} m along the track, Bane NOR gives {pl} m: not the same platform, placed by length instead')
        cand = []
    if cand:
        _, oid, s0, s1, oref = cand[0]
        if abs((s1 - s0) - num(pl)) > 0.25 * num(pl):
            flags.append(f'Platform at track {nr}: OSM outline {oid} runs {s1 - s0:.0f} m along the track, Bane NOR length {pl} m (the outline may include ramps or the part beyond the usable length); line drawn to the OSM outline')
        how = f'extent: OSM platform outline {oid}' + (f' (ref {oref})' if oref else '') + f', {s1 - s0:.0f} m along the track (Bane NOR: {pl} m)'
        osm_pl = oid
    else:
        sc = L.project(ref_pt)
        s0, s1 = max(sc - num(pl) / 2, 0), min(sc + num(pl) / 2, L.length)
        how = ('extent: Bane NOR length centred on the Entur NSR quay ' + qs[0]['id'] if qpts else 'extent: Bane NOR length centred on the station point (no NSR quay with this code)') + ' (no OSM platform outline beside the track)'
        osm_pl = None
        flags.append(f'Platform at track {nr}: no OSM platform outline beside OSM track {nr}; placed by length around ' + ('the NSR quay' if qpts else 'the station point') + ': ends uncertain')
    seg = substring(L, s0, s1)
    pts = [bw(x, y) for x, y in seg.coords]
    oid = f'{CODE}-{nr}'
    plat.append({'BisObjektNr': f'track {nr}', 'Points': ' '.join(f'{la:.7f} {lo:.7f}' for lo, la in pts),
                 'Höjd': hs[0] if hs else None, 'Höjd_beskr': (f'{ph} mm above top of rail (Bane NOR' + ('; two values: one per platform edge, the first taken for track ' + nr if len(hs) > 1 else '') + ')') if ph else None,
                 'x_height_mm_bane_nor': ph or None,
                 'Längd_m': num(pl), 'Bredd_m': num(pb), 'Väderskydd': None, 'SIDE': None, 'VALID_FROM': None,
                 'REFLINK_OID': oid, 'MEASURE_FROM': 0, 'MEASURE_TO': 1e9, 'Kmtal': None,
                 'x_platform_type': re.split(r'[;.]', note)[0].strip() if note else None, 'x_covers_tracks': covers, 'x_track_type': typ,
                 'x_track_length_m': num(tl), 'x_passing_loop_m': num(kl), 'x_comment': note, 'x_geometry': how, 'x_osm_platform': osm_pl,
                 'x_nsr_quays': [q['id'] for q in qs],
                 '_source': f"Bane NOR station page {TAB_URL} (track table), read {read}; geometry: {how}"})
    for tr_ in covers:
        trk.append({'REFLINK_OID': oid, 'IndKod': tr_, 'MEASURE_FROM': 0, 'MEASURE_TO': 1e9})

used = {p['x_osm_platform'] for p in plat}
allrail = unary_union([g for v in rails.values() for g in v]) if rails else None
for oid_, t_, P_ in plats:
    if oid_ in used or allrail is None or P_.distance(allrail) > 6 or P_.distance(centre) > 600 or P_.area < 200:
        continue
    if t_.get('railway') != 'platform' and t_.get('train') != 'yes':
        continue
    flags.append(f"OSM platform outline {oid_} (ref {t_.get('ref') or '-'}, {P_.area:.0f} m²) beside the tracks has no Bane NOR Sportabell row matched to it: check the table ({TAB_URL})")
slug = re.sub(r'[^a-z0-9]+', '_', ST['name'].lower().replace('ø', 'o').replace('æ', 'ae').replace('å', 'a')).strip('_')
LP = json.load(open(f'{SRC}/clack_no_laser_projects.json'))
proj = [p for p in LP['projects'][CODE] if p['name'] == ORD['project']][0]
d, mth, y = proj['last_flight'].split('.')
SCAN = f'{y}-{mth}-{d}' if proj['last_flight'] != f'01.01.{y}' else y
line = (f"Høydedata, project \"{proj['name']}\" (id {proj['id']}, {proj['catalogue']}, nominal {proj['density']} points/m², supplier {proj['supplier']}), "
        f"© Kartverket, CC BY 4.0, exported from hoydedata.no as LAZ (EPSG:25832, NN2000) clipped to the station box")
OBJ = [k for k in (1, 3, 4, 5, 6) if k in cls_all]
heights = {}
for p in plat:
    if p['Höjd'] and num(p['Höjd']):
        heights[p['Höjd'].lower()] = round(num(p['Höjd']) / 1000, 3)
meta = {
    'clack_id': 'NO-' + CODE, 'slug': slug, 'country': 'NO', 'lat': ST['lat'], 'lon': ST['lon'],
    'crs_epsg': EPSG, 'crs_name': 'ETRS89 / UTM 32N', 'vertical_datum': 'NN2000', 'box': [E0, N0, E1, N1],
    'height_classes': heights,
    'height_classes_source': f"Bane NOR Sportabell 'Høyde (mm)' per platform (height above top of rail), {TAB_URL}, read {read}",
    'platform_file_suffix': 'banenor',
    'platform_geometry_note': 'Bane NOR publishes no platform coordinates: the line is the OSM centreline of the platform track (railway:track_ref), cut to the OSM platform outline beside it, or to the Bane NOR length around the Entur NSR quay',
    'retrieved': read,
    'underground': 'all' if CODE == 'NTH' else None,
    'platform_from_unclassified': True,
    'dtm': {'items': [], 'from_laser': True, 'short_source': 'gridded from the laser ground class, © Kartverket, CC BY 4.0',
            'source_line': f'Gridded here from the ground points (class 2) of {line}: median per 1 m cell; cells without ground points left as no-data'},
    'laser': [{'id': f"hoydedata-{proj['id']}", 'datetime': SCAN, 'licence_line': line, 'object_classes': OBJ,
               'props': {'punkttathet': proj['density']}, 'url': 'https://hoydedata.no/LaserInnsyn2/'}],
    'baninfo': {'plat': plat, 'trk': trk},
    'build_flags': flags,
    'build_notes': skipped + ([NOTE_TAB] if NOTE_TAB else []),
    'doc_profile': {
        'brief': 'the Sweden brief, applied to Norway (sources swapped for the Norwegian equivalents)', 'vdatum': 'NN2000', 'crs': 'ETRS89 / UTM 32N (EPSG:25832)',
        'laser_line': line, 'scan_block': f"hoydedata.no project {proj['name']}",
        'box_note': ': the hoydedata.no export rectangle (platforms plus a margin)',
        'dtm_what': "Ground, 1 m, float32, EPSG:25832, NN2000, gridded here from the laser's ground points (class 2), median per 1 m cell; cells with no ground point (under buildings, trains, roofs) are no-data",
        'dtm_licence': line, 'ground_how': 'ground grid from the laser class 2 (see the GeoTIFF tags)',
        'register_short': 'Bane NOR', 'register_owner': 'Bane NOR',
        'register_file': f'{slug}_platform_banenor.geojson',
        'register_what': 'Bane NOR Sportabell platforms (track, length, height in mm, width, type) placed on the OSM track centreline, with the laser levels',
        'register_licence': 'facts from Bane NOR\'s station page (not open: facts only); line geometry © OpenStreetMap contributors, ODbL; NSR quays © Entur, NLOD',
        'register_text': f"Register: Bane NOR station page, track table ({TAB_URL}, read {read}): per track the platform length, height (mm above top of rail), width and type; "
                         "no coordinates, so each platform is drawn on the OSM track centreline (see `x_geometry` per feature). Heights are Bane NOR's per-platform values, not classes.",
        'id_label': 'Platform', 'object_points': 'non-ground (classes ' + ','.join(map(str, OBJ)) + ')',
        'osm_warning': 'The laser data is © Kartverket, CC BY 4.0: do not upload values derived from it to OpenStreetMap without Kartverket\'s permission for OSM.',
        'sources_md': f"- {line}. https://hoydedata.no/LaserInnsyn2/ (scan {{scan}}; {{points}} points in the box, {{density}} per m²; classes {{classes}}).\n"
                      f"- Ground grid: made here from the same laser (class 2), see `README.md`.\n"
                      f"- Bane NOR station page {TAB_URL} (track table, facts om stasjonen), read {read}: facts only.\n"
                      f"- Entur National Stop Register quays via journey-planner v3 (NLOD), read {OC['_read'][:10]}.",
    },
}
json.dump(meta, open(f'{OUT}/meta.json', 'w'), ensure_ascii=False, indent=1)
print(CODE, slug, 'platforms', len(plat), 'tiles', len(tiles), 'classes', cls_all, 'ground cells', int(np.isfinite(dtm).sum()), 'of', (E1 - E0) * (N1 - N0))
for f_ in flags:
    print('  FLAG', f_)
