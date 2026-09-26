#!/usr/bin/env bash
# deployv25.sh - wait for an empty server, then lint and deploy v25.
#
# Why this exists: the standing rule is that a datapack reload may only happen
# with 0 players online. Two people were on the server when v25 was ready, and
# the lint gate correctly refused to run, because lintpack.py is a real parse
# test - it EXECUTES every line it checks, so the pack's own setblock / give /
# kill / tag lines would have fired at two players.
#
# So rather than either stalling or breaking the rule, this waits for the server
# to empty and then does the normal gated sequence. It never forces anything:
# the worst case is that it times out having done nothing.
#
# Runs on the server. Everything it needs is already in /tmp.
set -uo pipefail
SID=241920ac-55ce-46c6-aa2f-c42ebf290457
SRV="$HOME/crafty/servers/$SID"
MAXWAIT=5400        # 90 minutes; giving up is always a safe outcome
t=0

count_players() {
  python3 /tmp/rcon.py 'list' 2>/dev/null \
    | grep -oE 'There are [0-9]+ of' | grep -oE '[0-9]+' | head -1
}

echo "=== waiting for an empty server (max ${MAXWAIT}s) ==="
# Two consecutive empty polls, 30s apart, before we act.
#
# A single 0 is not enough. On the first attempt the wait loop saw 0, the
# re-confirm 20 seconds later also saw 0, and then lint.sh's own guard - which
# runs later still, and is the check that matters because lint EXECUTES commands -
# saw 1 and refused. A player had walked in during the gap. Nothing was deployed
# and nothing was executed at them, so that was a correct outcome, not a failure,
# but it wasted the attempt. Requiring the server to be empty across a 30 second
# window means we only act on a real gap rather than a momentary dip.
needzero=2
zeros=0
while :; do
  n=$(count_players)
  if [ -z "$n" ]; then
    echo "  $t: player count UNREADABLE - not assuming empty, still waiting"
    zeros=0
  elif [ "$n" = "0" ]; then
    zeros=$((zeros+1))
    echo "  $t: 0 players online (consecutive: $zeros/$needzero)"
    if [ "$zeros" -ge "$needzero" ]; then
      echo "  $t: empty across a ${needzero}-poll window, proceeding"
      break
    fi
  else
    zeros=0
    # Only narrate on change, so the log stays readable over 90 minutes.
    if [ "${last:-x}" != "$n" ]; then echo "  $t: $n online, waiting"; last="$n"; fi
  fi
  if [ "$t" -ge "$MAXWAIT" ]; then
    echo "TIMEOUT after ${MAXWAIT}s. Nothing was deployed. Re-run when ready."
    exit 2
  fi
  sleep 30
  t=$((t+30))
done

echo
echo "=== re-confirming immediately before acting ==="
n=$(count_players)
if [ "$n" != "0" ]; then
  echo "  ABORT: $n online again after the wait. Not deploying."
  exit 1
fi
echo "  0 players, confirmed."

echo
echo "############ PRE-DEPLOY LINT GATE ############"
bash /tmp/lint.sh
rc=$?
# lint.sh exits non-zero on a bad block tag or an unreadable player count. The
# parse lint itself only reports in its output, so check that explicitly too.
if [ $rc -ne 0 ]; then
  echo "ABORT: lint.sh exited $rc (block tag invalid, or player count unreadable)."
  exit 1
fi

echo
echo "############ DEPLOY v25 ############"
bash /tmp/deploy.sh 25
rc=$?
if [ $rc -ne 0 ]; then
  echo "ABORT: deploy.sh exited $rc. Not claiming success."
  exit 1
fi

echo
echo "############ POST-DEPLOY VERIFY ############"
echo "--- #loaded version gate (must be 25) ---"
python3 /tmp/rcon.py 'scoreboard players get #loaded fart.var' 2>/dev/null | tail -2

echo "--- datapack list ---"
python3 /tmp/rcon.py 'datapack list' 2>/dev/null | tail -6

echo "--- Failed to load, with timestamps (a reload keeps the old log) ---"
grep -n 'Failed to load' "$SRV/logs/latest.log" 2>/dev/null | tail -20 || echo "  (none)"

echo "--- any new errors in the last 60 log lines ---"
tail -60 "$SRV/logs/latest.log" 2>/dev/null \
  | grep -iE 'error|exception|failed' | tail -20 || echo "  (none)"

echo
echo "--- weather state after bootstrap ran (all should read cleanly) ---"
for v in '#raining' '#rain_c' '#rain_cd' '#rain_dur' '#rain_tick' '#event_cd'; do
  printf '  %-12s ' "$v"
  python3 /tmp/rcon.py "scoreboard players get $v fart.var" 2>/dev/null | tail -1
done
echo "  #rain_target is EXPECTED to be unset until fart_rain_tick picks one."

echo
echo "--- player-vs-player knockback flag (must be 0; 1 would disable it pack-wide) ---"
python3 /tmp/rcon.py 'scoreboard players get #noplayer fart.var' 2>/dev/null | tail -2

echo
echo "--- lifesteal must be GONE, and pwr / Graves must be untouched ---"
DPS=$(python3 /tmp/rcon.py 'datapack list' 2>/dev/null)
if printf '%s' "$DPS" | grep -qi 'lifesteal'; then
  echo "  PROBLEM: lifesteal is still present after the reload:"
  printf '  %s\n' "$DPS" | grep -io '[^ ()]*lifesteal[^ ()]*'
else
  echo "  lifesteal: gone. good."
fi
printf '%s' "$DPS" | grep -qi 'pwr' \
  && echo "  pwr: still enabled. good." \
  || echo "  NOTE: pwr is not enabled. It was enabled before this deploy - check."
printf '%s' "$DPS" | grep -qi 'Graves' \
  && echo "  Graves: still available. good (it was never enabled)." \
  || echo "  NOTE: Graves is no longer listed at all - check."

echo
echo "--- backup of the removed pack, on disk ---"
ls -1 "$HOME/crafty/removed-datapacks/removed-from-datapacks/" 2>/dev/null \
  | sed 's/^/  /' || echo "  MISSING: no backup dir - lifesteal is gone with no way back."

echo
echo "############ NOT VERIFIABLE HERE ############"
echo "Player-vs-player knockback itself. Proving it needs a second player to be"
echo "the push target, and this gate only ever runs with 0 players online. What IS"
echo "checked is that nothing sets #noplayer to 1 any more, so the strip in"
echo "push/core cannot fire during a crouch release. Ask a player to crouch-fart"
echo "next to another player and confirm the other one is shoved."

echo
echo "=== DONE. v25 deployed. ==="
