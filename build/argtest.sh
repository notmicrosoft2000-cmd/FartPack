#!/usr/bin/env bash
# argtest.sh - find out how /function macro arguments actually parse.
#
# Why: verifycfg.sh reports every admin command as UNSET even though
# `admin/rate #cfgtest 2` is reported as running. Either the macro silently
# fails to write, or the ARGUMENTS are not being parsed the way the pack
# assumes. Each form gets its own fake holder so results cannot collide with
# each other or with the verifycfg run in flight.
#
# Read-only apart from writing to throwaway `#t*` scoreboard holders.
set -uo pipefail
rcon() { python3 /tmp/rcon.py "$@" 2>&1; }

probe() {
  local label="$1" cmd="$2" holder="$3"
  echo "--- $label"
  echo "    sent: $cmd"
  out=$(rcon "$cmd" | grep -v '^>' | sed 's/^/    /')
  [ -n "$out" ] && echo "$out"
  got=$(rcon "scoreboard players get $holder fart.rate" | tail -2 | sed 's/^/    /')
  echo "$got"
  # leave no residue
  rcon "scoreboard players reset $holder fart.rate" >/dev/null 2>&1
  echo
}

echo "=== how does /function parse macro arguments? ==="
echo

# Control: with no args at all, a macro reports what it wants. This establishes
# that the function exists and is a macro.
probe "d) no args (control - proves it is a macro)" \
      "function fartpack:admin/rate" "#tnone"

# a) the form the pack documents and verifycfg uses
probe "a) unquoted name + number" \
      "function fartpack:admin/rate #ta 2" "#ta"

# b) name quoted as an SNBT string. This is the one that matters: if function
#    args are parsed as NBT, a bare word is not a string and must be quoted.
probe "b) quoted name + number" \
      'function fartpack:admin/rate "#tb" 2' "#tb"

# c) both quoted
probe "c) both quoted" \
      'function fartpack:admin/rate "#tc" "2"' "#tc"

# e) a selector instead of a name - a selector is unambiguous and needs no
#    quoting, so if THIS works the problem is specifically bare-word args.
probe "e) selector as the holder" \
      "function fartpack:admin/rate @a 2" "#te"

echo "=== does a bare single arg parse at all? ==="
rcon "function fartpack:admin/rate 2" | grep -v '^>' | sed 's/^/  /'
echo
echo "=== and the other macros, unquoted, for comparison ==="
for f in every cap rel pow; do
  printf '  admin/%-6s ' "$f"
  rcon "function fartpack:admin/$f #tf 2" | grep -v '^>' | tr '\n' ' ' | cut -c1-90
  echo
  rcon "scoreboard players reset #tf fart.var" >/dev/null 2>&1
done
rcon "scoreboard players reset #tf fart.rate" >/dev/null 2>&1
rcon "scoreboard players reset #tf fart.cap" >/dev/null 2>&1
rcon "scoreboard players reset #tf fart.pow" >/dev/null 2>&1
rcon "scoreboard players reset #tf fart.leg" >/dev/null 2>&1
rcon "scoreboard players reset #tf fart.warn" >/dev/null 2>&1
rcon "scoreboard players reset #tf fart.every" >/dev/null 2>&1
rcon "scoreboard players reset #tf fart.rel" >/dev/null 2>&1
