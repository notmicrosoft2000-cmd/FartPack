# world/tick - per-tick world work. The fart.etick set is rebuilt separately in
# world/etick on a slower cadence; see tick.mcfunction for the 30-tick cycle.
execute as @e[tag=fart.etick] at @s run function fartpack:entities/timer
execute as @e[type=minecraft:area_effect_cloud,tag=fart.gas_atomic] at @s run function fartpack:clouds/gas_apply
execute as @e[type=minecraft:area_effect_cloud,tag=fart.gas_legendary] at @s run function fartpack:clouds/gas_apply
execute as @e[type=minecraft:marker,tag=fart.blocktimer] at @s if entity @a[name=!"Server",distance=..24] run function fartpack:blocks/timer
# Gas-scoreboard reaper, every 200 ticks.
scoreboard players add #rc fart.var 1
execute if score #rc fart.var matches 200.. run function fartpack:core/reap
