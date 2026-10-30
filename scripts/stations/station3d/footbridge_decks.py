"""Footbridge deck levels at a station, from the laser in its pack.

python3 footbridge_decks.py <pack dir> <OSM API 0.6 extract (.osm)> [epsg]   -> writes <pack>/footbridge_decks.json

Which bridges: OSM ways tagged bridge=* that are footways/paths/cycleways/corridors/steps (or man_made=bridge areas) and
cross one of the register's platform track lines (the *_platform_*.geojson in the pack) or come within 8 m of one.
What is measured, per bridge, on a 1.2 m-wide strip along the OSM line, over the part that lies above the tracks
(within 8 m of a platform track line):
  - deck_top_m: median of the bridge-deck class (Lantmäteriet/Helsinki class 17) points = the open deck's walking surface
    (plus railings and anything lying on it; p10/p90 given);
  - top_surface_m: median of non-ground object points (class 1, or 6 where buildings are classed) more than 2 m above
    that deck, or above the platform when no deck points exist. Without deck-class points this surface is EITHER an open
    deck that the classification left unclassified (railings included) OR the roof of an enclosed bridge: the laser alone
    cannot tell which, so deck_top_m stays null and the bridge is flagged (OSM covered=*, photos or a drawing decide).
Heights in the pack's vertical datum; *_above_platform_m = minus the pack's platform surface.
Nothing is interpolated or assumed; no deck thickness or clearance is derived.
"""
import json, sys, glob, os
import numpy as np, laspy, shapely
import xml.etree.ElementTree as ET
from shapely.geometry import LineString, Polygon
from pyproj import Transformer

P, OSM = sys.argv[1], sys.argv[2]
EPSG = int(sys.argv[3]) if len(sys.argv) > 3 else 3006
rep = json.load(open(f'{P}/_report.json'))
REF, BED = rep['platform_surface_m'], rep['track_bed_m']
fw = Transformer.from_crs(4326, EPSG, always_xy=True).transform
regf = glob.glob(f'{P}/*_platform_*.geojson')
tracks = []
for f in json.load(open(regf[0]))['features'] if regf else []:
    if f['geometry']['type'] == 'LineString':
        tracks.append((f['properties'].get('track'), LineString([fw(*c) for c in f['geometry']['coordinates']])))
TR = shapely.union_all([t for _, t in tracks]) if tracks else None
root = ET.parse(OSM).getroot()
N = {n.get('id'): (float(n.get('lon')), float(n.get('lat'))) for n in root.iter('node')}
tg = lambda e: {t.get('k'): t.get('v') for t in e.findall('tag')}
laz = glob.glob(f'{P}/*_laser_station_*.laz')[0]
l = laspy.read(laz)
X, Y, Z, C = np.asarray(l.x), np.asarray(l.y), np.asarray(l.z), np.asarray(l.classification)
OBJ = np.isin(C, [1, 6])
out = []
for w in root.iter('way'):
    t = tg(w)
    footish = t.get('highway') in ('footway', 'path', 'cycleway', 'corridor', 'steps', 'pedestrian') or t.get('man_made') == 'bridge'
    if not (footish and (t.get('bridge') not in (None, 'no') or t.get('man_made') == 'bridge')):
        continue
    pts = [fw(*N[nd.get('ref')]) for nd in w.findall('nd') if nd.get('ref') in N]
    if len(pts) < 2 or TR is None:
        continue
    g = Polygon(pts) if t.get('man_made') == 'bridge' and len(pts) >= 4 and pts[0] == pts[-1] else LineString(pts)
    if g.distance(TR) > 8:
        continue
    strip = (g.buffer(-0.6) if g.geom_type == 'Polygon' and g.area > 30 else g.buffer(0.6)).intersection(TR.buffer(8))
    if strip.is_empty:
        continue
    inn = shapely.contains_xy(strip, X, Y)
    z17 = Z[inn & (C == 17)]
    over = sorted({tr for tr, line in tracks if line.distance(g) < 1.0})
    rec = {'osm_id': 'w' + w.get('id'), 'name': t.get('name') or t.get('bridge:name'), 'osm_tags': {k: t[k] for k in ('highway', 'bridge', 'layer', 'level', 'covered', 'indoor', 'man_made') if k in t},
           'crosses_register_tracks': over, 'strip_area_m2': round(strip.area), 'points_class17': int(len(z17)),
           'platform_surface_m': REF, 'track_bed_m': BED}
    deck = float(np.median(z17)) if len(z17) >= 8 else None
    base = deck if deck is not None else (REF if REF is not None else -1e9)
    zr = Z[inn & OBJ & (Z > base + 2.0)]
    roof = float(np.median(zr)) if len(zr) >= 8 else None
    if deck is not None:
        rec.update(deck_top_m=round(deck, 2), deck_p10_p90_m=[round(float(np.percentile(z17, 10)), 2), round(float(np.percentile(z17, 90)), 2)],
                   deck_above_platform_m=round(deck - REF, 2) if REF is not None else None,
                   deck_above_track_bed_m=round(deck - BED, 2) if BED is not None else None)
    else:
        rec.update(deck_top_m=None)
    if roof is not None:
        rec.update(top_surface_m=round(roof, 2), top_surface_points=int(len(zr)), top_surface_above_platform_m=round(roof - REF, 2) if REF is not None else None)
    rec['osm_covered'] = t.get('covered')
    rec['osm_start_date'] = t.get('start_date')
    if deck is None and roof is not None:
        rec['note'] = ('no bridge-deck class: the top surface is either the open deck (unclassified) or the roof of an enclosed bridge; deck level not measured'
                       + ('; OSM says covered=' + t['covered'] if t.get('covered') else '; OSM has no covered tag'))
    elif deck is None:
        rec['note'] = 'no deck-class or roof points on the strip (too few points, or the bridge is newer than the scan ' + str(rep['laser']['scan_date']) + ')'
    elif roof is not None:
        rec['note'] = 'deck seen (bridge class) and a higher surface over parts of it (roof, canopy or lift tower)'
    out.append(rec)
json.dump({'what': 'footbridge deck and roof levels over the platform tracks', 'method': __doc__.split('What is measured')[1].split('Nothing is')[0].strip(),
           'source': f"laser {os.path.basename(laz)} (scan {rep['laser']['scan_date']}); bridge lines and tags: OpenStreetMap (ODbL), {os.path.basename(OSM)}; track lines: {os.path.basename(regf[0]) if regf else '-'}",
           'bridges': out}, open(f'{P}/footbridge_decks.json', 'w'), ensure_ascii=False, indent=1)
for r in out:
    print(json.dumps(r, ensure_ascii=False))
