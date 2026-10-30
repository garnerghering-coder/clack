#!/bin/bash
# Build one station pack from the browser bundle(s).
#   scripts/stations/station3d/run_station.sh <clack id> "<Station name>" <bundle.tar> [extra osm/commons .tar ...]
# Run from the repo root. Needs: pip install "laspy[lazrs]" numpy shapely rasterio pyproj pillow scipy
# Writes data/stations/research/<id>/ (the pack) and prints a short review: platform levels, trains, structures, flags.
set -e
ID=$1; NAME=$2; shift 2
HERE=$(cd "$(dirname "$0")" && pwd)
RESEARCH=${STATION3D_RESEARCH:-data/stations/research}
BUNDLES=${STATION3D_BUNDLES:-bundles}
mkdir -p "$BUNDLES"
for T in "$@"; do tar xf "$T" -C "$BUNDLES"; done            # main bundle first, then any *_osm.tar / *_commons.tar fixes
STATION3D_RESEARCH="$RESEARCH" python3 -I "$HERE/station_pack.py" "$BUNDLES/$ID" "$RESEARCH/$ID" > /dev/null
NOTES="$HERE/notes/$ID.md"
python3 "$HERE/gen_docs.py" "$RESEARCH/$ID" "$NAME" "$NOTES" > /dev/null
python3 - "$RESEARCH/$ID/_report.json" <<'EOF'
import json, sys
r = json.load(open(sys.argv[1]))
print(r['slug'], '| scan', r['laser']['scan_date'], r['laser']['density_in_box'], '/m2 | PLATFORM', r['platform_surface_m'], 'BED', r['track_bed_m'],
      '| trains', r['trains_in_scan'], '|', r['structures'], '| photos', r['photos'])
for n in r['notes']: print('  note:', n[:200])
for p in r['platforms']:
    print('  ', p['bis_object'], p['track'], p['height_class'], 'bed', p['track_bed_m'], 'surf', p['platform_surface_m'],
          'est', p.get('laser_estimate_above_rail_m'), p['platform_points'], (p.get('note') or '')[:70])
for f in r['flags']: print('  FLAG', f[:230])
EOF
