execute if score @s fart.pressure matches 1 run scoreboard players set @s fart.pressure 0
execute if score @s fart.pressure matches 2.. run scoreboard players remove @s fart.pressure 1
effect give @s minecraft:glowing 2 0 true
particle minecraft:campfire_cosy_smoke ~ ~0.3 ~ 0.2 0.1 0.2 0.005 2
scoreboard players add @s fart.sndt 1
execute if score @s fart.sndt matches 15.. run playsound minecraft:entity.player.burp player @s ~ ~ ~ 0.5 0.35
execute if score @s fart.sndt matches 15.. run playsound fartpack:fart.burp player @s ~ ~ ~ 0.6 1.0
execute if score @s fart.sndt matches 15.. run scoreboard players set @s fart.sndt 0
execute unless entity @s[tag=fart.sneak] run scoreboard players set @s fart.sndt 0
execute if score @s fart.pressure matches 0 run function fartpack:player/release_done
execute at @s run function fartpack:push/release
