#!/bin/bash
# Drafts or refreshes the map of every hub and mid station (data/station_tiers.json) and every station with an edits
# file: register facts (import_platforms.py), the OSM draft (draft_from_osm.py), then the validator with coverage and
# the audit's questions. One Overpass request per new station, 60 s apart (Overpass's fair use). A station whose draft
# fails (no numbered platforms in OSM) is listed and skipped; a map with unconnected platforms ships with them marked.
# Usage, from the repo root: scripts/stations/official/batch.sh [station ids...]
cd "$(dirname "$0")/../../.."
HERE=scripts/stations/official
if [ $# -gt 0 ]; then IDS="$*"; else
  IDS=$(python3 -c "
import json, os
t = json.load(open('data/station_tiers.json'))['stations']
e = [f[:-11].replace('_', ':', 2) if f.startswith(('NSR_', 'fi_', 'gtfs_')) else f[:-11] for f in os.listdir('scripts/stations') if f.endswith('.edits.json')]
print(' '.join(sorted(set(t) | set(e))))")
fi
failed=()
for ID in $IDS; do
  python3 $HERE/new_edits.py "$ID"
  case $? in
    0) sleep 60 ;;          # a new Overpass request was made
    1) failed+=("$ID (no edits)"); continue ;;
  esac
  python3 $HERE/import_platforms.py "$ID" || failed+=("$ID (import)")
  python3 scripts/stations/draft_from_osm.py "$ID" > /tmp/clack-draft.log 2>&1 || { failed+=("$ID: $(tail -1 /tmp/clack-draft.log)"); continue; }
  head -1 /tmp/clack-draft.log
done
npm run -s stations:validate -- --coverage --review | grep -v '^✓'
python3 $HERE/osm_audit.py
if [ ${#failed[@]} -gt 0 ]; then printf 'not drafted: %s\n' "${failed[@]}"; fi
