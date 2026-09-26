damage @s 1 minecraft:generic
particle minecraft:crit ~ ~1.2 ~ 0.6 0.6 0.6 0.3 20
effect give @s minecraft:nausea 3 0
playsound minecraft:entity.player.hurt player @s ~ ~ ~ 1.0 0.6
execute unless score @s fart.hurtt matches 1.. run title @s actionbar [{"text":"STRAINING! ","color":"red","bold":true},{"text":"Empty gas tank - it HURTS! Get moving to build pressure!","color":"red"}]
execute unless score @s fart.hurtt matches 1.. run scoreboard players set @s fart.hurtt 100
scoreboard players set @s fart.stress 0
