#!/usr/bin/env bash
# v30 crouch-heal verification, against the DEPLOYED pack.
#
# WHY THIS SCRIPT IS BATCHED. The first version of it read the cow's state after
# every single tick, which is one `rcon.py` process launch per read. Sixty ticks
# of trial is ~240 process launches over SSH, and the thing under test is a
# per-tick mechanic, so the probe itself became the bottleneck and got
# interrupted twice. rcon.py already accepts MANY commands as arguments -
# deploy.sh relies on it - so the whole trial goes out as a single argument list
# and the responses come back in order. Same measurements, ~240x fewer round
# trips. It ran in seconds.
#
# Fixture notes, all learned the hard way:
#   * fresh cow per trial - `damage` grants ~0.5s hurt immunity a paused world
#     never sheds, and `data merge {Health:..}` does not clear HurtTime
#   * health_boost 4 lifts the ceiling to 30, so healing is visible instead of
#     being clamped away at a cow's native 10 HP
#   * the cow never walks, so fill_gas sees zero movement. That is deliberate:
#     it is what a stationary crouching player looks like, and it is the case
#     v29 failed.
set -uo pipefail
say() { printf '  %s\n' "$1"; }

C='@e[type=minecraft:cow,tag=p.h,limit=1]'

# Build the whole trial as one argument vector, then fire it once.
run_trial() { # startHealth startTank ticks  -> prints parsed rows
  local sh=$1 tk=$2 ticks=$3
  local -a cmd=(
    'kill @e[type=minecraft:cow]'
    'kill @e[type=area_effect_cloud]'
    "summon minecraft:cow ~ ~1 ~ {Tags:[\"p.h\"],NoAI:1b,NoGravity:1b,Health:$sh}"
    "effect give $C minecraft:health_boost 400000 4 true"
    "execute as $C run function fartpack:admin/defaults"
    "execute as $C run scoreboard players set @s fart.pressure $tk"
    "execute as $C run scoreboard players set @s fart.leg 100"
  )
  local o
  for o in healcd stress hurtt healgas presspre lastx lastz; do
    cmd+=("execute as $C run scoreboard players set @s fart.$o 0")
  done
  cmd+=(
    "data remove storage fartpack:data macro"
    "scoreboard players reset #p30x fart.var"
    "scoreboard players reset #p30z fart.var"
  )
  # One marker read, then the tick loop. Each sampled tick contributes exactly
  # 4 responses, so the parser below can walk them positionally.
  cmd+=("scoreboard players get $C fart.healgas")
  cmd+=("data get entity $C Health")
  cmd+=("scoreboard players get $C fart.pressure")
  cmd+=("data get entity $C Health")
  local i
  for i in $(seq 1 "$ticks"); do
    cmd+=("execute as $C run function fartpack:player/press")
    case "$i" in
      1|5|10|15|20|25|30|35|40|50|60)
        cmd+=("scoreboard players get $C fart.healgas")
        cmd+=("data get entity $C Health")
        cmd+=("scoreboard players get $C fart.pressure")
        cmd+=("data get entity $C Health")
        ;;
    esac
  done
  python3 /tmp/rcon.py "${cmd[@]}" 2>/dev/null
}

mc() { python3 /tmp/rcon.py "$1" 2>&1 | sed -n '2,$p' | tr '\n' ' ' | cut -c1-100; }

python3 /tmp/rcon.py 'forceload add ~ ~' >/dev/null 2>&1

say "=== CONTROL: 40 idle reads, zero presses. Health must not drift. ==="
mc 'kill @e[type=minecraft:cow]' >/dev/null
mc 'summon minecraft:cow ~ ~1 ~ {Tags:["p.h"],NoAI:1b,NoGravity:1b,Health:6.0f}' >/dev/null
mc "effect give $C minecraft:health_boost 400000 4 true" >/dev/null
say "  start 6.0f -> after 40 idle reads: $(python3 /tmp/rcon.py "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" "data get entity $C Health" 2>/dev/null | grep -oE 'Health: [0-9.]+f' | tail -1)"

say ""
say "=== v30 CRATCH-HEAL, deployed pack. Ceiling 30, start Health 6.0 ==="
say "    v29 for comparison: ZERO heals from a tank of 10, ONE heal from a tank"
say "    of 50, then -4 HP strain. healcd peaked at 12 of the 20 it needed."

trial() { # label sh tk ticks
  say ""
  say "--- $1 : start Health $2, tank $3, $4 presses ---"
  local out; out=$(run_trial "$2" "$3" "$4")
  printf '  %s\n' "$out" | grep -E 'has [0-9-]+ \[fart\.(healgas|pressure)\]|Health: [0-9.]+f' \
    | awk '
      /fart\.healgas/ { g=$0; sub(/.*has /,"",g); sub(/ .*/,"",g); hg=g; next }
      /Health:/       { h=$0; sub(/.*Health: /,"",h); sub(/f.*/,"",h)
                        if (h2 ~ /^[0-9.]+$/) { printf "  health %-8s healgas %-8s\n", h, hg }
                        h2=h; next }
      /fart\.pressure/ { p=$0; sub(/.*has /,"",p); sub(/ .*/,"",p)
                         printf "  %-5s press %-6s\n", NR, p; next }
    '
}

trial "TANK 50" 6.0f 50 60
trial "TANK 12 (below the old 20-tick threshold - the common case)" 6.0f 12 40
trial "TANK 0 (negative control: no gas must mean NO healing)" 6.0f 0 40

python3 /tmp/rcon.py 'kill @e[type=minecraft:cow]' 'kill @e[type=area_effect_cloud]' >/dev/null 2>&1
