"""Make a station bundle (the input of station_pack.py) for a Finnish station.

python3 make_fi_bundle.py <code e.g. HKI> <out bundle dir> <laser source: hel2021|mml05> <E0 N0 E1 N1 in the laser's CRS> <laz files...>

Inputs (all read in the browser and saved as files, see HANDOFF):
  sources/FI/clack_fi_infra_platforms.json   Digitraffic infra-api laiturit + rautatieliikennepaikat (CC BY 4.0)
  sources/FI/clack_fi_osm_commons.json        OSM API 0.6 map call + Wikimedia Commons geosearch per station code
  fi_stations.json                            the 17 stations (code, name, position) worked out from the infra-api file
The terrain model is gridded here from the laser's own ground points (class 2), median per 1 m cell; cells without
ground points stay no-data (nothing is interpolated).
"""
import json, sys, os, glob, re
import numpy as np, laspy
from pyproj import Transformer
from shapely.geometry import LineString, MultiLineString
from shapely.ops import transform as shp_transform

CODE, OUT, SRCKIND = sys.argv[1], sys.argv[2], sys.argv[3]
E0, N0, E1, N1 = map(int, sys.argv[4:8])
LAZ = sys.argv[8:]
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get('FI_SOURCES', '/mnt/user-data/uploads/Downloads/clack_station3d/sources/FI')
ST = {s['code']: s for s in json.load(open(os.environ.get('FI_STATIONS', '/home/claude/fi/fi_stations.json')))}[CODE]
os.makedirs(OUT, exist_ok=True)

LASER = {
    'hel2021': dict(epsg=3879, crs_name='ETRS-GK25', year='2021', density=40, object_classes=[1, 3, 4, 5, 6],
                    line='Helsingin laserkeilausaineisto 2021 (kaikki pisteet, 0.5 km tiles {tiles}), City of Helsinki, Kaupunkimittauspalvelut, CC BY 4.0',
                    url='https://hri.fi/data/en/dataset/helsingin-laserkeilausaineistot'),
    'mml05': dict(epsg=3067, crs_name='ETRS-TM35FIN', year=None, density=0.5, object_classes=[1, 3, 4, 5],
                  line='Laserkeilausaineisto 0,5 p ({tiles}), Maanmittauslaitos (National Land Survey of Finland), CC BY 4.0',
                  url='https://www.maanmittauslaitos.fi/en/maps-and-spatial-data/datasets-and-interfaces/product-descriptions/laser-scanning-data-05-p'),
}[SRCKIND]
EPSG = LASER['epsg']
to_wgs = Transformer.from_crs(3067, 4326, always_xy=True).transform

# ---------------------------------------------------------------- laser: copy/clip and grid the ground
xs, ys, zs = [], [], []
tiles = []
for f in LAZ:
    las = laspy.read(f)
    m = (las.x >= E0 - 5) & (las.x < E1 + 5) & (las.y >= N0 - 5) & (las.y < N1 + 5)
    if not m.any():
        continue
    tiles.append(os.path.basename(f))
    sub = laspy.LasData(las.header)
    sub.points = las.points[m]
    sub.write(f'{OUT}/{os.path.basename(f)}')
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

# ---------------------------------------------------------------- platforms from the infra-api
I = json.load(open(f'{SRC}/clack_fi_infra_platforms.json'))
read = I['_meta']['read'][:10]
to_l = Transformer.from_crs(3067, EPSG, always_xy=True).transform
plat, trk = [], []
for v in I['laiturit'].values():
    p = v[0]
    if p['tunnus'].split()[1] != CODE:
        continue
    g = MultiLineString([LineString(part) for part in p['geometria']])
    line = max(g.geoms, key=lambda q: q.length)
    pts = [to_wgs(x, y) for x, y in line.coords]
    vf = p['objektinVoimassaoloaika'].split('/')[0][:10].replace('-', '')
    oid = p['tunniste']
    plat.append({'BisObjektNr': p['tunnus'].replace('Laituri ', ''), 'Points': ' '.join(f'{la:.7f} {lo:.7f}' for lo, la in pts),
                 'Höjd': p['korkeus'], 'Höjd_beskr': p['korkeus'], 'Längd_m': p['pituus'], 'Bredd_m': None, 'Väderskydd': None,
                 'SIDE': None, 'VALID_FROM': vf, 'REFLINK_OID': oid, 'MEASURE_FROM': 0, 'MEASURE_TO': 1e9,
                 'Kmtal': json.dumps(p.get('ratakmvalit')), 'x_platform_number': p['kaupallinenNumero'], 'x_infra_oid': oid,
                 'x_description': p.get('kuvaus'),
                 '_source': f"Digitraffic infra-api (Väylävirasto / Fintraffic), laiturit {oid}, read {read}, CC BY 4.0"})
    trk.append({'REFLINK_OID': oid, 'IndKod': p['kaupallinenNumero'], 'MEASURE_FROM': 0, 'MEASURE_TO': 1e9})

oc = json.load(open(f'{SRC}/clack_fi_osm_commons.json'))[CODE]
json.dump(oc['osm'], open(f'{OUT}/osm.json', 'w'))
json.dump(oc['commons'], open(f'{OUT}/commons.json', 'w'))
slug = re.sub(r'[^a-z0-9]+', '_', ST['name'].lower().replace('ä', 'a').replace('ö', 'o').replace('å', 'a')).strip('_')
line = LASER['line'].format(tiles=', '.join(t.replace('.laz', '') for t in tiles))
meta = {
    'clack_id': 'FI-' + CODE, 'slug': slug, 'country': 'FI', 'lat': ST['lat'], 'lon': ST['lon'],
    'crs_epsg': EPSG, 'crs_name': LASER['crs_name'], 'vertical_datum': 'N2000', 'box': [E0, N0, E1, N1],
    'height_classes': {'korkea': 0.55, 'matala': 0.265},
    'height_classes_source': 'Finnish platform standard: high 550 mm, older standard 265 mm above top of rail (Väylävirasto Network Statement 2021, appendix 3B, via Wikipedia "Platform height", read 2026-10-30)',
    'platform_file_suffix': 'vayla',
    'platform_geometry_note': 'Digitraffic infra-api platform line (laiturit.geometria) as published',
    'retrieved': read,
    'dtm': {'items': [], 'from_laser': True, 'short_source': 'gridded from the laser ground class, CC BY 4.0',
            'source_line': f'Gridded here from the ground points (class 2) of {line}: median per 1 m cell; cells without ground points left as no-data'},
    'laser': [{'id': SRCKIND, 'datetime': LASER['year'] or 'unknown', 'licence_line': line, 'object_classes': LASER['object_classes'],
               'props': {'punkttathet': LASER['density']}, 'url': LASER['url']}],
    'baninfo': {'plat': plat, 'trk': trk},
}
json.dump(meta, open(f'{OUT}/meta.json', 'w'), ensure_ascii=False, indent=1)
print(CODE, slug, 'platforms', len(plat), 'tiles', tiles, 'ground cells', int(np.isfinite(dtm).sum()), 'of', W * H)
