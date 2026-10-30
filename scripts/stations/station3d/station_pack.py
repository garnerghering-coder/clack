"""Build one station's 3D research pack from the bundle the browser collected.

Usage: python3 station_pack.py <bundle dir (contains meta.json, osm.json, commons.json, dtm_window.f32, *.copc.laz)> <out dir>

Follows docs STATION_3D_RESEARCH.md (playbook) and the Sweden brief: heights are m RH 2000, outlines need a source
(OSM or a trace from the laser), airborne laser sees tops only, trains in the scan are not structures.
"""
import json, sys, os, math, glob, datetime
import numpy as np
import laspy
import rasterio
from rasterio.transform import from_origin
from PIL import Image
from pyproj import Transformer
import shapely
from shapely.geometry import shape, Polygon, MultiPolygon, LineString, Point, mapping, box
from shapely.ops import unary_union, transform as shp_transform
import warnings; warnings.filterwarnings('ignore')
from scipy import ndimage

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
meta = json.load(open(f'{SRC}/meta.json'))
osm = json.load(open(f'{SRC}/osm.json'))
if 'osm_api_xml' in osm:   # fallback when Overpass was busy: raw OSM API 0.6 map call, turned into Overpass-style elements
    import xml.etree.ElementTree as ET
    root = ET.fromstring(osm['osm_api_xml'])
    nodes = {n.get('id'): {'lat': float(n.get('lat')), 'lon': float(n.get('lon'))} for n in root.iter('node')}
    tags = lambda el: {t.get('k'): t.get('v') for t in el.findall('tag')}
    ways = {}
    els_ = []
    for w in root.iter('way'):
        g = [nodes[nd.get('ref')] for nd in w.findall('nd') if nd.get('ref') in nodes]
        ways[w.get('id')] = g
        els_.append({'type': 'way', 'id': int(w.get('id')), 'tags': tags(w), 'geometry': g})
    for r in root.iter('relation'):
        mem = [{'type': m.get('type'), 'ref': int(m.get('ref')), 'role': m.get('role'), 'geometry': ways.get(m.get('ref'), [])}
               for m in r.findall('member') if m.get('type') == 'way']
        els_.append({'type': 'relation', 'id': int(r.get('id')), 'tags': tags(r), 'members': mem})
    osm = {'elements': els_, '_endpoint': osm['_endpoint']}
CID, SLUG = meta['clack_id'], meta['slug']
E0, N0, E1, N1 = meta.get('box_sweref') or meta['box']
COUNTRY = meta.get('country', 'SE')
EPSG = int(meta.get('crs_epsg', 3006)); CRS_NAME = meta.get('crs_name', 'SWEREF 99 TM'); VDATUM = meta.get('vertical_datum', 'RH 2000')
W, H = E1 - E0, N1 - N0
fw = Transformer.from_crs(4326, EPSG, always_xy=True).transform
bw = Transformer.from_crs(EPSG, 4326, always_xy=True).transform
H_CLS = meta.get('height_classes') or {'låg': 0.35, 'mellan': 0.58, 'hög': 0.73, 'tsd mellan': 0.55, 'tsd hög': 0.76}
EXCLUDE_BIS = {'740000001': {'2308', '2309', '811', '812'}, '740000361': {'1220'}, '740000170': {'2489', '2490'},
               '740001586': {'2597'}, '740000005': {'2335', '2336'}}
import csv
_SE_DIR = os.environ.get('SE_REGISTER_DIR', '/home/claude/work/out')
IN_BILAGA = {r['bis_object'] for r in csv.DictReader(open(f'{_SE_DIR}/trafikverket_platforms_SE.csv', encoding='utf-8'))
             if r['clack_id'] == CID and r['source_row'].startswith('Bilaga') and r['bis_object']} if COUNTRY == 'SE' else set()
BILAGA_ROWS = [(r_.split('|')[3].lower(), {t.strip().lower() for t in r_.split('|')[2].split(',')})
               for r_ in open(f'{_SE_DIR}/bilaga2a_raw.txt', encoding='utf-8') if not r_.startswith('#') and CID.endswith(r_.split('|')[0])] if COUNTRY == 'SE' else []
report = {'clack_id': CID, 'slug': SLUG, 'flags': [], 'notes': [], 'osm_source': osm.get('_endpoint', '?')}
flag = lambda s: report['flags'].append(s)

# ---------------------------------------------------------------- terrain model window
dtm = np.fromfile(f'{SRC}/dtm_window.f32', dtype='<f4').reshape(H, W)
dtm_items = meta['dtm']['items']
_zero = (dtm == 0.0)
if _zero.sum() > 1000 and np.nanmedian(dtm[~_zero]) > 20:
    dtm[_zero] = np.nan            # exact 0.00 far above sea level: no data in the terrain model tile, not ground
    ZERO_NOTE = f'{int(_zero.sum())} m² of the box hold exactly 0.00 in the terrain model (no data at a tile edge); left as no-data'
else:
    ZERO_NOTE = None
def dtm_at(x, y):
    c = np.clip(np.floor(np.asarray(x) - E0).astype(int), 0, W - 1)
    r = np.clip(np.floor(N1 - np.asarray(y)).astype(int), 0, H - 1)
    return dtm[r, c]

