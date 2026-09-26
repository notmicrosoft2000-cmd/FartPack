#!/usr/bin/env bash
# Deploy the datapack and verify.
#
# The player-count gate here is a real gate, not a printout. During the v19 deploy
# the check was echoed and a player was online for the reload anyway. If you cannot
# prove 0 players, do not deploy.
#
# NOTE: vanilla ROTATES logs/latest.log on every boot, so the "new log lines"
# window below is only valid for a reload. After a restart, use postrestart.sh,
# which checks the whole fresh file and asserts the Done line is present.
set -euo pipefail
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
cd /tmp

echo "=== GATE: 0 players online (aborts otherwise) ==="
ONLINE=$(python3 /tmp/rcon.py 'list' 2>/dev/null \
         | grep -oE 'There are [0-9]+ of' | grep -oE '[0-9]+' | head -1)
echo "  players online: ${ONLINE:-unknown}"
if [ -z "${ONLINE:-}" ]; then
  echo "  ABORT: could not determine the player count. Refusing to deploy blind."
  exit 1
fi
if [ "$ONLINE" != "0" ]; then
  echo "  ABORT: $ONLINE player(s) online. Wait for an empty server."
  exit 1
fi

echo
echo "=== installing ==="
# The lint/deploy handshake. lint.sh writes the hash of the zip it actually
# parse-tested; if the zip has changed since, the gate validated a build that is
# not the one about to go live and installing it would make the gate a lie.
# This is the #30 failure, mechanically prevented rather than remembered.
if [ -f /tmp/linted.sha1 ]; then
  LINTED=$(cut -d' ' -f1 /tmp/linted.sha1)
  NOW=$(sha1sum /tmp/fartpack-latest.zip | cut -d' ' -f1)
  echo "  linted : $LINTED"
  echo "  on disk: $NOW"
  if [ "$LINTED" != "$NOW" ]; then
    echo "  ABORT: the zip changed after it was linted. Re-run lint.sh, then deploy."
    exit 1
  fi
  echo "  lint/deploy handshake OK - this is the build that was parse-tested."
else
  echo "  ABORT: no /tmp/linted.sha1 - the pack was never linted. Run lint.sh first."
  exit 1
fi

cp /tmp/fartpack-latest.zip "$SRV/world/datapacks/fartpack.zip"
GOT=$(sha1sum "$SRV/world/datapacks/fartpack.zip" | cut -d' ' -f1)
WANT=$(sha1sum /tmp/fartpack-latest.zip | cut -d' ' -f1)
echo "  installed: $GOT"
echo "  expected : $WANT"
[ "$GOT" = "$WANT" ] || { echo "  ABORT: copy did not match what we built"; exit 1; }

echo
echo "=== enable + reload ==="
# Record where the log ends BEFORE the reload. A reload does NOT rotate
# latest.log (only a boot does), so a whole-file grep counts failures from
# previous deploys forever and there is no way to tell a fresh break from an
# old one. Everything below is scoped to lines this reload actually added.
LOGLINES=$(wc -l < "$SRV/logs/latest.log" 2>/dev/null || echo 0)
# Clear the "config layer is verified" flag BEFORE the reload, not after. If this
# deploy breaks the config layer, the flag must already be 0 so that nothing
# waiting on it acts on a stale 1. Clearing afterwards would leave a window where
# a failed deploy still looks verified. crown.sh waits on this flag.
python3 /tmp/rcon.py 'scoreboard players reset #cfgok fart.var' >/dev/null 2>&1 || true
python3 /tmp/rcon.py 'datapack enable "file/fartpack.zip"' 'datapack list' 'reload'

sleep 6
echo
echo "=== log: any failed function loads since THIS reload? ==="
NEWLOG=$(tail -n "+$((LOGLINES+1))" "$SRV/logs/latest.log" 2>/dev/null || true)
BAD=$(printf '%s' "$NEWLOG" | grep -c 'Failed to load function fartpack' || true)
echo "  failed function loads: $BAD"
printf '%s' "$NEWLOG" \
  | grep -iE 'Failed to load|Error loading|Unknown block|problems? (were|was) found|Unknown registry key' \
  | grep -v quickdeath | tail -20 || echo "  (clean)"

# This is the check that should have stopped #30 on the v26 deploy. It PRINTED
# "count: 2" - naming two files that would not load at all - and the deploy
# continued regardless, while the parse lint that should have caught them first
# was reading a stale tarball. Three independent things failed to stop a broken
# pack going live, so this one aborts.
if [ "${BAD:-0}" -ne 0 ]; then
  echo
  echo "  ABORT: $BAD function(s) failed to load in the pack just installed."
  echo "  It is live but INCOMPLETE - affected features silently do nothing."
  echo "  Fix and redeploy; do not report this version as working."
  exit 1
fi
echo "  all functions loaded."

echo
echo "=== state after reload ==="
python3 /tmp/rcon.py \
  'scoreboard objectives list' \
  'list'

sleep 4
echo
echo "=== internal counters ==="
# Compare the live version gate against what we just deployed. Pass the expected
# version explicitly: ./deploy.sh 20. A hand-typed number in two places is how
# the previous check drifted out of sync with the pack.
EXPECT="${1:-}"
python3 /tmp/rcon.py \
  'scoreboard players get #loaded fart.var' \
  'scoreboard players get #rc fart.var' \
  'scoreboard players get #scan_c fart.var' \
  'scoreboard players get #enabled fart.var' 2>/dev/null \
  | grep -E 'has [0-9-]+|none is set' | sed 's/^/  /'
if [ -n "$EXPECT" ]; then
  LIVE=$(python3 /tmp/rcon.py 'scoreboard players get #loaded fart.var' 2>/dev/null \
         | grep -oE 'has [0-9-]+' | grep -oE '[0-9-]+$')
  if [ "$LIVE" = "$EXPECT" ]; then
    echo "  version gate OK: #loaded=$LIVE (expected $EXPECT)"
  else
    echo "  MISMATCH: #loaded=$LIVE but we deployed $EXPECT -- bootstrap did not run"
  fi
fi

sleep 3
echo
echo "=== last 25 log lines (sanity) ==="
tail -25 "$SRV/logs/latest.log"
