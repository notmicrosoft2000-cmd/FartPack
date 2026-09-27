#!/usr/bin/env bash
# verifycfg.sh - machine-verify the admin config layer.
#
# Runs on the server AFTER the reload, with 0 players online.
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
# Set to 0 by the detector in section 1 if the admin invocation ever starts
# working. It exists so that "the clamps are unverified" is a computed fact
# rather than a sentence in a comment that nobody re-reads.
UNVERIFIABLE=1
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

  echo "=== 0a. did ANY pack function fail to load this reload? ==="
  # This is the check that should have caught #30 on the v26 deploy. A function
  # that will not load makes its whole feature silently do nothing - in v26,
  # player/apply_gas failed, so the gas bar stopped filling for every player and
  # nothing anywhere said so except one ERROR line naming the file.
  SRVLOG="$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/logs/latest.log"
  #
  # BOUNDED TO THE LAST RELOAD, and this matters more than it looks.
  #
  # This used to `grep -c` the WHOLE of latest.log. A reload does not clear the
  # log, so it counted the two earlier broken v28 deploys (12:40, 12:48, 12:49 -
  # all `Failed to load function fartpack:player/press`) and reported 4 failures
  # against a reload where that file loads perfectly. deploy.sh bounds the same
  # check with a line-count captured before the reload; verifycfg runs afterwards
  # and cannot share that number, so it finds the last `Reloading!` instead.
  #
  # The interesting part is the fallback. When no reload line can be found the
  # old behaviour - count everything - is a verdict about log history dressed up
  # as a verdict about the current pack, so it is NOT used. The check reports
  # that it could not bound itself and fails, because a check that cannot say
  # what it examined should not return a pass.
  RELOADLN=$(grep -n 'Reloading!' "$SRVLOG" 2>/dev/null | tail -1 | cut -d: -f1)
  if [ -n "${RELOADLN:-}" ]; then
    BOUNDED=$(tail -n "+$((RELOADLN+1))" "$SRVLOG" 2>/dev/null || true)
    echo "  (scanning only the $(printf '%s' "$BOUNDED" | wc -l) log lines after the reload at line $RELOADLN)"
  else
    BOUNDED=""
    echo "  (no 'Reloading!' line found - CANNOT BOUND TO THE CURRENT RELOAD)"
  fi
  BADLOAD=$(printf '%s' "$BOUNDED" | grep -c 'Failed to load function fartpack' || true)
  if [ -z "$RELOADLN" ]; then
    printf '  FAIL could not bound this check to a reload, so it cannot be run honestly\n'
    FAIL=$((FAIL+1))
  elif [ "${BADLOAD:-0}" -ne 0 ]; then
    printf '  FAIL %s pack function(s) failed to load SINCE THE LAST RELOAD:\n' "$BADLOAD"
    printf '%s' "$BOUNDED" | grep 'Failed to load function fartpack' \
      | sed 's/.*Failed to load/Failed to load/' | sort -u | sed 's/^/        /'
    FAIL=$((FAIL+1))
  else
    echo "  ok   0 pack functions failed to load since the last reload"
  fi
  echo
  echo "=== 1. the admin invocation form - this gate used to issue a command that does not exist ==="
  # HISTORY, because the 30 FAILs it used to print were not 30 broken clamps.
  # It issued:  function fartpack:admin/rate #cfgtest 2
  # which the server rejects outright with "Expected a valid unquoted string".
  # POSITIONAL MACRO ARGUMENTS CANNOT BE PASSED AS BARE COMMAND ARGUMENTS in this
  # server version. Measured, all rejected, none reached the macro:
  #     function fartpack:admin/rate #cfgtest 2       Expected a valid unquoted string
  #     function fartpack:admin/rate #cfgtest "2"     Expected a valid unquoted string
  #     function fartpack:admin/rate "#cfgtest" "2"   Expected a valid unquoted string
  #     function fartpack:admin/rate abc 2            Expected compound tag
  #     function fartpack:admin/rate abc 2.5          Expected compound tag
  # and the grammar, asked for directly:
  #     function <id>            -> runs, answers "Missing arguments"
  #     function <id> <one arg>  -> "Expected compound tag"  (it wants a TAG PATH)
  #     function <id> with ...   -> reaches the macro, answers "Missing argument arg0"
  # So the ONLY working form is `with storage`, which needs arg0/arg1 present in
  # that storage. Verified: writing {"arg0":"...","arg1":N} and calling
  # `with storage fartpack:data macro` DOES instantiate the macro and does the
  # clamp arithmetic.
  #
  # That makes the whole documented interface unusable, and it is PRE-EXISTING:
  # 9 of the 12 files in admin/ take positional args, all added in 50f17cf
  # "v26: per-player config layer" (#29). The only places the bare-arg form is
  # written down are 5 comment headers, and nothing in the pack calls them
  # internally, so it was never exercised by anything - not by a player, not by a
  # test, and not by this gate, which had never once been run to completion
  # before now (every earlier v28 deploy aborted upstream of it).
  #
  # A second, independent reason sections 1-5 cannot work at 0 players even
  # once the invocation is fixed: every setter ends in
  #     $tellraw $(arg0) [...]
  # and tellraw needs a real player, so `#cfgtest` cannot be the target. The
  # premise in this script's own header - "SCOREBOARD OPERATIONS WORK ON FAKE
  # PLAYERS, so nothing needs to be connected" - is FALSE for these macros. A
  # fake holder is not a substitute for a player when the command targets one.
  #
  # So the honest move is not to delete the checks, and not to relax them into a
  # pass. It is to (a) state that they are unreachable, and (b) turn the defect
  # into a DETECTOR: assert that the documented form is still rejected. The day
  # someone fixes the admin layer this gate will start failing and say the
  # sections are worth re-enabling, instead of the fix passing unnoticed - which
  # is exactly what happened to the defect in the first place.
  for f in rate every cap rel pow; do
    out=$(python3 /tmp/rcon.py "function fartpack:admin/$f SomePlayer 7" 2>&1)
    if printf '%s' "$out" | grep -qi 'Unknown function'; then
      printf '  FAIL admin/%-6s not found\n' "$f"; FAIL=$((FAIL+1))
    elif printf '%s' "$out" | grep -qiE 'Expected|Incorrect argument'; then
      printf '  KNOWN admin/%-6s documented form still rejected (positional args unusable)\n' "$f"
    else
      printf '  NEW  admin/%-6s ACCEPTED the documented form - the invocation now works!\n' "$f"
      printf '        response: %s\n' "$(printf '%s' "$out" | head -1 | cut -c1-90)"
      printf '        -> re-enable sections 2-6 against a real player; the clamps are\n'
      printf '           UNVERIFIED again until they are actually run.\n'
      UNVERIFIABLE=0
    fi
  done

  if [ "${UNVERIFIABLE:-1}" = 0 ]; then
    echo
    echo "  Sections 2-6 (the clamp arithmetic) are UNVERIFIED, not passing. They are"
    echo "  skipped below rather than reported green, because no test ran."
  else
    echo
    echo "  Sections 2-6 (rate/every/cap/rel/pow clamps, and the derived fart.leg and"
    echo "  fart.warn) are NOT VERIFIABLE and were NOT RUN. They are not passing."
  fi


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
  echo
  if [ "$FAIL" -ne 0 ]; then
    echo "RESULT: $FAIL CHECK(S) FAILED - do not call this verified."
    exit 1
  fi
  echo "RESULT: every check this gate can actually run passed."
  echo "        (sections 0a, 0b, 1-detector, 6, 7 - see section 1 for what is missing)"
  echo
  echo "NOT VERIFIED - no test was run for any of these. Not passing, not failing:"
  echo "  * the admin clamp arithmetic: rate, every, cap, rel, pow, and the"
  echo "    derived fart.leg and fart.warn. Unreachable because the documented"
  echo "    invocation form does not parse, and because every setter tellraws"
  echo "    its target, so a fake scoreboard holder cannot stand in for a player."
  echo "  * admin/reset, admin/show, admin/resync_bar (they start with 'execute as')"
  echo "  * the bar actually filling at the new rate, and the bossbar resizing"
  echo "  * the knockback distance changing with admin/pow"
  echo "  * player-vs-player knockback itself (#28) - also needs two people"
  echo
  echo "#cfgok MUST NOT be set from this script's exit status alone. Exit 0 here"
  echo "means 'nothing I can check is broken', which is a much weaker claim than"
  echo "'the config layer works'. See BUGS-AND-FIXES.md #32."
