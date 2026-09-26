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
cp /tmp/fartpack-latest.zip "$SRV/world/datapacks/fartpack.zip"
GOT=$(sha1sum "$SRV/world/datapacks/fartpack.zip" | cut -d' ' -f1)
WANT=$(sha1sum /tmp/fartpack-latest.zip | cut -d' ' -f1)
echo "  installed: $GOT"
echo "  expected : $WANT"
[ "$GOT" = "$WANT" ] || { echo "  ABORT: copy did not match what we built"; exit 1; }

echo
echo "=== enable + reload ==="
python3 /tmp/rcon.py 'datapack enable "file/fartpack.zip"' 'datapack list' 'reload'

sleep 6
echo
echo "=== log: any failed function loads? (whole file is valid for a RELOAD) ==="
echo "  count: $(grep -c 'Failed to load function fartpack' "$SRV/logs/latest.log" || true)"
grep -iE 'Failed to load|Error loading|Unknown block|problems? (were|was) found|Unknown registry key' "$SRV/logs/latest.log" | grep -v quickdeath | tail -20 || echo "  (clean)"

echo
echo "=== state after reload ==="
python3 /tmp/rcon.py \
  'scoreboard objectives list' \
  'list'

sleep 4
echo
echo "=== internal counters ==="
python3 /tmp/rcon.py \
  'execute if score #loaded fart.var matches 19 run say GATE_ok_loaded19' \
  'execute if score #loaded fart.var matches 18 run say WARN_still_18' \
  'execute if score #rc fart.var matches 0.. run say reap_counter_live' \
  'execute if score #scan_c fart.var matches 0..30 run say scan_cycle_live' \
  'execute if score #enabled fart.var matches 1 run say enabled_ok'

sleep 3
echo
echo "=== last 25 log lines (sanity) ==="
tail -25 "$SRV/logs/latest.log"
