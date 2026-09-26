scoreboard players set #neg1 fart.var -1
scoreboard players set #one fart.var 1
scoreboard players set #two fart.var 2
scoreboard players set #five fart.var 5
scoreboard players set #ten fart.var 10
scoreboard players set #twelve fart.var 12
execute store result score #tx fart.var run data get entity @s Pos[0] 10
execute store result score #tz fart.var run data get entity @s Pos[2] 10
scoreboard players operation #dx fart.var = #tx fart.var
scoreboard players operation #dx fart.var -= #ppx10 fart.var
scoreboard players operation #dz fart.var = #tz fart.var
scoreboard players operation #dz fart.var -= #ppz10 fart.var
scoreboard players operation #adx fart.var = #dx fart.var
execute if score #adx fart.var < #neg1 fart.var run scoreboard players operation #adx fart.var *= #neg1 fart.var
scoreboard players operation #adz fart.var = #dz fart.var
execute if score #adz fart.var < #neg1 fart.var run scoreboard players operation #adz fart.var *= #neg1 fart.var
scoreboard players operation #dist10 fart.var = #adx fart.var
scoreboard players operation #dist10 fart.var += #adz fart.var
execute if score #dist10 fart.var matches 0 run scoreboard players set #dist10 fart.var 1
scoreboard players operation #hop fart.var = #power fart.var
scoreboard players operation #hop fart.var /= #twelve fart.var
execute if score #hop fart.var < #one fart.var run scoreboard players set #hop fart.var 1
scoreboard players operation #ux10 fart.var = #dx fart.var
scoreboard players operation #ux10 fart.var *= #five fart.var
scoreboard players operation #ux10 fart.var /= #dist10 fart.var
scoreboard players operation #uz10 fart.var = #dz fart.var
scoreboard players operation #uz10 fart.var *= #five fart.var
scoreboard players operation #uz10 fart.var /= #dist10 fart.var
scoreboard players operation #steps fart.var = #hop fart.var
scoreboard players operation #steps fart.var *= #two fart.var
execute at @s run summon minecraft:marker ~ ~ ~ {Tags:["fart.hopper"]}
execute if score #steps fart.var matches 1.. run function fartpack:push/player_step
kill @e[type=minecraft:marker,tag=fart.hopper]