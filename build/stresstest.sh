#!/usr/bin/env bash
# End-to-end test of the v20 crouch-strain fix, on a real entity (a chicken) so
# that `data get entity @s Pos` genuinely resolves.
#
# Two halves to prove:
#   A. chicken standing still, empty tank, stress 19 -> one more tick hurts it
#   B. same, but it moved since the last sample   -> stress clears, no damage
#
# In v19 both halves did nothing, because player/fill_gas refilled the bar within
# 10 ticks and stress needs 20 empty ticks. We bypass fill_gas here by holding
# pressure at 0, which is the exact state that was unreachable in practice.
set -uo pipefail
R="python3 /tmp/rcon.py"

echo "=== setup: chicken, tagged as sneaking, empty tank, stress primed to 19 ==="
$R \
  'kill @e[type=minecraft:chicken,tag=fart.stresstest]' \
  'summon minecraft:chicken 100 100 100 {Tags:["fart.stresstest","fart.sneak"],Health:20.0f}' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.lastx 10000' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.lastz 10000' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.stress 19' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.pressure 0' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.hurtt 1' \
  'data get entity @e[type=minecraft:chicken,tag=fart.stresstest] Health' 2>&1 | tail -3

echo
echo "=== A. standing still (Pos 100,100,100 vs lastx/lastz 10000 -> delta 0) ==="
$R \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run function fartpack:player/stress' \
  'scoreboard players get @e[type=minecraft:chicken,tag=fart.stresstest] fart.stress' \
  'data get entity @e[type=minecraft:chicken,tag=fart.stresstest] Health' 2>&1 | tail -6

echo
echo "=== B. now it MOVES: reset stress to 19, teleport 3 blocks, one tick ==="
$R \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] at @s run tp @s ~3 ~ ~' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.stress 19' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.pressure 0' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run scoreboard players set @s fart.hurtt 1' \
  'execute as @e[type=minecraft:chicken,tag=fart.stresstest] run function fartpack:player/stress' \
  'scoreboard players get @e[type=minecraft:chicken,tag=fart.stresstest] fart.stress' \
  'data get entity @e[type=minecraft:chicken,tag=fart.stresstest] Health' 2>&1 | tail -6

echo
echo "=== cleanup ==="
$R 'kill @e[type=minecraft:chicken,tag=fart.stresstest]' >/dev/null 2>&1
echo "  test chicken removed"
