# Drain rate is configurable per player (admin/rel). `operation -=` is used
# rather than `players remove` because the amount has to come from a scoreboard
# holder, and `players remove` only takes an integer literal.
#
# The old two lines were an if/else that removed 1 and special-cased pressure
# being exactly 1. `operation -=` then a clamp at 0 is the same thing without
# the special case, and it is what lets the amount be a player's own setting.
# At the stock rel of 1 this is exactly equivalent: 1 becomes 0, 2 becomes 1.
scoreboard players operation @s fart.pressure -= @s fart.rel
execute if score @s fart.pressure matches ..0 run scoreboard players set @s fart.pressure 0
effect give @s minecraft:glowing 2 0 true
particle minecraft:campfire_cosy_smoke ~ ~0.3 ~ 0.2 0.1 0.2 0.005 2
scoreboard players add @s fart.sndt 1
execute if score @s fart.sndt matches 15.. run playsound minecraft:entity.player.burp player @s ~ ~ ~ 0.5 0.35
execute if score @s fart.sndt matches 15.. run playsound fartpack:fart.burp player @s ~ ~ ~ 0.6 1.0
execute if score @s fart.sndt matches 15.. run scoreboard players set @s fart.sndt 0
execute unless entity @s[tag=fart.sneak] run scoreboard players set @s fart.sndt 0
execute if score @s fart.pressure matches 0 run function fartpack:player/release_done
execute at @s run function fartpack:push/release
