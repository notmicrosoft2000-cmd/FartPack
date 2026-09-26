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
#
# HARNESS NOTES, both learned the hard way:
#
#   * `R` MUST be an array, not a string. `R="python3 /tmp/rcon.py"` then
#     `"$R" 'cmd'` passes the whole thing as ONE argv entry, so the shell looks
#     for an executable literally named "python3 /tmp/rcon.py" and every call
#     fails. Unquoted `$R` accidentally works; quoted `"$R"` silently does
#     nothing. Use "${R[@]}".
#   * The chunk is force-loaded. With 0 players the world is paused and chunks
#     unload; a summon into an unloaded chunk fails, and a leftover entity in an
#     unloaded chunk cannot even be killed - so it reappears the moment the chunk
#     loads and every selector then matches two entities.
#   * The uniqueness assert below is a genuine count, because `data get` with a
#     bare selector just errors and a `limit=1` would hide the problem.
set -uo pipefail
R=(python3 /tmp/rcon.py)

CX=100; CY=100; CZ=100
SEL="@e[type=minecraft:chicken,tag=fart.stresstest]"
SELL="@e[type=minecraft:chicken,tag=fart.stresstest,limit=1]   # limit goes INSIDE the brackets"

count_tagged() {  # -> number of tagged chickens
  # `data modify <storage> <key> add value 1` is rejected by this server, so build
  # a list instead and count the commas. `[]` means zero, `[1]` one, `[1, 1]` two.
  "${R[@]}" 'data modify storage fartpack:msg n set value []' >/dev/null 2>&1
  "${R[@]}" "execute as $SEL run data modify storage fartpack:msg n append value 1" >/dev/null 2>&1
  local out
  out=$("${R[@]}" 'data get storage fartpack:msg n' 2>/dev/null | tail -1)
  case "$out" in
    *'[]'*) echo 0 ;;
    *'['*)  echo $(( $(printf '%s' "$out" | tr -cd ',' | wc -c) + 1 )) ;;
    *)      echo "?" ;;
  esac
}

"${R[@]}" 'forceload add 100 100' >/dev/null 2>&1

echo "=== setup ==="
"${R[@]}" "kill $SEL" 'fill 100 97 100 100 102 100 minecraft:air' >/dev/null 2>&1
# kill can miss an entity that was unloaded a moment ago, so re-assert.
"${R[@]}" "kill $SEL" >/dev/null 2>&1
echo "  pre-existing tagged chickens: $(count_tagged)  (must be 0)"

"${R[@]}" \
  'setblock 100 99 100 minecraft:stone' \
  "summon minecraft:chicken $CX $CY $CZ {Tags:[\"fart.stresstest\",\"fart.sneak\"],Health:20.0f}" \
  "execute as $SEL run scoreboard players set @s fart.lastx 10000" \
  "execute as $SEL run scoreboard players set @s fart.lastz 10000" \
  "execute as $SEL run scoreboard players set @s fart.stress 19" \
  "execute as $SEL run scoreboard players set @s fart.pressure 0" \
  "execute as $SEL run scoreboard players set @s fart.hurtt 1" >/dev/null 2>&1

N=$(count_tagged)
echo "  tagged chickens after summon: $N  (must be 1)"
if [ "$N" != "1" ]; then
  echo "  ABORT: the test needs exactly one bird; a duplicate makes every selector"
  echo "         below match two entities and the results meaningless."
  "${R[@]}" "kill $SEL" 'forceload remove 100 100' >/dev/null 2>&1
  exit 1
fi
"${R[@]}" "data get entity $SELL Health" 2>&1 | tail -1

echo
echo "=== A. standing still: Pos (100,100,100) == lastx/lastz (10000) => delta 0 ==="
"${R[@]}" "execute as $SELL run function fartpack:player/stress" >/dev/null 2>&1
S=$("${R[@]}" "scoreboard players get $SELL fart.stress" 2>/dev/null | tail -1)
H=$("${R[@]}" "data get entity $SELL Health" 2>/dev/null | tail -1 | sed 's/.*entity data: //')
echo "  fart.stress after = ${S##*: }   (expected 0 - it tripped and hurt)"
echo "  Health             = $H   (expected < 20.0 - damage landed)"

echo
echo "=== B. same bird, but it MOVED: re-prime stress, move 3 blocks, one tick ==="
"${R[@]}" \
  "execute as $SELL at @s run tp @s ~3 ~ ~" \
  "execute as $SELL run scoreboard players set @s fart.stress 19" \
  "execute as $SELL run scoreboard players set @s fart.pressure 0" \
  "execute as $SELL run scoreboard players set @s fart.hurtt 1" >/dev/null 2>&1
"${R[@]}" "execute as $SELL run function fartpack:player/stress" >/dev/null 2>&1
S=$("${R[@]}" "scoreboard players get $SELL fart.stress" 2>/dev/null | tail -1)
H=$("${R[@]}" "data get entity $SELL Health" 2>/dev/null | tail -1 | sed 's/.*entity data: //')
echo "  fart.stress after = ${S##*: }   (expected 19 - movement cleared it, no damage)"
echo "  Health             = $H   (expected 20.0 - unharmed)"

echo
echo "=== C. control: v19 behaviour, movement is irrelevant, the bar is what forgives ==="
echo "  Same bird, re-primed, but with gas in the tank (pressure 100) and NOT moving."
"${R[@]}" \
  "execute as $SELL at @s run tp @s ~-3 ~ ~" \
  "execute as $SELL run scoreboard players set @s fart.lastx 999999" \
  "execute as $SELL run scoreboard players set @s fart.lastz 999999" \
  "execute as $SELL run scoreboard players set @s fart.stress 19" \
  "execute as $SELL run scoreboard players set @s fart.pressure 100" \
  "execute as $SELL run scoreboard players set @s fart.hurtt 1" >/dev/null 2>&1
"${R[@]}" "execute as $SELL run function fartpack:player/stress" >/dev/null 2>&1
S=$("${R[@]}" "scoreboard players get $SELL fart.stress" 2>/dev/null | tail -1)
H=$("${R[@]}" "data get entity $SELL Health" 2>/dev/null | tail -1 | sed 's/.*entity data: //')
echo "  fart.stress after = ${S##*: }   (expected 0 - forgiven, because the bar has gas)"
echo "  Health             = $H   (expected 20.0 - a full bar forgives, by design)"

echo
echo "=== cleanup ==="
"${R[@]}" "kill $SEL" 'fill 100 99 100 100 100 100 minecraft:air' 'forceload remove 100 100' >/dev/null 2>&1
echo "  bird killed, platform cleared, chunk released"
