#!/usr/bin/env bash
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
R="python3 /tmp/rcon.py"
val() { $R "scoreboard players get $1 fart.var" 2>/dev/null | grep -oE 'has [0-9-]+' | grep -oE '[0-9-]+'; }

echo "=== current counters ==="
echo "  #scan_c = $(val '#scan_c')"
echo "  #rc     = $(val '#rc')"
echo "  #loaded = $(val '#loaded')"
echo "  #enabled= $(val '#enabled')"

echo
echo "=== does the world tick at all? gametime twice, 3s apart ==="
$R 'scoreboard objectives add ftw dummy' >/dev/null 2>&1
$R 'execute store result score #g0 ftw run time query gametime' >/dev/null
A=$($R 'scoreboard players get #g0 ftw' | grep -oE 'has [0-9]+' | grep -oE '[0-9]+')
sleep 3
$R 'execute store result score #g1 ftw run time query gametime' >/dev/null
B=$($R 'scoreboard players get #g1 ftw' | grep -oE 'has [0-9]+' | grep -oE '[0-9]+')
echo "  gametime $A -> $B  (delta $((B-A)) over ~4s; 0 means the WORLD is not ticking)"

echo
echo "=== run fartpack:tick BY HAND and see if #scan_c moves ==="
S1=$(val '#scan_c')
$R 'function fartpack:tick' >/dev/null
S2=$(val '#scan_c')
echo "  #scan_c $S1 -> $S2  after one manual fartpack:tick"

echo
echo "=== raw log since the v19 reload, UNFILTERED ==="
awk '/14:26:23/{f=1} f' "$SRV/logs/latest.log" | grep -vE 'RCON Client|RCON Listener' | head -40
echo "--- end raw log ---"

$R 'scoreboard objectives remove ftw' >/dev/null 2>&1
