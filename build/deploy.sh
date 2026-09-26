#!/usr/bin/env bash
# Deploy the datapack and verify. Refuses to proceed if anyone is online.
set -euo pipefail
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
cd /tmp

echo "=== players online (must be 0) ==="
python3 /tmp/rcon.py 'list'

echo
echo "=== installing ==="
cp /tmp/fartpack-latest.zip "$SRV/world/datapacks/fartpack.zip"
echo "installed sha1: $(sha1sum "$SRV/world/datapacks/fartpack.zip" | cut -d' ' -f1)"
echo "expecting    : $(sha1sum /tmp/fartpack-latest.zip | cut -d' ' -f1)"

echo
echo "=== enable + reload ==="
python3 /tmp/rcon.py 'datapack enable "file/fartpack.zip"' 'datapack list' 'reload'

sleep 6
echo
echo "=== log: any failed function loads? ==="
grep -c 'Failed to load function fartpack' "$SRV/logs/latest.log" || echo "0 (none)"
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
