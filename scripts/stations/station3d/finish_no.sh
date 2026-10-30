#!/bin/bash
# finish_no.sh [codes...]: station facts + footbridge decks + docs for Norwegian packs
cd /home/claude/work
for c in "$@"; do
  id=NO-$c; name=$(python3 -c "import json; print(json.load(open('/home/claude/no/no_stations.json'))['$c']['name'])")
  PACK_DIR=/home/claude/packs_no OSMFACTS_DIR=/home/claude/osmfacts_no FACTS_MANUAL_DIR=/home/claude/work/facts_manual_no python3 facts.py $id /home/claude/packs_no/$id | tail -1
  python3 footbridge_decks.py /home/claude/packs_no/$id /home/claude/osmx_no/$id.osm 25832 > /dev/null 2>&1 || echo "  footbridge_decks failed $c"
  touch notes_no/$id.md; python3 gen_docs.py /home/claude/packs_no/$id "$name" notes_no/$id.md > /dev/null
done
