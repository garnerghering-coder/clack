#!/bin/bash
# run_dk.sh <safe id> <folder with that station's DHM punktsky 1 km LAZ tiles>
# Builds the 3D pack into data/stations/research/<safe id>/ next to the register-only files already there,
# then re-runs station facts (platform sides from the laser) and the docs.
SAFE=$1; TILES=$2
R=${STATION3D_RESEARCH:-data/stations/research}
HERE=$(cd "$(dirname "$0")" && pwd)
NAME=$(python3 -c "import json;print({s['safe']:s for s in json.load(open('$R/_sources/DK/dk_stations.json'))}['$SAFE']['name'])")
CID=$(python3 -c "import json;print({s['safe']:s for s in json.load(open('$R/_sources/DK/dk_stations.json'))}['$SAFE']['clack_id'])")
FILES=$(python3 -c "import json,glob,os;t=json.load(open('$R/_sources/DK/dk_tiles.json'))['stations']['$SAFE']['tiles_1km'];print(' '.join(f for f in glob.glob('$TILES/*.la[sz]') if any(x in os.path.basename(f) for x in t)))")
[ -z "$FILES" ] && { echo "no tiles for $SAFE in $TILES (need: see _sources/DK/dk_tiles.json)"; exit 1; }
B=${STATION3D_BUNDLES:-/tmp/station3d_bundles}/$SAFE
python3 $HERE/make_dk_bundle.py $SAFE $B $FILES || exit 1
python3 $HERE/station_pack.py $B $R/$SAFE || exit 1
PACK_DIR=$R OSMFACTS_DIR=$R/_sources/osm FACTS_MANUAL_DIR=$HERE/facts_manual_dk python3 $HERE/facts.py "$CID" $R/$SAFE | tail -1
python3 $HERE/footbridge_decks.py $R/$SAFE $R/_sources/DK/osm/$SAFE.osm 25832 > /dev/null 2>&1
touch $HERE/notes_dk/$SAFE.md 2>/dev/null || { mkdir -p $HERE/notes_dk; touch $HERE/notes_dk/$SAFE.md; }
rm -f $R/$SAFE/_register_only.json
python3 $HERE/gen_docs.py $R/$SAFE "$NAME" $HERE/notes_dk/$SAFE.md
