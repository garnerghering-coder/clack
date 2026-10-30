"""Cross-track ground profile per BanInfo platform: python3 profile.py <clack id> [bis ...]
Prints the median ground-class z in 1 m bins from −12 to +12 m (+ = left of the track line's direction), and BanInfo SIDE."""
import json, sys, glob, numpy as np, laspy, shapely
from shapely.geometry import LineString
from pyproj import Transformer
fw = Transformer.from_crs(4326, 3006, always_xy=True).transform
ID = sys.argv[1]; want = set(sys.argv[2:])
import os
B = os.path.join(os.environ.get('STATION3D_BUNDLES', 'bundles'), ID); meta = json.load(open(B + '/meta.json'))
l = laspy.read(glob.glob(os.path.join(os.environ.get('STATION3D_RESEARCH', 'data/stations/research'), ID, '*.laz'))[0])
X, Y, Z, C = np.asarray(l.x), np.asarray(l.y), np.asarray(l.z), np.asarray(l.classification)
for f in meta['baninfo']['plat']:
    if want and f['BisObjektNr'] not in want:
        continue
    p = [float(v) for v in f['Points'].split()]
    L = LineString([fw(p[i + 1], p[i]) for i in range(0, len(p) - 1, 2)])
    bb = L.buffer(15).bounds
    idx = np.where((X > bb[0]) & (X < bb[2]) & (Y > bb[1]) & (Y < bb[3]) & (C == 2))[0]
    if not len(idx):
        continue
    s = shapely.line_locate_point(L, shapely.points(X[idx], Y[idx]))
    a = shapely.line_interpolate_point(L, np.maximum(s - 1, 0)); b = shapely.line_interpolate_point(L, np.minimum(s + 1, L.length))
    q = shapely.line_interpolate_point(L, s)
    tx = shapely.get_x(b) - shapely.get_x(a); ty = shapely.get_y(b) - shapely.get_y(a); n = np.hypot(tx, ty) + 1e-9
    d = (X[idx] - shapely.get_x(q)) * (-ty / n) + (Y[idx] - shapely.get_y(q)) * (tx / n)
    inr = (s > 2) & (s < L.length - 2)
    prof = []
    for lo in range(-12, 12):
        zz = Z[idx][inr & (d >= lo) & (d < lo + 1)]
        prof.append(f"{np.median(zz):6.2f}" if len(zz) > 4 else '   -- ')
    print(f"{f['BisObjektNr']:>5} {f['Höjd'][:5]:5} w{f['Bredd_m']:>4} SIDE {f['SIDE']} |" + ''.join(prof))
print('bins: ' + ' '.join(str(x) for x in range(-12, 12)))
