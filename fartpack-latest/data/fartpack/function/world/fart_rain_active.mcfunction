# world/fart_rain_active - ambient particles fall around every player while it's
# raining, plus a mild, non-lethal nausea pulse every 1.5s (30 ticks) as a
# reminder to get inside. Purely atmospheric - no damage, no pressure changes, so
# it cannot interfere with the gas-bar mechanics.
#
# CADENCE: this is the most expensive thing in the weather system - two `particle`
# commands PER PLAYER PER CALL. Run per-tick that is 10 commands/tick for 5
# players, every tick, for the whole 20-40s storm, which is the kind of thing
# that quietly eats the tick budget Pass C reclaimed.
#
# So world/tick drives it on an exact 3-tick gate, and the two counters here
# advance by 3 rather than 1. That keeps wall-clock behaviour EXACTLY the same:
#   #rain_dur   400-800 ticks removed 3 at a time still ends after 400-800 ticks
#   #rain_tick  still reaches 30 after 30 ticks, so nausea still pulses every 1.5s
# while cutting particle dispatch to a third. Particles have a ~1-2s lifetime and
# are spawned with a count of 2-3, so at 6 spawns/second the visual is unchanged.
scoreboard players remove #rain_dur fart.var 3
scoreboard players add #rain_tick fart.var 3
execute as @a[name=!"Server"] at @s run particle minecraft:campfire_cosy_smoke ~ ~4 ~ 1.2 0.3 1.2 0.01 3
execute as @a[name=!"Server"] at @s run particle minecraft:cloud ~ ~5 ~ 1.5 0.6 1.5 0.01 2
# EXACT gate, not a range. #rain_tick is advanced by 3 and reset here, so it can
# only ever be 3,6,...,30 - a range would be harmless today but silently starts
# running this branch on unexpected values the moment the step size changes.
execute if score #rain_tick fart.var matches 30 run scoreboard players set #rain_tick fart.var 0
# NB: `matches 0` requires the score to be SET. fart_rain_start sets #rain_tick to
# 0 explicitly, so this does fire on the first pass - but that also means nausea
# lands on tick one of the storm. Harmless (non-lethal, 2s, refreshed), left as-is.
execute if score #rain_tick fart.var matches 0 as @a[name=!"Server"] run effect give @s minecraft:nausea 40 0 true
execute if score #rain_tick fart.var matches 0 run playsound minecraft:entity.player.burp ambient @a ~ ~ ~ 0.6 0.5
execute if score #rain_dur fart.var matches ..0 run function fartpack:world/fart_rain_end
