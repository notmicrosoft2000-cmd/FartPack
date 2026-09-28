#!/usr/bin/env bash
# One shot. Whole trial in a single rcon.py argument vector.
set -uo pipefail
C='@e[type=minecraft:cow,tag=p.h,limit=1]'
say() { printf '  %s\n' "$1"; }

trial() { # label health tank ticks
  say ""
  say "--- $1 : Health $2, tank $3, $4 presses ---"
  local -a cmd=(
    'kill @e[type=minecraft:cow]' 'kill @e[type=area_effect_cloud]'
    "summon minecraft:cow ~ ~1 ~ {Tags:[\"p.h\"],NoAI:1b,NoGravity:1b,Health:$2}"
    "effect give $C minecraft:health_boost 400000 4 true"
    "execute as $C run function fartpack:admin/defaults"
    "execute as $C run scoreboard players set @s fart.pressure $3"
    "execute as $C run scoreboard players set @s fart.leg 100"
  )
  local o
  for o in healcd stress hurtt healgas presspre lastx lastz; do
    cmd+=("execute as $C run scoreboard players set @s fart.$o 0")
  done
  cmd+=("data remove storage fartpack:data macro")
  # sample at tick 0
  cmd+=("data get entity $C Health" "scoreboard players get $C fart.healgas" "scoreboard players get $C fart.pressure")
  local i
  for i in $(seq 1 "$4"); do
    cmd+=("execute as $C run function fartpack:player/press")
    case "$i" in 1|5|10|20|30|40|50|60)
      cmd+=("data get entity $C Health" "scoreboard players get $C fart.healgas" "scoreboard players get $C fart.pressure")
    ;; esac
  done
  python3 /tmp/rcon.py "${cmd[@]}" 2>/dev/null \
    | grep -oE 'Health: [0-9.]+f|has -?[0-9]+ \[fart\.(healgas|pressure)\]' \
    | awk -F'[:]' '{ if ($0 ~ /Health/) { split($0,a," "); h=a[2] }
                     else if ($0 ~ /healgas/) { split($0,b," "); g=b[2] }
                     else { split($0,c," "); p=c[2] } }
           END { printf "    final: health %s  healgas %s  tank %s\n", h, g, p }'
  python3 /tmp/rcon.py "${cmd[@]}" 2>/dev/null \
    | grep -oE 'Health: [0-9.]+f|has -?[0-9]+ \[fart\.healgas\]' \
    | awk '{ if ($0 ~ /Health/) { split($0,a," "); h=a[2] } else { split($0,b," "); printf "    health %-8s healgas %-6s\n", a[2], b[2] } }'
}

python3 /tmp/rcon.py 'forceload add ~ ~' 'kill @e[type=minecraft:cow]' 'kill @e[type=area_effect_cloud]' >/dev/null 2>&1
say "=== v30 CRATCH-HEAL, deployed. v29 gave ZERO heals (tank 10) / ONE heal (tank 50) ==="
trial "TANK 50" 6.0f 50 60
trial "TANK 12 (below v29's 20-tick threshold - the common case)" 6.0f 12 40
trial "TANK 0  (negative control - no gas must mean no healing)" 6.0f 0 40
python3 /tmp/rcon.py 'kill @e[type=minecraft:cow]' 'kill @e[type=area_effect_cloud]' >/dev/null 2>&1
