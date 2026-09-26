#!/usr/bin/env bash
# Probe: world load state, leftover test entities, and whether forceload works
# while the server is paused with 0 players online.
R="python3 /tmp/rcon.py"

echo "=== players ==="
$R 'list' 2>&1 | tail -1

echo
echo "=== leftover test chickens from earlier runs ==="
$R 'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run say I_AM_A_LEFTOVER' 2>&1 | tail -3
$R 'data get entity @e[type=minecraft:chicken,tag=fart.stresstest,limit=1] Pos' 2>&1 | tail -1

echo
echo "=== is chunk 300,300 loaded right now? ==="
$R 'execute if loaded 300 100 300 run say CHUNK_IS_LOADED' 2>&1 | tail -1
$R 'execute if loaded 300 100 300 run data modify storage fartpack:msg probe set value 1' 2>&1 | tail -1

echo
echo "=== try forceload (this is the fix for the test harness) ==="
$R 'forceload add 300 300' 2>&1 | tail -1
$R 'execute if loaded 300 100 300 run say NOW_IT_IS_LOADED' 2>&1 | tail -1
$R 'setblock 300 100 300 minecraft:crafting_table' 2>&1 | tail -1
$R 'execute if block 300 100 300 minecraft:crafting_table run say SETBLOCK_WORKED' 2>&1 | tail -1

echo
echo "=== and does the lookup resolve now? ==="
$R 'execute positioned 300 100 300 run function fartpack:world/block_name' >/dev/null 2>&1
$R 'data get storage fartpack:msg name' 2>&1 | tail -1

echo
echo "=== cleanup ==="
$R 'setblock 300 100 300 minecraft:air' 2>&1 | tail -1
$R 'forceload remove 300 300' 2>&1 | tail -1
