#!/bin/bash
# finish_fi.sh [codes...]: station facts + docs for Finnish packs
cd /home/claude/work
CODES=${@:-$(python3 -c "import json;print(' '.join(s['code'] for s in json.load(open('/home/claude/fi/fi_stations.json'))))")}
for c in $CODES; do
  id=FI-$c; name=$(python3 -c "import json; print({x['code']:x for x in json.load(open('/home/claude/fi/fi_stations.json'))}['$c']['name'])")
  PACK_DIR=/home/claude/packs_fi OSMFACTS_DIR=/home/claude/osmfacts_fi FACTS_MANUAL_DIR=/home/claude/work/facts_manual_fi python3 facts.py $id /home/claude/packs_fi/$id | tail -1
  touch notes_fi/$id.md; python3 gen_docs.py /home/claude/packs_fi/$id "$name" notes_fi/$id.md > /dev/null
done
