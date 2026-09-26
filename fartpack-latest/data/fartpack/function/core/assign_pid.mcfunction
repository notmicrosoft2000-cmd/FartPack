scoreboard players add #pid_counter fart.pid 1
scoreboard players operation @s fart.pid = #pid_counter fart.pid
execute store result storage fartpack:data macro.pid int 1 run scoreboard players get @s fart.pid
function fartpack:bar/make_gas_bar with storage fartpack:data macro
execute store result score @s fart.lastx run data get entity @s Pos[0] 100
execute store result score @s fart.lastz run data get entity @s Pos[2] 100
scoreboard players set @s fart.slow 0
scoreboard players set @s fart.stress 0
scoreboard players set @s fart.hurtt 0
scoreboard players set @s fart.sndt 0
scoreboard players set @s fart.pressure 0
tag @s add fart.has_pid
tellraw @s [{"text":"[FartPack] ","color":"green"},{"text":"Welcome! Your Gas Pressure bar is in the top right.","color":"yellow"}]
tellraw @s [{"text":"  ","color":"gray"},{"text":"CROUCH","color":"aqua","bold":true},{"text":" to relieve your fart - it empties the bar and HEALS you while you hold it!","color":"gray"}]
tellraw @s [{"text":"  ","color":"gray"},{"text":"Move around","color":"gold"},{"text":" to fill it faster. Full bar = a LEGENDARY mega-fart, but crouching with an EMPTY bar hurts!","color":"gray"}]
