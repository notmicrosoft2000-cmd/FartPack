# push/core - radial knockback. Callers set #power, #vy and #radius, then run this.
#
# The four radius branches below look like four full entity scans, but they are
# not: `execute if score ... run <selector>` only evaluates the selector when the
# score matches, and #radius is set to exactly one of 3/4/5/12 by the callers, so
# exactly ONE `@e` scan happens per push. Do not "optimise" this into a single
# radius-12 pass - that would tag far-away entities as push targets and then
# have to un-tag them, which is strictly more work.
scoreboard players set #neg1 fart.var -1
scoreboard players set #one fart.var 1
scoreboard players set #ten fart.var 10
scoreboard players set #twelve fart.var 12
execute store result score #ppx fart.var run data get entity @s Pos[0]
execute store result score #ppz fart.var run data get entity @s Pos[2]
execute store result score #ppx10 fart.var run data get entity @s Pos[0] 10
execute store result score #ppz10 fart.var run data get entity @s Pos[2] 10
tag @s add fart.pushersrc
execute if score #radius fart.var matches 3 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..3] add fart.pushtarget
execute if score #radius fart.var matches 4 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..4] add fart.pushtarget
execute if score #radius fart.var matches 5 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..5] add fart.pushtarget
execute if score #radius fart.var matches 12 run tag @e[type=!#fartpack:no_push,tag=!fart.pushersrc,name=!"Server",distance=..12] add fart.pushtarget
# Global admin switch: at 1, players are never knockback targets, whoever farted.
# Nothing in the pack sets it any more - push/release used to set it around its own
# call, which is why a player's crouch fart could not shove another player while a
# sheep's could. It is left here as a pack-wide opt-out:
#   /scoreboard players set #noplayer fart.var 1
# bootstrap initialises it to 0, so a crash mid-push can never strand it at 1.
execute if score #noplayer fart.var matches 1 run tag @e[type=minecraft:player,tag=fart.pushtarget] remove fart.pushtarget
execute as @e[tag=fart.pushtarget,type=minecraft:player] at @s run function fartpack:push/player
execute as @e[tag=fart.pushtarget,type=!minecraft:player] at @s run function fartpack:push/one
tag @e[tag=fart.pushtarget] remove fart.pushtarget
tag @s remove fart.pushersrc
