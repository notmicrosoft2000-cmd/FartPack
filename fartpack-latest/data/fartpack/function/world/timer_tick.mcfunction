execute unless score @s fart.target matches 1.. if entity @s[tag=fart.blocktimer] run execute store result score @s fart.target run random value 300..1800
execute unless score @s fart.target matches 1.. if entity @s[type=minecraft:item] run execute store result score @s fart.target run random value 120..600
execute unless score @s fart.target matches 1.. unless entity @s[tag=fart.blocktimer] unless entity @s[type=minecraft:item] run execute store result score @s fart.target run random value 30..240
scoreboard players add @s fart.cooldown 1
execute if score @s fart.cooldown >= @s fart.target run function fartpack:world/fart_time
