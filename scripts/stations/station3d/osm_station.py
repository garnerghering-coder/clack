"""Pick a station's OSM facts out of an OSM API 0.6 extract: platforms, ways between levels, entrances, amenities.
python3 osm_station.py <clack id> <extract.osm> <lat> <lon> <out.json>"""
import sys, json, math, xml.etree.ElementTree as ET
from pyproj import Transformer
from shapely.geometry import Point, LineString, Polygon
from shapely.ops import unary_union

CID, SRC, LAT, LON, OUT = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
EPSG = int(sys.argv[6]) if len(sys.argv) > 6 else 3006   # any metric projection for the area
fw = Transformer.from_crs(4326, EPSG, always_xy=True).transform
root = ET.parse(SRC).getroot()
tags = lambda el: {t.get('k'): t.get('v') for t in el.findall('tag')}
N = {n.get('id'): (float(n.get('lon')), float(n.get('lat'))) for n in root.iter('node')}
NT = {n.get('id'): tags(n) for n in root.iter('node') if n.find('tag') is not None}
W = {}
for w in root.iter('way'):
    pts = [N[nd.get('ref')] for nd in w.findall('nd') if nd.get('ref') in N]
    W[w.get('id')] = (tags(w), pts)
P0 = Point(fw(LON, LAT))
geom = lambda pts: (Polygon([fw(*p) for p in pts]) if len(pts) >= 4 and pts[0] == pts[-1] else LineString([fw(*p) for p in pts])) if len(pts) >= 2 else None

platforms = []
for wid, (t, pts) in W.items():
    if t.get('railway') == 'platform' or (t.get('public_transport') == 'platform' and (t.get('train') == 'yes' or t.get('subway') == 'yes' or t.get('light_rail') == 'yes')):
        g = geom(pts)
        if g is not None and g.distance(P0) < 500:
            platforms.append({'osm_id': 'w' + wid, 'ref': t.get('ref') or t.get('local_ref') or t.get('name'), 'level': t.get('level'), 'g': g})
stations = [geom(pts) for wid, (t, pts) in W.items() if t.get('building') in ('train_station', 'transportation') or t.get('railway') == 'station']
stations = [s for s in stations if s is not None and s.distance(P0) < 300]
REGLINES = []
if len(sys.argv) > 7 and sys.argv[7]:   # the register's platform track lines (pack *_platform_*.geojson): widen the zone where OSM lacks platforms
    for f in json.load(open(sys.argv[7]))['features']:
        if f['geometry']['type'] == 'LineString':
            REGLINES.append(LineString([fw(*c) for c in f['geometry']['coordinates']]))
zone = unary_union([p['g'].buffer(25) for p in platforms] + [s.buffer(40) for s in stations] + [P0.buffer(60)] + [l.buffer(30) for l in REGLINES])
streets = [(t.get('name'), geom(pts)) for wid, (t, pts) in W.items() if t.get('highway') in (
    'primary', 'secondary', 'tertiary', 'residential', 'unclassified', 'pedestrian', 'living_street', 'service') and t.get('name') and len(pts) > 1]

def reaches(g, tol=6):
    return sorted({p['ref'] for p in platforms if p['ref'] and p['g'].distance(g) < tol})

bw = Transformer.from_crs(EPSG, 4326, always_xy=True).transform

def lonlat(g):
    c = g.representative_point() if g.geom_type != 'Point' else g
    x, y = bw(c.x, c.y)
    return round(x, 7), round(y, 7)

def where_is(g):
    inb = any(st.geom_type == 'Polygon' and st.buffer(1).contains(g) for st in stations)
    dp = min((p['g'].distance(g) for p in platforms), default=None)
    return {'in_station_building': inb, 'to_nearest_platform_m': round(dp, 1) if dp is not None else None}

EXTRA = ('brand', 'cuisine', 'website', 'contact:website', 'addr:unit', 'ref', 'operator', 'indoor', 'payment:coins')

out = {'clack_id': CID, 'source': 'OpenStreetMap, API 0.6 map call', 'licence': 'ODbL', 'platforms': [], 'connections': [], 'entrances': [], 'amenities': []}
for p in platforms:
    out['platforms'].append({'osm_id': p['osm_id'], 'ref': p['ref'], 'level': p['level']})
