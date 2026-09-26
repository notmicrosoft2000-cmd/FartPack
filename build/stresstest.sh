#!/usr/bin/env bash
# End-to-end test of the v20 crouch-strain fix, on a real entity (a chicken) so
# that `data get entity @s Pos` genuinely resolves.
#
# Three cases to prove:
#   A. standing still, empty tank, stress 19 -> one more tick trips it and hurts
#   B. same, but it MOVED since the last sample -> stress clears, no damage
#   C. control: gas in the tank, not moving -> forgiven, no damage (v19 behaviour)
#
# In v19 both of the first two did nothing, because player/fill_gas refilled the
# bar within 10 ticks and stress needs 20 empty ticks. We bypass fill_gas by
# holding pressure at 0, which is the exact state that was unreachable in
# practice.
#
# HARNESS NOTES. Four ways this test lied to me before it told me anything, and
# all four produced output that looked like a plausible result:
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
#   * THE BIG ONE: the subject has to be stationary. player/stress decides
#     "did you move?" by comparing Pos*100 against fart.lastx/lastz. A live
#     chicken wanders, so between priming the scores and calling the function the
#     bird had shifted, the movement branch fired, and stress came back as 1
#     instead of 0. That is #22 WORKING - and it read as a failure. Fixed with
#     NoAI, and by deriving lastx/lastz from the bird's real Pos rather than
#     hardcoding 10000.
#   * Do not assert absolute health on a mob. `summon ... {Health:20.0f}` does
#     not give a chicken 20 HP - the max_health attribute clamps it to 4 on the
#     first tick, so every read was 4.0 whether or not damage landed, and the
#     "expected 20.0" assertions were meaningless. Assert the DELTA from a
#     baseline captured immediately before the call.
set -uo pipefail
R=(python3 /tmp/rcon.py)

CX=100; CY=100; CZ=100
SEL="@e[type=minecraft:chicken,tag=fart.stresstest]"
SELL="@e[type=minecraft:chicken,tag=fart.stresstest,limit=1]"   # limit goes INSIDE the brackets
# Guard, same reason as verifyv20.sh: a contaminated selector fails silently and
# every assertion below then "passes" because the read returned nothing at all.
case "$SELL" in
  *" "*|*"#"*) echo "FATAL: \$SELL is contaminated -> $SELL" >&2; exit 1 ;;
  *",limit=1]") : ;;
  *) echo "FATAL: \$SELL has no in-bracket limit -> $SELL" >&2; exit 1 ;;
esac

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

# Prime the movement baseline from the bird's ACTUAL position. With NoAI it cannot
# move, so this makes the delta exactly 0 without depending on hardcoded coords.
prime_still() {
  "${R[@]}" \
    "execute as $SELL store result score @s fart.lastx run data get entity @s Pos[0] 100" \
    "execute as $SELL store result score @s fart.lastz run data get entity @s Pos[2] 100" \
    "execute as $SELL run scoreboard players set @s fart.stress 19" \
    "execute as $SELL run scoreboard players set @s fart.pressure 0" \
    "execute as $SELL run scoreboard players set @s fart.hurtt 1" >/dev/null 2>&1
}

health() {  # -> current health as a bare number, e.g. 3.5  (strips the "4.0f" suffix)
  "${R[@]}" "data get entity $SELL Health" 2>/dev/null | tail -1 \
    | sed 's/.*entity data: //; s/[^0-9.]*$//'
}
stress() {
  # rcon answers "Chicken has 0 [fart.stress]" - no colon to split on, so pull the
  # last integer out rather than assuming a ": " separator.
  "${R[@]}" "scoreboard players get $SELL fart.stress" 2>/dev/null | tail -1 \
    | grep -oE '\-?[0-9]+' | tail -1
}

