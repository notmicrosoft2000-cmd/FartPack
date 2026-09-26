#!/usr/bin/env bash
# Verify the v20 features the linter cannot check.
#
#   #23  the generated block-name lookup resolves to the right phrase
#   #24  a player-target push now writes Motion and never a position
#   #22  the crouch-strain fix, on a real entity (see stresstest.sh)
#
# HARNESS NOTES - each of these produced a WRONG ANSWER before it produced an
# error, so they are load-bearing rather than decoration:
#
#   * `R` MUST be an array. `R="python3 /tmp/rcon.py"` then `"$R" 'cmd'` passes the
#     whole string as ONE argv entry, so the shell looks for an executable
#     literally named "python3 /tmp/rcon.py". Every such call fails silently and
#     the script reports a clean run having tested nothing. Use "${R[@]}".
#   * The chunk is force-loaded. With 0 players the world is PAUSED and chunks
#     unload. `setblock` then fails with "That position is not loaded", and far
#     worse, `execute if block` in an unloaded chunk fails SILENTLY. A silent
#     false is indistinguishable from a broken lookup.
#   * Only use block ids that EXIST on this server. `minecraft:undyed_shulker_box`
#     is not one of them (it is `minecraft:shulker_box`), and a `setblock` with an
#     unknown id fails while LEAVING THE PREVIOUS BLOCK IN PLACE. The lookup then
#     correctly reported the anvil from the previous test case, which read exactly
#     like a name-lookup bug: the generated file cannot blame the wrong block for
#     a block that is not there.
#   * `setblock` reports "Could not set the block" when it is a NO-OP, i.e. when
#     the block is already what you asked for. That is not a failure, but it means
#     setup output cannot be used to confirm a block exists. Confirm with
#     `execute if block ... run data modify storage ...`.
#   * `say` is NOT captured by rcon.py; broadcast chat never comes back in the
#     response, so a `run say` probe prints nothing whether it fired or not.
#     Every assertion here uses `data get` / `scoreboard players get`.
#   * `data modify <storage> <key> add value 1` is rejected by this server, so the
#     entity count is built by appending to a list and counting the commas.
set -uo pipefail
R=(python3 /tmp/rcon.py)

CX=300; CY=100; CZ=300
CX10=3005                      # the test bird lands at 300.5 -> 3005 in tenths
KB="@e[type=minecraft:chicken,tag=fart.kbtest]"

count_sel() {  # <selector> -> number of matching entities
  "${R[@]}" 'data modify storage fartpack:msg n set value []' >/dev/null 2>&1
  "${R[@]}" "execute as $1 run data modify storage fartpack:msg n append value 1" >/dev/null 2>&1
  local out
  out=$("${R[@]}" 'data get storage fartpack:msg n' 2>/dev/null | tail -1)
  case "$out" in
    *'[]'*) echo 0 ;;
    *'['*)  echo $(( $(printf '%s' "$out" | tr -cd ',' | wc -c) + 1 )) ;;
    *)      echo "?" ;;
  esac
}
read_name()   { "${R[@]}" 'data get storage fartpack:msg name'   2>/dev/null | tail -1 | sed 's/.*contents: //'; }
read_motion() { "${R[@]}" "data get entity $KB,limit=1 Motion"  2>/dev/null | tail -1 | sed 's/.*entity data: //'; }
read_stress() { "${R[@]}" "scoreboard players get $KB,limit=1 fart.stress" 2>/dev/null | tail -1; }
read_health() { "${R[@]}" "data get entity $KB,limit=1 Health"  2>/dev/null | tail -1 | sed 's/.*entity data: //'; }

# Confirm a block is really there. A setblock success message is not evidence:
# the command is a silent no-op when the block already matches.
confirm_block() {  # <id> <y> -> prints the id if the server agrees
  "${R[@]}" "data modify storage fartpack:msg probe set value NO_MATCH" >/dev/null 2>&1
  "${R[@]}" "execute if block $CX $2 $CZ $1 run data modify storage fartpack:msg probe set value CONFIRMED" >/dev/null 2>&1
  local v; v=$("${R[@]}" 'data get storage fartpack:msg probe' 2>/dev/null | tail -1 | sed 's/.*contents: //')
  [ "$v" = '"CONFIRMED"' ] && echo "yes" || echo "NO -- server does not see it"
}

