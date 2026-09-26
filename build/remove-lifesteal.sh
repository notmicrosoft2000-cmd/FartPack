#!/usr/bin/env bash
# remove-lifesteal.sh - take the lifesteal datapack out of the world.
#
# Run on the server. Deliberately does NOT reload: removing a datapack takes effect
# on the next reload, and reloading needs an empty server. The v25 deploy performs
# that reload, so lifesteal disappears in the same operation and there is only ever
# one reload to reason about.
#
# The pack is backed up to ~/crafty/removed-datapacks/ FIRST and verified by hash.
# That directory is outside world/datapacks, so the backup can never be loaded by
# accident, and the removal is reversible by copying it back.
set -euo pipefail

SRV="$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457"
DP="$SRV/world/datapacks"
NAME="lifesteal_1.21.11.zip"
BACKUP="$HOME/crafty/removed-datapacks"

echo "=== 0 players? (we are not reloading, but a datapack command is still a command) ==="
ONLINE=$(python3 /tmp/rcon.py 'list' 2>/dev/null \
         | grep -oE 'There are [0-9]+ of' | grep -oE '[0-9]+' | head -1)
echo "  players online: ${ONLINE:-unknown}"
echo "  (no reload in this script, so this is informational only)"

echo
echo "=== is it enabled right now? ==="
python3 /tmp/rcon.py 'datapack list' 2>/dev/null | tr ' ' '\n' | grep -F "$NAME" || true

echo
echo "=== back it up before touching anything ==="
mkdir -p "$BACKUP"
if [ ! -f "$DP/$NAME" ]; then
  echo "  $NAME is not in datapacks/ - already removed? Nothing to do."
  exit 0
fi
cp "$DP/$NAME" "$BACKUP/$NAME"
A=$(sha256sum "$DP/$NAME" | cut -d' ' -f1)
B=$(sha256sum "$BACKUP/$NAME" | cut -d' ' -f1)
echo "  original: $A"
echo "  backup  : $B"
if [ "$A" != "$B" ]; then
  echo "  FATAL: backup does not match. Refusing to remove the original."
  exit 1
fi
echo "  backup verified, byte-identical."

echo
echo "=== disable, then move the file out of datapacks/ ==="
# `datapack disable` is harmless if it is not enabled, and makes the intent explicit
# rather than relying on the pack silently vanishing on the next reload.
python3 /tmp/rcon.py "datapack disable \"file/$NAME\"" 2>/dev/null || \
  echo "  (disable reported nothing - probably was not enabled by that exact id)"
mkdir -p "$BACKUP/removed-from-datapacks"
mv "$DP/$NAME" "$BACKUP/removed-from-datapacks/$NAME"
echo "  moved to $BACKUP/removed-from-datapacks/$NAME"

echo
echo "=== datapacks/ now contains ==="
ls -1 "$DP"

echo
echo "=== still enabled until a reload? (expected: yes, this is why we wait) ==="
python3 /tmp/rcon.py 'datapack list' 2>/dev/null | tr ' ' '\n' | grep -F "$NAME" \
  && echo "  ^ still listed - it drops off at the next reload, which the v25 deploy does." \
  || echo "  already gone from the enabled list."

echo
echo "OK. Lifesteal is backed up and out of datapacks/. It stops existing at the next"
echo "reload. Nothing else was touched: pwr and Graves are still exactly as they were."