for wid, (t, pts) in W.items():
    g = geom(pts)
    if g is None or not zone.intersects(g):
        continue
    kind = None
    if t.get('highway') == 'elevator' or t.get('elevator') == 'yes':
        kind = 'lift'
    elif t.get('conveying') or t.get('highway') == 'escalator':
        kind = 'escalator'
    elif t.get('highway') == 'steps':
        kind = 'stairs'
    elif t.get('highway') in ('footway', 'path', 'corridor', 'cycleway', 'pedestrian') and (t.get('tunnel') in ('yes', 'building_passage') or t.get('bridge') == 'yes'):
        kind = 'underpass' if t.get('tunnel') else 'footbridge'
    elif t.get('highway') in ('footway', 'path', 'corridor') and t.get('incline') and t.get('ramp') != 'no':
        kind = 'ramp'
    if kind:
        out['connections'].append({'kind': kind, 'osm_id': 'w' + wid, 'name': t.get('name'), 'level': t.get('level'), 'layer': t.get('layer'),
                                   'conveying': t.get('conveying'), 'wheelchair': t.get('wheelchair'), 'ramp': t.get('ramp'),
                                   'length_m': round(g.length, 1), 'reaches_platforms': reaches(g), 'lonlat': lonlat(g)})
for nid, t in NT.items():
    g = Point(fw(*N[nid]))
    if not zone.intersects(g):
        continue
    if t.get('highway') == 'elevator':
        out['connections'].append({'kind': 'lift', 'osm_id': 'n' + nid, 'name': t.get('name'), 'level': t.get('level'), 'wheelchair': t.get('wheelchair'),
                                   'reaches_platforms': reaches(g, 10), 'lonlat': lonlat(g)})
    if t.get('entrance') or t.get('railway') in ('subway_entrance', 'train_station_entrance'):
        st = min(((s.distance(g), n) for n, s in streets if s is not None), default=(None, None))
        out['entrances'].append({'osm_id': 'n' + nid, 'name': t.get('name') or t.get('ref'), 'entrance': t.get('entrance') or t.get('railway'),
                                 'level': t.get('level'), 'wheelchair': t.get('wheelchair'), 'door': t.get('door'),
                                 'addr_street': t.get('addr:street'), 'nearest_named_street': st[1] if st[0] is not None and st[0] < 40 else None,
                                 'nearest_street_m': round(st[0], 1) if st[0] is not None else None, 'lonlat': lonlat(g)})
    if t.get('amenity') or t.get('shop') or t.get('vending'):
        out['amenities'].append({'osm_id': 'n' + nid, 'category': t.get('amenity') or ('shop=' + t['shop'] if t.get('shop') else 'vending=' + t.get('vending', '')),
                                 'name': t.get('name') or t.get('brand') or t.get('operator'), 'level': t.get('level'), 'fee': t.get('fee'),
                                 'opening_hours': t.get('opening_hours'), 'wheelchair': t.get('wheelchair'),
                                 'distance_m': round(g.distance(P0)), 'lonlat': lonlat(g), **where_is(g),
                                 **{k: t[k] for k in EXTRA if k in t}})
for wid, (t, pts) in W.items():
    if (t.get('amenity') or t.get('shop')) and len(pts) > 2:
        g = geom(pts)
        if g is not None and zone.intersects(g):
            out['amenities'].append({'osm_id': 'w' + wid, 'category': t.get('amenity') or 'shop=' + t['shop'], 'name': t.get('name') or t.get('brand'),
                                     'level': t.get('level'), 'fee': t.get('fee'), 'opening_hours': t.get('opening_hours'),
                                     'distance_m': round(g.distance(P0)), 'lonlat': lonlat(g), 'drawn_as': 'area', **where_is(g),
                                     **{k: t[k] for k in EXTRA if k in t}})
json.dump(out, open(OUT, 'w'), ensure_ascii=False, indent=1)
print(CID, 'platforms', len(out['platforms']), 'connections', len(out['connections']), 'entrances', len(out['entrances']), 'amenities', len(out['amenities']))
