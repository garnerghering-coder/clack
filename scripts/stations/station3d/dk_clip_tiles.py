"""clip.py: per station, cut its DHM punktsky 1 km tiles to the station box (dk_tiles.json box_utm32 + 10 m), one file per tile."""
import json, os, sys, laspy, numpy as np
H = os.environ['HOME']
T = json.load(open(f'{H}/mnt/clack/data/stations/research/_sources/DK/dk_tiles.json'))['stations']
SRC = f'{H}/mnt/Downloads/clack_station3d/raw_bundles/DK/punktsky'
OUT = f'{H}/mnt/Downloads/clack_station3d/raw_bundles/DK/punktsky_clip'
for safe, v in T.items():
    if sys.argv[1:] and safe not in sys.argv[1:]:
        continue
    files = [f"{SRC}/PUNKTSKY_1km_{t}.laz" for t in v['tiles_1km']]
    if not all(os.path.exists(f) for f in files):
        continue
    od = f'{OUT}/{safe}'
    if os.path.exists(f'{od}/.done'):
        continue
    os.makedirs(od, exist_ok=True)
    e0, n0, e1, n1 = v['box_utm32']
    for f in files:
        with laspy.open(f) as rd, laspy.open(f'{od}/{os.path.basename(f)}', mode='w', header=rd.header) as wr:
            for pts in rd.chunk_iterator(2_000_000):
                m = (pts.x >= e0 - 10) & (pts.x < e1 + 10) & (pts.y >= n0 - 10) & (pts.y < n1 + 10)
                if m.any():
                    wr.write_points(pts[m])
    open(f'{od}/.done', 'w').write('ok')
    print(safe, v['name'], sum(os.path.getsize(f'{od}/{os.path.basename(f)}') for f in files) // 1000000, 'MB')
