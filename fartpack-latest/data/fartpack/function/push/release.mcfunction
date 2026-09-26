# push/release - the knockback from a player's own crouch release.
#
# v25: players in range are pushed again.
#
# This used to set `#noplayer 1` around the push, which made push/core strip every
# player out of the target set. That was a deliberate v16.3 change, but it left the
# pack inconsistent in a way that is obvious the moment you stand next to someone:
#
#   a sheep farting near you        -> pushes you   (push/norm,   no #noplayer)
#   a farting furnace near you      -> pushes you   (push/block,  no #noplayer)
#   another player crouch-farting   -> does NOT      (push/release, was #noplayer 1)
#
# So a mob could shove you but a person could not. Restored.
#
# The two `#noplayer` lines are gone rather than set to 0, because with nothing
# setting it to 1 the flag is no longer a per-call parameter. It stays in
# push/core and in bootstrap, where it is now what it should always have been: a
# global admin switch. If the player-vs-player shove turns out to be annoying,
# turn it off for the whole pack with
#
#   /scoreboard players set #noplayer fart.var 1
#
# and it stays off until set back to 0 (a reload will not reset it, which is the
# point of a toggle - and is also why bootstrap initialises it, so it can never be
# left stranded at 1 by a crash, see #4).
#
# You are never pushed by your own fart: push/core tags the source as
# `fart.pushersrc` and every target selector requires `tag=!fart.pushersrc`.
#
# v26: #power comes from the releasing player's own fart.pow (admin/pow, stock
# 30) instead of being hardcoded. Read with a guarded `operation =` rather than
# `store result ... scoreboard players get`, because a failed get does not write
# its target and would leave #power holding whatever the last caller put there -
# and because 0 is a legal setting meaning "no shove at all", which a
# `matches 1..` guard would have silently rewritten back to 30. `matches ..-1`
# is true only for 0 and negatives, so unset keeps the stock 30 and an explicit
# 0 is honoured.
scoreboard players set #power fart.var 30
execute if score @s fart.pow matches ..-1 run scoreboard players operation #power fart.var = @s fart.pow
scoreboard players set #vy fart.var 20
scoreboard players set #radius fart.var 5
function fartpack:push/core
