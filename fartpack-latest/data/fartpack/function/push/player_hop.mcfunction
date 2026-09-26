tp @s @e[type=minecraft:marker,tag=fart.hopper,sort=nearest,limit=1]
scoreboard players remove #steps fart.var 1
execute if score #steps fart.var matches 1.. run function fartpack:push/player_step