#!/usr/bin/env bash
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
LOG="$SRV/logs/latest.log"

echo "=== log time span ==="
head -1 "$LOG" | cut -c1-15
tail -1 "$LOG" | cut -c1-15

echo
echo "=== EVERY 'Failed to load function fartpack' with timestamp ==="
grep -n 'Failed to load function fartpack' "$LOG" | sed 's/\[Server thread\/ERROR\]: //'

echo
echo "=== where does the v19 reload start? ==="
grep -n 'Reloading\|Loaded .* advancements' "$LOG" | tail -6

echo
echo "=== any fartpack error/exception AFTER the last reload line ==="
LAST=$(grep -n 'Reloading' "$LOG" | tail -1 | cut -d: -f1)
echo "last reload at line $LAST of $(wc -l < "$LOG")"
tail -n +"$LAST" "$LOG" | grep -iE 'Failed to load|Error loading|Unknown block|problems? (were|was) found|Unknown registry|Exception|ERROR' | grep -viE 'quickdeath|gamerule' | head -20 || true
echo "--- (end) ---"

echo
echo "=== objectives, filtered to ours ==="
python3 /tmp/rcon.py 'scoreboard objectives list' 2>/dev/null \
  | tr ',' '\n' | grep -oE '\[(fart\.[a-z]+|Total Farts)\]' | tr -d '[]' | sort
