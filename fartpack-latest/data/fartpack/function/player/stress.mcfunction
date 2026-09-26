scoreboard players add @s fart.stress 1
execute if score @s fart.hurtt matches 1.. run scoreboard players remove @s fart.hurtt 1
execute if score @s fart.pressure matches 1.. run scoreboard players set @s fart.stress 0
execute if score @s fart.stress matches 20.. unless score @s fart.pressure matches 1.. run function fartpack:player/stress_hurt
