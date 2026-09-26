#!/usr/bin/env bash
# Scoreboard data persists across restart, so non-zero values after a boot are
# expected -- what matters is whether they ADVANCE. Sample twice and compare.
#
# Beware: pause-when-empty-seconds=60 means this only works in the first 60
# seconds after boot, or while a player is online. If both reads are identical
# and the server has been up > 60s with 0 players, the world is paused and that
# is correct behaviour, not a fault.
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
LOG="$SRV/logs/latest.log"

boot=$(head -1 "$LOG" | grep -oE '^\[[0-9:]+\]' | tr -d '[]')
echo "  this run started at $boot"
grep -c 'Server empty for 60 seconds, pausing' "$LOG" | sed 's/^/  pauses in this run: /'

get() { python3 /tmp/rcon.py "scoreboard players get $1 fart.var" 2>/dev/null \
         | grep -oE 'has [0-9-]+' | grep -oE '[0-9-]+$'; }

a_scan=$(get '#scan_c'); a_rc=$(get '#rc')
echo "  t0: #scan_c=$a_scan  #rc=$a_rc"
sleep 6
b_scan=$(get '#scan_c'); b_rc=$(get '#rc')
echo "  t1: #scan_c=$b_scan  #rc=$b_rc   (+6s)"

if [ "$a_scan" != "$b_scan" ] || [ "$a_rc" != "$b_rc" ]; then
  echo "  ADVANCING -> the pack is running"
else
  echo "  FROZEN -> either paused (expected with 0 players) or broken; check the pause line above"
fi
