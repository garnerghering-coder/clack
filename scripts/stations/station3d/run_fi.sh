#!/bin/bash
# run_fi.sh CODE [margin]: bundle + pack + docs for a Finnish station on the national 0.5 p laser
CODE=$1; M=${2:-110}
cd /home/claude/work
read E0 N0 E1 N1 SHEETS <<< $(python3 -c "
import json; s={x['code']:x for x in json.load(open('/home/claude/fi/fi_stations.json'))}['$CODE']; b=s['platform_bounds_3067']
print(b[0]-$M, b[1]-$M, b[2]+$M, b[3]+$M, ' '.join(x.split()[0] for x in s['mml_sheets']))")
FILES=$(for sh in $SHEETS; do echo /mnt/user-data/uploads/Downloads/clack_station3d/raw_bundles/FI/clack_fi_mml05_$sh.laz; done)
python3 make_fi_bundle.py $CODE /home/claude/bundles/FI-$CODE mml05 $E0 $N0 $E1 $N1 $FILES || exit 1
python3 station_pack.py /home/claude/bundles/FI-$CODE /home/claude/packs_fi/FI-$CODE > /home/claude/packs_fi/FI-$CODE.log 2>&1 || { tail -5 /home/claude/packs_fi/FI-$CODE.log; exit 1; }
NAME=$(python3 -c "import json; print({x['code']:x for x in json.load(open('/home/claude/fi/fi_stations.json'))}['$CODE']['name'])")
touch notes_fi/FI-$CODE.md
python3 gen_docs.py /home/claude/packs_fi/FI-$CODE "$NAME" notes_fi/FI-$CODE.md
python3 -c "
import json; r=json.load(open('/home/claude/packs_fi/FI-$CODE/_report.json'))
print('$CODE', 'scan', r['laser']['scan_date'], 'dens', r['laser']['density_in_box'], 'surface', r['platform_surface_m'], 'bed', r['track_bed_m'], 'trains', r['trains_in_scan'], 'flags', len(r['flags']))
for p in r['platforms']: print('  ', p['bis_object'], p['height_class'], p.get('track_bed_m'), p.get('platform_surface_m'), p.get('surface_minus_bed_m'), p.get('platform_points'), (p.get('note') or '')[:60])"
