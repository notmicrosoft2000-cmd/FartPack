execute at @s rotated as @s positioned ^ ^ ^-2 run summon minecraft:marker ~ ~ ~ {Tags:["fart.selfsrc"]}
execute store result score #ppx10 fart.var run data get entity @e[type=minecraft:marker,tag=fart.selfsrc,sort=nearest,limit=1] Pos[0] 10
execute store result score #ppz10 fart.var run data get entity @e[type=minecraft:marker,tag=fart.selfsrc,sort=nearest,limit=1] Pos[2] 10
function fartpack:push/player
kill @e[type=minecraft:marker,tag=fart.selfsrc]