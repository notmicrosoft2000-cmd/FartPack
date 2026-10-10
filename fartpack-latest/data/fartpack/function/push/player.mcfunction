# push/player - knockback applied to a PLAYER.
#
# v28: THIS NO LONGER USES `Motion`. It uses a relative `tp`, and the reason is
# the whole of #28 - "a player crouch-farting could not shove another player,
# but a sheep could", which v25 believed it had fixed and which was still true.
#
# Motion WORKS. On an entity. The arithmetic below has been correct for a long time
# and the reported symptom - "other entities yes, other players no" - is exactly the
# shape of a bug whose maths is not where it lives.
#
# WHAT IS MEASURED AND WHAT IS INFERRED, because this comment previously blurred
# the two and the difference matters:
#   MEASURED (live server, 0 players, chicken as target, driving this file): the
#   arithmetic is right and the write is accepted. #dx 20, #dz 0, #dist 20,
#   #ux10 300, #vy10 200, Motion left at [0.3, 0.2, 0.0] - identical to what
#   push/one gave the mob path in the same run.
#   MEASURED (the user's report, three versions running): a crouch-fart shoves a
#   sheep and does not shove a player.
#   INFERRED (the explanation, not a measurement): a mob's delta movement is
#   integrated by its own physics each tick, so an impulse survives and decays; a
#   player's position is reconciled against the movement packet its client sends,
#   so whatever a datapack wrote into Motion is superseded before it matters. I
#   could not test this - there is no way to observe it at 0 players, which is
#   precisely why the bug survived v25, v26 and v27. But it is the standard reason
#   Motion does not work on players, and it is consistent with both measurements.
#   Either way the conclusion is the same: `Motion` is not a lever a datapack has
#   over a player, so the fix does not depend on the inference being right.
#
# That last point is the reason to be careful about the wording but not cautious
# about the change: `tp` moves a player under BOTH explanations - whether the
# packet reconciliation is the cause, or whether the write is discarded later. A
# fix justified by an inference should be chosen so that the inference is not load-
# bearing. This one is.
#
# `tp` is the only primitive a datapack has that moves a player
# authoritatively, so that is what this uses now. The old pre-v17 implementation
# was also a `tp` - the "marker hop" - and was replaced with Motion because a
# long walk of small `tp`s inside one tick reads as teleporting. The mistake was
# treating the two as alternatives. It is one step of 0.3 blocks, not a walk.
#
# THE COST, stated rather than hidden: Motion is an impulse and `tp` is a
# displacement. Impulse decays; displacement does not. A 0.3-block `tp` every
# tick would drag a player along at 6 blocks a second, which is not remotely the
# mob experience. So the radial shove is gated to every 5th call - see
# push/player_cd, which is deliberately NOT in this file so that push/self's
# one-shot self-launch still fires immediately.
#
# INPUTS
#   #ppx10 / #ppz10  push SOURCE in tenths of a block. Written by push/core for a
#                    radial push, and by push/self for the self-push.
#   #power           horizontal impulse, in 1/100 blocks per tick (35 -> 0.35).
#   #vy              vertical impulse, same units.
#
# The direction used is a manhattan-length normaliser (dx / (|dx|+|dz|)), the same
# one push/one uses, so players and mobs are pushed consistently.
#
# ARITHMETIC
#   offset_x = (power/100) * dx/dist
# Carrying a factor of 10 through the division lands the result in 1/1000 blocks
# per tick. The factor of 10 is also what stops this truncating: push/one divides
# down to an integer immediately, so at power 12 and distance 12 a component
# floors to 0 and the far edge of the radius gets almost nothing. One decimal
# place of headroom costs nothing and keeps the near and far edges consistent.

scoreboard players set #neg1 fart.var -1
scoreboard players set #ten fart.var 10
execute store result score #tx fart.var run data get entity @s Pos[0] 10
execute store result score #tz fart.var run data get entity @s Pos[2] 10

# target - source
scoreboard players operation #dx fart.var = #tx fart.var
scoreboard players operation #dx fart.var -= #ppx10 fart.var
scoreboard players operation #dz fart.var = #tz fart.var
scoreboard players operation #dz fart.var -= #ppz10 fart.var
scoreboard players operation #adx fart.var = #dx fart.var
execute if score #adx fart.var < #neg1 fart.var run scoreboard players operation #adx fart.var *= #neg1 fart.var
scoreboard players operation #adz fart.var = #dz fart.var
execute if score #adz fart.var < #neg1 fart.var run scoreboard players operation #adz fart.var *= #neg1 fart.var

# Manhattan distance, floored at 1 so a perfectly radial hit cannot divide by zero.
scoreboard players operation #dist fart.var = #adx fart.var
scoreboard players operation #dist fart.var += #adz fart.var
execute if score #dist fart.var matches 0 run scoreboard players set #dist fart.var 1

# offset in 1/1000 blocks per tick
scoreboard players operation #ux10 fart.var = #dx fart.var
scoreboard players operation #ux10 fart.var *= #power fart.var
scoreboard players operation #ux10 fart.var *= #ten fart.var
scoreboard players operation #ux10 fart.var /= #dist fart.var
scoreboard players operation #uz10 fart.var = #dz fart.var
scoreboard players operation #uz10 fart.var *= #power fart.var
scoreboard players operation #uz10 fart.var *= #ten fart.var
scoreboard players operation #uz10 fart.var /= #dist fart.var
scoreboard players operation #vy10 fart.var = #vy fart.var
scoreboard players operation #vy10 fart.var *= #ten fart.var

# No minimum-velocity floor, deliberately. A hit straight down one axis legitimately
# has a zero component on the other axis, and forcing a non-zero value there would
# shove players sideways for no reason. The divide-by-zero case is the #dist floor
# above, and that is the only thing that needed guarding.

# The three offsets go into the macro storage as DOUBLES here, in the CALLER, and
# not inside push/apply_tp. A macro function is expanded in full before any of its
# lines execute, so a macro that stored its own arguments would substitute values
# from the PREVIOUS target - and push/core walks every player in the radius in one
# pass, so every player would be shoved along the last player's vector. Same rule,
# same reason, as bar/tick_gas_bar writing pid and cap before calling its macros.
execute store result storage fartpack:data macro.dx double 0.001 run scoreboard players get #ux10 fart.var
execute store result storage fartpack:data macro.dz double 0.001 run scoreboard players get #uz10 fart.var
execute store result storage fartpack:data macro.dyy double 0.001 run scoreboard players get #vy10 fart.var
function fartpack:push/apply_tp with storage fartpack:data macro
