#!/usr/bin/env bash
# The reaper is the one new mechanism the 70-tick smoke test could not reach
# (it fires at 200). Arm it directly and prove it wipes stale gas rows and
# resets its own counter.
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
R="python3 /tmp/rcon.py"

echo "=== seed stale gas rows (they are supposed to be leftovers from dead clouds) ==="
$R \
  'scoreboard players set #ghost_a fart.gtick 37' \
  'scoreboard players set #ghost_b fart.gtick 12' \
  'scoreboard players set #ghost_c fart.gtick 99' \
  'scoreboard players set #rc fart.var 199' \
  'scoreboard players get #ghost_a fart.gtick' \
  'scoreboard players get #rc fart.var' 2>&1 | tail -10

echo
echo "=== one more tick: #rc hits 200 -> core/reap should wipe all three and reset #rc ==="
$R \
  'function fartpack:tick' \
  'scoreboard players get #rc fart.var' \
  'scoreboard players get #ghost_a fart.gtick' \
  'scoreboard players get #ghost_b fart.gtick' \
  'scoreboard players get #ghost_c fart.gtick' 2>&1 | tail -14

echo
echo "=== and it does NOT touch the objectives it must not touch ==="
$R \
  'scoreboard players get #scan_c fart.var' \
  'scoreboard players get #loaded fart.var' \
  'scoreboard players get #enabled fart.var' 2>&1 | tail -8