# Compare a float without bc. Prints one of: LOWER / SAME / HIGHER / UNREADABLE
cmp_f() {  # <before> <after>
  awk -v a="$1" -v b="$2" 'BEGIN{ if (a=="" || b=="") { print "UNREADABLE"; exit }
                               if (b<a) print "LOWER"; else if (b==a) print "SAME"; else print "HIGHER" }'
}

"${R[@]}" 'forceload add 100 100' >/dev/null 2>&1

echo "=== setup ==="
"${R[@]}" "kill $SEL" 'fill 100 97 100 100 102 100 minecraft:air' >/dev/null 2>&1
# kill can miss an entity that was unloaded a moment ago, so re-assert.
"${R[@]}" "kill $SEL" >/dev/null 2>&1
echo "  pre-existing tagged chickens: $(count_tagged)  (must be 0)"

"${R[@]}" \
  'setblock 100 99 100 minecraft:stone' \
  "summon minecraft:chicken $CX $CY $CZ {Tags:[\"fart.stresstest\",\"fart.sneak\"],NoAI:1b,NoGravity:1b,PersistenceRequired:1b}" \
  >/dev/null 2>&1
prime_still

N=$(count_tagged)
echo "  tagged chickens after summon: $N  (must be 1)"
if [ "$N" != "1" ]; then
  echo "  ABORT: the test needs exactly one bird; a duplicate makes every selector"
  echo "         below match two entities and the results meaningless."
  "${R[@]}" "kill $SEL" 'forceload remove 100 100' >/dev/null 2>&1
  exit 1
fi
echo "  NoAI set, so the bird cannot wander between priming and the call."
echo "  baseline health: $(health)  (a chicken's max_health is 4, not the 20 the old"
echo "  assertions assumed - so every assertion below compares a DELTA)"

echo
echo "=== A. standing still, empty tank: Pos*100 == lastx/lastz => delta 0 ==="
prime_still
H0=$(health)
"${R[@]}" "execute as $SELL run function fartpack:player/stress" >/dev/null 2>&1
S=$(stress); H=$(health)
echo "  fart.stress after = $S   (expected 0 - tripped 20, stress_hurt reset it)"
echo "  health $H0 -> $H  [$(cmp_f "$H0" "$H")]   (expected LOWER - damage landed)"

echo
echo "=== B. same bird, but it MOVED: re-prime, then a fake 3-block delta ==="
echo "  Movement is simulated by setting lastx/lastz away from the real Pos, because"
echo "  tp-ing the bird also moves it and the two effects cannot be separated cleanly."
prime_still
"${R[@]}" \
  "execute as $SELL run scoreboard players set @s fart.lastx 0" \
  "execute as $SELL run scoreboard players set @s fart.lastz 0" >/dev/null 2>&1
H0=$(health)
"${R[@]}" "execute as $SELL run function fartpack:player/stress" >/dev/null 2>&1
S=$(stress); H=$(health)
echo "  fart.stress after = $S   (expected 1 - cleared by movement, then +1)"
echo "  health $H0 -> $H  [$(cmp_f "$H0" "$H")]   (expected SAME - movement spared it)"

echo
echo "=== C. control: gas in the tank, not moving -> forgiven, no damage ==="
echo "  This is v19 behaviour, and it is the branch the old bug report was really about."
prime_still
"${R[@]}" "execute as $SELL run scoreboard players set @s fart.pressure 100" >/dev/null 2>&1
H0=$(health)
"${R[@]}" "execute as $SELL run function fartpack:player/stress" >/dev/null 2>&1
S=$(stress); H=$(health)
echo "  fart.stress after = $S   (expected 0 - forgiven, because the bar has gas)"
echo "  health $H0 -> $H  [$(cmp_f "$H0" "$H")]   (expected SAME - a full bar forgives)"

echo
echo "=== cleanup ==="
"${R[@]}" "kill $SEL" 'fill 100 99 100 100 100 100 minecraft:air' 'forceload remove 100 100' >/dev/null 2>&1
echo "  bird killed, platform cleared, chunk released"
