#!/bin/bash
# finish_dk.sh: station facts for the Danish folders (register-only until the 3D pass)
cd /home/claude/work
python3 -c "import json;[print(s['clack_id'], s['safe']) for s in json.load(open('/home/claude/dk/dk_stations.json'))]" | while read cid safe; do
  PACK_DIR=/home/claude/packs_dk OSMFACTS_DIR=/home/claude/osmfacts_dk FACTS_MANUAL_DIR=/home/claude/work/facts_manual_dk python3 facts.py "$cid" /home/claude/packs_dk/$safe | tail -1
done