# ---------------------------------------------------------------- laser points in the box
xs, ys, zs, cl, rn, nr, it, gps = [], [], [], [], [], [], [], []
hdr = None
tiles = sorted(glob.glob(f'{SRC}/*.copc.laz')) or sorted(glob.glob(f'{SRC}/*.laz'))
for t in tiles:
    las = laspy.read(t)
    hdr = hdr or las.header
    m = (las.x >= E0) & (las.x < E1) & (las.y >= N0) & (las.y < N1)
    xs.append(np.asarray(las.x[m])); ys.append(np.asarray(las.y[m])); zs.append(np.asarray(las.z[m]))
    cl.append(np.asarray(las.classification[m])); rn.append(np.asarray(las.return_number[m]))
    nr.append(np.asarray(las.number_of_returns[m])); it.append(np.asarray(las.intensity[m]))
    gps.append(np.asarray(las.gps_time[m]))
X, Y, Z = np.concatenate(xs), np.concatenate(ys), np.concatenate(zs)
C, RN, NR, I, T = map(np.concatenate, (cl, rn, nr, it, gps))
# drop exact duplicates where two tiles overlap
key = np.round(X * 100).astype(np.int64) * 10**12 + np.round(Y * 100).astype(np.int64) * 10**3 + (np.round(Z * 10).astype(np.int64) % 1000)
_, uniq = np.unique(key, return_index=True)
X, Y, Z, C, RN, NR, I, T = (a[uniq] for a in (X, Y, Z, C, RN, NR, I, T))
# where the terrain model has no data, fill 1 m cells from the laser's own ground points (median per cell)
FILL_NOTE = None
if np.isnan(dtm).any() and not meta['dtm'].get('from_laser'):
    gm = (C == 2)
    cc = np.clip((X[gm] - E0).astype(int), 0, W - 1); rr = np.clip((N1 - Y[gm]).astype(int), 0, H - 1)
    order = np.lexsort((Z[gm], rr * W + cc))
    keys = (rr * W + cc)[order]; zz = Z[gm][order]
    uk, start, cnt = np.unique(keys, return_index=True, return_counts=True)
    med = zz[start + cnt // 2]
    flat = dtm.ravel()
    hole = np.isnan(flat[uk])
    flat[uk[hole]] = med[hole]
    dtm = flat.reshape(H, W)
    FILL_NOTE = (f'{int(hole.sum())} m² of terrain-model no-data filled from the laser ground points (class 2, median per 1 m cell); '
                 f'{int(np.isnan(dtm).sum())} m² still have no ground value')
tif = f'{OUT}/{SLUG}_ground_1m.tif'
with rasterio.open(tif, 'w', driver='GTiff', height=H, width=W, count=1, dtype='float32', crs=f'EPSG:{EPSG}',
                   transform=from_origin(E0, N1, 1, 1), compress='deflate', nodata=np.nan) as d:
    d.write(dtm, 1)
    d.update_tags(source=(meta['dtm'].get('source_line') or ('Lantmäteriet Markhöjdmodell Nedladdning (dtm-cog) ' + ', '.join(i['id'] + ' ' + i['datetime'][:10] for i in dtm_items)
                  + '; © Lantmäteriet, bearbetad, CC BY 4.0')) + ('; ' + FILL_NOTE + ' (' + (meta['laser'][0].get('licence_line') or 'Laserdata Nedladdning, skog, © Lantmäteriet, CC BY 4.0') + ')' if FILL_NOTE else ''),
                  vertical_datum=VDATUM, units='m')
lo, hi = np.nanpercentile(dtm, 0.5), np.nanpercentile(dtm, 99.5)
prev = np.clip((dtm - lo) / max(hi - lo, 0.01) * 255, 0, 255)
prev = np.where(np.isnan(dtm), 0, prev).astype('uint8')
Image.fromarray(prev, 'L').save(f'{OUT}/{SLUG}_ground_1m_preview.png')
base = math.floor(np.nanmin(dtm))
span = np.nanmax(dtm) - base
scale = 1000 if span < 65 else 100
hm = np.where(np.isnan(dtm), 0, np.round((dtm - base) * scale)).astype('uint16')
Image.fromarray(hm).save(f'{OUT}/{SLUG}_ground_1m_heightmap.png')
json.dump({'file': f'{SLUG}_ground_1m_heightmap.png', 'format': 'PNG 16-bit grey, row 0 = north edge',
           'height_m': f'base_m + value / {scale}', 'base_m': base, 'scale': scale, 'nodata_value': 0,
           'crs': f'EPSG:{EPSG} ({CRS_NAME})', 'vertical_datum': VDATUM, 'origin_top_left_EN': [E0, N1], 'pixel_m': 1,
           'width': W, 'height': H, 'source': f'{SLUG}_ground_1m.tif (' + meta['dtm'].get('short_source', 'Lantmäteriet Markhöjdmodell, CC BY 4.0') + ')'},
          open(f'{OUT}/{SLUG}_ground_1m_heightmap.json', 'w'), indent=1)
report['ground'] = {'min_m': round(float(np.nanmin(dtm)), 2), 'median_m': round(float(np.nanmedian(dtm)), 2),
                    'max_m': round(float(np.nanmax(dtm)), 2), 'nan_cells': int(np.isnan(dtm).sum()), 'size_m': [W, H],
                    'box_sweref': [E0, N0, E1, N1], 'tiles': [i['id'] + ' (' + i['datetime'][:10] + ')' for i in dtm_items]}
if ZERO_NOTE:
    report['notes'].append(ZERO_NOTE)
if FILL_NOTE:
    report['notes'].append(FILL_NOTE)
# flat constant patches (lakes / sea): exactly equal values over large areas — playbook rule
vals, cnts = np.unique(dtm[~np.isnan(dtm)], return_counts=True)
big = [(float(v), int(c)) for v, c in zip(vals, cnts) if c > 1500]
if big:
    report['notes'].append('terrain model is exactly flat over large areas (a water surface, not ground): ' +
                           ', '.join(f'{v:.2f} m over {c} m²' for v, c in big))


G = dtm_at(X, Y)
HAG = Z - G
scan = meta['laser'][0]
scan_date = scan['datetime'][:10]
report['laser'] = {'tiles': [os.path.basename(t) for t in tiles], 'scan_date': scan_date,
                   'density_pts_m2_nominal': scan.get('props', {}).get('punkttathet'), 'flight_height_m': scan.get('props', {}).get('flyghojd'),
                   'points_in_box': int(len(X)), 'density_in_box': round(len(X) / (W * H), 2),
                   'classes': {str(k): int(v) for k, v in zip(*np.unique(C, return_counts=True))}}
OBJ = np.isin(C, scan.get('object_classes', [1]))   # classes that hold roofs, canopies and trains (Lantmäteriet: 1 unclassified)
LINE = scan.get('licence_line') or f"Laserdata Nedladdning, skog ({scan['id'].split('-')[0]}, scanned {scan_date}), © Lantmäteriet, bearbetad, CC BY 4.0"

# ---------------------------------------------------------------- OSM geometry
def to_sweref(g):
    return shp_transform(lambda x, y, z=None: fw(x, y), g)
def to_wgs(g):
    return shp_transform(lambda x, y, z=None: bw(x, y), g)

def el_geom(e):
    if e['type'] == 'way' and 'geometry' in e:
        pts = [(p['lon'], p['lat']) for p in e['geometry']]
        if len(pts) >= 4 and pts[0] == pts[-1]:
            return Polygon(pts)
        return LineString(pts) if len(pts) >= 2 else None
    if e['type'] == 'relation' and e.get('tags', {}).get('type') == 'multipolygon':
        outers, inners = [], []
        for mbr in e.get('members', []):
            if mbr.get('type') == 'way' and 'geometry' in mbr:
                ls = [(p['lon'], p['lat']) for p in mbr['geometry'] if p]
                (inners if mbr.get('role') == 'inner' else outers).append(ls)
        try:
            from shapely.ops import polygonize
            polys = list(polygonize([LineString(l) for l in outers if len(l) >= 2]))
            holes = list(polygonize([LineString(l) for l in inners if len(l) >= 2]))
            if not polys:
                return None
            g = unary_union(polys)
            if holes:
                g = g.difference(unary_union(holes))
            return g
        except Exception:
            return None
    return None

els = osm.get('elements', [])
rails, plat_osm, cand, highways = [], [], [], []
for e in els:
    tg = e.get('tags', {})
    g = el_geom(e)
    if g is None:
        continue
    gs = to_sweref(g)
    oid = ('w' if e['type'] == 'way' else 'r' if e['type'] == 'relation' else 'n') + str(e['id'])
    if tg.get('railway') in ('rail', 'light_rail', 'subway') and gs.geom_type == 'LineString' and tg.get('tunnel') in (None, 'no') \
            and not str(tg.get('layer', '0')).startswith('-'):
        rails.append((oid, tg, gs))
    if tg.get('highway') and gs.geom_type == 'LineString':
        highways.append((tg, gs))
    if (tg.get('railway') == 'platform' or tg.get('public_transport') == 'platform') and gs.geom_type in ('Polygon', 'MultiPolygon'):
        plat_osm.append((oid, tg, gs))
    if gs.geom_type in ('Polygon', 'MultiPolygon') and (tg.get('building') or tg.get('building:part') or tg.get('man_made') in ('canopy', 'bridge')
                                                         or tg.get('amenity') == 'shelter'):
        cand.append((oid, tg, gs))

# BanInfo platforms near the station
H2 = lambda f: H_CLS.get((f.get('Höjd') or '').lower())
plat_bi = []
for f in meta['baninfo']['plat']:
    if f.get('BisObjektNr') in EXCLUDE_BIS.get(CID, set()):
        continue
    p = [float(v) for v in (f.get('Points') or '').split()]
    pts = [fw(p[i + 1], p[i]) for i in range(0, len(p) - 1, 2)]
    if len(pts) < 2:
        continue
    L = LineString(pts)
    if not box(E0, N0, E1, N1).contains(L.centroid):
        continue
    mf, mt = float(f.get('MEASURE_FROM') or 0), float(f.get('MEASURE_TO') or 0)
    trk = sorted({t['IndKod'] for t in meta['baninfo']['trk'] if t.get('REFLINK_OID') == f.get('REFLINK_OID')
                  and not (float(t['MEASURE_TO']) <= min(mf, mt) or float(t['MEASURE_FROM']) >= max(mf, mt))})
    plat_bi.append({'f': f, 'L': L, 'track': ','.join(trk) or None})
track_lines = [r[2] for r in rails] + [p['L'] for p in plat_bi]
tracks_u = unary_union(track_lines) if track_lines else None

# ---------------------------------------------------------------- platform surface and track bed per BanInfo platform
ground_m = (C == 2)
def along_across(L, px, py):
    s = shapely.line_locate_point(L, shapely.points(px, py))
    a = shapely.line_interpolate_point(L, np.maximum(s - 1, 0))
    b = shapely.line_interpolate_point(L, np.minimum(s + 1, L.length))
    q = shapely.line_interpolate_point(L, s)
    ax, ay = shapely.get_x(a), shapely.get_y(a); bx, by = shapely.get_x(b), shapely.get_y(b)
    tx, ty = bx - ax, by - ay; n = np.hypot(tx, ty) + 1e-9
    d = (px - shapely.get_x(q)) * (-ty / n) + (py - shapely.get_y(q)) * (tx / n)
    return s, d

UNDERGROUND = {'740000556': 'all', '740001587': 'all', '740000003': {'2092', '2093'}, '740000110': 'all'}   # Arlanda C, Triangeln, Malmö C Citytunneln, Varberg (tunnel)
UG_NOTE = {'740000110': 'platform of the new Varberg station in the railway tunnel (opened after the January 2020 scan): the laser shows only the ground of the old site on its line, not the platform or its track bed'}
plat_rows = []
for p in plat_bi:
    L, f = p['L'], p['f']
    wdt = float(f.get('Bredd_m') or 0) or 6.0
    near = L.buffer(wdt + 6).bounds
    m = (X > near[0]) & (X < near[2]) & (Y > near[1]) & (Y < near[3])
    idx = np.where(m)[0]
    s, d = along_across(L, X[idx], Y[idx])
    inr = (s > 2) & (s < L.length - 2)
    gi = ground_m[idx] & inr
    on_bridge = False
    n2 = int(np.sum(gi & (np.abs(d) < 0.8)))
    n17 = int(np.sum((C[idx] == 17) & inr & (np.abs(d) < 0.8)))
    if n17 > max(3 * n2, 30):                 # the track runs on a bridge: the laser classes the deck as 17, not ground
        gi = (C[idx] == 17) & inr
        on_bridge = True
    bed_pts = Z[idx][gi & (np.abs(d) < 0.8)]
    bed = float(np.median(bed_pts)) if len(bed_pts) >= 15 else None
    sides = {}
    for sgn in (1, -1):
        sel = gi & (sgn * d > 1.8) & (sgn * d < 1.8 + max(wdt - 0.3, 2.0))
        zall = Z[idx][sel]
        if bed is None or len(zall) < 15:
            sides[sgn] = (None, int(len(zall)), 0.0)
            continue
        frac = float(np.mean(zall > bed + 0.3))
        zz = zall[(zall > bed + 0.2) & (zall < bed + 1.6)]
        sides[sgn] = (float(np.median(zz)) if len(zz) >= 30 and frac >= 0.5 else None, int(len(zz)), frac)
    # Which side is the platform? If only one side of the track is raised, that one. If both are (a track between two
    # platforms), BanInfo's SIDE decides: 1 = left of the line's direction, 2 = right (true at Göteborg C; at Hässleholm some
    # lines run the other way, so SIDE alone is not trusted).
    want = {'1': 1, '2': -1}.get(str(f.get('SIDE')))
    ok_ = [k for k in (1, -1) if sides[k][0] is not None]
    plat_lvl, side, npts, both = None, None, 0, None
    if len(ok_) == 1:
        side = ok_[0]
    elif len(ok_) == 2:
        side = want if want else max(ok_, key=lambda k: sides[k][0])
        both = sides[-side][0]
    if side is not None:
        plat_lvl, npts = sides[side][0], sides[side][1]
    cls = (f.get('Höjd') or '').lower()
    row = {'bis_object': f.get('BisObjektNr'), 'track': p['track'], 'height_class': f.get('Höjd'),
           'class_height_m': H2(f), 'length_m': float(f.get('Längd_m') or 0) or None, 'width_m': float(f.get('Bredd_m') or 0) or None,
           'roof': f.get('Väderskydd'), 'track_bed_m': round(bed, 2) if bed is not None else None, 'track_bed_points': int(len(bed_pts)),
           'platform_surface_m': round(plat_lvl, 2) if plat_lvl is not None else None, 'platform_points': npts,
           'platform_side': {1: 'left', -1: 'right'}.get(side), 'baninfo_side': f.get('SIDE')}
    if on_bridge:
        row['on_bridge'] = True
        row['bridge_note'] = 'track and platform on a bridge: bed and surface from laser class 17 (bridge deck) instead of ground'
    if both is not None:
        row['other_side_surface_m'] = round(both, 2)
        row['side_note'] = 'raised ground on both sides of the track; BanInfo SIDE picked the side'
    if plat_lvl is not None and bed is not None:
        diff = plat_lvl - bed
        row['surface_minus_bed_m'] = round(diff, 2)
        if H2(f) is not None:
            est = diff - 0.175
            row['laser_estimate_above_rail_m'] = round(est, 2)
            vf = str(f.get('VALID_FROM') or '')
            newer = vf[:4].isdigit() and int(vf[:4]) >= int(scan_date[:4]) + 2
            in_bil = f.get('BisObjektNr') in IN_BILAGA or any(cls == c and (set(map(str.lower, (p['track'] or '').split(','))) & t) for c, t in BILAGA_ROWS)
            if newer and not in_bil:
                row['note'] = (f'laser ({scan_date}) disagrees with the register' if abs(est - H2(f)) > 0.25 else 'not in Bilaga 2A (report 2026-02-04)') + f' and the BanInfo record is from {vf[:4]}-{vf[4:6]}-{vf[6:]}: probably built or rebuilt after the scan, so the laser value is not this platform; left out of the station level'
                row['after_scan'] = True
                flag(f"Platform BIS {f.get('BisObjektNr')} (track {p['track']}): register {f.get('Höjd')}, laser {diff:.2f} m above the bed; record valid from {vf[:4]}-{vf[4:6]}-{vf[6:]}" + ('' if in_bil else ', not in Bilaga 2A') + f"; the scan is from {scan_date}: probably built after the scan.")
            elif abs(est - H2(f)) > 0.125:
                flag(f"Platform BIS {f.get('BisObjektNr')} (track {p['track']}): laser gives {diff:.2f} m above the track bed "
                     f"(≈{est:.2f} m above rail after −0.15…0.2 m), register class {f.get('Höjd')} = {H2(f)} m. Not decided; add to REVIEW.md.")
    else:
        row['note'] = 'no platform surface or track bed found in the laser here (covered by a roof, underground, or too few ground points)'
    ug = UNDERGROUND.get(CID)
    if ug == 'all' or (ug and f.get('BisObjektNr') in ug):
        row = {k: row[k] for k in ('bis_object', 'track', 'height_class', 'class_height_m', 'length_m', 'width_m', 'roof', 'baninfo_side')}
        row.update(track_bed_m=None, track_bed_points=0, platform_surface_m=None, platform_points=0, platform_side=None, underground=True,
                   note=UG_NOTE.get(CID, 'underground platform: the airborne laser sees the surface above it, not the platform or the track bed'))
        report['flags'][:] = [x for x in report['flags'] if f"BIS {f.get('BisObjektNr')} " not in x]
    plat_rows.append(row)
report['platforms'] = plat_rows
_beds = [r['track_bed_m'] for r in plat_rows if r['track_bed_m'] is not None]
if _beds:
    _mb = float(np.median(_beds))
    for r_ in plat_rows:
        surf_ok = r_.get('platform_surface_m') is not None and r_['platform_surface_m'] - r_['track_bed_m'] > 0.35 if r_['track_bed_m'] is not None else False
        if r_['track_bed_m'] is not None and abs(r_['track_bed_m'] - _mb) > 1.5 and not surf_ok:
            r_['note'] = (f"'track bed' here is {r_['track_bed_m']:.2f} m, {r_['track_bed_m'] - _mb:+.1f} m from the station's median {_mb:.2f} m: "
                          'the ground-class points over this track are a deck, roof or bridge, not the bed; values left out')
            r_['after_scan'] = True
            for k in ('surface_minus_bed_m', 'laser_estimate_above_rail_m'):
                r_.pop(k, None)
            report['flags'][:] = [x for x in report['flags'] if f"BIS {r_['bis_object']} " not in x]
            flag(f"Platform BIS {r_['bis_object']} (track {r_['track']}): the laser 'ground' over the track is {r_['track_bed_m'] - _mb:+.1f} m from the other tracks (deck or roof over the tracks?): not measured.")
lv = [r['platform_surface_m'] for r in plat_rows if r['platform_surface_m'] is not None and not r.get('after_scan')]
bd = [r['track_bed_m'] for r in plat_rows if r['track_bed_m'] is not None and not r.get('after_scan')]
report['platform_surface_m'] = round(float(np.median(lv)), 2) if lv else None
report['track_bed_m'] = round(float(np.median(bd)), 2) if bd else None
if lv and max(lv) - min(lv) > 0.5:
    flag(f'Platform surfaces differ by {max(lv) - min(lv):.2f} m across the station ({min(lv):.2f}–{max(lv):.2f} m); '
         'the station reference above is their median — check which level the app should use.')
REF = report['platform_surface_m']

# ---------------------------------------------------------------- trains standing in the scan
# A train roof sits ~3.8–4.2 m above the track bed, centred on one track, ~3 m wide; canopies sit over the platforms.
is_train = np.zeros(len(X), bool)
trains = []
tlines = [r[2] for r in rails]
if tlines and len(X):
    cand_t = np.where(OBJ & (HAG > 2.6) & (HAG < 5.0))[0]
    if len(cand_t):
        P = shapely.points(X[cand_t], Y[cand_t])
        D = np.stack([shapely.distance(l, P) for l in tlines])
        near_i = D.argmin(0); near_d = D.min(0)
        keep = near_d < 2.2
        cand_t, near_i = cand_t[keep], near_i[keep]
        for li in np.unique(near_i):
            L = tlines[li]
            pi = cand_t[near_i == li]
            s_, d_ = along_across(L, X[pi], Y[pi])
            o = np.argsort(s_); pi, s_, d_ = pi[o], s_[o], d_[o]
            cuts = np.where(np.diff(s_) > 4.0)[0] + 1
            for seg in np.split(np.arange(len(pi)), cuts):
                if len(seg) < 20:
                    continue
                length = s_[seg[-1]] - s_[seg[0]]
                if length < 15 or len(seg) / length < 1.5:
                    continue
                ad = np.abs(d_[seg])
                if np.median(ad) > 1.0 or np.percentile(ad, 90) > 1.9:
                    continue
                bedloc = dtm_at(X[pi[seg]], Y[pi[seg]])
                above = float(np.median(Z[pi[seg]] - bedloc))
                if not 3.0 <= above <= 4.8:
                    continue
                pts = pi[seg]
                is_train[pts] = True
                cells = {(int(N1 - y), int(x - E0)) for x, y in zip(X[pts], Y[pts])}
                poly = unary_union([box(E0 + c, N1 - r - 1, E0 + c + 1, N1 - r) for r, c in cells]).buffer(0.6).buffer(-0.6).simplify(0.7)
                trains.append({'poly': poly, 'top': float(np.median(Z[pts])), 'n': int(len(pts)), 'len': round(float(length), 1),
                               'width': round(float(np.percentile(d_[seg], 95) - np.percentile(d_[seg], 5)), 1), 'above_bed': round(above, 2)})
report['trains_in_scan'] = len(trains)

# ---------------------------------------------------------------- structures from OSM outlines
plat_zone = unary_union([p['L'].buffer(float(p['f'].get('Bredd_m') or 0) + 12) for p in plat_bi] + [g.buffer(8) for _, _, g in plat_osm]) \
    if (plat_bi or plat_osm) else box(E0, N0, E1, N1).centroid.buffer(150)
STATION_TAGS = lambda tg: (tg.get('building') in ('train_station', 'transportation', 'roof') or tg.get('man_made') in ('canopy', 'bridge')
                           or tg.get('railway') in ('station', 'platform') or tg.get('public_transport') in ('station', 'platform')
                           or tg.get('amenity') == 'shelter' or 'station' in (tg.get('name', '') + tg.get('building', '')).lower()
                           or 'central' in tg.get('name', '').lower() or 'resecentrum' in tg.get('name', '').lower())
BRIDGES = []
tight_zone = unary_union([p['L'].buffer((float(p['f'].get('Bredd_m') or 0) or 6) + 3) for p in plat_bi]) if plat_bi else box(0, 0, 1, 1)
feats = []
used_mask = np.zeros(len(X), bool)
def ring_ground(g):
    ring = g.buffer(1.5).difference(g.buffer(0.3))
    if ring.is_empty:
        return None
    xs_, ys_ = [], []
    minx, miny, maxx, maxy = ring.bounds
    gx, gy = np.meshgrid(np.arange(math.floor(minx), math.ceil(maxx)) + 0.5, np.arange(math.floor(miny), math.ceil(maxy)) + 0.5)
    inside = shapely.contains_xy(ring, gx.ravel(), gy.ravel())
    v = dtm_at(gx.ravel()[inside], gy.ravel()[inside])
    v = v[~np.isnan(v)]
    return v if len(v) else None

def pts_in(g):
    minx, miny, maxx, maxy = g.bounds
    m = (X >= minx) & (X <= maxx) & (Y >= miny) & (Y <= maxy)
    idx = np.where(m)[0]
    return idx[shapely.contains_xy(g, X[idx], Y[idx])]

for oid, tg, g in cand:
    if not g.intersects(box(E0, N0, E1, N1)):
        continue
    if not (STATION_TAGS(tg) or g.intersects(plat_zone)):
        continue
    if g.area < 6:
        continue
    gr = ring_ground(g)
    idx = pts_in(g)
    idx = idx[OBJ[idx] & ~is_train[idx]]
    hag = HAG[idx]
    roof = idx[hag > 2.0]
    kind = 'building'
    if tg.get('building') == 'roof' or tg.get('man_made') == 'canopy' or tg.get('amenity') == 'shelter' or tg.get('covered') == 'yes' and not tg.get('building'):
        kind = 'canopy_osm'
    if tg.get('man_made') == 'bridge':
        ways_on = [h for h in highways if h[0].get('bridge') and h[0].get('bridge') != 'no' and h[1].intersection(g).length > 3]
        foot = ways_on and all(h[0].get('highway') in ('footway', 'path', 'steps', 'pedestrian', 'cycleway', 'corridor') for h in ways_on)
        kind = 'footbridge' if foot else 'bridge'
        if kind == 'bridge':
            BRIDGES.append(f"{oid}{' ' + tg['name'] if tg.get('name') else ''} (" + (', '.join(sorted({h[0].get('highway') for h in ways_on})) or 'no mapped ways') + ')')
    name = tg.get('name') or tg.get('description') or ''
    what = tg.get('building') or tg.get('building:part') or tg.get('man_made') or tg.get('amenity')
    what = {'yes': 'building', 'roof': 'roof', 'train_station': 'station building', 'canopy': 'canopy'}.get(what, what)
    label = f'{name} ({what})' if name else what
    props = {'kind': kind, 'osm_id': oid, 'name': label.strip(), 'osm_tags': {k: v for k, v in tg.items() if k in (
        'building', 'building:part', 'building:levels', 'height', 'roof:shape', 'man_made', 'name', 'layer', 'level', 'start_date', 'covered', 'amenity')}}
    if gr is not None:
        props.update(ground_min_m=round(float(gr.min()), 2), ground_median_m=round(float(np.median(gr)), 2), ground_max_m=round(float(gr.max()), 2))
    if len(roof) >= 5:
        med, p95 = float(np.median(Z[roof])), float(np.percentile(Z[roof], 95))
        props.update(roof_top_median_m=round(med, 2), roof_top_p95_m=round(p95, 2), laser_points=int(len(roof)))
        gmed = props.get('ground_median_m', float(np.nanmedian(dtm_at(X[roof], Y[roof]))))
        props.update(height_above_ground_median_m=round(med - gmed, 2), height_above_ground_p95_m=round(p95 - gmed, 2))
        if REF is not None:
            props['top_above_platform_m'] = round(med - REF, 2)
            if 'ground_min_m' in props:
                props['base_above_platform_m'] = round(props['ground_min_m'] - REF, 2)
        if p95 - med > 3.0 and kind != 'bridge' and (STATION_TAGS(tg) or kind != 'building' or g.intersects(tight_zone)):
            flag(f"{oid} {label}: p95 {p95:.1f} m is {p95 - med:.1f} m above the median {med:.1f} m (a taller neighbour or a mast inside the outline?).")
        used_mask[roof] = True
        props['source'] = f'Outline OSM {oid} (ODbL); roof = median of {len(roof)} unclassified laser points >2 m above the terrain model inside the outline; ' + LINE
    else:
        props['laser_points'] = int(len(roof))
        props['source'] = f'Outline OSM {oid} (ODbL); fewer than 5 laser roof points inside the outline (roof not measured); ' + LINE
    if kind == 'footbridge':
        props['deck_m'] = None
        props['note'] = 'airborne laser sees the top only; deck and underside unknown'
    elif kind in ('canopy_osm',):
        props['underside_m'] = None
    feats.append({'type': 'Feature', 'geometry': mapping(to_wgs(g)), 'properties': props, '_g': g})

if BRIDGES:
    flag("OSM bridge outlines at the platforms that carry roads, tram or service ways, kept as kind 'bridge' (not footbridges): " + '; '.join(BRIDGES) + '.')
# ---------------------------------------------------------------- roofs traced from the laser over the platforms
osm_cover = unary_union([f['_g'] for f in feats]) if feats else None
if REF is not None and plat_bi:
    zone = unary_union([p['L'].buffer(float(p['f'].get('Bredd_m') or 0) + 4) for p in plat_bi])
    sel = np.where(OBJ & ~is_train & (Z > REF + 2.4) & (Z < REF + 14))[0]
    if len(sel):
        sel = sel[shapely.contains_xy(zone, X[sel], Y[sel])]
    if osm_cover is not None and len(sel):
        sel = sel[~shapely.contains_xy(osm_cover.buffer(0.5), X[sel], Y[sel])]
    grid = np.zeros((H, W), np.int32)
    if len(sel):
        cc = np.clip((X[sel] - E0).astype(int), 0, W - 1); rr = np.clip((N1 - Y[sel]).astype(int), 0, H - 1)
        np.add.at(grid, (rr, cc), 1)
        occ = ndimage.binary_closing(grid > 0, np.ones((3, 3)))
        lab, nl = ndimage.label(occ)
        cell_lab = lab[rr, cc]
        for k in range(1, nl + 1):
            pk = sel[cell_lab == k]
            cells = np.argwhere(lab == k)
            if len(cells) < 40 or len(pk) < 20:
                continue
            multi = float(np.mean(NR[pk] > 1))
            rough = float(np.std(Z[pk]))
            if multi > 0.35 or rough > 1.2:   # vegetation, wires or mixed
                continue
            poly = unary_union([box(E0 + c, N1 - r - 1, E0 + c + 1, N1 - r) for r, c in cells]).simplify(0.7)
            top_med = float(np.median(Z[pk]))
            gr = ring_ground(poly)
            kind = 'canopy_laser' if top_med - REF < 6.0 else 'hall_roof_laser'
            on_track = tracks_u is not None and float(np.mean(shapely.distance(tracks_u, shapely.points(X[pk], Y[pk])) < 1.7)) > 0.3
            props = {'kind': kind, 'osm_id': None, 'name': 'roof over the platforms (traced from the laser)',
                     'top_median_m': round(top_med, 2), 'top_p10_m': round(float(np.percentile(Z[pk], 10)), 2),
                     'top_p90_m': round(float(np.percentile(Z[pk], 90)), 2), 'laser_points': int(len(pk)),
                     'top_above_platform_m': round(top_med - REF, 2), 'area_m2': round(poly.area, 1), 'underside_m': None,
                     'multi_return_share': round(multi, 2),
                     'source': f'Outline traced from the laser alone (1 m cells holding unclassified points 2.4–14 m above the platform surface over the BanInfo platforms, outside OSM outlines, closed 3×3, simplified 0.7 m); ' + LINE}
            if gr is not None:
                props.update(ground_min_m=round(float(gr.min()), 2), ground_median_m=round(float(np.median(gr)), 2), ground_max_m=round(float(gr.max()), 2))
            if kind == 'hall_roof_laser':
                flag(f'Laser-traced roof ({poly.area:.0f} m², top {top_med - REF:.1f} m above the platform) could be a building or hall roof, not a canopy: check OSM and a platform photo.')
            if on_track:
                ab = top_med - (report["track_bed_m"] or REF)
                flag(f'Laser-traced roof ({poly.area:.0f} m², top {top_med - REF:.1f} m above the platform, {ab:.1f} m above the track bed) lies partly over a track: '
                     + ('it may be a train (a double-deck X40 is ~4.6 m tall), check in a cross-section.' if ab < 5.2 else 'a bridge, gantry or roof over the track; check in a cross-section.'))
            feats.append({'type': 'Feature', 'geometry': mapping(to_wgs(poly)), 'properties': props, '_g': poly})

for t in trains:
    feats.append({'type': 'Feature', 'geometry': mapping(to_wgs(t['poly'])), '_g': t['poly'], 'properties': {
        'kind': 'train_in_scan', 'osm_id': None, 'name': f"train standing during the scan ({t['len']} m × {t['width']} m)",
        'top_median_m': round(t['top'], 2), 'top_above_track_bed_m': t['above_bed'], 'laser_points': t['n'],
        'source': f'Traced from the laser: unclassified points 2.6–5.0 m above the terrain model within 1.8 m of a track centreline, strip ≤4.5 m wide and ≥15 m long, scan {scan_date}. Not a structure; these points are class 64 in the LAZ. ' + LINE}})

for f in feats:
    f.pop('_g', None)
gj = {'type': 'FeatureCollection', 'name': f'{SLUG}_structures_heights', 'crs_note': f'WGS84 lon/lat; heights m {VDATUM}',
      'platform_surface_m': REF, 'track_bed_m': report['track_bed_m'], 'features': feats}
json.dump(gj, open(f'{OUT}/{SLUG}_structures_heights.geojson', 'w'), ensure_ascii=False, indent=1)
report['structures'] = {k: sum(1 for f in feats if f['properties']['kind'] == k) for k in
                        ('building', 'footbridge', 'canopy_osm', 'canopy_laser', 'hall_roof_laser', 'train_in_scan')}

# ---------------------------------------------------------------- clipped LAZ, trains as class 64
year = scan_date[:4]
hdr_out = laspy.LasHeader(point_format=6, version='1.4')
hdr_out.scales = np.array([0.01, 0.01, 0.01]); hdr_out.offsets = np.array([E0, N0, 0.0])
hdr_out.add_crs(rasterio.crs.CRS.from_epsg(EPSG)) if hasattr(hdr_out, 'add_crs') else None
out = laspy.LasData(hdr_out)
out.x, out.y, out.z = X, Y, Z
cls_out = C.astype(np.uint8).copy(); cls_out[is_train] = 64
out.classification = cls_out
out.return_number, out.number_of_returns, out.intensity, out.gps_time = RN, NR, I, T
laz = f'{OUT}/{SLUG}_laser_station_{year}.laz'
out.write(laz)
report['laser']['train_points_class64'] = int(is_train.sum())

# ---------------------------------------------------------------- BanInfo platform GeoJSON
pf = []
for p, r in zip(plat_bi, plat_rows):
    f = p['f']
    pf.append({'type': 'Feature', 'geometry': mapping(to_wgs(p['L'])), 'properties': {
        'bis_object': f.get('BisObjektNr'), 'track': p['track'], 'height_class': f.get('Höjd'), 'height_m': H2(f),
        'height_text': f.get('Höjd_beskr'), 'length_m': r['length_m'], 'width_m': r['width_m'], 'roof': f.get('Väderskydd'),
        'edge_material': f.get('Plattformskant_mtrl'), 'surface': f.get('Beläggning'), 'safety_zone': f.get('Skyddszon_och_ledstråk'),
        'km_from': f.get('Kmtal'), 'km_to': f.get('Kmtalti'), 'side': f.get('SIDE'), 'valid_from': f.get('VALID_FROM'),
        'reflink_oid': f.get('REFLINK_OID'), 'measure_from': f.get('MEASURE_FROM'), 'measure_to': f.get('MEASURE_TO'),
        'laser_platform_surface_m': r['platform_surface_m'], 'laser_track_bed_m': r['track_bed_m'],
        'geometry_note': meta.get('platform_geometry_note', 'Trafikverket track line (track centre) along the platform, not the platform edge'),
        **({k: f[k] for k in f if k.startswith('x_')}),
        'source': f.get('_source') or ('Trafikverket BanInfo WMS BanInfo_1_5, layers Plattform + Sparnummer, GetFeatureInfo ' + meta['retrieved'][:10] + ', CC0')}})
    if f.get('_outline'):
        pf.append({'type': 'Feature', 'geometry': f['_outline'], 'properties': {'bis_object': f.get('BisObjektNr'), 'track': p['track'],
                   'what': 'platform outline as published by the register', 'source': f.get('_source')}})
json.dump({'type': 'FeatureCollection', 'features': pf}, open(f"{OUT}/{SLUG}_platform_{meta.get('platform_file_suffix', 'trafikverket')}.geojson", 'w'), ensure_ascii=False, indent=1)

# ---------------------------------------------------------------- photos
com = json.load(open(f'{SRC}/commons.json'))
import re, html
strip = lambda s: html.unescape(re.sub('<[^>]+>', '', s or '')).strip()
photos = []
if isinstance(com, list):
    for c in com:
        txt = (c['title'] + ' ' + strip(c.get('description'))).lower()
        rel = bool(re.search(r'station|stationen|perrong|plattform|spår|tåg|train|platform|central|resecentrum|x2000|pendel|järnväg|railway|bangård|tak|canopy', txt))
        photos.append({'source': 'Wikimedia Commons', 'station_related': rel, 'viewed': False, 'pageid': c['pageid'], 'title': c['title'], 'url': c['url'], 'file_url': c['file_url'],
                       'author': strip(c.get('author')), 'licence': c.get('licence'), 'licence_url': c.get('licence_url'),
                       'date': strip(c.get('date')), 'lat': c.get('lat'), 'lon': c.get('lon'), 'description': strip(c.get('description'))[:300]})
photos.sort(key=lambda p: (not p['station_related'], p['title']))
json.dump({'note': 'Wikimedia Commons files within 400 m of the station point (geosearch) or found by the station name. '
                   '"station_related" = title or description names a station, platform, track, train or roof. "viewed": whether the image '
                   'itself was looked at for this pass (labels in the structures file come from OSM tags and the laser, see 3D_SOURCES_FINDINGS.md). '
                   'Mapillary was not searched in this pass.', 'photos': photos},
          open(f'{OUT}/photos.json', 'w'), ensure_ascii=False, indent=1)
report['photos'] = len(photos); report['photos_station_related'] = sum(p['station_related'] for p in photos)
json.dump(report, open(f'{OUT}/_report.json', 'w'), ensure_ascii=False, indent=1)
print(json.dumps(report, ensure_ascii=False, indent=1)[:6000])
