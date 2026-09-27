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

# Wait on EVIDENCE THE FEATURE WORKS, not on a version number.
#
# This used to wait for `#loaded == 26`, which is the wrong thing to wait for and
# fails in the most dangerous direction. On v26 the config layer was half alive:
# admin/rate, admin/pow and the rest all loaded and worked, while
# player/apply_gas - the function that actually moves gas into the bar - failed
# to load entirely. A version-number check would have gone green, crowned the
# player, and announced a 2x bar on a bar that could not fill at all.
#
# deployauto.sh therefore sets #cfgok to 1 only after verifycfg.sh has actually
# passed, and clears it to 0 before every reload. If the config layer is broken
# in any way, that flag is 0 and this script refuses - which is the correct
# outcome, because the alternative is telling a player their buff is live when
# it is not.
# CAN THE ADMIN LAYER EVEN BE CALLED? Checked before waiting, because #cfgok is
# now never set at 0 players and this loop would otherwise sit for 90 minutes
# waiting for a flag that cannot arrive. That is not a safety property, it is a
# way of making the operator wait to learn something already known.
#
# Measured on this server: positional macro arguments cannot be passed as bare
# command arguments, so `function fartpack:admin/rate <name> <n>` is REJECTED by
# the parser - "Expected a valid unquoted string" - and never reaches the macro.
# Nine of the twelve files in admin/ take positional args, including both
# commands this script exists to run. See BUGS-AND-FIXES.md #32.
#
# So the probe below is not a formality. If the documented form is rejected the
# crown cannot be applied, and refusing now - in one second, with the reason - is
# strictly better than waiting out the timeout and failing with "the config layer
# never verified", which is true but does not say why.
echo "=== can the admin commands be called at all? ==="
probe=$(rcon "function fartpack:admin/rate __crown_probe__ 2" 2>&1)
if printf '%s' "$probe" | grep -qiE 'Expected|Incorrect argument'; then
  echo "  REFUSING: 'function fartpack:admin/rate <player> <n>' is rejected by the parser."
  # rcon.py echoes the command back with a leading "> " before the server's
  # reply, so head -1 shows the echo rather than the error. Skip those lines:
  # a refusal that quotes its own command back is not an explanation.
  echo "  response: $(printf '%s' "$probe" | grep -v '^>' | head -1 | cut -c1-100)"
  echo
  echo "  $WHO is NOT crowned, and NO announcement was made. Nothing was changed."
  echo
  echo "  A crown promises a 2x bar. Setting it needs admin/rate, and admin/rate"
  echo "  cannot currently be invoked, so the promise would be empty. This script"
  echo "  refuses rather than announce something untrue - which is the same"
  echo "  property it has always had, just reached sooner and with a reason."
  echo
  echo "  Fix: BUGS-AND-FIXES.md #32, then re-run this script."
  exit 2
fi
echo "  ok  the admin invocation form is accepted."
echo
echo "=== waiting for the verified config layer (max 5400s) ==="
t=0
while [ "$t" -lt 5400 ]; do
  ok=$(get '#cfgok' fart.var)
  if [ "$ok" = "1" ]; then
    echo "  config layer verified at v$(get '#loaded' fart.var)."
    break
  fi
  if [ $((t % 300)) -eq 0 ]; then
    online=$(rcon list | grep -oE 'There are [0-9]+ of' | grep -oE '[0-9]+' | head -1)
    echo "  $t: v$(get '#loaded' fart.var), #cfgok=${ok:-UNSET}, ${online:-?} players online"
  fi
  sleep 15
  t=$((t+15))
done

if [ "$(get '#cfgok' fart.var)" != "1" ]; then
  echo "TIMEOUT: the config layer never verified. Nothing was changed, nothing was announced."
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
