#!/bin/zsh
# Pull the server's backups and data archive to this Mac (docs/SERVER.md "Backups"). Run by launchd once a day
# (app.clack.backup.plist); safe to run by hand. Copies only what's new: the database copies, and the
# observed record and raw timetable copies, which are written once and never change.
set -eu
HOST=root@2.29.143.151
KEY=$HOME/.ssh/clack_oracle
DEST=$HOME/ClackBackups
SSH=(ssh -i $KEY -o BatchMode=yes -o ConnectTimeout=20)
mkdir -p $DEST/db $DEST/observed $DEST/archive
log() { print -r -- "$(date '+%F %T') $*" >> $DEST/pull.log }
"${SSH[@]}" $HOST true 2>/dev/null || { log "server not reachable"; exit 0 }
# A folder that doesn't exist yet (a fresh server) is skipped, not an error.
pull() {
  if "${SSH[@]}" $HOST "test -d $1"; then
    rsync -a -e "${SSH[*]}" $HOST:$1/ $2/ || log "rsync $1 failed ($?)"
  fi
}
pull /home/clack/backups $DEST/db
pull /home/clack/clack/data/observed $DEST/observed
pull /home/clack/clack/data/archive $DEST/archive
# Tell the server when the last pull was, so /api/health can say when backups fall behind.
"${SSH[@]}" $HOST "touch /home/clack/backups/.last-pull"
log "pulled: $(du -sh $DEST | cut -f1)"
