"""Make a station bundle (the input of station_pack.py) for a Danish station.

python3 make_dk_bundle.py <safe id e.g. 860000626> <out bundle dir> <laz files (Danmarks Højdemodel punktsky 1 km tiles)...>

Inputs: _sources/DK/dk_register/<safe id>.json (make_dk_register.py: Bilag 3.6 rows on Banedanmark open data),
_sources/DK/clack_dk_osm_commons.json (OSM API map call + Commons), _sources/DK/dk_stations.json.
Box: the register's platform lines plus 120 m. The ground grid is made from the laser's class 2, median per 1 m cell
(no-data where there is no ground point; nothing interpolated). Heights DVR90, EPSG:25832.
"""
import json, sys, os, re
import numpy as np, laspy
from pyproj import Transformer
from shapely.geometry import LineString
from shapely.ops import unary_union

SAFE, OUT = sys.argv[1], sys.argv[2]
LAZ = sys.argv[3:]
SRC = os.environ.get('DK_SOURCES', 'data/stations/research/_sources/DK')
REGD = os.environ.get('DK_REGISTER', 'data/stations/research/_sources/DK/dk_register')
ST = {s['safe']: s for s in json.load(open(os.environ.get('DK_STATIONS', 'data/stations/research/_sources/DK/dk_stations.json')))}[SAFE]
REG = json.load(open(f'{REGD}/{SAFE}.json'))
EPSG = 25832
os.makedirs(OUT, exist_ok=True)
fw = Transformer.from_crs(4326, EPSG, always_xy=True).transform
lines = []
for p in REG['plat']:
    v = [float(x) for x in p['Points'].split()]
    lines.append(LineString([fw(v[i + 1], v[i]) for i in range(0, len(v) - 1, 2)]))
b = unary_union(lines).bounds if lines else (*fw(ST['lon'], ST['lat']), *fw(ST['lon'], ST['lat']))
E0, N0, E1, N1 = int(b[0] - 120), int(b[1] - 120), int(b[2] + 120) + 1, int(b[3] + 120) + 1

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
        gt = np.asarray(las.gps_time[m])
        if gt.size:
            gts.append(float(np.median(gt)))
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

tiles, cls_all, gts = [], {}, []
dtm = np.array([np.nan])
if LAZ:
    grid_laser()


OC = json.load(open(f'{SRC}/clack_dk_osm_commons.json'))[SAFE]
json.dump(OC['osm'], open(f'{OUT}/osm.json', 'w'))
json.dump(OC['commons'], open(f'{OUT}/commons.json', 'w'))
slug = re.sub(r'[^a-z0-9]+', '_', ST['name'].lower().replace('ø', 'o').replace('æ', 'ae').replace('å', 'a')).strip('_')
import datetime
# scan date: from the points' GPS time (adjusted standard GPS time = GPS seconds − 1e9), median over the box
SCAN = os.environ.get('DK_SCAN_DATE') or (
    (datetime.datetime(1980, 1, 6) + datetime.timedelta(seconds=float(np.median(gts)) + 1e9)).strftime('%Y-%m-%d') if gts else 'unknown')
line = ('Danmarks Højdemodel – Punktsky, Klimadatastyrelsen, CC BY 4.0 (tiles ' + ', '.join(t.replace('.laz', '') for t in tiles) + ')')
OBJ = [k for k in (1, 3, 4, 5, 6) if k in cls_all]
meta = {
    'clack_id': ST['clack_id'], 'slug': slug, 'country': 'DK', 'lat': ST['lat'], 'lon': ST['lon'],
    'crs_epsg': EPSG, 'crs_name': 'ETRS89 / UTM 32N', 'vertical_datum': 'DVR90', 'box': [E0, N0, E1, N1],
    'height_classes': REG['heights'],
    'height_classes_source': 'Banedanmark Netredegørelse 2027, Bilag 3.6: platform height in cm above top of rail, per platform',
    'platform_file_suffix': 'banedanmark',
    'platform_geometry_note': 'Bilag 3.6 rows placed on Banedanmark Open Data track centrelines (Sporforløb) cut to the Banedanmark platform outline (FOR_PERRONER_OD); see x_geometry',
    'retrieved': '2026-10-30',
    'underground': 'all' if SAFE in ('860000858', '860000646') else None,
    'platform_from_unclassified': True,
    'dtm': {'items': [], 'from_laser': True, 'short_source': 'gridded from the laser ground class, CC BY 4.0',
            'source_line': f'Gridded here from the ground points (class 2) of {line}: median per 1 m cell; cells without ground points left as no-data'},
    'laser': [{'id': 'dhm-punktsky', 'datetime': SCAN, 'licence_line': line, 'object_classes': OBJ, 'props': {'punkttathet': 8},
               'url': 'https://dataforsyningen.dk/data/3931'}],
    'baninfo': {'plat': REG['plat'], 'trk': REG['trk']},
    'build_flags': REG['flags'],
    'doc_profile': {
        'brief': 'the brief STATION_3D_RESEARCH_BRIEF_DK_FI.md (Denmark)', 'vdatum': 'DVR90', 'crs': 'ETRS89 / UTM 32N (EPSG:25832)',
        'laser_line': line, 'scan_block': 'DHM punktsky ' + ', '.join(t.replace('.laz', '') for t in tiles),
        'box_note': ': the platforms\' extent plus 120 m',
        'dtm_what': "Ground, 1 m, float32, EPSG:25832, DVR90, gridded here from the laser's ground points (class 2), median per 1 m cell; no-data where there is no ground point",
        'dtm_licence': line, 'ground_how': 'ground grid from the laser class 2 (see the GeoTIFF tags)',
        'register_short': 'Banedanmark', 'register_owner': 'Banedanmark', 'register_file': f'{slug}_platform_banedanmark.geojson',
        'register_what': 'Bilag 3.6 platforms (perron, track, length, height in cm) on Banedanmark track centrelines, with the laser levels',
        'register_licence': 'Bilag 3.6: facts from Banedanmark\'s network statement; geometry Banedanmark Open Data, CC BY 4.0',
        'register_text': 'Register: Banedanmark Netredegørelse 2027 Bilag 3.6 (perron, track, length, height in cm above rail; table dated 1 August 2023), placed on Banedanmark Open Data (CC BY 4.0) track centrelines and platform outlines; widths are outline area / length.',
        'id_label': 'Perron / track', 'object_points': 'non-ground (classes ' + ','.join(map(str, OBJ)) + ')',
        'osm_warning': 'The laser data is CC BY 4.0: do not upload values derived from it to OpenStreetMap without the licensor\'s permission for OSM.',
        'sources_md': f"- {line}. https://dataforsyningen.dk/data/3931 (scan {{scan}}; {{points}} points in the box, {{density}} per m²; classes {{classes}}).\n- Ground grid: made here from the same laser (class 2).\n- Banedanmark Netredegørelse 2027, Bilag 3.6 (bane.dk), read 2026-10-30; Banedanmark Open Data (services1.arcgis.com/QcgJt0vVxSaqMKl7), CC BY 4.0, read 2026-10-30.",
    },
}
json.dump(meta, open(f'{OUT}/meta.json', 'w'), ensure_ascii=False, indent=1)
print(SAFE, slug, 'platforms', len(REG['plat']), 'tiles', len(tiles), 'classes', cls_all, 'ground cells', int(np.isfinite(dtm).sum()), 'box', [E0, N0, E1, N1])
