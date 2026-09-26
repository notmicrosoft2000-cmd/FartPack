# world/tick - per-tick world work. The fart.etick set is rebuilt separately in
# world/etick on a slower cadence; see tick.mcfunction for the 30-tick cycle.
execute as @e[tag=fart.etick] at @s run function fartpack:entities/timer
execute as @e[type=minecraft:area_effect_cloud,tag=fart.gas_atomic] at @s run function fartpack:clouds/gas_apply
execute as @e[type=minecraft:area_effect_cloud,tag=fart.gas_legendary] at @s run function fartpack:clouds/gas_apply
execute as @e[type=minecraft:marker,tag=fart.blocktimer] at @s if entity @a[name=!"Server",distance=..24] run function fartpack:blocks/timer
# Gas-scoreboard reaper, every 200 ticks.
scoreboard players add #rc fart.var 1
execute if score #rc fart.var matches 200.. run function fartpack:core/reap
# Fart rain. The countdown is cheap and lives on the 30-tick cycle in
# tick.mcfunction; only the particle storm is per-tick, and that runs on an exact
# 3-tick gate to keep it off the tick budget. #rain_c wraps at 3.
#
# Deliberately NOT ported from the source fork: that version called
# world/fart_rain_tick and world/fart_event_tick every tick AND rebuilt the
# fart.etick set every tick. The etick rebuild is the single most expensive thing
# this pack did - see world/etick for the numbers - and it is already on a
# 9-in-30 cadence here. Keep those two countdowns on the 30-tick cycle.
scoreboard players add #rain_c fart.var 1
# Fire BEFORE the reset. Testing `matches 3` and then zeroing gives a clean
# every-3rd-tick cycle (1,2,FIRE,0,1,2,FIRE,0,...). Incrementing to 3 and testing
# `matches 0` instead would fire on the tick AFTER the wrap, i.e. every 4th tick -
# an easy off-by-one that still looks like it works.
execute if score #rain_c fart.var matches 3 if score #raining fart.var matches 1 run function fartpack:world/fart_rain_active
execute if score #rain_c fart.var matches 3 run scoreboard players set #rain_c fart.var 0
