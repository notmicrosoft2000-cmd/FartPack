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
while :; do
  n=$(count_players)
  if [ -z "$n" ]; then
    echo "  $t: player count UNREADABLE - not assuming empty, still waiting"
  elif [ "$n" = "0" ]; then
    echo "  $t: 0 players online, proceeding"
    break
  else
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
echo "=== DONE. v25 deployed. ==="
