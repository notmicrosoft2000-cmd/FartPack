scoreboard players set #enabled fart.var 0
scoreboard objectives setdisplay sidebar
execute as @a[tag=fart.has_pid] run function fartpack:bar/remove
kill @e[type=minecraft:marker,tag=fart.blocktimer]
tag @e remove fart.etick
tag @a remove fart.sneak
tag @a remove fart.releasing
tag @a remove fart.healtick
tag @a remove fart.healing
tag @a remove fart.warnfull
effect clear @a minecraft:regeneration
effect clear @a minecraft:hunger
effect clear @a minecraft:glowing
# Stop the weather too. tick.mcfunction returns early when #enabled is 0, so
# world/tick never runs and the rain particle loop simply freezes -- but #raining
# would still be 1, so the storm would resume the instant the pack is re-enabled,
# possibly with #rain_dur already expired. Clear it so toggling is a real stop.
scoreboard players set #raining fart.var 0
scoreboard players set #rain_c fart.var 0
scoreboard players set #event_cd fart.var 0
tellraw @a [{"text":"[FartPack] ","color":"green"},{"text":"FartPack STOPPED. All farts and gas bars cleaned up. Run /trigger fart.toggle to start it again.","color":"gray"}]