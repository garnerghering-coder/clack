#!/bin/bash
# finish_all.sh [ids...]: rerun finish.sh for the given packs (default: all), names from each pack's README title
cd /home/claude/work
IDS=${@:-$(ls /home/claude/packs | grep '^7400')}
for id in $IDS; do
  name=$(head -1 /home/claude/packs/$id/README.md | sed -E 's/^# (.*) \(`.*$/\1/')
  ./finish.sh $id "$name" 2>&1 | head -1
done
