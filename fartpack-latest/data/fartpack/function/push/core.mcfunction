# push/core - radial knockback. Callers set #power, #vy and #radius, then run this.
#
# #radius IS AN ENUM, NOT A KNOB. This is the single most misleading thing in
# the file, so it is worth being blunt: `distance=..N` cannot take a scoreboard
# score or a macro, so the radius has to be a LITERAL in the selector, and the
# only radii that exist are the ones written below. Setting #radius to 20 does
# not push people 20 blocks away - it matches NO branch, nothing is tagged, and
# the fart pushes nobody at all, silently, with no error anywhere. Anyone adding
# a radius must add a branch here as well; there is no way to make it generic.
#
# The branches below look like four full entity scans, but they are
# not: `execute if score ... run <selector>` only evaluates the selector when the
# score matches, and #radius is set to exactly one of 3/4/5/12/20/30 by the callers
# and by the king line, so exactly ONE `@e` scan happens per push. Do not
# "optimise" this into a single radius-20 pass - that would tag far-away entities
# as push targets and then have to un-tag them, which is strictly more work.

scoreboard players set #neg1 fart.var -1
scoreboard players set #one fart.var 1
scoreboard players set #ten fart.var 10
scoreboard players set #twelve fart.var 12
# v30: the Fart King's knockback, applied HERE and not in the callers, because
# this is the only place that knows #radius is an enum - a caller can only pick
# from the list, so "the king pushes further" has to be a decision made where
# the list lives. It is also the only place guaranteed to still be running as the
# FARTER: the lines below read @s's own position, and the `execute as @e[...]`
# that switches to the targets does not happen until line 39.
#
# #kpow scales the impulse; #radius 30 replaces whatever the caller asked for,
# so a king's ordinary fart shoves nearly as far as a legendary one used to.
# v31: 20 -> 30 blocks and x2 -> x3, because "more op" was the request and the
# crown's whole point is that it is noticeable across a room.
execute if entity @s[tag=fart.king] run scoreboard players operation #power fart.var *= #kpow fart.var
execute if entity @s[tag=fart.king] run scoreboard players operation #vy fart.var *= #kpow fart.var
execute if entity @s[tag=fart.king] run scoreboard players set #radius fart.var 30
execute store result score #ppx fart.var run data get entity @s Pos[0]
execute store result score #ppz fart.var run data get entity @s Pos[2]
execute store result score #ppx10 fart.var run data get entity @s Pos[0] 10
execute store result score #ppz10 fart.var run data get entity @s Pos[2] 10
tag @s add fart.pushersrc
execute if score #radius fart.var matches 3 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..3] add fart.pushtarget
execute if score #radius fart.var matches 4 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..4] add fart.pushtarget
execute if score #radius fart.var matches 5 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..5] add fart.pushtarget
execute if score #radius fart.var matches 12 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..12] add fart.pushtarget
# v30: the king's 20. This line is the ONLY reason fart.rate 2 reads to a player
# as "I shove people across the room" - without it the two lines above would set
# #radius to 20 and push nobody.
# v31: 20 -> 30, and the comment above it is stale about WHY in one respect: the
# king no longer gets there via fart.rate (that is a gas multiplier in
# player/apply_gas now). The radius is still set here, still overriding the
# caller's request, and it still needs its own branch or the king's fart pushes
# nobody at all. A new enum value with no branch is the quietest failure in this
# entire pack: no error, no warning, and a king whose crown does nothing.
execute if score #radius fart.var matches 20 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..20] add fart.pushtarget
execute if score #radius fart.var matches 30 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..30] add fart.pushtarget
# Global admin switch: at 1, players are never knockback targets, whoever farted.
# Nothing in the pack sets it any more - push/release used to set it around its own
# call, which is why a player's crouch fart could not shove another player while a
# sheep's could. v25 deleted those two lines believing that was the whole of #28.
# It was not: #noplayer was measured at 0 on the live server at the time of the
# v28 work, so the switch was not what was stopping player shoves. See
# push/player for what was. The switch is kept, because a pack-wide opt-out is
# still the right thing to have:
#   /scoreboard players set #noplayer fart.var 1
# bootstrap initialises it to 0, so a crash mid-push can never strand it at 1.
execute if score #noplayer fart.var matches 1 run tag @e[type=minecraft:player,tag=fart.pushtarget] remove fart.pushtarget
# v28: players go through push/player_cd, not push/player. The extra hop is the
# 5-tick cadence gate, and it exists because the player path is a `tp` (a
# displacement) where the mob path is `Motion` (an impulse that decays). See
# push/player_cd and push/player for the whole story, including why the gate is
# not inside push/player.
execute as @e[tag=fart.pushtarget,type=minecraft:player] at @s run function fartpack:push/player_cd
execute as @e[tag=fart.pushtarget,type=!minecraft:player] at @s run function fartpack:push/one
tag @e[tag=fart.pushtarget] remove fart.pushtarget
tag @s remove fart.pushersrc