echo "=== setup ==="
"${R[@]}" 'forceload add 300 300' >/dev/null 2>&1
"${R[@]}" "fill $CX $CY $CZ $CX $((CY+6)) $CZ minecraft:air" >/dev/null 2>&1
"${R[@]}" "setblock $CX $((CY+3)) $CZ minecraft:stone" >/dev/null 2>&1
echo "  chunk ($CX,$CZ) force-loaded, column cleared, floor placed"
echo "  floor present? $(confirm_block minecraft:stone $((CY+3)))"

echo
echo "=== #23 block-name lookup ==="
echo "  One lookup per block. Every id below is verified to exist on this server"
echo "  BEFORE the lookup runs. The last case is NOT a utility block and must fall"
echo "  back to the generic phrase, because the generated file resets the name"
echo "  BEFORE the lookup chain - so an unmatched block can never inherit the"
echo "  previous block's name."
echo
for b in minecraft:crafting_table minecraft:enchanting_table minecraft:jukebox \
         minecraft:anvil minecraft:furnace minecraft:barrel \
         minecraft:white_shulker_box minecraft:smithing_table ; do
  "${R[@]}" "setblock $CX $((CY+4)) $CZ $b" >/dev/null 2>&1
  present=$(confirm_block "$b" $((CY+4)))
  "${R[@]}" "execute positioned $CX $((CY+4)) $CZ run function fartpack:world/block_name" >/dev/null 2>&1
  printf '  %-32s placed=%-4s name=%s\n' "$b" "$present" "$(read_name)"
done
printf '  %-32s %-9s name=%s   <- not a utility block, must be generic\n' \
  minecraft:stone "n/a" "$( "${R[@]}" "execute positioned $CX $((CY+4)) $CZ run function fartpack:world/block_name" >/dev/null 2>&1; read_name )"

echo
echo "  The string macro splices that name into the sentence. Worth checking on its"
echo "  own: a macro whose lines lack \$(var) is a total function failure and it"
echo "  never appears in the log, so a broken one is invisible until someone farts."
"${R[@]}" "setblock $CX $((CY+4)) $CZ minecraft:crafting_table" >/dev/null 2>&1
"${R[@]}" "execute positioned $CX $((CY+4)) $CZ run function fartpack:world/block_name" >/dev/null 2>&1
"${R[@]}" "execute positioned $CX $((CY+4)) $CZ run function fartpack:world/fart_msg with storage fartpack:msg" 2>&1 | tail -1
echo "  (no error above = the macro resolved. The substituted text goes to chat,"
echo "   which rcon.py does not return, so the wording cannot be read back here.)"

echo
echo "=== #24 knockback: Motion, not tp ==="
echo "  No player is online, so push/player is driven against a chicken."
echo "  push/player is type-agnostic - it reads only Pos and writes only Motion -"
echo "  so this exercises the identical code path. The one player-specific line is"
echo "  a selector in push/core, checked at the end of this section."
echo
"${R[@]}" "kill $KB" >/dev/null 2>&1
"${R[@]}" "kill $KB" >/dev/null 2>&1
"${R[@]}" "summon minecraft:chicken $CX $((CY+4)) $CZ {Tags:[\"fart.kbtest\"]}" >/dev/null 2>&1
N=$(count_sel "$KB")
echo "  test birds: $N  (must be 1)"
if [ "$N" != "1" ]; then
  echo "  ABORT: duplicates make every selector ambiguous."
  "${R[@]}" "kill $KB" 'forceload remove 300 300' >/dev/null 2>&1
  exit 1
