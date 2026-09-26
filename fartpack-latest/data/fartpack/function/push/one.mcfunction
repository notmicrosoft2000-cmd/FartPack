execute store result score #tx fart.var run data get entity @s Pos[0]
execute store result score #tz fart.var run data get entity @s Pos[2]
scoreboard players operation #dx fart.var = #tx fart.var
scoreboard players operation #dx fart.var -= #ppx fart.var
scoreboard players operation #dz fart.var = #tz fart.var
scoreboard players operation #dz fart.var -= #ppz fart.var
scoreboard players operation #adx fart.var = #dx fart.var
execute if score #adx fart.var < #neg1 fart.var run scoreboard players operation #adx fart.var *= #neg1 fart.var
scoreboard players operation #adz fart.var = #dz fart.var
execute if score #adz fart.var < #neg1 fart.var run scoreboard players operation #adz fart.var *= #neg1 fart.var
scoreboard players operation #dist fart.var = #adx fart.var
scoreboard players operation #dist fart.var += #adz fart.var
execute if score #dist fart.var matches 0 run scoreboard players set #dist fart.var 1
scoreboard players operation #vx fart.var = #power fart.var
scoreboard players operation #vx fart.var *= #dx fart.var
scoreboard players operation #vx fart.var /= #dist fart.var
scoreboard players operation #vz fart.var = #power fart.var
scoreboard players operation #vz fart.var *= #dz fart.var
scoreboard players operation #vz fart.var /= #dist fart.var
data modify storage fartpack:data motion set value [0.0,0.0,0.0]
execute store result storage fartpack:data motion[0] double 0.01 run scoreboard players get #vx fart.var
execute store result storage fartpack:data motion[1] double 0.01 run scoreboard players get #vy fart.var
execute store result storage fartpack:data motion[2] double 0.01 run scoreboard players get #vz fart.var
data modify entity @s Motion set from storage fartpack:data motion
