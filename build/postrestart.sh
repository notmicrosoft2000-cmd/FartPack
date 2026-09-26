#!/usr/bin/env bash
# Post-restart verification against the NEW latest.log.
#
# The previous run of this check reported "0 Failed to load" over a line range
# that no longer existed: vanilla RENAMES latest.log to a dated .gz and starts a
# fresh one on every boot. Any line-number mark taken before a restart is
# therefore garbage afterwards -- always verify against the whole new file.
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
LOG="$SRV/logs/latest.log"

echo "=== the new log file ==="
ls -la "$LOG"
echo "  lines: $(wc -l < "$LOG")"
echo "  first : $(head -1 "$LOG" | cut -c1-90)"

echo
echo "=== did the server finish booting? (the 'Done' line) ==="
grep -n 'Done (.*)! For help' "$LOG" | tail -2 || echo "  NOT FOUND - still booting or failed"
tail -3 "$LOG" | sed 's/^/  /'

echo
echo "=== 'Failed to load function fartpack' in the ENTIRE new run ==="
N=$(grep -c 'Failed to load function fartpack' "$LOG" || true)
echo "  count: ${N:-0}"
grep 'Failed to load function fartpack' "$LOG" | head -10

echo
echo "=== every ERROR / exception in the new run (quickdeath is pre-existing) ==="
grep -nE 'ERROR|Exception|FATAL' "$LOG" | sed 's/^/  /' | head -20
echo "  (excluding known pre-existing lifesteal quickdeath noise: $(grep -cE 'ERROR|Exception|FATAL' "$LOG" || true) total)"

echo
echo "=== datapack list ==="
python3 /tmp/rcon.py 'datapack list' 2>/dev/null | grep -iE 'fartpack|enabled' | sed 's/^/  /'

echo
echo "=== FartPack state ==="
python3 /tmp/rcon.py \
  'scoreboard players get #loaded fart.var' \
  'scoreboard players get #enabled fart.var' \
  'scoreboard players get #scan_c fart.var' \
  'scoreboard players get #rc fart.var' 2>/dev/null \
  | grep -E 'has |none is set' | sed 's/^/  /'

echo
echo "=== objectives declared vs present ==="
python3 /tmp/rcon.py 'scoreboard objectives list' 2>/dev/null \
  | tr ',' '\n' | grep -oE 'fart\.[a-z_]+' | sort -u | tr '\n' ' ' | fold -w 100 | sed 's/^/  /'
echo

echo
echo "=== server health ==="
python3 /tmp/rcon.py 'tick query' 2>/dev/null | tail -1 | sed 's/^/  /'
python3 /tmp/rcon.py 'list' 2>/dev/null | tail -1 | sed 's/^/  /'

echo
echo "=== the properties the server booted WITH ==="
grep -E '^(resource-pack|require-resource-pack|pause-when-empty)' "$SRV/server.properties" \
  | sed -E 's/(hm=)[a-f0-9]+/\1<sig>/' | sed 's/^/  /'
