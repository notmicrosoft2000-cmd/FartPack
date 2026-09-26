#!/usr/bin/env bash
# verifycfg.sh - machine-verify the v26 admin config layer.
#
# Runs on the server AFTER the v26 reload, with 0 players online.
#
# The obvious objection to testing a per-player feature during a 0-player gate is
# that there is no player to configure. That is not quite true, and the loophole
# is that SCOREBOARD OPERATIONS WORK ON FAKE PLAYERS. `#cfgtest` is a legal
# scoreboard holder, so:
#
#   /function fartpack:admin/rate #cfgtest 2
#
# runs the real macro, with the real argument substitution, and writes a real
# score. Nothing needs to be connected. That makes the whole clamp-and-derive
# path testable at 0 players, which is the only time we are allowed to run
# anything.
#
# What this CANNOT cover, stated plainly rather than glossed:
#
#   * admin/reset, admin/show and admin/resync_bar all begin with
#     `execute as <name>`, and `execute as` resolves only against real entities.
#     Against `#cfgtest` that line simply fails, so those three are NOT tested
#     here and need a real player.
#   * the gas bar actually filling at the new rate, the bossbar resizing, and
#     the push distance all need a real player too.
#
# So this proves the arithmetic and the argument handling, which is where a typo
# would hide. It does not prove the feature works, and the report says so.
set -uo pipefail
FAIL=0
T='#cfgtest'

get() {
  local out
  out=$(python3 /tmp/rcon.py "scoreboard players get $1 $2" 2>/dev/null | tail -3)
  if printf '%s' "$out" | grep -qi 'none is set\|Unknown'; then
    echo "UNSET"
  else
    printf '%s' "$out" | grep -oE 'has -?[0-9]+' | grep -oE '\-?[0-9]+' | head -1
  fi
}

fn() { python3 /tmp/rcon.py "function $1 $2 $3" >/dev/null 2>&1; }

expect() {
  if [ "$2" = "$3" ]; then
    printf '  ok   %-34s = %s\n' "$1" "$3"
  else
    printf '  FAIL %-34s got %-8s want %s\n' "$1" "'$3'" "$2"
    FAIL=$((FAIL+1))
  fi
}

echo "=== 0. do the functions exist at all? (a dropped macro fails everything) ==="
for f in rate every cap rel pow reset show; do
  if python3 /tmp/rcon.py "function fartpack:admin/$f $T 1" 2>&1 | grep -qi 'Unknown function\|error'; then
    printf '  FAIL admin/%-6s did not load\n' "$f"
    FAIL=$((FAIL+1))
  else
    printf '  ok   admin/%-6s loaded\n' "$f"
  fi
done

echo
echo "=== 1. admin/rate, including both clamps ==="
fn fartpack:admin/rate "$T" 2;  expect "rate 2"            2     "$(get $T fart.rate)"
fn fartpack:admin/rate "$T" 5;  expect "rate 5"            5     "$(get $T fart.rate)"
fn fartpack:admin/rate "$T" 99; expect "rate 99 clamps to 5" 5    "$(get $T fart.rate)"
fn fartpack:admin/rate "$T" -3; expect "rate -3 clamps to 0" 0    "$(get $T fart.rate)"
fn fartpack:admin/rate "$T" 1;  expect "rate back to 1"     1     "$(get $T fart.rate)"

echo
echo "=== 2. admin/every ==="
fn fartpack:admin/every "$T" 3;  expect "every 3"           3    "$(get $T fart.every)"
fn fartpack:admin/every "$T" 99; expect "every 99 clamps to 4" 4   "$(get $T fart.every)"
fn fartpack:admin/every "$T" 0;  expect "every 0 clamps to 1"  1   "$(get $T fart.every)"
fn fartpack:admin/every "$T" 1;  expect "every back to 1"   1    "$(get $T fart.every)"

echo
echo "=== 3. admin/cap, and the two thresholds derived from it ==="
fn fartpack:admin/cap "$T" 200
expect "cap 200"                     200 "$(get $T fart.cap)"
expect "  leg  == cap"               200 "$(get $T fart.leg)"
expect "  warn == cap/4"              50 "$(get $T fart.warn)"
fn fartpack:admin/cap "$T" 100
expect "cap 100 restores"            100 "$(get $T fart.cap)"
expect "  leg  == cap"               100 "$(get $T fart.leg)"
expect "  warn == cap/4 (stock 25)"   25 "$(get $T fart.warn)"
fn fartpack:admin/cap "$T" 5
expect "cap 5 clamps up to 20"        20 "$(get $T fart.cap)"
expect "  leg  follows the clamp"     20 "$(get $T fart.leg)"
expect "  warn == 20/4"                5 "$(get $T fart.warn)"
fn fartpack:admin/cap "$T" 9000
expect "cap 9000 clamps to 500"      500 "$(get $T fart.cap)"
expect "  warn == 500/4"             125 "$(get $T fart.warn)"
# The one that would actually break the pack: a non-multiple-of-4 cap.
fn fartpack:admin/cap "$T" 101
expect "cap 101 (odd) warn floors"   101 "$(get $T fart.cap)"
expect "  warn == 101/4 = 25"         25 "$(get $T fart.warn)"
fn fartpack:admin/cap "$T" 100

echo
echo "=== 4. admin/rel ==="
fn fartpack:admin/rel "$T" 3;  expect "rel 3"               3  "$(get $T fart.rel)"
fn fartpack:admin/rel "$T" 99; expect "rel 99 clamps to 10" 10 "$(get $T fart.rel)"
fn fartpack:admin/rel "$T" 0;  expect "rel 0 clamps to 1"   1 "$(get $T fart.rel)"

echo
echo "=== 5. admin/pow - 0 must survive, not silently become stock ==="
fn fartpack:admin/pow "$T" 80; expect "pow 80"               80 "$(get $T fart.pow)"
fn fartpack:admin/pow "$T" 0;  expect "pow 0 is honoured"     0 "$(get $T fart.pow)"
fn fartpack:admin/pow "$T" 999; expect "pow 999 clamps to 200" 200 "$(get $T fart.pow)"
fn fartpack:admin/pow "$T" 30; expect "pow back to stock 30"  30 "$(get $T fart.pow)"

echo
echo "=== 6. #rc_four, the constant admin/cap divides by ==="
expect "bootstrap seeded #rc_four"    4 "$(get '#rc_four' fart.var)"

echo
echo "=== 7. clean up the test holder ==="
for o in rate every cyc cap leg warn rel pow; do
  python3 /tmp/rcon.py "scoreboard players reset $T fart.$o" >/dev/null 2>&1
done
expect "test scores cleared (cap)"  UNSET "$(get $T fart.cap)"

echo
if [ "$FAIL" -ne 0 ]; then
  echo "RESULT: $FAIL CHECK(S) FAILED - do not call this verified."
  exit 1
fi
echo "RESULT: all config checks passed."
echo
echo "STILL UNVERIFIED - these need a real player, not a fake scoreboard holder:"
echo "  * admin/reset, admin/show, admin/resync_bar (they start with 'execute as')"
echo "  * the bar actually filling at the new rate, and the bossbar resizing"
echo "  * the knockback distance changing with admin/pow"
echo "  * player-vs-player knockback itself (#28) - also needs two people"
