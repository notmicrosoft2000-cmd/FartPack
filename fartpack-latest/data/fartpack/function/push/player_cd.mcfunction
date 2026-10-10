# push/player_cd - the cadence gate on the RADIAL player shove.
#
# v28. This exists because `tp` is a displacement and `Motion` was an impulse.
# An impulse decays; a displacement does not. player/press runs every tick and
# player/release_gas calls push/core every tick for the whole length of a
# crouch release, so an ungated 0.3-block `tp` would drag a player at 6 blocks
# a second for as long as they held the crouch - nothing like the mob shove it
# is supposed to match. Every 5th call gives 4 shoves a second, which reads as
# being shoved rather than being dragged.
#
# It is a separate function, and that is the whole design point: the gate must
# NOT be inside push/player, because push/self also calls push/player and it
# wants to fire IMMEDIATELY. push/self drives two one-shot events - the crouch
# self-push from player/press, and the 0.9-block self-launch at the end of
# world/fart_forced. Gating those would delay the forced mega-fart's launch by
# up to 5 ticks, and worse, could swallow it outright if the target's counter
# happened to be high. A gate that silently eats a one-shot is worse than no
# gate.
#
# Per-player, not global. A single #shovecd would mean one shoved player delays
# every other player's shove, so a crowd would push each other in sequence
# rather than all at once.

# The `run` is REQUIRED and its absence is not a style matter: the pre-deploy
# parse lint rejected the no-`run` form of this line on v28 with
#   Incorrect argument for command...ches 1..4 return 0<--[HERE]
# and stopped the deploy, which is the lint working as designed. Asked directly
# over RCON, the server accepts `execute if ... matches 1..4 run return 0` and
# rejects the same line without `run`. The caret points past the end of the line,
# so the error does not name the missing token - the same unhelpful failure shape
# as #30's arity error. tick.mcfunction:60 already had the `run`; this file was
# the only place in the pack written without it.
#
# `return` takes a bare integer: `return 0 1` and `return true` are both rejected.
# The value is irrelevant here because nothing fetches a function's return value;
# 0 is just the "did nothing" convention.
scoreboard players add @s fart.shovecd 1
execute if score @s fart.shovecd matches 1..4 run return 0
scoreboard players set @s fart.shovecd 0
function fartpack:push/player
