execute store result score #fpx fart.var run data get entity @s Pos[0] 100
execute store result score #fpz fart.var run data get entity @s Pos[2] 100
scoreboard players operation #dx fart.var = #fpx fart.var
scoreboard players operation #dx fart.var -= @s fart.lastx
scoreboard players operation #dz fart.var = #fpz fart.var
scoreboard players operation #dz fart.var -= @s fart.lastz
execute if score #dx fart.var < #neg1 fart.var run scoreboard players operation #dx fart.var *= #neg1 fart.var
execute if score #dz fart.var < #neg1 fart.var run scoreboard players operation #dz fart.var *= #neg1 fart.var
scoreboard players operation #fdist fart.var = #dx fart.var
scoreboard players operation #fdist fart.var += #dz fart.var
scoreboard players operation @s fart.lastx = #fpx fart.var
scoreboard players operation @s fart.lastz = #fpz fart.var
execute if score #fdist fart.var matches 1.. if score @s fart.slow matches 1.. run scoreboard players add @s fart.pressure 1
execute if score #fdist fart.var matches 1.. unless score @s fart.slow matches 1.. run scoreboard players add @s fart.pressure 2
execute if score #fdist fart.var matches 0 unless score @s fart.slow matches 1.. run scoreboard players add @s fart.pressure 1
execute if score @s fart.pressure matches 101.. run scoreboard players set @s fart.pressure 100