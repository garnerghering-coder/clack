#!/bin/bash
# run_no.sh CODE JOB : bundle + 3D pack + docs for one Norwegian station from its hoydedata.no point-cloud export
CODE=$1; JOB=$2
cd /home/claude/work
NAME=$(python3 -c "import json; print(json.load(open('/home/claude/no/no_stations.json'))['$CODE']['name'])")
FILES=$(find /home/claude/no/pc/$JOB -name "*.laz" -o -name "*.las")
python3 make_no_bundle.py $CODE /home/claude/bundles/NO-$CODE $FILES || exit 1
python3 station_pack.py /home/claude/bundles/NO-$CODE /home/claude/packs_no/NO-$CODE > /home/claude/packs_no/NO-$CODE.log 2>&1 || { tail -8 /home/claude/packs_no/NO-$CODE.log; exit 1; }
mkdir -p notes_no; touch notes_no/NO-$CODE.md
python3 gen_docs.py /home/claude/packs_no/NO-$CODE "$NAME" notes_no/NO-$CODE.md
python3 - <<PY
import json; r=json.load(open('/home/claude/packs_no/NO-$CODE/_report.json'))
print('$CODE', 'surface', r['platform_surface_m'], 'bed', r['track_bed_m'], 'structures', r['structures'], 'flags', len(r['flags']))
for p in r['platforms']: print('  ', p['bis_object'], p['track'], p['height_class'], p['track_bed_m'], p['platform_surface_m'], p.get('surface_minus_bed_m'), p.get('laser_estimate_above_rail_m'), p.get('note',''))
PY
