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
scoreboard players set #power fart.var 30
scoreboard players set #vy fart.var 20
scoreboard players set #radius fart.var 5
function fartpack:push/core