fi
"${R[@]}" 'execute store result score #px fart.var run data get entity @e[type=minecraft:chicken,tag=fart.kbtest,limit=1] Pos[0] 10' >/dev/null 2>&1
echo "  bird Pos[0] in tenths: $("${R[@]}" 'scoreboard players get #px fart.var' 2>/dev/null | tail -1 | sed 's/.*: //')  (summon at $CX -> 300.5 -> 3005)"
echo "  sanity, a push with no source offset is the zero case:"
echo
printf '  %-36s %-22s %s\n' "case" "expected" "actual"
kb() {  # <label> <source_x10> <power> <vy> <expected>
  "${R[@]}" "scoreboard players set #power fart.var $3" \
            "scoreboard players set #vy fart.var $4" \
            "scoreboard players set #ppx10 fart.var $2" \
            "scoreboard players set #ppz10 fart.var $CX10" >/dev/null 2>&1
  "${R[@]}" "execute as $KB,limit=1 run function fartpack:push/player" >/dev/null 2>&1
  printf '  %-36s %-22s %s\n' "$1" "$5" "$(read_motion)"
}
# vx = (power/100) * dx/(dx+dz); source due west => dx>0 => push +X.
kb "3 blocks, power 35 (normal)"      $((CX10-30))  35 20 "[0.35, 0.2, 0.0]"
kb "3 blocks, power 90 (legendary)"   $((CX10-30))  90 40 "[0.9, 0.4, 0.0]"
kb "12 blocks, power 12 (long range)" $((CX10-120)) 12 20 "[0.12, 0.2, 0.0]"
kb "diagonal 3+3, power 35"           $((CX10-30))  35 20 "[0.175, 0.2, 0.175]"
kb "power 0 (must be exactly zero)"   $((CX10-30))  0 0  "[0.0, 0.0, 0.0]"

echo
echo "  Same cases through push/one (the mob path) for comparison. push/one divides"
echo "  straight to an integer, so note the long-range row."
one() {  # <label> <source_x10> <power> <vy>
  "${R[@]}" "scoreboard players set #power fart.var $3" \
            "scoreboard players set #vy fart.var $4" \
            "scoreboard players set #ppx fart.var $(( $2 / 10 ))" \
            "scoreboard players set #ppz fart.var $(( CX10 / 10 ))" >/dev/null 2>&1
  "${R[@]}" "execute as $KB,limit=1 run function fartpack:push/one" >/dev/null 2>&1
  printf '  %-36s %s\n' "$1" "$(read_motion)"
}
one "push/one 3 blocks, power 35"   $((CX10-30))  35 20
one "push/one 12 blocks, power 12" $((CX10-120)) 12 20

echo
echo "  Player routing (the one player-specific line, and why the bird stood in):"
python3 - "$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/world/datapacks/fartpack.zip" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
n = [x for x in z.namelist() if x.endswith('push/core.mcfunction')][0]
for i, line in enumerate(z.read(n).decode().splitlines(), 1):
    if 'push/player' in line or 'push/one' in line:
        print("    core:%d  %s" % (i, line.strip()))
PY

echo
echo "=== the tp machinery is gone from the deployed pack ==="
python3 - "$HOME/crafty/servers/241920ac-55ce-46c6-aa2f-c42ebf290457/world/datapacks/fartpack.zip" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
names = z.namelist()
gone = [n for n in names if n.endswith(('player_step.mcfunction', 'player_hop.mcfunction'))]
print("  deleted files still present:", gone if gone else "none - good")
tp = []
for n in names:
    if n.endswith('.mcfunction'):
        for i, line in enumerate(z.read(n).decode(errors='replace').splitlines(), 1):
            s = line.strip()
            if s.startswith('tp ') or ' run tp ' in s:
                tp.append("    %s:%d  %s" % (n.split('function/')[-1], i, s))
print("  remaining tp commands in the whole pack:", "none - good" if not tp else "\n" + "\n".join(tp))
new = sorted(x.split('function/')[-1] for x in names
             if x.endswith(('block_name.mcfunction', 'fart_msg.mcfunction')))
print("  new v20 files present:", new)
PY

echo
echo "=== #22 crouch strain ==="
bash /tmp/stresstest.sh

echo
echo "=== cleanup ==="
"${R[@]}" "kill $KB" \
  "fill $CX $CY $CZ $CX $((CY+6)) $CZ minecraft:air" \
  'forceload remove 300 300' >/dev/null 2>&1
echo "  test birds killed, column cleared, chunk released"
echo "  forceloaded chunks now: $("${R[@]}" 'forceload query' 2>/dev/null | tail -1 | sed 's/^ *//')"
