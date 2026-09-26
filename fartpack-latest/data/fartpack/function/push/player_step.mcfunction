execute store result score #curx10 fart.var run data get entity @e[type=minecraft:marker,tag=fart.hopper,sort=nearest,limit=1] Pos[0] 10
execute store result score #curz10 fart.var run data get entity @e[type=minecraft:marker,tag=fart.hopper,sort=nearest,limit=1] Pos[2] 10
scoreboard players operation #mx10 fart.var = #curx10 fart.var
scoreboard players operation #mx10 fart.var += #ux10 fart.var
scoreboard players operation #mz10 fart.var = #curz10 fart.var
scoreboard players operation #mz10 fart.var += #uz10 fart.var
execute store result entity @e[type=minecraft:marker,tag=fart.hopper,sort=nearest,limit=1] Pos[0] double 0.1 run scoreboard players get #mx10 fart.var
execute store result entity @e[type=minecraft:marker,tag=fart.hopper,sort=nearest,limit=1] Pos[2] double 0.1 run scoreboard players get #mz10 fart.var
execute positioned as @e[type=minecraft:marker,tag=fart.hopper,sort=nearest,limit=1] if block ~ ~ ~ #minecraft:replaceable if block ~ ~1 ~ #minecraft:replaceable run function fartpack:push/player_hop