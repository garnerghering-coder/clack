"""Country platform CSV (Swedish columns) + REVIEW_platform_heights_<CC>.md from built packs.

python3 country_review.py NO <packs dir> <bundles dir> <out dir>
"""
import json, sys, glob, csv, os
CC, PACKS, BUNDLES, OUT = sys.argv[1:5]
cols = ['clack_id', 'station_name', 'bandel', 'tracks', 'bis_object', 'height_class', 'height_m', 'length_m', 'width_m', 'roof',
        'valid_from', 'source_row', 'remark']
rows, rev, n = [], [], 0
for rp in sorted(glob.glob(f'{PACKS}/*/_report.json')):
    r = json.load(open(rp))
    d = os.path.basename(os.path.dirname(rp))
    meta = json.load(open(f'{BUNDLES}/{d}/meta.json'))
    NAMES = json.load(open(os.environ.get('NO_STATIONS', '/home/claude/no/no_stations.json'))) if CC == 'NO' else {}
    name = (NAMES.get(d[3:], {}) or {}).get('name') or meta.get('name') or r.get('slug')
    bym = {p['BisObjektNr']: p for p in meta['baninfo']['plat']}
    for p in r['platforms']:
        f = bym.get(p['bis_object'], {})
        n += 1
        if CC == 'NO':
            rows.append(dict(clack_id=r['clack_id'], station_name=name, bandel='', tracks=','.join(f.get('x_covers_tracks') or []),
                             bis_object=p['bis_object'], height_class=f"{f.get('x_height_mm_bane_nor') or f.get('Höjd')} mm",
                             height_m=p['class_height_m'], length_m=p['length_m'], width_m=p['width_m'] or '', roof='',
                             valid_from='', source_row=f.get('_source', '').split('; geometry')[0], remark=f.get('x_geometry', '')))
        est, ch = p.get('laser_estimate_above_rail_m'), p.get('class_height_m')
        if est is not None and ch is not None and abs(est - ch) > 0.125:
            rev.append(f"| {r['clack_id']} | {p['bis_object']} | {p['track'] or '?'} | {p['height_class']} ({ch}) | {p['track_bed_m']} | "
                       f"{p['platform_surface_m']} | {p.get('surface_minus_bed_m')} | {est} | {' '.join(x for x in (p.get('note'), p.get('surface_note')) if x)} |")
if rows:
    with open(f'{OUT}/banenor_platforms_{CC}.csv', 'w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, cols); w.writeheader(); w.writerows(rows)
reg = {'NO': 'Bane NOR track table height (mm above rail)', 'DK': 'Banedanmark Bilag 3.6 height (cm above rail)'}[CC]
out = [f'# {CC}: platform heights, laser vs register (review list)', '',
       f"Laser 'surface − bed' minus 0.175 m (ballast to rail head, playbook 0.15–0.2 m) against the {reg}. Listed when they differ "
       'by more than 0.125 m. Nothing here is decided.', '',
       '| Station | Platform | Track | Register (m) | Bed (m) | Surface (m) | Surface − bed | ≈ above rail | Note |', '|---|---|---|---|---|---|---|---|---|']
out += rev + ['', f'{len(rev)} of {n} platforms differ by more than 0.125 m.', '']
open(f'{OUT}/REVIEW_platform_heights_{CC}.md', 'w').write('\n'.join(out))
print(CC, 'platforms', n, 'flagged', len(rev), 'csv rows', len(rows))
