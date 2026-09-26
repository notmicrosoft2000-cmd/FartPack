#!/usr/bin/env bash
# crown.sh <player> - crown a player King of the Farts, idempotently.
#
# The three commands the user asked for, in the only order that works:
#
#   1. wait until #loaded is actually 26
#   2. set the config
#   3. and only THEN announce it
#
# The order is the whole point. The announcement promises a 2x bar, so running
# the tellraw first - which is possible today, it is a vanilla command and
# nothing about it depends on the pack - would tell the player their buff is
# live while their bar is still filling at 1x. The config cannot be applied
# early either: `fartpack:admin/rate` does not exist before the v26 reload, and
# writing the scoreboard rows by hand on v20 would be worse than useless,
# because v20's fill code never reads them. It would be a promise with nothing
# behind it that also looks like it worked.
#
# Idempotent: running it twice is the same as running it once, so a re-run after
# a failed deploy is safe. Both config commands are absolute sets, not
# increments.
#
# Safe for an OFFLINE player. admin/rate and admin/pow are pure scoreboard
# operations - `scoreboard players set <name> ...` - which work on a holder who
# is not connected. The tellraw at the end is the only part that needs them
# online, and it fails silently rather than erroring if they are not.
set -uo pipefail
WHO="${1:?usage: crown.sh <player>}"
RATE=2
POW=60

rcon() { python3 /tmp/rcon.py "$@" 2>&1; }

get() {
  local out
  out=$(rcon "scoreboard players get $1 $2" | tail -3)
  if printf '%s' "$out" | grep -qi 'none is set\|Unknown'; then echo "UNSET"; else
    printf '%s' "$out" | grep -oE 'has -?[0-9]+' | grep -oE '\-?[0-9]+' | head -1
  fi
}

echo "=== waiting for #loaded to be 26 (max 5400s) ==="
t=0
while [ "$t" -lt 5400 ]; do
  v=$(get '#loaded' fart.var)
  if [ "$v" = "26" ]; then
    echo "  v26 is live."
    break
  fi
  if [ $((t % 300)) -eq 0 ]; then
    online=$(rcon list | grep -oE 'There are [0-9]+ of' | grep -oE '[0-9]+' | head -1)
    echo "  $t: #loaded=$v, ${online:-?} players online"
  fi
  sleep 15
  t=$((t+15))
done

if [ "$(get '#loaded' fart.var)" != "26" ]; then
  echo "TIMEOUT: v26 never went live. Nothing was changed, nothing was announced."
  exit 2
fi

echo
echo "=== applying the config to $WHO ==="
rcon "function fartpack:admin/rate $WHO $RATE" | grep -v '^>' | sed 's/^/  /'
rcon "function fartpack:admin/pow $WHO $POW"   | grep -v '^>' | sed 's/^/  /'

echo
echo "=== verifying (not trusting the command's exit) ==="
got_rate=$(get "$WHO" fart.rate)
got_pow=$(get "$WHO" fart.pow)
fail=0
if [ "$got_rate" = "$RATE" ]; then echo "  ok   rate = $got_rate"; else echo "  FAIL rate = '$got_rate', want $RATE"; fail=1; fi
if [ "$got_pow" = "$POW" ];   then echo "  ok   pow  = $got_pow";   else echo "  FAIL pow  = '$got_pow', want $POW"; fail=1; fi
# And the rest of the config should still be stock - prove the crown did not
# quietly move anything else.
cap=$(get "$WHO" fart.cap)
echo "  info cap = ${cap:-UNSET} (100 is stock)"

if [ "$fail" -ne 0 ]; then
  echo
  echo "CONFIG DID NOT APPLY. Not announcing - the message promises something untrue."
  exit 1
fi

echo
echo "=== announcing (only now, because it is finally true) ==="
rcon "tellraw @a [{\"text\":\"[Fartpack] Player $WHO is now declared the first King of the farts! You will now fart 2x faster!\",\"color\":\"gold\"}]" | grep -v '^>' | sed 's/^/  /'
echo
echo "=== DONE. $WHO is rate $RATE, knockback $POW. ==="
